package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.*;
import com.katasticho.erp.ar.entity.*;
import com.katasticho.erp.ar.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.cache.CacheInvalidationService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.event.DomainEventPublisher;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.service.DocumentEmailService;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
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
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import com.katasticho.erp.common.dto.BulkOperationResult;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

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
    private final AccountingPostingEngine postingEngine;
    private final TaxEngine taxEngine;
    private final CurrencyService currencyService;
    private final AuditService auditService;
    private final InventoryService inventoryService;
    private final PriceListService priceListService;
    private final CommentService commentService;
    private final DocumentEmailService documentEmailService;
    private final ItemRepository itemRepository;
    private final StockBatchRepository stockBatchRepository;
    private final CacheInvalidationService cacheInvalidationService;
    private final DocumentSnapshotService documentSnapshotService;
    private final DomainEventPublisher domainEventPublisher;
    private final com.katasticho.erp.tax.service.TcsService tcsService;
    private final com.katasticho.erp.common.country.CountryAccessService countryAccessService;

    /**
     * Create a DRAFT invoice with tax calculation via TaxEngine.
     */
    @Transactional
    public InvoiceResponse createInvoice(CreateInvoiceRequest request) {
        return createInvoice(request, true, false);
    }

    /**
     * Create an invoice from an already-priced Sales Order. The SO line
     * rate is the booked customer agreement, so this path deliberately
     * skips price-list resolution even if the customer's price list has
     * changed since the order was accepted.
     */
    @Transactional
    public InvoiceResponse createInvoiceFromSalesOrder(CreateInvoiceRequest request) {
        return createInvoice(request, false, true);
    }

    private InvoiceResponse createInvoice(CreateInvoiceRequest request, boolean resolvePriceLists, boolean allowZeroAmountLines) {
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

        BigDecimal exchangeRate = currencyService.getRate(org.getBaseCurrency(), org.getBaseCurrency(), request.invoiceDate());

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
                .currency(org.getBaseCurrency())
                .exchangeRate(exchangeRate)
                .placeOfSupply(placeOfSupply)
                .reverseCharge(request.reverseCharge())
                .notes(request.notes())
                .termsAndConditions(request.termsAndConditions())
                .periodYear(periodYear)
                .periodMonth(request.invoiceDate().getMonthValue())
                .createdBy(userId)
                .build();

        invoice = materializeInvoiceLinesAndTotals(invoice, request, orgId, org, contact,
                placeOfSupply, exchangeRate, resolvePriceLists, allowZeroAmountLines);

        auditService.log("INVOICE", invoice.getId(), "CREATE", null,
                "{\"invoiceNumber\":\"" + invoice.getInvoiceNumber() + "\",\"total\":\"" + invoice.getTotalAmount() + "\"}");

        commentService.addSystemComment("INVOICE", invoice.getId(), "Invoice created");

        log.info("Invoice {} created: {} lines, total={}", invoice.getInvoiceNumber(),
                invoice.getLines().size(), invoice.getTotalAmount());
        return toResponse(invoice);
    }

    /**
     * Edit a DRAFT invoice: replace its lines and recompute every total via the
     * exact same line/tax pipeline {@code createInvoice} uses, so an edited
     * invoice is byte-for-byte what it would have been if entered correctly the
     * first time. Only DRAFT invoices qualify — once SENT the journal + stock
     * are committed and corrections must go through a credit note. SO-derived
     * invoices are also off-limits (their lines mirror the order; edit the SO).
     * The invoice number is preserved.
     */
    @Transactional
    public InvoiceResponse updateInvoice(UUID invoiceId, CreateInvoiceRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        if (!"DRAFT".equals(invoice.getStatus())) {
            throw new BusinessException("Only DRAFT invoices can be edited (status: " + invoice.getStatus()
                    + "). Use a credit note to correct a sent invoice.",
                    "AR_INVOICE_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }
        if (invoice.getSalesOrderId() != null) {
            throw new BusinessException("This invoice was created from a sales order — edit the order instead",
                    "AR_INVOICE_FROM_SO_NOT_EDITABLE", HttpStatus.BAD_REQUEST);
        }

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));

        String placeOfSupply = request.placeOfSupply() != null
                ? request.placeOfSupply()
                : contact.getBillingStateCode();
        LocalDate dueDate = request.dueDate() != null
                ? request.dueDate()
                : request.invoiceDate().plusDays(contact.getPaymentTermsDays());
        BigDecimal exchangeRate = currencyService.getRate(org.getBaseCurrency(), org.getBaseCurrency(), request.invoiceDate());

        // Reset the editable header. Number + status + branch stay as-is.
        invoice.setContactId(contact.getId());
        invoice.setInvoiceDate(request.invoiceDate());
        invoice.setDueDate(dueDate);
        invoice.setPlaceOfSupply(placeOfSupply);
        invoice.setReverseCharge(request.reverseCharge());
        invoice.setNotes(request.notes());
        invoice.setTermsAndConditions(request.termsAndConditions());
        invoice.setExchangeRate(exchangeRate);
        invoice.setPeriodYear(computeFiscalYear(request.invoiceDate(), org.getFiscalYearStart()));
        invoice.setPeriodMonth(request.invoiceDate().getMonthValue());

        // Drop the old lines (orphanRemoval deletes them on save) + their tax
        // lines, then re-materialize from the request via the shared pipeline.
        invoice.getLines().clear();
        taxLineItemRepository.deleteBySourceTypeAndSourceId("INVOICE", invoiceId);

        invoice = materializeInvoiceLinesAndTotals(invoice, request, orgId, org, contact,
                placeOfSupply, exchangeRate, true, false);

        auditService.log("INVOICE", invoice.getId(), "UPDATE", null,
                "{\"invoiceNumber\":\"" + invoice.getInvoiceNumber() + "\",\"total\":\"" + invoice.getTotalAmount() + "\"}");
        commentService.addSystemComment("INVOICE", invoice.getId(), "Invoice edited (draft)");
        log.info("Invoice {} edited: {} lines, total={}", invoice.getInvoiceNumber(),
                invoice.getLines().size(), invoice.getTotalAmount());
        return toResponse(invoice);
    }

    /**
     * Build invoice lines + tax line items + roll-up totals from the request and
     * persist them onto {@code invoice} (which must already carry its header).
     * Shared by {@link #createInvoice} and {@link #updateInvoice} so the tax
     * math has exactly one home. Returns the saved invoice.
     */
    private Invoice materializeInvoiceLinesAndTotals(
            Invoice invoice, CreateInvoiceRequest request, UUID orgId, Organisation org,
            Contact contact, String placeOfSupply, BigDecimal exchangeRate,
            boolean resolvePriceLists, boolean allowZeroAmountLines) {

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();
        // Parallel list: for each entry in allTaxLines, the 0-based index of the
        // invoice line that produced it. Indian GST yields 1 (IGST) or 2
        // (CGST+SGST) components per line — never a fixed 3 — so we record the
        // owning line as components are built instead of guessing a slot window.
        List<Integer> taxLineToLineIdx = new ArrayList<>();

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
            if (resolvePriceLists && lineReq.itemId() != null) {
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
            boolean zeroAmountLine = grossAmount.compareTo(BigDecimal.ZERO) == 0;
            if (grossAmount.compareTo(BigDecimal.ZERO) < 0 || (zeroAmountLine && !allowZeroAmountLines)) {
                throw new BusinessException(
                        "Invoice line amount must be greater than zero for: " + lineReq.description(),
                        "AR_INVOICE_LINE_AMOUNT_NOT_POSITIVE",
                        HttpStatus.BAD_REQUEST);
            }
            BigDecimal discountAmt = grossAmount.multiply(lineReq.discountPercent())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal taxableAmount = grossAmount.subtract(discountAmt);
            if (taxableAmount.compareTo(BigDecimal.ZERO) < 0
                    || (taxableAmount.compareTo(BigDecimal.ZERO) == 0 && !allowZeroAmountLines)) {
                throw new BusinessException(
                        "Invoice line taxable amount must be greater than zero for: " + lineReq.description(),
                        "AR_INVOICE_LINE_AMOUNT_NOT_POSITIVE",
                        HttpStatus.BAD_REQUEST);
            }

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
                taxLineToLineIdx.add(i);
            }
        }

        BigDecimal totalAmount = totalSubtotal.add(totalTax);
        if (totalAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(
                    "Invoice total must be greater than zero",
                    "AR_INVOICE_TOTAL_NOT_POSITIVE",
                    HttpStatus.BAD_REQUEST);
        }

        // TCS 206C(1H): collected from the buyer on top of subtotal + GST once
        // the FY consideration crosses ₹50 lakh (org setting tax.tcs_enabled).
        // India-only — 206C is an Income Tax Act provision; non-IN orgs skip.
        BigDecimal tcsAmount = BigDecimal.ZERO;
        if (countryAccessService.isCountry("IN")) {
            var tcs = tcsService.computeForInvoice(orgId, contact.getId(), totalAmount, request.invoiceDate());
            if (tcs != null) {
                tcsAmount = tcs.amount();
                totalAmount = totalAmount.add(tcsAmount);
                log.info("TCS {} on invoice for {} ({})", tcsAmount, contact.getDisplayName(), tcs.note());
            }
        }
        invoice.setTcsAmount(tcsAmount.setScale(2, RoundingMode.HALF_UP));

        invoice.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        invoice.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        invoice.setTotalAmount(totalAmount.setScale(2, RoundingMode.HALF_UP));
        invoice.setBalanceDue(totalAmount.setScale(2, RoundingMode.HALF_UP));
        invoice.setBaseSubtotal(totalSubtotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        invoice.setBaseTaxAmount(totalTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        invoice.setBaseTotal(totalAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));

        invoice = invoiceRepository.save(invoice);

        // Save tax line items with source references
        final UUID savedInvoiceId = invoice.getId();
        List<InvoiceLine> savedLines = invoice.getLines();
        for (int i = 0; i < allTaxLines.size(); i++) {
            TaxLineItem tli = allTaxLines.get(i);
            tli.setSourceId(savedInvoiceId);
            // Link each tax line to the exact invoice line that produced it,
            // using the per-component owning-line index recorded above.
            int ownerIdx = taxLineToLineIdx.get(i);
            if (ownerIdx >= 0 && ownerIdx < savedLines.size()) {
                tli.setSourceLineId(savedLines.get(ownerIdx).getId());
            }
        }
        taxLineItemRepository.saveAll(allTaxLines);
        return invoice;
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
        return sendInvoice(invoiceId, false);
    }

    @Transactional
    public InvoiceResponse sendInvoice(UUID invoiceId, boolean skipStockMovement) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Pessimistic lock so a concurrent double-send serialises: the second
        // transaction re-reads the flipped status and fails the DRAFT check
        // below, instead of both deducting stock + posting a duplicate journal.
        Invoice invoice = invoiceRepository.findLockedByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        if (!"DRAFT".equals(invoice.getStatus())) {
            throw new BusinessException("Only DRAFT invoices can be sent",
                    "AR_INVOICE_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        if (invoice.getLines() == null || invoice.getLines().isEmpty()) {
            throw new BusinessException("Cannot send an invoice with no line items",
                    "AR_INVOICE_NO_LINES", HttpStatus.BAD_REQUEST);
        }

        // Validate stock availability before posting anything
        if (!skipStockMovement && invoice.getSalesOrderId() == null) {
            inventoryService.validateStockForInvoice(invoice);
        }

        // Deduct stock BEFORE posting the journal — same transaction, so a
        // posting failure rolls the movements back. Order matters for FIFO
        // orgs: the posting rule reads the SALE movements' recorded cost to
        // book COGS at the true lot cost; posting first would leave COGS on
        // the purchase-price fallback while the lots drained at FIFO cost.
        // Skip when the invoice originates from a Sales Order — stock was
        // already deducted on delivery challan dispatch (PGI).
        if (!skipStockMovement && invoice.getSalesOrderId() == null) {
            inventoryService.deductStockForInvoice(invoice);
        }

        // Post journal via the accounting posting engine
        JournalEntry journalEntry = postingEngine.postSalesInvoice(invoice);

        // Update invoice status
        invoice.setStatus("SENT");
        invoice.setSentAt(Instant.now());
        invoice.setJournalEntryId(journalEntry.getId());
        invoice = invoiceRepository.save(invoice);

        auditService.log("INVOICE", invoice.getId(), "SEND", "{\"status\":\"DRAFT\"}",
                "{\"status\":\"SENT\",\"journalEntryId\":\"" + journalEntry.getId() + "\"}");

        InvoiceResponse response = toResponse(invoice);
        documentSnapshotService.createSnapshot("INVOICE", invoice.getId(), invoice.getInvoiceNumber(), response);
        domainEventPublisher.publish("INVOICE_POSTED", "INVOICE", invoice.getId(), Map.of(
                "invoiceNumber", invoice.getInvoiceNumber(),
                "status", invoice.getStatus(),
                "totalAmount", invoice.getTotalAmount(),
                "journalEntryId", journalEntry.getId()
        ));

        // Side effects run after commit — email/comment/cache failure cannot roll back the posting
        final UUID invoiceId2 = invoice.getId();
        final UUID contactId = invoice.getContactId();
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                try {
                    String sendComment = "Invoice sent";
                    if (contactId != null) {
                        Contact contact = contactRepository.findById(contactId).orElse(null);
                        if (contact != null && contact.getEmail() != null && !contact.getEmail().isBlank()) {
                            boolean emailed = documentEmailService.sendInvoice(response, contact.getEmail());
                            sendComment = emailed
                                    ? "Invoice emailed to " + contact.getEmail()
                                    : "Invoice sent (email delivery failed)";
                        } else {
                            sendComment = "Invoice sent (no email on file)";
                        }
                    }
                    commentService.addSystemComment("INVOICE", invoiceId2, sendComment);
                    cacheInvalidationService.onInvoiceChanged(orgId, contactId);
                } catch (Exception e) {
                    log.warn("Post-commit side effect failed for invoice {}: {}", invoiceId2, e.getMessage());
                }
            }
        });

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

        cacheInvalidationService.onInvoiceChanged(orgId, invoice.getContactId());

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
    public Page<InvoiceResponse> listInvoiceResponses(String status, String search, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        boolean hasSearch = search != null && !search.isBlank();
        boolean hasStatus = status != null && !status.isBlank();

        if (hasSearch && hasStatus) {
            return invoiceRepository.searchByOrgIdAndStatus(orgId, status.toUpperCase(), search.trim(), pageable)
                    .map(this::toResponse);
        } else if (hasSearch) {
            return invoiceRepository.searchByOrgId(orgId, search.trim(), pageable)
                    .map(this::toResponse);
        } else if (hasStatus) {
            return invoiceRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByInvoiceDateDesc(
                    orgId, status.toUpperCase(), pageable).map(this::toResponse);
        }
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
        if (invoice.getAmountPaid().compareTo(BigDecimal.ZERO) < 0) {
            throw new BusinessException("Invoice paid amount cannot become negative",
                    "AR_INVOICE_PAYMENT_REVERSAL_INVALID", HttpStatus.BAD_REQUEST);
        }
        invoice.setBalanceDue(invoice.getTotalAmount().subtract(invoice.getAmountPaid()));

        if (invoice.getBalanceDue().compareTo(BigDecimal.ZERO) <= 0) {
            invoice.setStatus("PAID");
            invoice.setBalanceDue(BigDecimal.ZERO);
        } else if (invoice.getAmountPaid().compareTo(BigDecimal.ZERO) > 0) {
            invoice.setStatus("PARTIALLY_PAID");
        } else if (!"DRAFT".equals(invoice.getStatus()) && !"CANCELLED".equals(invoice.getStatus())) {
            invoice.setStatus(invoice.getDueDate() != null && invoice.getDueDate().isBefore(LocalDate.now())
                    ? "OVERDUE"
                    : "SENT");
        }

        invoiceRepository.save(invoice);

        cacheInvalidationService.onPaymentReceived(invoice.getOrgId(), invoice.getContactId());
    }

    public InvoiceResponse toResponse(Invoice inv) {
        Contact contact = contactRepository.findById(inv.getContactId()).orElse(null);
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", inv.getId());

        Set<UUID> itemIds = inv.getLines().stream()
                .map(InvoiceLine::getItemId).filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, Item> itemMap = itemIds.isEmpty() ? Map.of()
                : itemRepository.findAllById(itemIds).stream()
                .collect(Collectors.toMap(Item::getId, i -> i));

        Set<UUID> batchIds = inv.getLines().stream()
                .map(InvoiceLine::getBatchId).filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, StockBatch> batchMap = batchIds.isEmpty() ? Map.of()
                : stockBatchRepository.findAllById(batchIds).stream()
                .collect(Collectors.toMap(StockBatch::getId, b -> b));

        List<InvoiceResponse.LineResponse> lineResponses = inv.getLines().stream()
                .map(l -> {
                    Item item = l.getItemId() != null ? itemMap.get(l.getItemId()) : null;
                    StockBatch batch = l.getBatchId() != null ? batchMap.get(l.getBatchId()) : null;
                    return new InvoiceResponse.LineResponse(
                        l.getId(), l.getItemId(), l.getBatchId(), l.getTaxGroupId(),
                        l.getLineNumber(), l.getDescription(), l.getHsnCode(),
                        l.getQuantity(), l.getUnitPrice(), l.getDiscountPercent(), l.getDiscountAmount(),
                        l.getTaxableAmount(), l.getGstRate(), l.getTaxAmount(), l.getLineTotal(),
                        l.getAccountCode(),
                        item != null ? item.getMrp() : null,
                        batch != null ? batch.getBatchNumber() : null,
                        batch != null && batch.getExpiryDate() != null
                                ? batch.getExpiryDate().toString() : null);
                })
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
                inv.getStatus(), inv.getSubtotal(), inv.getTaxAmount(), inv.getTcsAmount(),
                inv.getTotalAmount(), inv.getAmountPaid(), inv.getBalanceDue(),
                inv.getCurrency(), inv.getPlaceOfSupply(), inv.isReverseCharge(),
                inv.getJournalEntryId(), inv.getNotes(), inv.getTermsAndConditions(),
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

}
