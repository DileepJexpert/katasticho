package com.katasticho.erp.recurring.service;

import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest.BillLineRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.recurring.dto.RecurringBillDtos.*;
import com.katasticho.erp.recurring.entity.*;
import com.katasticho.erp.recurring.repository.RecurringBillGenerationRepository;
import com.katasticho.erp.recurring.repository.RecurringBillRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Recurring vendor bills — mirror of {@code RecurringInvoiceService}. A template
 * carries a JSONB line payload + a due-date cursor; {@link #generateFromTemplate}
 * drafts a PurchaseBill each period and (opt-in) posts it. Swept by
 * {@code RecurringDocumentJob}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RecurringBillService {

    private final RecurringBillRepository billRepository;
    private final RecurringBillGenerationRepository generationRepository;
    private final ContactRepository contactRepository;
    private final PurchaseBillService purchaseBillService;
    private final Clock clock;

    // ── CRUD ────────────────────────────────────────────────────────────────

    @Transactional
    public RecurringBillResponse createTemplate(CreateRecurringBillRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (req.profileName() == null || req.profileName().isBlank()) {
            throw new BusinessException("Profile name is required", "REC_BILL_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        validateFrequency(req.frequency());
        if (req.startDate() == null) {
            throw new BusinessException("Start date is required", "REC_BILL_START_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        requireEndAfterStart(req.startDate(), req.endDate());
        requireVendor(orgId, req.contactId());
        validateLines(req.lineItems());

        RecurringBill t = RecurringBill.builder()
                .profileName(req.profileName().trim())
                .contactId(req.contactId())
                .frequency(req.frequency())
                .startDate(req.startDate())
                .endDate(req.endDate())
                .nextBillDate(req.startDate())
                .lineItems(req.lineItems())
                .paymentTermsDays(req.paymentTermsDays() != null ? req.paymentTermsDays() : 0)
                .reverseCharge(req.reverseCharge())
                .placeOfSupply(req.placeOfSupply())
                .autoPost(req.autoPost())
                .status("ACTIVE")
                .notes(req.notes())
                .terms(req.terms())
                .build();
        t.setOrgId(orgId);
        t.setCreatedBy(TenantContext.getCurrentUserId());
        return RecurringBillResponse.of(billRepository.save(t));
    }

    @Transactional
    public RecurringBillResponse updateTemplate(UUID id, UpdateRecurringBillRequest req) {
        RecurringBill t = load(id);
        if ("STOPPED".equals(t.getStatus()) || "EXPIRED".equals(t.getStatus())) {
            throw new BusinessException("A stopped/expired template can't be edited",
                    "REC_BILL_NOT_EDITABLE", HttpStatus.BAD_REQUEST);
        }
        if (req.profileName() != null && !req.profileName().isBlank()) t.setProfileName(req.profileName().trim());
        if (req.frequency() != null) { validateFrequency(req.frequency()); t.setFrequency(req.frequency()); }
        if (req.endDate() != null) { requireEndAfterStart(t.getStartDate(), req.endDate()); t.setEndDate(req.endDate()); }
        if (req.paymentTermsDays() != null) t.setPaymentTermsDays(req.paymentTermsDays());
        if (req.reverseCharge() != null) t.setReverseCharge(req.reverseCharge());
        if (req.placeOfSupply() != null) t.setPlaceOfSupply(req.placeOfSupply());
        if (req.autoPost() != null) t.setAutoPost(req.autoPost());
        if (req.notes() != null) t.setNotes(req.notes());
        if (req.terms() != null) t.setTerms(req.terms());
        if (req.lineItems() != null) { validateLines(req.lineItems()); t.setLineItems(req.lineItems()); }
        return RecurringBillResponse.of(billRepository.save(t));
    }

    @Transactional
    public RecurringBillResponse stopTemplate(UUID id) {
        RecurringBill t = load(id);
        t.setStatus("STOPPED");
        return RecurringBillResponse.of(billRepository.save(t));
    }

    @Transactional
    public RecurringBillResponse resumeTemplate(UUID id) {
        RecurringBill t = load(id);
        if ("EXPIRED".equals(t.getStatus())) {
            throw new BusinessException("An expired template can't be resumed",
                    "REC_BILL_EXPIRED", HttpStatus.BAD_REQUEST);
        }
        // Snap a past cursor forward to today so it doesn't backfill missed periods.
        LocalDate today = LocalDate.now(clock);
        if (t.getNextBillDate().isBefore(today)) t.setNextBillDate(today);
        t.setStatus("ACTIVE");
        return RecurringBillResponse.of(billRepository.save(t));
    }

    @Transactional(readOnly = true)
    public RecurringBillResponse getTemplate(UUID id) {
        return RecurringBillResponse.of(load(id));
    }

    @Transactional(readOnly = true)
    public Page<RecurringBillResponse> listTemplates(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<RecurringBill> page = (status == null || status.isBlank())
                ? billRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                : billRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pageable);
        return page.map(RecurringBillResponse::of);
    }

    @Transactional(readOnly = true)
    public List<GeneratedBillResponse> listGenerated(UUID id) {
        load(id); // tenant check
        return generationRepository.findByRecurringBillIdOrderByGeneratedAtDesc(id).stream()
                .map(GeneratedBillResponse::of).toList();
    }

    // ── Generation ──────────────────────────────────────────────────────────

    @Transactional
    public UUID generateFromTemplate(UUID templateId) {
        // Org-scoped: the daily job sets TenantContext to each template's own
        // org before calling, and the generate-now endpoint must not reach a
        // foreign org's template (it passes the raw path id straight in).
        // Pessimistic lock so concurrent generate-now clicks serialise on the
        // template row and can't both post for the same cursor (double-post).
        RecurringBill t = billRepository.findByIdAndOrgIdForUpdate(
                        templateId, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Recurring bill", templateId));
        if (!"ACTIVE".equals(t.getStatus())) {
            log.warn("Skipping non-ACTIVE recurring bill {} (status={})", templateId, t.getStatus());
            return null;
        }
        if (t.getLineItems() == null || t.getLineItems().isEmpty()) {
            log.warn("Skipping recurring bill {} with no lines", templateId);
            return null;
        }
        contactRepository.findByIdAndOrgIdAndIsDeletedFalse(t.getContactId(), t.getOrgId())
                .orElseThrow(() -> new BusinessException("Template vendor contact not found",
                        "REC_BILL_CONTACT_NOT_FOUND", HttpStatus.BAD_REQUEST));

        LocalDate billDate = LocalDate.now(clock);
        LocalDate dueDate = t.getPaymentTermsDays() > 0 ? billDate.plusDays(t.getPaymentTermsDays()) : null;

        List<BillLineRequest> lines = t.getLineItems().stream()
                .map(l -> new BillLineRequest(
                        l.getLineType() != null && !l.getLineType().isBlank() ? l.getLineType() : "SERVICE",
                        l.getDescription(), l.getHsnCode(), l.getItemId(), null, l.getAccountCode(),
                        l.getQuantity() != null ? l.getQuantity() : BigDecimal.ONE,
                        l.getUnitPrice() != null ? l.getUnitPrice() : BigDecimal.ZERO,
                        l.getDiscountPercent(), l.getGstRate(), null, l.getUnitUomId(), null, null))
                .toList();

        CreatePurchaseBillRequest req = new CreatePurchaseBillRequest(
                t.getContactId(), null, billDate, dueDate, t.getPlaceOfSupply(), t.isReverseCharge(),
                "Auto-generated from recurring bill: " + t.getProfileName()
                        + (t.getNotes() != null ? "\n\n" + t.getNotes() : ""),
                t.getTerms(), null, null, lines);

        PurchaseBillResponse bill = purchaseBillService.createBill(req);
        boolean posted = false;
        if (t.isAutoPost()) {
            try {
                purchaseBillService.postBill(bill.id());
                posted = true;
            } catch (Exception e) {
                // Leave the DRAFT — a human can post it. Don't fail the sweep.
                log.warn("Auto-post failed for recurring bill {} -> {}: {}",
                        templateId, bill.billNumber(), e.getMessage());
            }
        }

        generationRepository.save(RecurringBillGeneration.builder()
                .recurringBillId(t.getId()).billId(bill.id()).autoPosted(posted).build());

        RecurringFrequency freq = RecurringFrequency.valueOf(t.getFrequency());
        LocalDate next = freq.advance(t.getNextBillDate());
        t.setNextBillDate(next);
        t.setTotalGenerated(t.getTotalGenerated() + 1);
        t.setLastGeneratedAt(Instant.now(clock));
        if (t.getEndDate() != null && next.isAfter(t.getEndDate())) {
            t.setStatus("EXPIRED");
        }
        billRepository.save(t);
        return bill.id();
    }

    @Transactional(readOnly = true)
    public List<DueTemplate> findDueTemplates() {
        return billRepository.findDueTemplates(LocalDate.now(clock)).stream()
                .map(t -> new DueTemplate(t.getId(), t.getOrgId(), t.getCreatedBy()))
                .toList();
    }

    public record DueTemplate(UUID id, UUID orgId, UUID createdBy) {}

    // ── helpers ───────────────────────────────────────────────────────────

    private RecurringBill load(UUID id) {
        return billRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Recurring bill", id));
    }

    private void validateFrequency(String frequency) {
        try {
            RecurringFrequency.valueOf(frequency);
        } catch (Exception e) {
            throw new BusinessException("Invalid frequency: " + frequency,
                    "REC_BILL_BAD_FREQUENCY", HttpStatus.BAD_REQUEST);
        }
    }

    private void requireEndAfterStart(LocalDate start, LocalDate end) {
        if (start != null && end != null && end.isBefore(start)) {
            throw new BusinessException("End date can't be before start date",
                    "REC_BILL_END_BEFORE_START", HttpStatus.BAD_REQUEST);
        }
    }

    private void requireVendor(UUID orgId, UUID contactId) {
        if (contactId == null) {
            throw new BusinessException("Vendor contact is required", "REC_BILL_CONTACT_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        Contact c = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
        String type = c.getContactType() != null ? c.getContactType().name() : "";
        if (!"VENDOR".equals(type) && !"BOTH".equals(type)) {
            throw new BusinessException("Contact is not a vendor", "REC_BILL_CONTACT_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }
    }

    private void validateLines(List<RecurringBillLineItem> lines) {
        if (lines == null || lines.isEmpty()) {
            throw new BusinessException("At least one line is required", "REC_BILL_LINES_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        for (RecurringBillLineItem l : lines) {
            if ("GOODS".equalsIgnoreCase(l.getLineType()) && l.getItemId() == null) {
                throw new BusinessException("A GOODS line needs an item",
                        "REC_BILL_GOODS_ITEM_REQUIRED", HttpStatus.BAD_REQUEST);
            }
        }
    }
}
