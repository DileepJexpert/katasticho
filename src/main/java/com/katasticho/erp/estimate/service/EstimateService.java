package com.katasticho.erp.estimate.service;

import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceLineRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.estimate.dto.CreateEstimateRequest;
import com.katasticho.erp.estimate.dto.EstimateLineRequest;
import com.katasticho.erp.estimate.dto.EstimateResponse;
import com.katasticho.erp.estimate.dto.UpdateEstimateRequest;
import com.katasticho.erp.estimate.entity.Estimate;
import com.katasticho.erp.estimate.entity.EstimateLine;
import com.katasticho.erp.estimate.entity.EstimateStatus;
import com.katasticho.erp.estimate.repository.EstimateRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Sales estimates / quotations — F9.
 *
 * Estimates are deliberately non-financial: they never touch the
 * journal. Converting an estimate to an invoice delegates to
 * {@link InvoiceService#createInvoice} so the invoice follows the
 * normal AR posting rules when it is later sent.
 *
 * Lifecycle:
 *   DRAFT → SENT → (ACCEPTED → INVOICED) | DECLINED
 *
 * Terminal states: INVOICED, DECLINED, EXPIRED.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EstimateService {

    private final EstimateRepository estimateRepository;
    private final ContactRepository contactRepository;
    private final CustomerRepository customerRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final OrganisationRepository organisationRepository;
    private final InvoiceService invoiceService;
    private final AuditService auditService;
    private final CommentService commentService;

    /** Default revenue GL used when converting estimate lines into invoice lines. */
    private static final String DEFAULT_REVENUE_ACCOUNT_CODE = "4000";

    /** States in which the seller can still edit the estimate. */
    private static final Set<String> EDITABLE_STATUSES = Set.of("DRAFT", "SENT");

    // ─────────────────────────────────────────────────────────────
    // CREATE
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public EstimateResponse createEstimate(CreateEstimateRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Contact contact = requireBuyerContact(orgId, request.contactId());

        int periodYear = computeFiscalYear(request.estimateDate(), org.getFiscalYearStart());
        String estimateNumber = generateNumber(orgId, "EST", periodYear);

        Estimate estimate = Estimate.builder()
                .orgId(orgId)
                .estimateNumber(estimateNumber)
                .contactId(contact.getId())
                .estimateDate(request.estimateDate())
                .expiryDate(request.expiryDate())
                .status(EstimateStatus.DRAFT.name())
                .currency(request.currency() != null ? request.currency() : "INR")
                .referenceNumber(request.referenceNumber())
                .subject(request.subject())
                .notes(request.notes())
                .terms(request.terms())
                .createdBy(userId)
                .build();

        buildLines(estimate, request.lines());
        recalcTotals(estimate);

        estimate = estimateRepository.save(estimate);

        auditService.log("ESTIMATE", estimate.getId(), "CREATE", null,
                "{\"estimateNumber\":\"" + estimate.getEstimateNumber()
                        + "\",\"total\":\"" + estimate.getTotal() + "\"}");
        commentService.addSystemComment("ESTIMATE", estimate.getId(), "Estimate created");

        log.info("Estimate {} created: {} lines, total={}",
                estimate.getEstimateNumber(), estimate.getLines().size(), estimate.getTotal());
        return toResponse(estimate);
    }

    // ─────────────────────────────────────────────────────────────
    // UPDATE (DRAFT / SENT only)
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public EstimateResponse updateEstimate(UUID estimateId, UpdateEstimateRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if (!EDITABLE_STATUSES.contains(estimate.getStatus())) {
            throw new BusinessException(
                    "Cannot update estimate in status " + estimate.getStatus(),
                    "EST_NOT_EDITABLE", HttpStatus.BAD_REQUEST);
        }

        if (request.contactId() != null) {
            Contact contact = requireBuyerContact(orgId, request.contactId());
            estimate.setContactId(contact.getId());
        }
        if (request.estimateDate() != null) estimate.setEstimateDate(request.estimateDate());
        if (request.expiryDate() != null) estimate.setExpiryDate(request.expiryDate());
        if (request.referenceNumber() != null) estimate.setReferenceNumber(request.referenceNumber());
        if (request.subject() != null) estimate.setSubject(request.subject());
        if (request.notes() != null) estimate.setNotes(request.notes());
        if (request.terms() != null) estimate.setTerms(request.terms());

        if (request.lines() != null) {
            if (request.lines().isEmpty()) {
                throw new BusinessException(
                        "At least one line item is required",
                        "EST_EMPTY_LINES", HttpStatus.BAD_REQUEST);
            }
            estimate.clearLines();
            buildLines(estimate, request.lines());
            recalcTotals(estimate);
        }

        estimate = estimateRepository.save(estimate);

        auditService.log("ESTIMATE", estimate.getId(), "UPDATE", null,
                "{\"total\":\"" + estimate.getTotal() + "\"}");
        commentService.addSystemComment("ESTIMATE", estimate.getId(), "Estimate updated");

        return toResponse(estimate);
    }

    // ─────────────────────────────────────────────────────────────
    // DELETE (DRAFT only)
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public void deleteEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if (!"DRAFT".equals(estimate.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT estimates can be deleted",
                    "EST_DELETE_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        estimate.setDeleted(true);
        estimateRepository.save(estimate);

        auditService.log("ESTIMATE", estimate.getId(), "DELETE", null, null);
        log.info("Estimate {} deleted", estimate.getEstimateNumber());
    }

    // ─────────────────────────────────────────────────────────────
    // LIFECYCLE: send / accept / decline
    // ─────────────────────────────────────────────────────────────
    @Transactional
    public EstimateResponse sendEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if (!"DRAFT".equals(estimate.getStatus()) && !"SENT".equals(estimate.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT or SENT estimates can be (re)sent",
                    "EST_SEND_INVALID", HttpStatus.BAD_REQUEST);
        }

        estimate.setStatus(EstimateStatus.SENT.name());
        estimate.setSentAt(Instant.now());
        estimate = estimateRepository.save(estimate);

        // Best-effort: include recipient email in the comment.
        String sendComment = "Estimate sent";
        Contact contact = contactRepository.findById(estimate.getContactId()).orElse(null);
        if (contact != null && contact.getEmail() != null && !contact.getEmail().isBlank()) {
            sendComment = "Estimate emailed to " + contact.getEmail();
        }
        commentService.addSystemComment("ESTIMATE", estimate.getId(), sendComment);

        auditService.log("ESTIMATE", estimate.getId(), "SEND", null,
                "{\"status\":\"SENT\"}");
        log.info("Estimate {} sent", estimate.getEstimateNumber());
        return toResponse(estimate);
    }

    @Transactional
    public EstimateResponse acceptEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if (!"SENT".equals(estimate.getStatus()) && !"DRAFT".equals(estimate.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT or SENT estimates can be accepted",
                    "EST_ACCEPT_INVALID", HttpStatus.BAD_REQUEST);
        }

        estimate.setStatus(EstimateStatus.ACCEPTED.name());
        estimate.setAcceptedAt(Instant.now());
        estimate = estimateRepository.save(estimate);

        auditService.log("ESTIMATE", estimate.getId(), "ACCEPT", null, null);
        commentService.addSystemComment("ESTIMATE", estimate.getId(), "Estimate accepted by customer");
        return toResponse(estimate);
    }

    @Transactional
    public EstimateResponse declineEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if ("INVOICED".equals(estimate.getStatus())) {
            throw new BusinessException(
                    "Cannot decline an invoiced estimate",
                    "EST_DECLINE_INVOICED", HttpStatus.BAD_REQUEST);
        }

        estimate.setStatus(EstimateStatus.DECLINED.name());
        estimate.setDeclinedAt(Instant.now());
        estimate = estimateRepository.save(estimate);

        auditService.log("ESTIMATE", estimate.getId(), "DECLINE", null, null);
        commentService.addSystemComment("ESTIMATE", estimate.getId(), "Estimate declined");
        return toResponse(estimate);
    }

    // ─────────────────────────────────────────────────────────────
    // CONVERT TO INVOICE
    // ─────────────────────────────────────────────────────────────
    /**
     * Copies the estimate lines into a fresh DRAFT invoice. The invoice
     * is posted through {@link InvoiceService#createInvoice} which
     * handles tax calculation, price-list resolution and journal
     * preparation. Caller is expected to review + send the invoice.
     */
    @Transactional
    public InvoiceResponse convertToInvoice(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if ("INVOICED".equals(estimate.getStatus())) {
            throw new BusinessException(
                    "Estimate has already been converted to invoice",
                    "EST_ALREADY_INVOICED", HttpStatus.BAD_REQUEST);
        }
        if ("DECLINED".equals(estimate.getStatus())) {
            throw new BusinessException(
                    "Cannot convert a declined estimate",
                    "EST_CONVERT_DECLINED", HttpStatus.BAD_REQUEST);
        }
        if (estimate.getLines().isEmpty()) {
            throw new BusinessException(
                    "Estimate has no line items",
                    "EST_EMPTY", HttpStatus.BAD_REQUEST);
        }

        // After V2__unified_contact, contact.id and customer.id share the same UUID
        // for CUSTOMER/BOTH contacts, so we can pass the same value to both fields.
        // Validate there's actually a Customer row for this contact.
        customerRepository.findByIdAndOrgIdAndIsDeletedFalse(estimate.getContactId(), orgId)
                .orElseThrow(() -> new BusinessException(
                        "Estimate contact is not a customer — add them to customers first",
                        "EST_CONTACT_NOT_CUSTOMER", HttpStatus.BAD_REQUEST));

        List<InvoiceLineRequest> invoiceLines = estimate.getLines().stream()
                .map(l -> new InvoiceLineRequest(
                        l.getDescription(),
                        l.getHsnCode(),
                        l.getQuantity(),
                        l.getRate(),
                        l.getDiscountPct(),
                        l.getTaxRate(),
                        DEFAULT_REVENUE_ACCOUNT_CODE,
                        l.getItemId(),
                        null,
                        null))
                .toList();

        CreateInvoiceRequest invoiceRequest = new CreateInvoiceRequest(
                estimate.getContactId(),  // customerId
                estimate.getContactId(),  // contactId
                LocalDate.now(),
                null,                      // dueDate — InvoiceService derives from customer terms
                null,                      // placeOfSupply — derived
                false,                     // reverseCharge
                joinNotes(estimate),
                estimate.getTerms(),
                invoiceLines);

        InvoiceResponse invoice = invoiceService.createInvoice(invoiceRequest);

        estimate.setStatus(EstimateStatus.INVOICED.name());
        estimate.setConvertedToInvoiceId(invoice.id());
        estimate.setConvertedAt(Instant.now());
        estimateRepository.save(estimate);

        auditService.log("ESTIMATE", estimate.getId(), "CONVERT", null,
                "{\"invoiceId\":\"" + invoice.id() + "\"}");
        commentService.addSystemComment("ESTIMATE", estimate.getId(),
                "Converted to invoice " + invoice.invoiceNumber());

        log.info("Estimate {} converted to invoice {}",
                estimate.getEstimateNumber(), invoice.invoiceNumber());
        return invoice;
    }

    // ─────────────────────────────────────────────────────────────
    // READ
    // ─────────────────────────────────────────────────────────────
    @Transactional(readOnly = true)
    public EstimateResponse getEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));
        return toResponse(estimate);
    }

    @Transactional(readOnly = true)
    public Page<EstimateResponse> listEstimates(String status, UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Page<Estimate> page;
        if (contactId != null) {
            page = estimateRepository
                    .findByOrgIdAndContactIdAndIsDeletedFalseOrderByEstimateDateDescCreatedAtDesc(
                            orgId, contactId, pageable);
        } else if (status != null && !status.isBlank()) {
            page = estimateRepository
                    .findByOrgIdAndStatusAndIsDeletedFalseOrderByEstimateDateDescCreatedAtDesc(
                            orgId, status, pageable);
        } else {
            page = estimateRepository
                    .findByOrgIdAndIsDeletedFalseOrderByEstimateDateDescCreatedAtDesc(orgId, pageable);
        }
        return page.map(this::toResponse);
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────
    private Contact requireBuyerContact(UUID orgId, UUID contactId) {
        Contact contact = contactRepository.findById(contactId)
                .filter(c -> orgId.equals(c.getOrgId()) && !c.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
        // CUSTOMER or BOTH only — VENDOR-only contacts shouldn't receive estimates.
        String type = contact.getContactType() != null ? contact.getContactType().name() : "";
        if (!"CUSTOMER".equals(type) && !"BOTH".equals(type)) {
            throw new BusinessException(
                    "Contact " + contact.getDisplayName() + " is not a customer",
                    "EST_CONTACT_NOT_CUSTOMER", HttpStatus.BAD_REQUEST);
        }
        return contact;
    }

    private void buildLines(Estimate estimate, List<EstimateLineRequest> lineRequests) {
        for (int i = 0; i < lineRequests.size(); i++) {
            EstimateLineRequest req = lineRequests.get(i);
            BigDecimal amount = computeLineAmount(req);

            EstimateLine line = EstimateLine.builder()
                    .lineNumber(i + 1)
                    .itemId(req.itemId())
                    .description(req.description())
                    .unit(req.unit())
                    .hsnCode(req.hsnCode())
                    .quantity(req.quantity())
                    .rate(req.rate())
                    .discountPct(req.discountPct())
                    .taxRate(req.taxRate())
                    .amount(amount)
                    .build();
            estimate.addLine(line);
        }
    }

    private BigDecimal computeLineAmount(EstimateLineRequest req) {
        BigDecimal gross = req.quantity().multiply(req.rate())
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal discount = gross.multiply(req.discountPct())
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        BigDecimal taxable = gross.subtract(discount);
        BigDecimal tax = taxable.multiply(req.taxRate())
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        return taxable.add(tax).setScale(2, RoundingMode.HALF_UP);
    }

    private void recalcTotals(Estimate estimate) {
        BigDecimal subtotal = BigDecimal.ZERO;
        BigDecimal discount = BigDecimal.ZERO;
        BigDecimal tax = BigDecimal.ZERO;

        for (EstimateLine l : estimate.getLines()) {
            BigDecimal gross = l.getQuantity().multiply(l.getRate())
                    .setScale(2, RoundingMode.HALF_UP);
            BigDecimal lineDiscount = gross.multiply(l.getDiscountPct())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal taxable = gross.subtract(lineDiscount);
            BigDecimal lineTax = taxable.multiply(l.getTaxRate())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

            subtotal = subtotal.add(taxable);
            discount = discount.add(lineDiscount);
            tax = tax.add(lineTax);
        }

        estimate.setSubtotal(subtotal.setScale(2, RoundingMode.HALF_UP));
        estimate.setDiscountAmount(discount.setScale(2, RoundingMode.HALF_UP));
        estimate.setTaxAmount(tax.setScale(2, RoundingMode.HALF_UP));
        estimate.setTotal(subtotal.add(tax).setScale(2, RoundingMode.HALF_UP));
    }

    private String joinNotes(Estimate estimate) {
        StringBuilder sb = new StringBuilder("Converted from estimate ").append(estimate.getEstimateNumber());
        if (estimate.getNotes() != null && !estimate.getNotes().isBlank()) {
            sb.append("\n\n").append(estimate.getNotes());
        }
        return sb.toString();
    }

    private String generateNumber(UUID orgId, String prefix, int year) {
        var seqOpt = sequenceRepository.findByOrgIdAndPrefixAndYear(orgId, prefix, year);
        long nextVal;
        if (seqOpt.isPresent()) {
            nextVal = seqOpt.get().getNextValue();
            sequenceRepository.incrementAndGet(orgId, prefix, year);
        } else {
            var seq = InvoiceNumberSequence.builder()
                    .id(new InvoiceNumberSequence.InvoiceNumberSequenceId(orgId, prefix, year))
                    .nextValue(2L)
                    .build();
            sequenceRepository.save(seq);
            nextVal = 1L;
        }
        return String.format("%s-%d-%06d", prefix, year, nextVal);
    }

    private int computeFiscalYear(LocalDate date, int fiscalYearStartMonth) {
        return date.getMonthValue() >= fiscalYearStartMonth ? date.getYear() : date.getYear() - 1;
    }

    private EstimateResponse toResponse(Estimate e) {
        String contactName = null;
        if (e.getContactId() != null) {
            Contact c = contactRepository.findById(e.getContactId()).orElse(null);
            if (c != null) contactName = c.getDisplayName();
        }

        List<EstimateResponse.LineResponse> lineResponses = e.getLines().stream()
                .map(l -> new EstimateResponse.LineResponse(
                        l.getId(),
                        l.getLineNumber(),
                        l.getItemId(),
                        l.getDescription(),
                        l.getUnit(),
                        l.getHsnCode(),
                        l.getQuantity(),
                        l.getRate(),
                        l.getDiscountPct(),
                        l.getTaxRate(),
                        l.getAmount()))
                .toList();

        return new EstimateResponse(
                e.getId(),
                e.getEstimateNumber(),
                e.getContactId(),
                contactName,
                e.getEstimateDate(),
                e.getExpiryDate(),
                e.getStatus(),
                e.getSubtotal(),
                e.getDiscountAmount(),
                e.getTaxAmount(),
                e.getTotal(),
                e.getCurrency(),
                e.getReferenceNumber(),
                e.getSubject(),
                e.getNotes(),
                e.getTerms(),
                e.getConvertedToInvoiceId(),
                e.getConvertedAt(),
                e.getSentAt(),
                e.getAcceptedAt(),
                e.getDeclinedAt(),
                lineResponses,
                e.getCreatedAt());
    }
}
