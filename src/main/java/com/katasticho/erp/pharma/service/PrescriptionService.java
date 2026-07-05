package com.katasticho.erp.pharma.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.pharma.dto.PrescriptionItemDto;
import com.katasticho.erp.pharma.dto.PrescriptionRequest;
import com.katasticho.erp.pharma.dto.PrescriptionResponse;
import com.katasticho.erp.pharma.entity.PrescriptionRecord;
import com.katasticho.erp.pharma.entity.PrescriptionRecordItem;
import com.katasticho.erp.pharma.register.StatutoryRegisterService;
import com.katasticho.erp.pharma.repository.PrescriptionRecordRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PrescriptionService {

    private final PrescriptionRecordRepository prescriptionRecordRepository;
    private final StatutoryRegisterService statutoryRegisterService;

    @Transactional
    public PrescriptionResponse create(PrescriptionRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PrescriptionRecord record = PrescriptionRecord.builder()
                .contactId(request.contactId())
                .receiptId(request.receiptId())
                .doctorName(request.doctorName())
                .doctorRegNumber(request.doctorRegNumber())
                .prescriptionNumber(request.prescriptionNumber())
                .prescribedDate(request.prescribedDate())
                .validUntil(request.validUntil())
                .notes(request.notes())
                .build();
        record.setOrgId(orgId);

        if (request.items() != null) {
            for (PrescriptionItemDto dto : request.items()) {
                PrescriptionRecordItem item = PrescriptionRecordItem.builder()
                        .prescriptionRecord(record)
                        .itemId(dto.itemId())
                        .itemName(dto.itemName())
                        .quantity(dto.quantity() != null ? dto.quantity() : BigDecimal.ONE)
                        .dosageInstructions(dto.dosageInstructions())
                        .build();
                record.getItems().add(item);
            }
        }

        PrescriptionRecord saved = prescriptionRecordRepository.save(record);

        // If this Rx is linked to an already-rung sale, backfill the statutory
        // register rows that were written at sale time with blank prescriber
        // columns (the common flow — the Rx is captured just after the receipt).
        if (saved.getReceiptId() != null) {
            statutoryRegisterService.backfillPrescriber(saved.getReceiptId(),
                    saved.getDoctorName(), saved.getDoctorRegNumber(), saved.getNotes());
        }

        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<PrescriptionResponse> getByContact(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return prescriptionRecordRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, contactId)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public Optional<PrescriptionResponse> getByReceipt(UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return prescriptionRecordRepository
                .findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<PrescriptionResponse> list(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return prescriptionRecordRepository
                .findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public PrescriptionResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PrescriptionRecord record = prescriptionRecordRepository
                .findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PrescriptionRecord", id));
        return toResponse(record);
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PrescriptionRecord record = prescriptionRecordRepository
                .findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PrescriptionRecord", id));
        record.setDeleted(true);
        prescriptionRecordRepository.save(record);
    }

    private PrescriptionResponse toResponse(PrescriptionRecord r) {
        List<PrescriptionItemDto> itemDtos = r.getItems() != null
                ? r.getItems().stream()
                        .map(i -> new PrescriptionItemDto(
                                i.getItemId(),
                                i.getItemName(),
                                i.getQuantity(),
                                i.getDosageInstructions()))
                        .toList()
                : Collections.emptyList();

        return new PrescriptionResponse(
                r.getId(),
                r.getContactId(),
                r.getReceiptId(),
                r.getDoctorName(),
                r.getDoctorRegNumber(),
                r.getPrescriptionNumber(),
                r.getPrescribedDate(),
                r.getValidUntil(),
                r.getNotes(),
                itemDtos,
                r.getCreatedAt());
    }
}
