package com.katasticho.erp.recurring.service;

import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceLineRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.recurring.dto.CreateRecurringInvoiceRequest;
import com.katasticho.erp.recurring.dto.GeneratedInvoiceResponse;
import com.katasticho.erp.recurring.dto.RecurringInvoiceResponse;
import com.katasticho.erp.recurring.dto.RecurringLineItemRequest;
import com.katasticho.erp.recurring.dto.UpdateRecurringInvoiceRequest;
import com.katasticho.erp.recurring.entity.RecurringFrequency;
import com.katasticho.erp.recurring.entity.RecurringInvoice;
import com.katasticho.erp.recurring.entity.RecurringInvoiceGeneration;
import com.katasticho.erp.recurring.entity.RecurringLineItem;
import com.katasticho.erp.recurring.entity.RecurringStatus;
import com.katasticho.erp.recurring.repository.RecurringInvoiceGenerationRepository;
import com.katasticho.erp.recurring.repository.RecurringInvoiceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Recurring invoices — F8.
 *
 * A template is a non-financial record. When the scheduler (or a
 * manual trigger) fires {@link #generateFromTemplate}, it delegates
 * to {@link InvoiceService#createInvoice} so the resulting invoice
 * follows the normal AR posting rules. Each generation is logged
 * in {@code recurring_invoice_generation} for the detail screen.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RecurringInvoiceService {

    private final RecurringInvoiceRepository templateRepository;
    private final RecurringInvoiceGenerationRepository generationRepository;
    private final ContactRepository contactRepository;
    private final CustomerRepository customerRepository;
    private final InvoiceRepository invoiceRepository;
    private final InvoiceService invoiceService;
    private final AuditService auditService;
    private final CommentService commentService;

    /** Default revenue GL used when a template line omits {@code accountCode}. */
    private static final String DEFAULT_REVENUE_ACCOUNT_CODE = "4000";

    private static final Set<String> VALID_FREQUENCIES = Set.of(
            "WEEKLY", "MONTHLY", "QUARTERLY", "HALF_YEARLY", "YEARLY");

    // ─────────────────────────────────────────────────────────────
    // CREATE
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public RecurringInvoiceResponse createTemplate(CreateRecurringInvoiceRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Contact contact = requireBuyerContact(orgId, request.contactId());
        String frequency = validateFrequency(request.frequency());

        if (request.endDate() != null && request.endDate().isBefore(request.startDate())) {
            throw new BusinessException(
                    "End date cannot be before start date",
                    "REC_END_BEFORE_START", HttpStatus.BAD_REQUEST);
        }

        LocalDate nextDate = request.nextInvoiceDate() != null
                ? request.nextInvoiceDate()
                : request.startDate();

        RecurringInvoice template = RecurringInvoice.builder()
                .orgId(orgId)
                .profileName(request.profileName())
                .contactId(contact.getId())
                .frequency(frequency)
                .startDate(request.startDate())
                .endDate(request.endDate())
                .nextInvoiceDate(nextDate)
                .paymentTermsDays(request.paymentTermsDays() != null ? request.paymentTermsDays() : 0)
                .autoSend(Boolean.TRUE.equals(request.autoSend()))
                .status(RecurringStatus.ACTIVE.name())
                .currency(request.currency() != null ? request.currency() : "INR")
                .notes(request.notes())
                .terms(request.terms())
                .lineItems(toEntityLines(request.lineItems()))
                .createdBy(userId)
                .build();

        template = templateRepository.save(template);

        auditService.log("RECURRING_INVOICE", template.getId(), "CREATE", null,
                "{\"profileName\":\"" + template.getProfileName()
                        + "\",\"frequency\":\"" + template.getFrequency() + "\"}");
        commentService.addSystemComment("RECURRING_INVOICE", template.getId(),
                "Recurring invoice template created");

        log.info("Recurring template {} created: {} lines, freq={}, next={}",
                template.getProfileName(),
                template.getLineItems().size(),
                template.getFrequency(),
                template.getNextInvoiceDate());
        return toResponse(template);
    }

    // ─────────────────────────────────────────────────────────────
    // UPDATE
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public RecurringInvoiceResponse updateTemplate(UUID templateId, UpdateRecurringInvoiceRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        RecurringInvoice template = templateRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Recurring invoice", templateId));

        if ("STOPPED".equals(template.getStatus()) || "EXPIRED".equals(template.getStatus())) {
            throw new BusinessException(
                    "Cannot update a " + template.getStatus().toLowerCase() + " template",
                    "REC_NOT_EDITABLE", HttpStatus.BAD_REQUEST);
        }

        if (request.profileName() != null) template.setProfileName(request.profileName());
        if (request.contactId() != null) {
            Contact contact = requireBuyerContact(orgId, request.contactId());
            template.setContactId(contact.getId());
        }
        if (request.frequency() != null) {
            template.setFrequency(validateFrequency(request.frequency()));
        }
        if (request.startDate() != null) template.setStartDate(request.startDate());
        if (request.endDate() != null) template.setEndDate(request.endDate());
        if (request.nextInvoiceDate() != null) template.setNextInvoiceDate(request.nextInvoiceDate());
        if (request.paymentTermsDays() != null) template.setPaymentTermsDays(request.paymentTermsDays());
        if (request.autoSend() != null) template.setAutoSend(request.autoSend());
        if (request.currency() != null) template.setCurrency(request.currency());
        if (request.notes() != null) template.setNotes(request.notes());
        if (request.terms() != null) template.setTerms(request.terms());
        if (request.lineItems() != null) {
            if (request.lineItems().isEmpty()) {
                throw new BusinessException(
                        "At least one line item is required",
                        "REC_EMPTY_LINES", HttpStatus.BAD_REQUEST);
            }
            template.setLineItems(toEntityLines(request.lineItems()));
        }

        if (template.getEndDate() != null && template.getEndDate().isBefore(template.getStartDate())) {
            throw new BusinessException(
                    "End date cannot be before start date",
                    "REC_END_BEFORE_START", HttpStatus.BAD_REQUEST);
        }

        template = templateRepository.save(template);

        auditService.log("RECURRING_INVOICE", template.getId(), "UPDATE", null, null);
        commentService.addSystemComment("RECURRING_INVOICE", template.getId(),
                "Recurring invoice template updated");
        return toResponse(template);
    }

    // ─────────────────────────────────────────────────────────────
    // STOP / RESUME / PAUSE
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public RecurringInvoiceResponse stopTemplate(UUID templateId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        RecurringInvoice template = templateRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Recurring invoice", templateId));

        if ("STOPPED".equals(template.getStatus())) {
            return toResponse(template);
        }

        template.setStatus(RecurringStatus.STOPPED.name());
        template = templateRepository.save(template);

        auditService.log("RECURRING_INVOICE", template.getId(), "STOP", null, null);
        commentService.addSystemComment("RECURRING_INVOICE", template.getId(),
                "Recurring template stopped");
        return toResponse(template);
    }

    @Transactional
    public RecurringInvoiceResponse resumeTemplate(UUID templateId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        RecurringInvoice template = templateRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Recurring invoice", templateId));

        if ("EXPIRED".equals(template.getStatus())) {
            throw new BusinessException(
                    "Cannot resume an expired template — extend the end date first",
                    "REC_EXPIRED", HttpStatus.BAD_REQUEST);
        }

        template.setStatus(RecurringStatus.ACTIVE.name());
        // If next_invoice_date slid into the past while paused, snap it forward to today.
        if (template.getNextInvoiceDate().isBefore(LocalDate.now())) {
            template.setNextInvoiceDate(LocalDate.now());
        }
        template = templateRepository.save(template);

        auditService.log("RECURRING_INVOICE", template.getId(), "RESUME", null, null);
        commentService.addSystemComment("RECURRING_INVOICE", template.getId(),
                "Recurring template resumed");
        return toResponse(template);
    }

    // ─────────────────────────────────────────────────────────────
    // READ
    // ─────────────────────────────────────────────────────────────
    @Transactional(readOnly = true)
    public RecurringInvoiceResponse getTemplate(UUID templateId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        RecurringInvoice template = templateRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Recurring invoice", templateId));
        return toResponse(template);
    }

    @Transactional(readOnly = true)
    public Page<RecurringInvoiceResponse> listTemplates(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Page<RecurringInvoice> page;
        if (status != null && !status.isBlank()) {
            page = templateRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                    orgId, status, pageable);
        } else {
            page = templateRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);
        }
        return page.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public List<GeneratedInvoiceResponse> listGeneratedInvoices(UUID templateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Verify template belongs to this tenant before dumping its generations.
        templateRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Recurring invoice", templateId));

        List<RecurringInvoiceGeneration> generations =
                generationRepository.findByRecurringInvoiceIdOrderByGeneratedAtDesc(templateId);
        if (generations.isEmpty()) return List.of();

        // Batch-load invoices to avoid N+1.
        Map<UUID, Invoice> invoicesById = invoiceRepository
                .findAllById(generations.stream().map(RecurringInvoiceGeneration::getInvoiceId).toList())
                .stream()
                .collect(Collectors.toMap(Invoice::getId, i -> i));

        return generations.stream()
                .map(gen -> {
                    Invoice inv = invoicesById.get(gen.getInvoiceId());
                    return new GeneratedInvoiceResponse(
                            gen.getInvoiceId(),
                            inv != null ? inv.getInvoiceNumber() : null,
                            inv != null ? inv.getInvoiceDate() : null,
                            inv != null ? inv.getTotalAmount() : null,
                            inv != null ? inv.getStatus() : null,
                            gen.isAutoSent(),
                            gen.getGeneratedAt());
                })
                .toList();
    }

    // ─────────────────────────────────────────────────────────────
    // GENERATE (scheduler + manual)
    // ─────────────────────────────────────────────────────────────
    /**
     * Mint a single invoice from a template, advance the cursor,
     * and log the generation. Called by {@code RecurringInvoiceJob}
     * once per due template with the tenant context already set.
     * Each call is its own transaction so one bad template can't
     * roll back the whole batch.
     *
     * @return the created invoice, or empty if the template was
     *         skipped (e.g. expired mid-run).
     */
    @Transactional
    public InvoiceResponse generateFromTemplate(UUID templateId) {
        RecurringInvoice template = templateRepository.findById(templateId)
                .orElseThrow(() -> BusinessException.notFound("Recurring invoice", templateId));

        if (!"ACTIVE".equals(template.getStatus())) {
            log.warn("Skipping non-ACTIVE template {} (status={})",
                    templateId, template.getStatus());
            return null;
        }
        if (template.getLineItems() == null || template.getLineItems().isEmpty()) {
            log.warn("Skipping template {} with no line items", templateId);
            return null;
        }

        // Ensure the buyer is still a valid customer.
        customerRepository.findByIdAndOrgIdAndIsDeletedFalse(template.getContactId(), template.getOrgId())
                .orElseThrow(() -> new BusinessException(
                        "Template buyer is no longer a customer",
                        "REC_CONTACT_NOT_CUSTOMER", HttpStatus.BAD_REQUEST));

        LocalDate invoiceDate = LocalDate.now();
        LocalDate dueDate = template.getPaymentTermsDays() > 0
                ? invoiceDate.plusDays(template.getPaymentTermsDays())
                : null;

        List<InvoiceLineRequest> invoiceLines = template.getLineItems().stream()
                .map(l -> new InvoiceLineRequest(
                        l.getDescription(),
                        l.getHsnCode(),
                        l.getQuantity() != null ? l.getQuantity() : BigDecimal.ONE,
                        l.getRate() != null ? l.getRate() : BigDecimal.ZERO,
                        l.getDiscountPct() != null ? l.getDiscountPct() : BigDecimal.ZERO,
                        l.getTaxRate() != null ? l.getTaxRate() : BigDecimal.ZERO,
                        l.getAccountCode() != null && !l.getAccountCode().isBlank()
                                ? l.getAccountCode()
                                : DEFAULT_REVENUE_ACCOUNT_CODE,
                        l.getItemId(),
                        null,
                        null))
                .toList();

        CreateInvoiceRequest invoiceRequest = new CreateInvoiceRequest(
                template.getContactId(),   // customerId
                template.getContactId(),   // contactId
                invoiceDate,
                dueDate,
                null,                       // placeOfSupply — derived
                false,                      // reverseCharge
                template.getNotes() != null
                        ? "Auto-generated from template: " + template.getProfileName()
                                + "\n\n" + template.getNotes()
                        : "Auto-generated from template: " + template.getProfileName(),
                template.getTerms(),
                invoiceLines);

        InvoiceResponse invoice = invoiceService.createInvoice(invoiceRequest);
        boolean autoSent = false;

        if (template.isAutoSend()) {
            try {
                invoiceService.sendInvoice(invoice.id());
                autoSent = true;
            } catch (Exception e) {
                // Don't fail the whole generation — the invoice is
                // already a valid DRAFT that a human can send later.
                log.warn("Auto-send failed for invoice {}: {}",
                        invoice.invoiceNumber(), e.getMessage());
            }
        }

        // Audit trail link row
        generationRepository.save(RecurringInvoiceGeneration.builder()
                .recurringInvoiceId(template.getId())
                .invoiceId(invoice.id())
                .autoSent(autoSent)
                .build());

        // Advance the cursor.
        RecurringFrequency freq = RecurringFrequency.valueOf(template.getFrequency());
        LocalDate nextDate = freq.advance(template.getNextInvoiceDate());
        template.setNextInvoiceDate(nextDate);
        template.setTotalGenerated(template.getTotalGenerated() + 1);
        template.setLastGeneratedAt(Instant.now());

        // Flip to EXPIRED if we've now overshot the end_date.
        if (template.getEndDate() != null && nextDate.isAfter(template.getEndDate())) {
            template.setStatus(RecurringStatus.EXPIRED.name());
            commentService.addSystemComment("RECURRING_INVOICE", template.getId(),
                    "Template expired after reaching end date");
        }

        templateRepository.save(template);

        commentService.addSystemComment("RECURRING_INVOICE", template.getId(),
                "Generated invoice " + invoice.invoiceNumber()
                        + (autoSent ? " (auto-sent)" : ""));
        auditService.log("RECURRING_INVOICE", template.getId(), "GENERATE", null,
                "{\"invoiceId\":\"" + invoice.id() + "\"}");

        log.info("Template {} generated invoice {} (next={})",
                template.getProfileName(), invoice.invoiceNumber(), nextDate);
        return invoice;
    }

    /**
     * Find all ACTIVE templates whose next_invoice_date is today or
     * earlier. Returned as lightweight (id, orgId) tuples so the
     * caller can set per-row tenant context before generating.
     */
    @Transactional(readOnly = true)
    public List<DueTemplate> findDueTemplates() {
        return templateRepository.findDueTemplates(LocalDate.now()).stream()
                .map(t -> new DueTemplate(t.getId(), t.getOrgId(), t.getCreatedBy()))
                .toList();
    }

    /** Lightweight handle for scheduler iteration. */
    public record DueTemplate(UUID id, UUID orgId, UUID createdBy) {}

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────
    private Contact requireBuyerContact(UUID orgId, UUID contactId) {
        Contact contact = contactRepository.findById(contactId)
                .filter(c -> orgId.equals(c.getOrgId()) && !c.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        String type = contact.getContactType() != null ? contact.getContactType().name() : "";
        if (!"CUSTOMER".equals(type) && !"BOTH".equals(type)) {
            throw new BusinessException(
                    "Contact " + contact.getDisplayName() + " is not a customer",
                    "REC_CONTACT_NOT_CUSTOMER", HttpStatus.BAD_REQUEST);
        }
        return contact;
    }

    private String validateFrequency(String frequency) {
        String upper = frequency.toUpperCase();
        if (!VALID_FREQUENCIES.contains(upper)) {
            throw new BusinessException(
                    "Invalid frequency: " + frequency
                            + " (expected one of " + VALID_FREQUENCIES + ")",
                    "REC_INVALID_FREQUENCY", HttpStatus.BAD_REQUEST);
        }
        return upper;
    }

    private List<RecurringLineItem> toEntityLines(List<RecurringLineItemRequest> requests) {
        List<RecurringLineItem> out = new ArrayList<>(requests.size());
        for (RecurringLineItemRequest r : requests) {
            out.add(RecurringLineItem.builder()
                    .itemId(r.itemId())
                    .description(r.description())
                    .unit(r.unit())
                    .hsnCode(r.hsnCode())
                    .quantity(r.quantity())
                    .rate(r.rate())
                    .discountPct(r.discountPct())
                    .taxRate(r.taxRate())
                    .accountCode(r.accountCode())
                    .build());
        }
        return out;
    }

    private BigDecimal computeLineAmount(RecurringLineItem line) {
        BigDecimal qty = line.getQuantity() != null ? line.getQuantity() : BigDecimal.ONE;
        BigDecimal rate = line.getRate() != null ? line.getRate() : BigDecimal.ZERO;
        BigDecimal disc = line.getDiscountPct() != null ? line.getDiscountPct() : BigDecimal.ZERO;
        BigDecimal tax = line.getTaxRate() != null ? line.getTaxRate() : BigDecimal.ZERO;

        BigDecimal gross = qty.multiply(rate).setScale(2, RoundingMode.HALF_UP);
        BigDecimal discount = gross.multiply(disc)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        BigDecimal taxable = gross.subtract(discount);
        BigDecimal taxAmt = taxable.multiply(tax)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        return taxable.add(taxAmt).setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal computeTemplateTotal(List<RecurringLineItem> lines) {
        return lines.stream()
                .map(this::computeLineAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
    }

    private RecurringInvoiceResponse toResponse(RecurringInvoice t) {
        String contactName = null;
        if (t.getContactId() != null) {
            Contact c = contactRepository.findById(t.getContactId()).orElse(null);
            if (c != null) contactName = c.getDisplayName();
        }

        List<RecurringInvoiceResponse.LineResponse> lineResponses = t.getLineItems().stream()
                .sorted(Comparator.comparing(
                        (RecurringLineItem l) -> l.getDescription() != null ? l.getDescription() : ""))
                .map(l -> new RecurringInvoiceResponse.LineResponse(
                        l.getItemId(),
                        l.getDescription(),
                        l.getUnit(),
                        l.getHsnCode(),
                        l.getQuantity(),
                        l.getRate(),
                        l.getDiscountPct(),
                        l.getTaxRate(),
                        l.getAccountCode(),
                        computeLineAmount(l)))
                .toList();

        return new RecurringInvoiceResponse(
                t.getId(),
                t.getProfileName(),
                t.getContactId(),
                contactName,
                t.getFrequency(),
                t.getStartDate(),
                t.getEndDate(),
                t.getNextInvoiceDate(),
                t.getPaymentTermsDays(),
                t.isAutoSend(),
                t.getStatus(),
                t.getCurrency(),
                t.getNotes(),
                t.getTerms(),
                t.getTotalGenerated(),
                t.getLastGeneratedAt(),
                computeTemplateTotal(t.getLineItems()),
                lineResponses,
                t.getCreatedAt());
    }
}
