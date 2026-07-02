package com.katasticho.erp.ap.service;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.dto.UpdatePurchaseBillRequest;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.match.ThreeWayMatchService;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentAllocationRepository;
import com.katasticho.erp.procurement.repository.StockReceiptLineRepository;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
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
 * Purchase bill lifecycle: DRAFT → OPEN (posts journal + stock) → PARTIALLY_PAID / PAID → VOID
 *
 * On post():
 *   DR line.accountId (Expense / Inventory) per line = taxable amount
 *   DR 1500 (GST Input Credit) per tax component     = tax amount
 *   CR 2010 (Accounts Payable) = totalAmount − tdsAmount
 *   CR 2030 (TDS Payable)      = tdsAmount (if applicable)
 *
 * All financial writes go through journalService.postJournal().
 * All stock writes go through inventoryService.recordMovement().
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PurchaseBillService {

    private final PurchaseBillRepository billRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final AccountRepository accountRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final BranchRepository branchRepository;
    private final WarehouseRepository warehouseRepository;
    private final VendorPaymentAllocationRepository allocationRepository;
    private final JournalService journalService;
    private final AccountingPostingEngine postingEngine;
    private final TaxEngine taxEngine;
    private final com.katasticho.erp.tax.service.TdsService tdsService;
    private final com.katasticho.erp.common.country.CountryAccessService countryAccessService;
    private final CurrencyService currencyService;
    private final InventoryService inventoryService;
    private final StockMovementRepository stockMovementRepository;
    private final DefaultAccountService defaultAccountService;
    private final CommentService commentService;
    private final DocumentSnapshotService documentSnapshotService;
    private final StockReceiptLineRepository stockReceiptLineRepository;
    @Lazy private final ThreeWayMatchService threeWayMatchService;

    // ── Create ──────────────────────────────────────────────────

    @Transactional
    public PurchaseBillResponse createBill(CreatePurchaseBillRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));

        if (contact.getContactType() != ContactType.VENDOR && contact.getContactType() != ContactType.BOTH) {
            throw new BusinessException("Contact is not a vendor",
                    "AP_CONTACT_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }

        String placeOfSupply = request.placeOfSupply() != null
                ? request.placeOfSupply()
                : contact.getBillingStateCode();

        int periodYear = computeFiscalYear(request.billDate(), org.getFiscalYearStart());
        String billNumber = generateNumber(orgId, "BILL", periodYear);

        LocalDate dueDate = request.dueDate() != null
                ? request.dueDate()
                : request.billDate().plusDays(contact.getPaymentTermsDays());

        BigDecimal exchangeRate = currencyService.getRate("INR", org.getBaseCurrency(), request.billDate());

        UUID branchId = request.branchId() != null
                ? request.branchId()
                : branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                        .map(Branch::getId).orElse(null);

        PurchaseBill bill = PurchaseBill.builder()
                .orgId(orgId)
                .branchId(branchId)
                .contactId(contact.getId())
                .billNumber(billNumber)
                .vendorBillNumber(request.vendorBillNumber())
                .billDate(request.billDate())
                .dueDate(dueDate)
                .status("DRAFT")
                .currency("INR")
                .exchangeRate(exchangeRate)
                .placeOfSupply(placeOfSupply)
                .reverseCharge(request.reverseCharge())
                .purchaseOrderId(request.purchaseOrderId())
                .notes(request.notes())
                .termsAndConditions(request.termsAndConditions())
                .periodYear(periodYear)
                .periodMonth(request.billDate().getMonthValue())
                .createdBy(userId)
                .build();

        // Validate: GOODS lines must have an itemId for stock tracking
        for (int idx = 0; idx < request.lines().size(); idx++) {
            var line = request.lines().get(idx);
            if (line.isGoods() && line.itemId() == null) {
                throw new BusinessException(
                        "Line " + (idx + 1) + ": Goods line requires an item for stock tracking. "
                                + "Use the item picker or change line type to SERVICE.",
                        "AP_GOODS_ITEM_REQUIRED", HttpStatus.BAD_REQUEST);
            }
        }

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();

        for (int i = 0; i < request.lines().size(); i++) {
            CreatePurchaseBillRequest.BillLineRequest lineReq = request.lines().get(i);

            Account lineAccount = resolveLineAccount(orgId, lineReq);

            BigDecimal grossAmount = lineReq.quantity().multiply(lineReq.unitPrice())
                    .setScale(2, RoundingMode.HALF_UP);
            BigDecimal discountAmt = grossAmount.multiply(lineReq.discountPercent())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal taxableAmount = grossAmount.subtract(discountAmt);

            UUID lineTaxGroupId = lineReq.taxGroupId();
            if (lineTaxGroupId == null && lineReq.gstRate() != null
                    && lineReq.gstRate().compareTo(BigDecimal.ZERO) > 0) {
                lineTaxGroupId = taxEngine.resolveGroupId(orgId, lineReq.gstRate(),
                        contact.getBillingStateCode(), org.getStateCode()).orElse(null);
            }

            TaxEngine.TaxCalculationResult taxResult = taxEngine.calculate(
                    orgId, lineTaxGroupId, taxableAmount, TaxEngine.TransactionType.PURCHASE);

            BigDecimal lineTax = taxResult.totalTaxAmount();
            BigDecimal lineTotal = taxableAmount.add(lineTax);

            BigDecimal baseTaxable = taxableAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTax = lineTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTotal = lineTotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

            BigDecimal convFactor = lineReq.unitConversionFactor();
            BigDecimal baseQty = lineReq.quantity();
            if (convFactor != null && convFactor.compareTo(BigDecimal.ONE) > 0) {
                baseQty = lineReq.quantity().multiply(convFactor)
                        .setScale(4, RoundingMode.HALF_UP);
            }

            PurchaseBillLine line = PurchaseBillLine.builder()
                    .lineNumber(i + 1)
                    .description(lineReq.description())
                    .hsnCode(lineReq.hsnCode())
                    .itemId(lineReq.itemId())
                    .accountId(lineAccount.getId())
                    .purchaseOrderLineId(lineReq.purchaseOrderLineId())
                    .quantity(lineReq.quantity())
                    .unitPrice(lineReq.unitPrice())
                    .discountPercent(lineReq.discountPercent())
                    .discountAmount(discountAmt)
                    .taxableAmount(taxableAmount)
                    .gstRate(lineReq.gstRate())
                    .taxGroupId(lineTaxGroupId)
                    .taxAmount(lineTax)
                    .lineTotal(lineTotal)
                    .unitUomId(lineReq.unitUomId())
                    .unitConversionFactor(convFactor)
                    .baseQuantity(baseQty)
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            bill.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("BILL")
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
        bill.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        bill.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        bill.setTotalAmount(totalAmount.setScale(2, RoundingMode.HALF_UP));
        bill.setBalanceDue(totalAmount.setScale(2, RoundingMode.HALF_UP));
        bill.setBaseSubtotal(totalSubtotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        bill.setBaseTaxAmount(totalTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        bill.setBaseTotal(totalAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        applyTds(orgId, bill, contact);

        bill = billRepository.save(bill);

        final UUID billId = bill.getId();
        allTaxLines.forEach(tli -> tli.setSourceId(billId));
        taxLineItemRepository.saveAll(allTaxLines);

        commentService.addSystemComment("BILL", bill.getId(), "Bill created");
        log.info("Purchase bill {} created: {} lines, total={}", bill.getBillNumber(),
                bill.getLines().size(), bill.getTotalAmount());

        // 3-way match (best-effort). Match failures NEVER block bill creation —
        // an EXCEPTION just lands in the AI Inbox and the planner reviews. Match
        // service swallows BusinessException too inside this catch on purpose:
        // create() must not fail if config / tolerances are off-shape.
        try {
            threeWayMatchService.match(bill.getId());
        } catch (Exception e) {
            log.warn("3-way match failed for bill {}: {}", bill.getBillNumber(), e.getMessage());
        }

        return toResponse(bill);
    }

    // ── Post (DRAFT → OPEN) ────────────────────────────────────

    /**
     * Post a draft purchase bill: creates GL journal entry and records
     * stock movements for tracked items.
     *
     * Journal mapping (double-entry):
     *   DR  line.accountCode (Expense/Inventory) per line = taxableAmount
     *   DR  1500 (GST Input Credit) per tax component     = tax amount
     *   CR  2010 (Accounts Payable)                       = totalAmount − tdsAmount
     *   CR  2030 (TDS Payable)                            = tdsAmount (if > 0)
     *
     * Stock movements:
     *   For each line with a non-null itemId:
     *     MovementType.PURCHASE, quantity = +qty (stock in)
     *     ReferenceType.BILL, referenceId = bill.id
     */
    @Transactional
    public PurchaseBillResponse postBill(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));

        if (!"DRAFT".equals(bill.getStatus())) {
            throw new BusinessException("Only DRAFT bills can be posted",
                    "AP_BILL_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        // Post journal via the accounting posting engine
        JournalEntry journalEntry = postingEngine.postPurchaseBill(bill);

        // ── Record stock movements (PURCHASE, +qty) ─────────────

        recordStockForBill(bill);

        // ── Update bill status and contact outstanding ──────────

        bill.setStatus("OPEN");
        bill.setPostedAt(Instant.now());
        bill.setJournalEntryId(journalEntry.getId());
        bill = billRepository.save(bill);

        // Increase vendor's outstanding AP
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(bill.getContactId(), orgId)
                .orElse(null);
        if (contact != null) {
            contact.setOutstandingAp(contact.getOutstandingAp().add(bill.getTotalAmount()));
            contactRepository.save(contact);
        }

        commentService.addSystemComment("BILL", bill.getId(),
                "Bill posted to accounts payable");
        PurchaseBillResponse response = toResponse(bill);
        documentSnapshotService.createSnapshot("PURCHASE_BILL", bill.getId(), bill.getBillNumber(), response);
        log.info("Purchase bill {} posted, journal={}", bill.getBillNumber(),
                journalEntry.getEntryNumber());
        return response;
    }

    // ── Void ────────────────────────────────────────────────────

    @Transactional
    public PurchaseBillResponse voidBill(UUID billId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));

        if ("VOID".equals(bill.getStatus())) {
            throw new BusinessException("Bill is already voided",
                    "AP_BILL_ALREADY_VOID", HttpStatus.BAD_REQUEST);
        }

        if (bill.getAmountPaid().compareTo(BigDecimal.ZERO) > 0) {
            throw new BusinessException(
                    "Cannot void bill with existing payments. Reverse payments first.",
                    "AP_BILL_HAS_PAYMENTS", HttpStatus.BAD_REQUEST);
        }

        if (allocationRepository.existsByPurchaseBillId(billId)) {
            throw new BusinessException(
                    "Cannot void bill with payment allocations. Remove allocations first.",
                    "AP_BILL_HAS_ALLOCATIONS", HttpStatus.BAD_REQUEST);
        }

        // Reverse journal entry if it was posted
        if (bill.getJournalEntryId() != null) {
            journalService.reverseEntry(bill.getJournalEntryId());
        }

        // Reverse the bill's PURCHASE movements via the stock gate's reversal
        // path (marks originals reversed; closes FIFO cost lots).
        reverseStockForBill(bill);

        // Reduce vendor's outstanding AP
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(bill.getContactId(), orgId)
                .orElse(null);
        if (contact != null) {
            contact.setOutstandingAp(contact.getOutstandingAp().subtract(bill.getBalanceDue()));
            contactRepository.save(contact);
        }

        bill.setStatus("VOID");
        bill.setVoidedAt(Instant.now());
        bill.setVoidedBy(userId);
        bill.setVoidReason(reason);
        bill.setBalanceDue(BigDecimal.ZERO);
        bill = billRepository.save(bill);

        String voidComment = (reason == null || reason.isBlank())
                ? "Bill voided" : "Bill voided: " + reason;
        commentService.addSystemComment("BILL", bill.getId(), voidComment);
        log.info("Purchase bill {} voided: {}", bill.getBillNumber(), reason);
        return toResponse(bill);
    }

    // ── Bulk operations ─────────────────────────────────────────

    public BulkOperationResult bulkPost(List<UUID> ids) {
        BulkOperationResult.Accumulator acc = BulkOperationResult.accumulator();
        for (UUID id : ids) {
            try {
                postBill(id);
                acc.success(id);
            } catch (Exception e) {
                acc.failure(id, e.getMessage());
            }
        }
        return acc.build();
    }

    public BulkOperationResult bulkVoid(List<UUID> ids, String reason) {
        BulkOperationResult.Accumulator acc = BulkOperationResult.accumulator();
        for (UUID id : ids) {
            try {
                voidBill(id, reason);
                acc.success(id);
            } catch (Exception e) {
                acc.failure(id, e.getMessage());
            }
        }
        return acc.build();
    }

    /**
     * Auto-deduct TDS when the vendor master says so (tdsApplicable + rate),
     * honouring section thresholds. The vendor is owed total − TDS; the TDS
     * itself posts to TDS Payable on bill posting.
     *
     * <p>India-only — TDS sections (194C/194Q/194J/194H/194I/194A) are Income
     * Tax Act provisions. A Gulf/Kenya org's bill skips the call entirely so
     * the orgsetting/vendor-master TDS fields never accidentally fire there.
     */
    private void applyTds(UUID orgId, PurchaseBill bill, Contact vendor) {
        if (!countryAccessService.isCountry("IN")) {
            bill.setTdsAmount(BigDecimal.ZERO);
            bill.setTdsSection(null);
            return;
        }
        var tds = tdsService.computeForBill(orgId, vendor, bill.getSubtotal(), bill.getBillDate());
        if (tds == null) {
            bill.setTdsAmount(BigDecimal.ZERO);
            bill.setTdsSection(null);
            return;
        }
        bill.setTdsAmount(tds.amount());
        bill.setTdsSection(tds.section());
        bill.setBalanceDue(bill.getTotalAmount().subtract(tds.amount()));
        log.info("TDS {} on bill for {}: {} ({})",
                tds.section(), vendor.getDisplayName(), tds.amount().toPlainString(), tds.note());
    }

    // ── Payment status update ───────────────────────────────────

    @Transactional
    public void updatePaymentStatus(PurchaseBill bill, BigDecimal paymentAmount) {
        String previousStatus = bill.getStatus();

        BigDecimal tds = bill.getTdsAmount() == null ? BigDecimal.ZERO : bill.getTdsAmount();
        bill.setAmountPaid(bill.getAmountPaid().add(paymentAmount));
        // Vendor is owed total − TDS (the TDS portion is deposited to the government).
        bill.setBalanceDue(bill.getTotalAmount().subtract(tds).subtract(bill.getAmountPaid()));

        if (bill.getBalanceDue().compareTo(BigDecimal.ZERO) <= 0) {
            bill.setStatus("PAID");
            bill.setBalanceDue(BigDecimal.ZERO);
        } else if (bill.getAmountPaid().compareTo(BigDecimal.ZERO) > 0) {
            bill.setStatus("PARTIALLY_PAID");
        }

        billRepository.save(bill);

        if ("PAID".equals(bill.getStatus()) && !"PAID".equals(previousStatus)) {
            commentService.addSystemComment("BILL", bill.getId(), "Bill fully paid");
        }
    }

    // ── Overdue scheduler ───────────────────────────────────────

    @Scheduled(cron = "0 0 1 * * *")
    @SchedulerLock(name = "PurchaseBillService", lockAtMostFor = "PT25M", lockAtLeastFor = "PT30S")
    @Transactional
    public void markOverdueBills() {
        List<UUID> orgIds = organisationRepository.findAll().stream()
                .map(Organisation::getId).toList();

        LocalDate today = LocalDate.now();
        int count = 0;

        for (UUID orgId : orgIds) {
            List<PurchaseBill> overdue = billRepository.findOverdueBills(orgId, today);
            for (PurchaseBill bill : overdue) {
                bill.setStatus("OVERDUE");
                billRepository.save(bill);
                commentService.addSystemComment(orgId, "BILL", bill.getId(), "Bill became overdue");
                count++;
            }
        }

        if (count > 0) {
            log.info("Marked {} purchase bills as OVERDUE", count);
        }
    }

    // ── Queries ─────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public PurchaseBillResponse getBillResponse(UUID billId) {
        return toResponse(getBill(billId));
    }

    public PurchaseBill getBill(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));
    }

    @Transactional(readOnly = true)
    public Page<PurchaseBillResponse> listBills(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return billRepository.findByOrgIdAndIsDeletedFalseOrderByBillDateDesc(orgId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<PurchaseBillResponse> listBillsFiltered(
            String status, UUID contactId, UUID branchId,
            LocalDate dateFrom, LocalDate dateTo, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return billRepository.findFiltered(orgId, status, contactId, branchId, dateFrom, dateTo, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<PurchaseBillResponse> listBillsByVendor(UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return billRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(orgId, contactId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<PurchaseBillResponse> listBillsByStatus(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return billRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByBillDateDesc(orgId, status, pageable)
                .map(this::toResponse);
    }

    @Transactional
    public PurchaseBillResponse updateBill(UUID billId, UpdatePurchaseBillRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));

        if (!"DRAFT".equals(bill.getStatus())) {
            throw new BusinessException("Only DRAFT bills can be updated",
                    "AP_BILL_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        final UUID vendorContactId = bill.getContactId();
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(vendorContactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", vendorContactId));

        // Clear existing lines (orphanRemoval removes them) and tax line items
        bill.getLines().clear();
        taxLineItemRepository.deleteBySourceTypeAndSourceId("BILL", billId);

        // Update simple fields
        if (request.vendorBillNumber() != null) bill.setVendorBillNumber(request.vendorBillNumber());
        if (request.dueDate() != null) bill.setDueDate(request.dueDate());
        if (request.placeOfSupply() != null) bill.setPlaceOfSupply(request.placeOfSupply());
        bill.setReverseCharge(request.reverseCharge());
        if (request.notes() != null) bill.setNotes(request.notes());
        if (request.termsAndConditions() != null) bill.setTermsAndConditions(request.termsAndConditions());

        String placeOfSupply = bill.getPlaceOfSupply() != null
                ? bill.getPlaceOfSupply()
                : contact.getBillingStateCode();

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();
        final BigDecimal exchangeRate = bill.getExchangeRate();

        for (int i = 0; i < request.lines().size(); i++) {
            UpdatePurchaseBillRequest.BillLineRequest lineReq = request.lines().get(i);

            Account lineAccount = resolveUpdateLineAccount(orgId, lineReq);

            BigDecimal grossAmount = lineReq.quantity().multiply(lineReq.unitPrice())
                    .setScale(2, RoundingMode.HALF_UP);
            BigDecimal discountAmt = grossAmount.multiply(lineReq.discountPercent())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal taxableAmount = grossAmount.subtract(discountAmt);

            UUID lineTaxGroupId = lineReq.taxGroupId();
            if (lineTaxGroupId == null && lineReq.gstRate() != null
                    && lineReq.gstRate().compareTo(BigDecimal.ZERO) > 0) {
                lineTaxGroupId = taxEngine.resolveGroupId(orgId, lineReq.gstRate(),
                        contact.getBillingStateCode(), org.getStateCode()).orElse(null);
            }

            TaxEngine.TaxCalculationResult taxResult = taxEngine.calculate(
                    orgId, lineTaxGroupId, taxableAmount, TaxEngine.TransactionType.PURCHASE);

            BigDecimal lineTax = taxResult.totalTaxAmount();
            BigDecimal lineTotal = taxableAmount.add(lineTax);
            BigDecimal baseTaxable = taxableAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTax = lineTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTotal = lineTotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

            BigDecimal convFactor = lineReq.unitConversionFactor();
            BigDecimal baseQty = lineReq.quantity();
            if (convFactor != null && convFactor.compareTo(BigDecimal.ONE) > 0) {
                baseQty = lineReq.quantity().multiply(convFactor)
                        .setScale(4, RoundingMode.HALF_UP);
            }

            PurchaseBillLine line = PurchaseBillLine.builder()
                    .lineNumber(i + 1)
                    .description(lineReq.description())
                    .hsnCode(lineReq.hsnCode())
                    .itemId(lineReq.itemId())
                    .accountId(lineAccount.getId())
                    .quantity(lineReq.quantity())
                    .unitPrice(lineReq.unitPrice())
                    .discountPercent(lineReq.discountPercent())
                    .discountAmount(discountAmt)
                    .taxableAmount(taxableAmount)
                    .gstRate(lineReq.gstRate())
                    .taxGroupId(lineTaxGroupId)
                    .taxAmount(lineTax)
                    .lineTotal(lineTotal)
                    .unitUomId(lineReq.unitUomId())
                    .unitConversionFactor(convFactor)
                    .baseQuantity(baseQty)
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            bill.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("BILL")
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
        bill.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        bill.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        bill.setTotalAmount(totalAmount.setScale(2, RoundingMode.HALF_UP));
        bill.setBalanceDue(totalAmount.setScale(2, RoundingMode.HALF_UP));
        bill.setBaseSubtotal(totalSubtotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        bill.setBaseTaxAmount(totalTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        bill.setBaseTotal(totalAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        applyTds(orgId, bill, contact);

        bill = billRepository.save(bill);

        final UUID savedBillId = bill.getId();
        allTaxLines.forEach(tli -> tli.setSourceId(savedBillId));
        taxLineItemRepository.saveAll(allTaxLines);

        log.info("Purchase bill {} updated", bill.getBillNumber());
        return toResponse(bill);
    }

    @Transactional
    public void deleteBill(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));

        if (!"DRAFT".equals(bill.getStatus())) {
            throw new BusinessException("Only DRAFT bills can be deleted",
                    "AP_BILL_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        bill.setDeleted(true);
        billRepository.save(bill);
        log.info("Purchase bill {} deleted", bill.getBillNumber());
    }

    @Transactional(readOnly = true)
    public List<PurchaseBill> getOutstandingBillsByVendor(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return billRepository.findOutstandingByContact(orgId, contactId);
    }

    // ── Stock helpers ───────────────────────────────────────────

    private void recordStockForBill(PurchaseBill bill) {
        UUID orgId = bill.getOrgId();

        Warehouse defaultWarehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElse(null);

        if (defaultWarehouse == null) {
            log.warn("No default warehouse for org {} — skipping stock movements for bill {}",
                    orgId, bill.getBillNumber());
            return;
        }

        // P2P architecture guard (2026-06-22, refined 2026-06-23): GRN is the only
        // stock-posting step when a PO line is in play. For each bill LINE, if it
        // links a PO line and any RECEIVED GRN line has already booked stock
        // against that PO line, skip — re-posting would double-count. Per-line
        // (not bill-level) so a bill that mixes a received PO line and a fresh
        // line still posts the fresh one. Lines without a PO link (direct bills,
        // services, supplier-bill-first shops) always post; that's the legacy
        // path of record. DRAFT GRNs deliberately don't trigger the skip — an
        // abandoned draft hasn't actually booked anything.
        for (PurchaseBillLine line : bill.getLines()) {
            if (line.getItemId() == null) {
                continue;
            }
            if (line.getPurchaseOrderLineId() != null) {
                BigDecimal alreadyReceived = stockReceiptLineRepository
                        .sumReceivedQuantityForPurchaseOrderLine(line.getPurchaseOrderLineId());
                if (alreadyReceived != null && alreadyReceived.signum() > 0) {
                    log.info("Bill {} line {} links PO line with {} received via GRN — "
                                    + "skipping stock post (GRN already booked it)",
                            bill.getBillNumber(), line.getLineNumber(), alreadyReceived);
                    continue;
                }
            }

            // Use base quantity (converted to base UoM) for stock movements
            BigDecimal stockQty = line.getBaseQuantity() != null
                    ? line.getBaseQuantity() : line.getQuantity();
            BigDecimal unitCost = line.getUnitPrice();
            // When bought in bulk unit, compute cost per base unit for valuation
            if (line.getUnitConversionFactor() != null
                    && line.getUnitConversionFactor().compareTo(BigDecimal.ONE) > 0) {
                unitCost = line.getUnitPrice().divide(
                        line.getUnitConversionFactor(), 4, RoundingMode.HALF_UP);
            }

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    defaultWarehouse.getId(),
                    MovementType.PURCHASE,
                    stockQty,
                    unitCost,
                    bill.getBillDate(),
                    ReferenceType.BILL,
                    bill.getId(),
                    bill.getBillNumber(),
                    "Purchase via " + bill.getBillNumber()));
        }
    }

    /**
     * Reverse each PURCHASE movement the bill posted through the stock gate's
     * own reversal path. Going through {@code reverseMovement} (instead of
     * recording fresh negative REVERSAL rows) marks the originals as reversed
     * and — critically for FIFO orgs — closes the cost lots those receipts
     * opened, so a voided bill can't leave phantom inventory value behind.
     */
    private void reverseStockForBill(PurchaseBill bill) {
        List<StockMovement> originals = stockMovementRepository.findOriginalsByReference(
                bill.getOrgId(), ReferenceType.BILL, bill.getId(), MovementType.PURCHASE);
        for (StockMovement movement : originals) {
            inventoryService.reverseMovement(movement.getId(),
                    "Bill void: " + bill.getBillNumber());
        }
    }

    // ── Number generation ───────────────────────────────────────

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

    // ── Response mapping ────────────────────────────────────────

    public PurchaseBillResponse toResponse(PurchaseBill bill) {
        Contact contact = contactRepository.findById(bill.getContactId()).orElse(null);

        List<PurchaseBillResponse.LineResponse> lineResponses = bill.getLines().stream()
                .map(l -> new PurchaseBillResponse.LineResponse(
                        l.getId(), l.getLineNumber(), l.getDescription(), l.getHsnCode(),
                        l.getItemId(), l.getAccountId(),
                        l.getQuantity(), l.getUnitPrice(), l.getDiscountPercent(), l.getDiscountAmount(),
                        l.getTaxableAmount(), l.getGstRate(), l.getTaxAmount(), l.getLineTotal(),
                        l.getPurchaseOrderLineId()))
                .toList();

        return new PurchaseBillResponse(
                bill.getId(), bill.getContactId(),
                contact != null ? contact.getDisplayName() : null,
                bill.getBillNumber(), bill.getVendorBillNumber(),
                bill.getBillDate(), bill.getDueDate(),
                bill.getStatus(),
                bill.getSubtotal(), bill.getTaxAmount(),
                bill.getTotalAmount(), bill.getAmountPaid(), bill.getBalanceDue(),
                bill.getTdsAmount(),
                bill.getCurrency(), bill.getPlaceOfSupply(), bill.isReverseCharge(),
                bill.getJournalEntryId(), bill.getPurchaseOrderId(),
                bill.getThreeWayMatchStatus(), bill.getThreeWayMatchAt(),
                bill.getThreeWayMatchOverriddenBy(), bill.getThreeWayMatchOverrideReason(),
                bill.getNotes(),
                lineResponses, bill.getCreatedAt());
    }

    private Account resolveLineAccount(UUID orgId, CreatePurchaseBillRequest.BillLineRequest lineReq) {
        if (lineReq.accountId() != null) {
            return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, lineReq.accountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", lineReq.accountId()));
        }
        if (lineReq.accountCode() != null && !lineReq.accountCode().isBlank()) {
            String code = lineReq.accountCode().trim();
            return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                    .orElseThrow(() -> new BusinessException(
                            "Purchase account not found: " + code,
                            "AP_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
        }
        // Fall through to per-org default for the PURCHASE purpose.
        return defaultAccountService.get(orgId, DefaultAccountPurpose.PURCHASE);
    }

    private Account resolveUpdateLineAccount(UUID orgId, UpdatePurchaseBillRequest.BillLineRequest lineReq) {
        if (lineReq.accountId() != null) {
            return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, lineReq.accountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", lineReq.accountId()));
        }
        if (lineReq.accountCode() != null && !lineReq.accountCode().isBlank()) {
            String code = lineReq.accountCode().trim();
            return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                    .orElseThrow(() -> new BusinessException(
                            "Purchase account not found: " + code,
                            "AP_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
        }
        return defaultAccountService.get(orgId, DefaultAccountPurpose.PURCHASE);
    }
}
