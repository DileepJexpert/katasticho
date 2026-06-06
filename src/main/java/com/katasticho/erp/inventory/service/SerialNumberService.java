package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.SerialNumber;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.SerialNumberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SerialNumberService {

    private final SerialNumberRepository serialRepository;
    private final ItemRepository itemRepository;

    @Transactional
    public List<SerialNumber> receiveSerials(UUID itemId, UUID warehouseId, UUID batchId,
                                              UUID receiptLineId, List<String> serials) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));
        if (!item.isTrackSerialNumbers()) {
            throw new BusinessException("Item does not track serial numbers",
                    "SN_NOT_TRACKED", HttpStatus.BAD_REQUEST);
        }

        List<SerialNumber> created = new ArrayList<>();
        for (String serial : serials) {
            if (serial == null || serial.isBlank()) continue;
            String trimmed = serial.trim();

            if (serialRepository.findByOrgIdAndItemIdAndSerialAndIsDeletedFalse(orgId, itemId, trimmed).isPresent()) {
                throw new BusinessException("Serial number '" + trimmed + "' already exists for this item",
                        "SN_DUPLICATE", HttpStatus.CONFLICT);
            }

            SerialNumber sn = SerialNumber.builder()
                    .itemId(itemId)
                    .serial(trimmed)
                    .warehouseId(warehouseId)
                    .batchId(batchId)
                    .status("IN_STOCK")
                    .receivedAt(Instant.now())
                    .receiptLineId(receiptLineId)
                    .build();
            created.add(serialRepository.save(sn));
        }

        log.info("Received {} serial numbers for item {} in warehouse {}", created.size(), itemId, warehouseId);
        return created;
    }

    @Transactional
    public List<SerialNumber> assignToSale(UUID itemId, UUID warehouseId, UUID invoiceLineId,
                                            List<String> serials) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<SerialNumber> assigned = new ArrayList<>();
        for (String serial : serials) {
            if (serial == null || serial.isBlank()) continue;
            String trimmed = serial.trim();

            SerialNumber sn = serialRepository.findByOrgIdAndItemIdAndSerialAndIsDeletedFalse(orgId, itemId, trimmed)
                    .orElseThrow(() -> new BusinessException("Serial number '" + trimmed + "' not found",
                            "SN_NOT_FOUND", HttpStatus.NOT_FOUND));

            if (!"IN_STOCK".equals(sn.getStatus())) {
                throw new BusinessException("Serial '" + trimmed + "' is not available (status: " + sn.getStatus() + ")",
                        "SN_NOT_AVAILABLE", HttpStatus.BAD_REQUEST);
            }

            sn.setStatus("SOLD");
            sn.setSoldAt(Instant.now());
            sn.setInvoiceLineId(invoiceLineId);
            assigned.add(serialRepository.save(sn));
        }

        log.info("Assigned {} serial numbers for item {} to invoice line {}", assigned.size(), itemId, invoiceLineId);
        return assigned;
    }

    @Transactional
    public SerialNumber markDamaged(UUID serialId, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SerialNumber sn = serialRepository.findByIdAndOrgIdAndIsDeletedFalse(serialId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Serial Number", serialId));

        if (!"IN_STOCK".equals(sn.getStatus())) {
            throw new BusinessException("Only IN_STOCK serials can be marked damaged",
                    "SN_NOT_IN_STOCK", HttpStatus.BAD_REQUEST);
        }

        sn.setStatus("DAMAGED");
        sn.setNotes(notes);
        return serialRepository.save(sn);
    }

    @Transactional
    public SerialNumber markReturned(UUID serialId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SerialNumber sn = serialRepository.findByIdAndOrgIdAndIsDeletedFalse(serialId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Serial Number", serialId));

        if (!"SOLD".equals(sn.getStatus())) {
            throw new BusinessException("Only SOLD serials can be returned",
                    "SN_NOT_SOLD", HttpStatus.BAD_REQUEST);
        }

        sn.setStatus("RETURNED");
        sn.setSoldAt(null);
        sn.setInvoiceLineId(null);
        return serialRepository.save(sn);
    }

    @Transactional(readOnly = true)
    public List<SerialNumber> listAvailable(UUID itemId, UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (warehouseId != null) {
            return serialRepository.findByOrgIdAndItemIdAndWarehouseIdAndStatusAndIsDeletedFalse(
                    orgId, itemId, warehouseId, "IN_STOCK");
        }
        return serialRepository.findByOrgIdAndItemIdAndStatusAndIsDeletedFalse(orgId, itemId, "IN_STOCK");
    }

    @Transactional(readOnly = true)
    public Page<SerialNumber> listByItem(UUID itemId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return serialRepository.findByOrgIdAndItemIdAndIsDeletedFalse(orgId, itemId, pageable);
    }

    @Transactional(readOnly = true)
    public long countInStock(UUID itemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return serialRepository.countByOrgIdAndItemIdAndStatusAndIsDeletedFalse(orgId, itemId, "IN_STOCK");
    }
}
