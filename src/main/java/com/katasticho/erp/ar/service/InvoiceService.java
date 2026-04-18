package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.*;
import com.katasticho.erp.ar.entity.*;
import com.katasticho.erp.ar.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.service.DocumentEmailService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.tax.TaxEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.katasticho.erp.common.dto.BulkOperationResult;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Invoice lifecycle: DRAFT → SENT (posts journal) → PARTIALLY_PAID / PAID → CANCELLED
 *
 * On sendInvoice():
 *   DR Accounts Receivable (1200)
 *   CR Revenue (4010 etc.) — per line
 *   CR GST Payable (2020/2021/2022) — per tax component
 *
 * All financial writes go through journalService.postJournal().
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class InvoiceService {

    private final InvoiceRepository invoiceRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final ContactRepository contactRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final OrganisationRepository organisationRepository;
    private final BranchRepository branchRepository;
    private final JournalService journalService;
    private final TaxEngine taxEngine;
    private final CurrencyService currencyService;
    private final AuditService auditService;
    private final InventoryService inventoryService;
    private final PriceListService priceListService;
    private final CommentService commentService;
    private final DefaultAccountService defaultAccountService;
    private final DocumentEmailService documentEmailService;

    /**
     * Create a DRAFT invoice with tax calculation via TaxEngine.
     */
    @Transactional
    public InvoiceResponse createInvoice(CreateInvoiceRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));

        String placeOfSupply = request.placeOfSupply() != null
                ? request.placeOfSupply()
                : contact.getBillingStateCode();

        int periodYear = computeFiscalYear(request.invoiceDate(), org.getFiscalYearStart());
        String invoiceNumber = generateNumber(orgId, "INV", periodYear);

        LocalDate dueDate = request.dueDate() != null
                ? request.dueDate()
                : request.invoiceDate().plusDays(contact.getPaymentTermsDays());

        BigDecimal exchangeRate = currencyService.getRate("INR", org.getBaseCurrency(), request.invoiceDate());

        // Stamp the org's default branch. Multi-branch selection comes later
        // via a request field; for now every new invoice rolls up to the
        // default branch so dashboard breakdowns work out-of-the-box.
        UUID branchId = branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Branch::getId).orElse(null);

        // Build invoice
        Invoice invoice = Invoice.builder()
                .orgId(orgId)
                .branchId(branchId)
                .contactId(contact.getId())
                .invoiceNumber(invoiceNumber)
                .invoiceDate(request.invoiceDate())
                .dueDate(dueDate)
                .status("DRAFT")
                .currency("INR")
                .exchangeRate(exchangeRate)
                .placeOfSupply(placeOfSupply)
                .reverseCharge(request.reverseCharge())
                .notes(request.notes())
                .termsAndConditions(request.termsAndConditions())
                .periodYear(periodYear)
                .periodMonth(request.invoiceDate().getMonthValue())
                .createdBy(userId)
                .build();

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();

        // Process each line
        for (int i = 0; i < request.lines().size(); i++) {
            InvoiceLineRequest lineReq = request.lines().get(i);

            // Resolve unit price via the v2 F3 price list chain. Only
            // itemised lines (free-text has itemId = null) can be
            // resolved; everything else falls through to the client
            // unitPrice unchanged. The resolver walks:
            //   customer.defaultPriceListId → org default list → empty
            // and returns empty if neither step matches — in which
            // case the client price is authoritative (legacy path).
            BigDecimal effectiveUnitPrice = lineReq.unitPrice();
            if (lineReq.itemId() != null) {
                effectiveUnitPrice = priceListService
                        .resolvePrice(contact.getId(), lineReq.itemId(), lineReq.quantity())
                        .map(resolved -> {
                            if (resolved.compareTo(lineReq.unitPrice()) != 0) {
                                log.info("Price list override line {}: client={} resolved={}",
                                        lineReq.itemId(), lineReq.unitPrice(), resolved);
                            }
                            return resolved;
                        })
                        .orElse(lineReq.unitPrice());
            }

            // Calculate line amounts
            BigDecimal grossAmount = lineReq.quantity().multiply(effectiveUnitPrice)
                    .setScale(2, RoundingMode.HALF_UP);
            BigDecimal discountAmt = grossAmount.multiply(lineReq.discountPercent())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal taxableAmount = grossAmount.subtract(discountAmt);

            // Resolve tax group: prefer explicit taxGroupId, else resolve from legacy gstRate
            UUID lineTaxGroupId = lineReq.taxGroupId();
            if (lineTaxGroupId == null && lineReq.gstRate() != null
                    && lineReq.gstRate().compareTo(BigDecimal.ZERO) > 0) {
                lineTaxGroupId = taxEngine.resolveGroupId(orgId, lineReq.gstRate(),
                        org.getStateCode(), placeOfSupply).orElse(null);
            }

            // Calculate tax via database-driven TaxEngine
            TaxEngine.TaxCalculationResult taxResult = taxEngine.calculate(
                    orgId, lineTaxGroupId, taxableAmount, TaxEngine.TransactionType.SALE);

            BigDecimal lineTax = taxResult.totalTaxAmount();
            BigDecimal lineTotal = taxableAmount.add(lineTax);

            // Base currency amounts
            BigDecimal baseTaxable = taxableAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTax = lineTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTotal = lineTotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

            InvoiceLine line = InvoiceLine.builder()
                    .lineNumber(i + 1)
                    .description(lineReq.description())
                    .hsnCode(lineReq.hsnCode())
                    .quantity(lineReq.quantity())
                    .unitPrice(effectiveUnitPrice)
                    .discountPercent(lineReq.discountPercent())
                    .discountAmount(discountAmt)
                    .taxableAmount(taxableAmount)
                    .gstRate(lineReq.gstRate())
                    .taxGroupId(lineTaxGroupId)
                    .taxAmount(lineTax)
                    .lineTotal(lineTotal)
                    .accountCode(lineReq.accountCode())
                    .itemId(lineReq.itemId())
                    .batchId(lineReq.batchId())
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            invoice.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            // Create tax line items for each component (will be saved after invoice)
            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("INVOICE")
                        .taxRegime("TAX")
                        .componentCode(comp.rateCode())
                        .rate(comp.percentage())
                        .taxableAmount(taxableAmount)
                        .taxAmount(comp.amount())
                        .accountCode(comp.glAccountCode())
                        .hsnCode(lineReq.hsnCode())
                        .baseTaxableAmount(baseTaxable)
                        .baseTaxAmount(comp.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP))
                        .build());
            }
        }

        BigDecimal totalAmount = totalSubtotal.add(totalTax);
        invoice.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        invoice.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        invoice.setTotalAmount(totalAmount.setScale(2, RoundingMode.HALF_UP));
        invoice.setBalanceDue(totalAmount.setScale(2, RoundingMode.HALF_UP));
        invoice.setBaseSubtotal(totalSubtotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        invoice.setBaseTaxAmount(totalTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        invoice.setBaseTotal(totalAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));

        invoice = invoiceRepository.save(invoice);

        // Save tax line items with source references
        final UUID invoiceId = invoice.getId();
        for (int i = 0; i < allTaxLines.size(); i++) {
            TaxLineItem tli = allTaxLines.get(i);
            tli.setSourceId(invoiceId);
            // Link to invoice line if we can determine it
            if (invoice.getLines().size() > 0) {
                // Tax lines are grouped per invoice line; we'll set sourceLineId
                // based on accumulated count
                tli.setSourceLineId(findLineIdForTaxLine(invoice, allTaxLines, i));
            }
        }
        taxLineItemRepository.saveAll(allTaxLines);

        auditService.log("INVOICE", invoice.getId(), "CREATE", null,
                "{\"invoiceNumber\":\"" + invoice.getInvoiceNumber() + "\",\"total\":\"" + invoice.getTotalAmount() + "\"}");

        commentService.addSystemComment("INVOICE", invoice.getId(), "Invoice created");

        log.info("Invoice {} created: {} lines, total={}", invoice.getInvoiceNumber(),
                invoice.getLines().size(), invoice.getTotalAmount());
        return toResponse(invoice);
    }

    /**
     * Send invoice: DRAFT → SENT. Posts journal entry via journalService.postJournal().
     *
     * Journal mapping:
     *   DR 1200 (Accounts Receivable) = totalAmount
     *   CR 4010 (Revenue) = taxableAmount per line
     *   CR 2020/2021/2022 (GST Payable) = tax per component
     */
    @Transactional
    public InvoiceResponse sendInvoice(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        if (!"DRAFT".equals(invoice.getStatus())) {
            throw new BusinessException("Only DRAFT invoices can be sent",
                    "AR_INVOICE_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        // Build journal lines
        List<JournalLineRequest> journalLines = new ArrayList<>();

        // DR: Accounts Receivable for total amount (per-org default)
        journalLines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                invoice.getTotalAmount(),
                BigDecimal.ZERO,
                "AR: " + invoice.getInvoiceNumber(),
                null, null));

        // CR: Revenue per invoice line
        for (InvoiceLine line : invoice.getLines()) {
            journalLines.add(new JournalLineRequest(
                    line.getAccountCode(),
                    BigDecimal.ZERO,
                    line.getTaxableAmount(),
                    "Revenue: " + line.getDescription(),
                    null, null));
        }

        // CR: Tax payable per component
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoice.getId());
        for (TaxLineItem tli : taxLines) {
            if (tli.getAccountCode() == null || tli.getAccountCode().isBlank()) {
                throw new BusinessException(
                        "Tax component " + tli.getComponentCode()
                                + " has no GL output account. Configure it in Settings → Tax Account Mapping.",
                        "TAX_GL_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST);
            }
            journalLines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    BigDecimal.ZERO,
                    tli.getTaxAmount(),
                    tli.getComponentCode() + " Payable",
                    tli.getComponentCode(), null));
        }

        // Post journal via the single posting gate
        JournalPostRequest journalRequest = new JournalPostRequest(
                invoice.getInvoiceDate(),
                "Invoice " + invoice.getInvoiceNumber(),
                "AR",
                invoice.getId(),
                journalLines,
                true);

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

        // Deduct stock for any itemised lines (free-text lines are silently
        // skipped). Runs after the journal post so a journal failure aborts
        // the whole transaction without leaving a stock movement orphan.
        inventoryService.deductStockForInvoice(invoice);

        // Update invoice status
        invoice.setStatus("SENT");
        invoice.setSentAt(Instant.now());
        invoice.setJournalEntryId(journalEntry.getId());
        invoice = invoiceRepository.save(invoice);

        auditService.log("INVOICE", invoice.getId(), "SEND", "{\"status\":\"DRAFT\"}",
                "{\"status\":\"SENT\",\"journalEntryId\":\"" + journalEntry.getId() + "\"}");

        // Build response once — reused for both email and return value
        InvoiceResponse response = toResponse(invoice);

        // Send email and record outcome in the system comment
        String sendComment = "Invoice sent";
        if (invoice.getContactId() != null) {
            Contact contact = contactRepository.findById(invoice.getContactId()).orElse(null);
            if (contact != null && contact.getEmail() != null && !contact.getEmail().isBlank()) {
                boolean emailed = documentEmailService.sendInvoice(response, contact.getEmail());
                sendComment = emailed
                        ? "Invoice emailed to " + contact.getEmail()
                        : "Invoice sent (email delivery failed)";
            } else {
                sendComment = "Invoice sent (no email on file)";
            }
        }
        commentService.addSystemComment("INVOICE", invoice.getId(), sendComment);

        log.info("Invoice {} sent, journal={}", invoice.getInvoiceNumber(), journalEntry.getEntryNumber());
        return response;
    }

    /**
     * Cancel a DRAFT or SENT invoice. If SENT, reverses the journal entry.
     */
    @Transactional
    public InvoiceResponse cancelInvoice(UUID invoiceId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        if ("PAID".equals(invoice.getStatus()) || "CANCELLED".equals(invoice.getStatus())) {
            throw new BusinessException("Cannot cancel " + invoice.getStatus() + " invoice",
                    "AR_INVOICE_CANCEL_INVALID", HttpStatus.BAD_REQUEST);
        }

        if (invoice.getAmountPaid().compareTo(BigDecimal.ZERO) > 0) {
            throw new BusinessException("Cannot cancel invoice with existing payments. Issue a credit note instead.",
                    "AR_INVOICE_HAS_PAYMENTS", HttpStatus.BAD_REQUEST);
        }

        // If journal was posted, reverse it
        if (invoice.getJournalEntryId() != null) {
            journalService.reverseEntry(invoice.getJournalEntryId());
        }

        invoice.setStatus("CANCELLED");
        invoice.setCancelledAt(Instant.now());
        invoice.setCancelledBy(userId);
        invoice.setCancelReason(reason);
        invoice.setBalanceDue(BigDecimal.ZERO);
        invoice = invoiceRepository.save(invoice);

        auditService.log("INVOICE", invoice.getId(), "CANCEL", null,
                "{\"reason\":\"" + reason + "\"}");

        log.info("Invoice {} cancelled: {}", invoice.getInvoiceNumber(), reason);
        return toResponse(invoice);
    }

    @Transactional(readOnly = true)
    public InvoiceResponse getInvoiceResponse(UUID invoiceId) {
        return toResponse(getInvoice(invoiceId));
    }

    public Invoice getInvoice(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
    }

    @Transactional(readOnly = true)
    public Page<InvoiceResponse> listInvoiceResponses(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return invoiceRepository.findByOrgIdAndIsDeletedFalseOrderByInvoiceDateDesc(orgId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<InvoiceResponse> listInvoiceResponsesByContact(UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return invoiceRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(orgId, contactId, pageable)
                .map(this::toResponse);
    }

    public BulkOperationResult bulkSend(List<UUID> ids) {
        BulkOperationResult.Accumulator acc = BulkOperationResult.accumulator();
        for (UUID id : ids) {
            try {
                sendInvoice(id);
                acc.success(id);
            } catch (Exception e) {
                acc.failure(id, e.getMessage());
            }
        }
        return acc.build();
    }

    public BulkOperationResult bulkCancel(List<UUID> ids, String reason) {
        BulkOperationResult.Accumulator acc = BulkOperationResult.accumulator();
        for (UUID id : ids) {
            try {
                cancelInvoice(id, reason);
                acc.success(id);
            } catch (Exception e) {
                acc.failure(id, e.getMessage());
            }
        }
        return acc.build();
    }

    /**
     * Update invoice payment status after a payment or credit note is applied.
     */
    @Transactional
    public void updatePaymentStatus(Invoice invoice, BigDecimal paymentAmount) {
        invoice.setAmountPaid(invoice.getAmountPaid().add(paymentAmount));
        invoice.setBalanceDue(invoice.getTotalAmount().subtract(invoice.getAmountPaid()));

        if (invoice.getBalanceDue().compareTo(BigDecimal.ZERO) <= 0) {
            invoice.setStatus("PAID");
            invoice.setBalanceDue(BigDecimal.ZERO);
        } else if (invoice.getAmountPaid().compareTo(BigDecimal.ZERO) > 0) {
            invoice.setStatus("PARTIALLY_PAID");
        }

        invoiceRepository.save(invoice);
    }

    public InvoiceResponse toResponse(Invoice inv) {
        Contact contact = contactRepository.findById(inv.getContactId()).orElse(null);
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", inv.getId());

        List<InvoiceResponse.LineResponse> lineResponses = inv.getLines().stream()
                .map(l -> new InvoiceResponse.LineResponse(
                        l.getId(), l.getLineNumber(), l.getDescription(), l.getHsnCode(),
                        l.getQuantity(), l.getUnitPrice(), l.getDiscountPercent(), l.getDiscountAmount(),
                        l.getTaxableAmount(), l.getGstRate(), l.getTaxAmount(), l.getLineTotal(),
                        l.getAccountCode()))
                .toList();

        List<InvoiceResponse.TaxLineResponse> taxLineResponses = taxLines.stream()
                .map(t -> new InvoiceResponse.TaxLineResponse(
                        t.getComponentCode(), t.getRate(), t.getTaxableAmount(),
                        t.getTaxAmount(), t.getAccountCode()))
                .toList();

        return new InvoiceResponse(
                inv.getId(), inv.getContactId(),
                contact != null ? contact.getDisplayName() : null,
                inv.getInvoiceNumber(), inv.getInvoiceDate(), inv.getDueDate(),
                inv.getStatus(), inv.getSubtotal(), inv.getTaxAmount(),
                inv.getTotalAmount(), inv.getAmountPaid(), inv.getBalanceDue(),
                inv.getCurrency(), inv.getPlaceOfSupply(), inv.isReverseCharge(),
                inv.getJournalEntryId(), inv.getNotes(),
                lineResponses, taxLineResponses, inv.getCreatedAt());
    }

    String generateNumber(UUID orgId, String prefix, int year) {
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

    int computeFiscalYear(LocalDate date, int fiscalYearStartMonth) {
        if (date.getMonthValue() >= fiscalYearStartMonth) {
            return date.getYear();
        }
        return date.getYear() - 1;
    }

    private UUID findLineIdForTaxLine(Invoice invoice, List<TaxLineItem> allTaxLines, int taxLineIndex) {
        // Simple approach: map tax lines back to invoice lines based on order
        // Tax components are generated per invoice line, so we track the accumulated count
        int lineIdx = 0;
        int accumulated = 0;
        for (InvoiceLine invLine : invoice.getLines()) {
            // Count how many tax components this line would generate
            int componentCount = 0;
            for (int j = accumulated; j < allTaxLines.size() && j < accumulated + 3; j++) {
                if (j == taxLineIndex) {
                    return invLine.getId();
                }
                componentCount++;
            }
            accumulated += componentCount;
            lineIdx++;
            if (lineIdx >= invoice.getLines().size()) break;
        }
        return invoice.getLines().isEmpty() ? null : invoice.getLines().get(0).getId();
    }
}
