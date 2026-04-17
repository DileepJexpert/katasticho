package com.katasticho.erp.ap.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.dto.UpdatePurchaseBillRequest;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentAllocationRepository;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
    private final TaxEngine taxEngine;
    private final CurrencyService currencyService;
    private final InventoryService inventoryService;

    private static final String AP_ACCOUNT_CODE = "2010";
    private static final String TDS_PAYABLE_CODE = "2030";

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
                .notes(request.notes())
                .termsAndConditions(request.termsAndConditions())
                .periodYear(periodYear)
                .periodMonth(request.billDate().getMonthValue())
                .createdBy(userId)
                .build();

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

            // Resolve tax group: prefer explicit taxGroupId, else resolve from legacy gstRate
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
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            bill.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                if (comp.glAccountCode() == null) continue; // non-recoverable tax
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

        bill = billRepository.save(bill);

        final UUID billId = bill.getId();
        allTaxLines.forEach(tli -> tli.setSourceId(billId));
        taxLineItemRepository.saveAll(allTaxLines);

        log.info("Purchase bill {} created: {} lines, total={}", bill.getBillNumber(),
                bill.getLines().size(), bill.getTotalAmount());
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

        // ── Build journal lines ─────────────────────────────────

        List<JournalLineRequest> journalLines = new ArrayList<>();

        // DR: Expense / Inventory account per line (using accountId → accountCode lookup)
        for (PurchaseBillLine line : bill.getLines()) {
            Account lineAccount = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, line.getAccountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", line.getAccountId()));

            journalLines.add(new JournalLineRequest(
                    lineAccount.getCode(),
                    line.getTaxableAmount(), BigDecimal.ZERO,
                    "Purchase: " + line.getDescription(),
                    null, null));
        }

        // DR: Tax input credit per component (account code from tax engine, not hardcoded)
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("BILL", bill.getId());
        for (TaxLineItem tli : taxLines) {
            journalLines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    tli.getTaxAmount(), BigDecimal.ZERO,
                    tli.getComponentCode() + " Input Credit",
                    tli.getComponentCode(), null));
        }

        // CR: Accounts Payable (net of TDS)
        BigDecimal apCredit = bill.getTotalAmount().subtract(bill.getTdsAmount());
        journalLines.add(new JournalLineRequest(
                AP_ACCOUNT_CODE,
                BigDecimal.ZERO, apCredit,
                "AP: " + bill.getBillNumber(),
                null, null));

        // CR: TDS Payable (if vendor has TDS deducted)
        if (bill.getTdsAmount().compareTo(BigDecimal.ZERO) > 0) {
            journalLines.add(new JournalLineRequest(
                    TDS_PAYABLE_CODE,
                    BigDecimal.ZERO, bill.getTdsAmount(),
                    "TDS: " + bill.getBillNumber(),
                    null, null));
        }

        // ── Post journal via single posting gate ────────────────

        JournalPostRequest journalRequest = new JournalPostRequest(
                bill.getBillDate(),
                "Purchase Bill " + bill.getBillNumber(),
                "AP",
                bill.getId(),
                journalLines,
                true);

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

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

        log.info("Purchase bill {} posted, journal={}", bill.getBillNumber(),
                journalEntry.getEntryNumber());
        return toResponse(bill);
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

        // Reverse stock movements: REVERSAL with negative quantity
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

        log.info("Purchase bill {} voided: {}", bill.getBillNumber(), reason);
        return toResponse(bill);
    }

    // ── Payment status update ───────────────────────────────────

    @Transactional
    public void updatePaymentStatus(PurchaseBill bill, BigDecimal paymentAmount) {
        bill.setAmountPaid(bill.getAmountPaid().add(paymentAmount));
        bill.setBalanceDue(bill.getTotalAmount().subtract(bill.getAmountPaid()));

        if (bill.getBalanceDue().compareTo(BigDecimal.ZERO) <= 0) {
            bill.setStatus("PAID");
            bill.setBalanceDue(BigDecimal.ZERO);
        } else if (bill.getAmountPaid().compareTo(BigDecimal.ZERO) > 0) {
            bill.setStatus("PARTIALLY_PAID");
        }

        billRepository.save(bill);
    }

    // ── Overdue scheduler ───────────────────────────────────────

    @Scheduled(cron = "0 0 1 * * *")
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
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            bill.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                if (comp.glAccountCode() == null) continue;
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

        for (PurchaseBillLine line : bill.getLines()) {
            if (line.getItemId() == null) {
                continue;
            }

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    defaultWarehouse.getId(),
                    MovementType.PURCHASE,
                    line.getQuantity(),
                    line.getUnitPrice(),
                    bill.getBillDate(),
                    ReferenceType.BILL,
                    bill.getId(),
                    bill.getBillNumber(),
                    "Purchase via " + bill.getBillNumber()));
        }
    }

    private void reverseStockForBill(PurchaseBill bill) {
        UUID orgId = bill.getOrgId();
        Warehouse defaultWarehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElse(null);

        if (defaultWarehouse == null) {
            return;
        }

        for (PurchaseBillLine line : bill.getLines()) {
            if (line.getItemId() == null) {
                continue;
            }

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    defaultWarehouse.getId(),
                    MovementType.REVERSAL,
                    line.getQuantity().negate(),
                    line.getUnitPrice(),
                    bill.getBillDate(),
                    ReferenceType.BILL,
                    bill.getId(),
                    bill.getBillNumber(),
                    "Void reversal: " + bill.getBillNumber()));
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
                        l.getTaxableAmount(), l.getGstRate(), l.getTaxAmount(), l.getLineTotal()))
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
                bill.getJournalEntryId(), bill.getNotes(),
                lineResponses, bill.getCreatedAt());
    }

    private static final String DEFAULT_PURCHASE_ACCOUNT_CODE = "5000";

    private Account resolveLineAccount(UUID orgId, CreatePurchaseBillRequest.BillLineRequest lineReq) {
        if (lineReq.accountId() != null) {
            return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, lineReq.accountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", lineReq.accountId()));
        }
        String code = lineReq.accountCode() != null && !lineReq.accountCode().isBlank()
                ? lineReq.accountCode().trim()
                : DEFAULT_PURCHASE_ACCOUNT_CODE;
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                .orElseThrow(() -> new BusinessException(
                        "Purchase account not found: " + code,
                        "AP_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
    }

    private Account resolveUpdateLineAccount(UUID orgId, UpdatePurchaseBillRequest.BillLineRequest lineReq) {
        if (lineReq.accountId() != null) {
            return accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, lineReq.accountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", lineReq.accountId()));
        }
        String code = lineReq.accountCode() != null && !lineReq.accountCode().isBlank()
                ? lineReq.accountCode().trim()
                : DEFAULT_PURCHASE_ACCOUNT_CODE;
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                .orElseThrow(() -> new BusinessException(
                        "Purchase account not found: " + code,
                        "AP_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
    }
}
