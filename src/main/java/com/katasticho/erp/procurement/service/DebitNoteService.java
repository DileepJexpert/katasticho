package com.katasticho.erp.procurement.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.procurement.dto.DebitNoteLineRequest;
import com.katasticho.erp.procurement.dto.DebitNoteLineResponse;
import com.katasticho.erp.procurement.dto.DebitNoteRequest;
import com.katasticho.erp.procurement.dto.DebitNoteResponse;
import com.katasticho.erp.procurement.entity.DebitNote;
import com.katasticho.erp.procurement.entity.DebitNoteLine;
import com.katasticho.erp.procurement.repository.DebitNoteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DebitNoteService {

    private final DebitNoteRepository debitNoteRepository;
    private final ContactRepository contactRepository;

    // ── Create ──────────────────────────────────────────────────────────────

    @Transactional
    public DebitNoteResponse create(DebitNoteRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String debitNoteNumber = generateDebitNoteNumber(orgId);

        DebitNote debitNote = DebitNote.builder()
                .supplierId(request.supplierId())
                .debitNoteNumber(debitNoteNumber)
                .status("DRAFT")
                .noteDate(request.noteDate())
                .returnReason(request.returnReason())
                .referenceBillId(request.referenceBillId())
                .notes(request.notes())
                .build();

        // Build and attach lines
        List<DebitNoteLine> lines = buildLines(request.lines(), debitNote);
        debitNote.getLines().addAll(lines);

        // Calculate totals
        BigDecimal subtotal = lines.stream()
                .map(l -> l.getQuantity().multiply(l.getUnitPrice()))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(4, RoundingMode.HALF_UP);

        BigDecimal taxTotal = lines.stream()
                .map(DebitNoteLine::getTaxAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(4, RoundingMode.HALF_UP);

        debitNote.setSubtotal(subtotal);
        debitNote.setTaxAmount(taxTotal);
        debitNote.setTotalAmount(subtotal.add(taxTotal).setScale(4, RoundingMode.HALF_UP));

        DebitNote saved = debitNoteRepository.save(debitNote);
        log.info("DebitNote {} created for supplier {}", saved.getDebitNoteNumber(), saved.getSupplierId());
        return toResponse(saved);
    }

    // ── Submit (DRAFT → SUBMITTED) ───────────────────────────────────────────

    @Transactional
    public DebitNoteResponse submit(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();

        DebitNote debitNote = debitNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DebitNote", id));

        if (!"DRAFT".equals(debitNote.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT debit notes can be submitted; current status: " + debitNote.getStatus(),
                    "DEBIT_NOTE_NOT_DRAFT",
                    HttpStatus.BAD_REQUEST);
        }

        debitNote.setStatus("SUBMITTED");
        DebitNote saved = debitNoteRepository.save(debitNote);
        log.info("DebitNote {} submitted", saved.getDebitNoteNumber());
        return toResponse(saved);
    }

    // ── List ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Page<DebitNoteResponse> list(String status, UUID supplierId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Page<DebitNote> page;
        if (status != null) {
            page = debitNoteRepository.findByOrgIdAndStatusAndIsDeletedFalse(orgId, status, pageable);
        } else if (supplierId != null) {
            page = debitNoteRepository.findByOrgIdAndSupplierIdAndIsDeletedFalse(orgId, supplierId, pageable);
        } else {
            page = debitNoteRepository.findByOrgIdAndIsDeletedFalseOrderByNoteDateDesc(orgId, pageable);
        }

        return page.map(this::toResponse);
    }

    // ── Get by ID ─────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public DebitNoteResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DebitNote debitNote = debitNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DebitNote", id));
        return toResponse(debitNote);
    }

    // ── Delete (soft, DRAFT only) ─────────────────────────────────────────────

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DebitNote debitNote = debitNoteRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DebitNote", id));

        if (!"DRAFT".equals(debitNote.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT debit notes can be deleted; current status: " + debitNote.getStatus(),
                    "DEBIT_NOTE_NOT_DRAFT",
                    HttpStatus.BAD_REQUEST);
        }

        debitNote.setDeleted(true);
        debitNoteRepository.save(debitNote);
        log.info("DebitNote {} soft-deleted", debitNote.getDebitNoteNumber());
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String generateDebitNoteNumber(UUID orgId) {
        long count = debitNoteRepository.countByOrgIdAndIsDeletedFalse(orgId) + 1;
        int year = LocalDate.now().getYear();
        return "DN-" + year + "-" + String.format("%04d", count);
    }

    private List<DebitNoteLine> buildLines(List<DebitNoteLineRequest> lineRequests, DebitNote debitNote) {
        return lineRequests.stream().map(req -> {
            BigDecimal qty = req.quantity().setScale(4, RoundingMode.HALF_UP);
            BigDecimal unitPrice = req.unitPrice().setScale(4, RoundingMode.HALF_UP);
            BigDecimal taxRate = req.taxRate() != null
                    ? req.taxRate().setScale(2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            // taxAmount = quantity * unitPrice * taxRate / 100
            BigDecimal taxAmount = qty.multiply(unitPrice)
                    .multiply(taxRate)
                    .divide(BigDecimal.valueOf(100), 4, RoundingMode.HALF_UP);

            // lineTotal = quantity * unitPrice + taxAmount
            BigDecimal lineTotal = qty.multiply(unitPrice)
                    .setScale(4, RoundingMode.HALF_UP)
                    .add(taxAmount);

            return DebitNoteLine.builder()
                    .debitNote(debitNote)
                    .itemId(req.itemId())
                    .description(req.description())
                    .batchId(req.batchId())
                    .batchNumber(req.batchNumber())
                    .expiryDate(req.expiryDate())
                    .quantity(qty)
                    .unitPrice(unitPrice)
                    .taxGroupId(req.taxGroupId())
                    .hsnCode(req.hsnCode())
                    .taxRate(taxRate)
                    .taxAmount(taxAmount)
                    .lineTotal(lineTotal)
                    .build();
        }).toList();
    }

    private DebitNoteResponse toResponse(DebitNote dn) {
        String supplierName = contactRepository.findById(dn.getSupplierId())
                .map(c -> c.getDisplayName())
                .orElse("Unknown");

        List<DebitNoteLineResponse> lineResponses = dn.getLines().stream()
                .map(l -> new DebitNoteLineResponse(
                        l.getId(),
                        l.getItemId(),
                        l.getDescription(),
                        l.getBatchId(),
                        l.getBatchNumber(),
                        l.getExpiryDate(),
                        l.getQuantity(),
                        l.getUnitPrice(),
                        l.getTaxGroupId(),
                        l.getHsnCode(),
                        l.getTaxRate(),
                        l.getTaxAmount(),
                        l.getLineTotal()))
                .toList();

        return new DebitNoteResponse(
                dn.getId(),
                dn.getSupplierId(),
                supplierName,
                dn.getDebitNoteNumber(),
                dn.getStatus(),
                dn.getNoteDate(),
                dn.getReturnReason(),
                dn.getReferenceBillId(),
                dn.getNotes(),
                dn.getSubtotal(),
                dn.getTaxAmount(),
                dn.getTotalAmount(),
                lineResponses,
                dn.getCreatedAt());
    }
}
