package com.katasticho.erp.indent.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.indent.dto.IndentRequest;
import com.katasticho.erp.indent.dto.IndentResponse;
import com.katasticho.erp.indent.dto.IndentSummary;
import com.katasticho.erp.indent.entity.CustomerIndent;
import com.katasticho.erp.indent.repository.CustomerIndentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class CustomerIndentService {

    private final CustomerIndentRepository indentRepository;

    public IndentResponse create(IndentRequest req) {
        CustomerIndent indent = new CustomerIndent();
        indent.setContactId(req.contactId());
        indent.setContactName(req.contactName());
        indent.setContactPhone(req.contactPhone());
        indent.setItemId(req.itemId());
        indent.setItemName(req.itemName());
        indent.setSku(req.sku());
        if (req.requestedQty() != null) {
            indent.setRequestedQty(req.requestedQty());
        }
        indent.setUnit(req.unit());
        indent.setNotes(req.notes());
        indent.setPromisedDate(req.promisedDate());
        indent.setStatus("PENDING");

        indent = indentRepository.save(indent);
        log.info("Created customer indent {} for item {} (org={})", indent.getId(), indent.getItemId(), indent.getOrgId());
        return toResponse(indent);
    }

    @Transactional(readOnly = true)
    public Page<IndentResponse> list(String status, int page, int size) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Pageable pageable = PageRequest.of(page, size);

        Page<CustomerIndent> indents;
        if (status != null && !status.isBlank()) {
            indents = indentRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pageable);
        } else {
            indents = indentRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);
        }
        return indents.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public IndentResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerIndent indent = indentRepository.findById(id)
                .filter(i -> orgId.equals(i.getOrgId()) && !i.isDeleted())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Indent not found"));
        return toResponse(indent);
    }

    public IndentResponse markOrdered(UUID id, UUID purchaseOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerIndent indent = indentRepository.findById(id)
                .filter(i -> orgId.equals(i.getOrgId()) && !i.isDeleted())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Indent not found"));

        if (!"PENDING".equals(indent.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indent must be in PENDING status to mark as ordered");
        }

        indent.setStatus("ORDERED");
        indent.setPurchaseOrderId(purchaseOrderId);
        indent = indentRepository.save(indent);
        log.info("Indent {} marked as ORDERED (PO={})", id, purchaseOrderId);
        return toResponse(indent);
    }

    public IndentResponse markArrived(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerIndent indent = indentRepository.findById(id)
                .filter(i -> orgId.equals(i.getOrgId()) && !i.isDeleted())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Indent not found"));

        if (!"ORDERED".equals(indent.getStatus()) && !"PENDING".equals(indent.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indent must be in PENDING or ORDERED status to mark as arrived");
        }

        indent.setStatus("ARRIVED");
        indent = indentRepository.save(indent);
        log.info("Indent {} marked as ARRIVED", id);
        return toResponse(indent);
    }

    public IndentResponse markFulfilled(UUID id, UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerIndent indent = indentRepository.findById(id)
                .filter(i -> orgId.equals(i.getOrgId()) && !i.isDeleted())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Indent not found"));

        if (!"ARRIVED".equals(indent.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indent must be in ARRIVED status to mark as fulfilled");
        }

        indent.setStatus("FULFILLED");
        indent.setFulfilledReceiptId(receiptId);
        indent.setFulfilledAt(Instant.now());
        indent = indentRepository.save(indent);
        log.info("Indent {} marked as FULFILLED (receipt={})", id, receiptId);
        return toResponse(indent);
    }

    public void cancel(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerIndent indent = indentRepository.findById(id)
                .filter(i -> orgId.equals(i.getOrgId()) && !i.isDeleted())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Indent not found"));

        if ("FULFILLED".equals(indent.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot cancel a fulfilled indent");
        }

        indent.setStatus("CANCELLED");
        indentRepository.save(indent);
        log.info("Indent {} cancelled", id);
    }

    public void onStockReceived(UUID orgId, UUID itemId) {
        List<CustomerIndent> indents = indentRepository.findByOrgIdAndItemIdAndStatusInAndIsDeletedFalse(
                orgId, itemId, List.of("PENDING", "ORDERED"));

        for (CustomerIndent indent : indents) {
            String previousStatus = indent.getStatus();
            indent.setStatus("ARRIVED");
            indentRepository.save(indent);
            log.info("Indent {} auto-transitioned from {} to ARRIVED on stock receipt (org={}, item={})",
                    indent.getId(), previousStatus, orgId, itemId);
        }

        if (!indents.isEmpty()) {
            log.info("Auto-transitioned {} indent(s) to ARRIVED for item {} in org {}", indents.size(), itemId, orgId);
        }
    }

    @Transactional(readOnly = true)
    public IndentSummary summary() {
        UUID orgId = TenantContext.getCurrentOrgId();
        long pending = indentRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING");
        long ordered = indentRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "ORDERED");
        long arrived = indentRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "ARRIVED");
        return new IndentSummary(pending, ordered, arrived);
    }

    private IndentResponse toResponse(CustomerIndent indent) {
        return new IndentResponse(
                indent.getId(),
                indent.getContactId(),
                indent.getContactName(),
                indent.getContactPhone(),
                indent.getItemId(),
                indent.getItemName(),
                indent.getSku(),
                indent.getRequestedQty(),
                indent.getUnit(),
                indent.getNotes(),
                indent.getStatus(),
                indent.getPurchaseOrderId(),
                indent.getPromisedDate(),
                indent.getFulfilledReceiptId(),
                indent.getFulfilledAt(),
                indent.getCreatedAt(),
                indent.getCreatedBy()
        );
    }
}
