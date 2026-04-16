package com.katasticho.erp.ap.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.dto.ApplyVendorCreditRequest;
import com.katasticho.erp.ap.dto.CreateVendorCreditRequest;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.VendorCredit;
import com.katasticho.erp.ap.entity.VendorCreditApplication;
import com.katasticho.erp.ap.entity.VendorCreditLine;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorCreditApplicationRepository;
import com.katasticho.erp.ap.repository.VendorCreditRepository;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxEngine;
import com.katasticho.erp.tax.TaxEngineFactory;
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
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Vendor credit lifecycle: DRAFT → OPEN (posts reversal journal + stock return) → APPLIED → VOID
 *
 * On postCredit():
 *   DR 2010 (Accounts Payable)          = totalAmount  (reduces what we owe)
 *   CR line.accountCode (Expense)        = taxable per line (reverses the purchase expense)
 *   CR 1500 (GST Input Credit)           = tax per component (reverses the input credit)
 *
 * On applyToBill():
 *   Reduces bill.balanceDue and credit.balance, no additional journal needed
 *   (the journal was already posted when the credit was issued).
 *
 * All financial writes go through journalService.postJournal().
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class VendorCreditService {

    private final VendorCreditRepository creditRepository;
    private final VendorCreditApplicationRepository applicationRepository;
    private final PurchaseBillRepository billRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final AccountRepository accountRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final BranchRepository branchRepository;
    private final WarehouseRepository warehouseRepository;
    private final JournalService journalService;
    private final PurchaseBillService billService;
    private final TaxEngineFactory taxEngineFactory;
    private final CurrencyService currencyService;
    private final InventoryService inventoryService;

    private static final String AP_ACCOUNT_CODE = "2010";
    private static final String GST_INPUT_CREDIT_CODE = "1500";

    // ── Create ──────────────────────────────────────────────────

    @Transactional
    public VendorCredit createCredit(CreateVendorCreditRequest request) {
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

        if (request.purchaseBillId() != null) {
            billRepository.findByIdAndOrgIdAndIsDeletedFalse(request.purchaseBillId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("PurchaseBill", request.purchaseBillId()));
        }

        String placeOfSupply = request.placeOfSupply() != null
                ? request.placeOfSupply()
                : contact.getBillingStateCode();

        TaxEngine taxEngine = taxEngineFactory.getEngine(org.getTaxRegime());

        int periodYear = billService.computeFiscalYear(request.creditDate(), org.getFiscalYearStart());
        String creditNumber = billService.generateNumber(orgId, "VCRED", periodYear);
        BigDecimal exchangeRate = currencyService.getRate("INR", org.getBaseCurrency(), request.creditDate());

        UUID branchId = request.branchId() != null
                ? request.branchId()
                : branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                        .map(Branch::getId).orElse(null);

        VendorCredit credit = VendorCredit.builder()
                .orgId(orgId)
                .branchId(branchId)
                .contactId(contact.getId())
                .creditNumber(creditNumber)
                .creditDate(request.creditDate())
                .purchaseBillId(request.purchaseBillId())
                .reason(request.reason())
                .status("DRAFT")
                .currency("INR")
                .exchangeRate(exchangeRate)
                .placeOfSupply(placeOfSupply)
                .createdBy(userId)
                .build();

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();

        for (int i = 0; i < request.lines().size(); i++) {
            CreateVendorCreditRequest.CreditLineRequest lineReq = request.lines().get(i);

            Account lineAccount = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, lineReq.accountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", lineReq.accountId()));

            BigDecimal taxableAmount = lineReq.quantity().multiply(lineReq.unitPrice())
                    .setScale(2, RoundingMode.HALF_UP);

            TaxEngine.TaxableItem taxableItem = new TaxEngine.TaxableItem(
                    lineReq.description(), lineReq.hsnCode(), taxableAmount, lineReq.gstRate());

            TaxEngine.TaxContext taxContext = new TaxEngine.TaxContext(
                    contact.getBillingCountry(), contact.getBillingStateCode(),
                    org.getCountryCode(), org.getStateCode(),
                    lineReq.hsnCode(),
                    TaxEngine.TransactionType.DOMESTIC,
                    request.creditDate(),
                    false);

            TaxEngine.TaxResult taxResult = taxEngine.calculateTax(taxableItem, taxContext);

            BigDecimal lineTax = taxResult.totalTaxAmount();
            BigDecimal lineTotal = taxableAmount.add(lineTax);

            BigDecimal baseTaxable = taxableAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTax = lineTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
            BigDecimal baseTotal = lineTotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

            VendorCreditLine line = VendorCreditLine.builder()
                    .lineNumber(i + 1)
                    .description(lineReq.description())
                    .hsnCode(lineReq.hsnCode())
                    .itemId(lineReq.itemId())
                    .accountId(lineReq.accountId())
                    .quantity(lineReq.quantity())
                    .unitPrice(lineReq.unitPrice())
                    .taxableAmount(taxableAmount)
                    .gstRate(lineReq.gstRate())
                    .taxAmount(lineTax)
                    .lineTotal(lineTotal)
                    .baseTaxableAmount(baseTaxable)
                    .baseTaxAmount(baseTax)
                    .baseLineTotal(baseTotal)
                    .build();

            credit.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);

            for (TaxEngine.TaxComponentResult comp : taxResult.components()) {
                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("VENDOR_CREDIT")
                        .taxRegime(taxResult.taxRegime())
                        .componentCode(comp.componentCode())
                        .rate(comp.rate())
                        .taxableAmount(taxableAmount)
                        .taxAmount(comp.amount())
                        .accountCode(comp.accountCode())
                        .hsnCode(lineReq.hsnCode())
                        .baseTaxableAmount(baseTaxable)
                        .baseTaxAmount(comp.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP))
                        .build());
            }
        }

        BigDecimal totalAmount = totalSubtotal.add(totalTax);
        credit.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        credit.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        credit.setTotalAmount(totalAmount.setScale(2, RoundingMode.HALF_UP));
        credit.setBaseSubtotal(totalSubtotal.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        credit.setBaseTaxAmount(totalTax.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));
        credit.setBaseTotal(totalAmount.multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP));

        credit = creditRepository.save(credit);

        final UUID creditId = credit.getId();
        allTaxLines.forEach(tli -> tli.setSourceId(creditId));
        taxLineItemRepository.saveAll(allTaxLines);

        log.info("Vendor credit {} created: total={}", credit.getCreditNumber(), credit.getTotalAmount());
        return credit;
    }

    // ── Post (DRAFT → OPEN) ────────────────────────────────────

    /**
     * Post a vendor credit: creates GL reversal journal and records
     * stock return movements for tracked items.
     *
     * Journal mapping (reverse of purchase bill post):
     *   DR 2010 (Accounts Payable)        = totalAmount (reduces liability)
     *   CR line.accountCode (Expense)       = taxable per line
     *   CR 1500 (GST Input Credit)          = tax per component (reverses input credit)
     *
     * Stock movements:
     *   For each line with itemId: RETURN_OUT with negative quantity (stock leaves).
     */
    @Transactional
    public VendorCredit postCredit(UUID creditId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        VendorCredit credit = creditRepository.findByIdAndOrgIdAndIsDeletedFalse(creditId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorCredit", creditId));

        if (!"DRAFT".equals(credit.getStatus())) {
            throw new BusinessException("Only DRAFT vendor credits can be posted",
                    "AP_CREDIT_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        List<JournalLineRequest> journalLines = new ArrayList<>();

        // DR: Accounts Payable (reduces what we owe)
        journalLines.add(new JournalLineRequest(
                AP_ACCOUNT_CODE,
                credit.getTotalAmount(), BigDecimal.ZERO,
                "AP debit: VC " + credit.getCreditNumber(),
                null, null));

        // CR: Expense reversal per line
        for (VendorCreditLine line : credit.getLines()) {
            Account lineAccount = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, line.getAccountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", line.getAccountId()));

            journalLines.add(new JournalLineRequest(
                    lineAccount.getCode(),
                    BigDecimal.ZERO, line.getTaxableAmount(),
                    "Expense reversal: " + line.getDescription(),
                    null, null));
        }

        // CR: GST Input Credit reversal per tax component
        List<TaxLineItem> taxLines = taxLineItemRepository.findBySourceTypeAndSourceId("VENDOR_CREDIT", credit.getId());
        for (TaxLineItem tli : taxLines) {
            journalLines.add(new JournalLineRequest(
                    GST_INPUT_CREDIT_CODE,
                    BigDecimal.ZERO, tli.getTaxAmount(),
                    tli.getComponentCode() + " Input Credit reversal",
                    tli.getComponentCode(), null));
        }

        JournalPostRequest journalRequest = new JournalPostRequest(
                credit.getCreditDate(),
                "Vendor Credit " + credit.getCreditNumber(),
                "AP",
                credit.getId(),
                journalLines,
                true);

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

        // Record stock return movements (goods returned to vendor)
        recordStockReturnForCredit(credit);

        credit.setStatus("OPEN");
        credit.setBalance(credit.getTotalAmount());
        credit.setJournalEntryId(journalEntry.getId());
        credit = creditRepository.save(credit);

        // Reduce vendor's outstanding AP
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(credit.getContactId(), orgId)
                .orElse(null);
        if (contact != null) {
            contact.setOutstandingAp(contact.getOutstandingAp().subtract(credit.getTotalAmount()));
            contactRepository.save(contact);
        }

        // If linked to a specific bill, auto-apply
        if (credit.getPurchaseBillId() != null) {
            PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(credit.getPurchaseBillId(), orgId)
                    .orElse(null);
            if (bill != null) {
                BigDecimal applyAmount = credit.getTotalAmount().min(bill.getBalanceDue());
                if (applyAmount.compareTo(BigDecimal.ZERO) > 0) {
                    applyToBillInternal(credit, bill, applyAmount);
                }
            }
        }

        log.info("Vendor credit {} posted, journal={}", credit.getCreditNumber(),
                journalEntry.getEntryNumber());
        return credit;
    }

    // ── Void ────────────────────────────────────────────────────

    @Transactional
    public VendorCredit voidCredit(UUID creditId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();

        VendorCredit credit = creditRepository.findByIdAndOrgIdAndIsDeletedFalse(creditId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorCredit", creditId));

        if ("VOID".equals(credit.getStatus())) {
            throw new BusinessException("Vendor credit is already voided",
                    "AP_CREDIT_ALREADY_VOID", HttpStatus.BAD_REQUEST);
        }

        if (credit.getBalance().compareTo(credit.getTotalAmount()) < 0) {
            throw new BusinessException(
                    "Cannot void vendor credit that has been partially applied",
                    "AP_CREDIT_PARTIALLY_APPLIED", HttpStatus.BAD_REQUEST);
        }

        if (credit.getJournalEntryId() != null) {
            journalService.reverseEntry(credit.getJournalEntryId());
        }

        // Restore vendor's outstanding AP
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(credit.getContactId(), orgId)
                .orElse(null);
        if (contact != null) {
            contact.setOutstandingAp(contact.getOutstandingAp().add(credit.getTotalAmount()));
            contactRepository.save(contact);
        }

        credit.setStatus("VOID");
        credit.setBalance(BigDecimal.ZERO);
        credit = creditRepository.save(credit);

        log.info("Vendor credit {} voided: {}", credit.getCreditNumber(), reason);
        return credit;
    }

    // ── Apply to bill ───────────────────────────────────────────

    @Transactional
    public VendorCreditApplication applyToBill(UUID creditId, ApplyVendorCreditRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        VendorCredit credit = creditRepository.findByIdAndOrgIdAndIsDeletedFalse(creditId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorCredit", creditId));

        if (!"OPEN".equals(credit.getStatus())) {
            throw new BusinessException("Only OPEN vendor credits can be applied",
                    "AP_CREDIT_NOT_OPEN", HttpStatus.BAD_REQUEST);
        }

        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(request.billId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", request.billId()));

        if ("DRAFT".equals(bill.getStatus()) || "VOID".equals(bill.getStatus()) || "PAID".equals(bill.getStatus())) {
            throw new BusinessException(
                    "Bill " + bill.getBillNumber() + " is not eligible for credit application (status: " + bill.getStatus() + ")",
                    "AP_BILL_NOT_ELIGIBLE", HttpStatus.BAD_REQUEST);
        }

        if (request.amount().compareTo(credit.getBalance()) > 0) {
            throw new BusinessException(
                    "Application amount " + request.amount() + " exceeds credit balance " + credit.getBalance(),
                    "AP_CREDIT_INSUFFICIENT", HttpStatus.BAD_REQUEST);
        }

        if (request.amount().compareTo(bill.getBalanceDue()) > 0) {
            throw new BusinessException(
                    "Application amount " + request.amount() + " exceeds bill balance due " + bill.getBalanceDue(),
                    "AP_BILL_BALANCE_EXCEEDED", HttpStatus.BAD_REQUEST);
        }

        return applyToBillInternal(credit, bill, request.amount());
    }

    private VendorCreditApplication applyToBillInternal(VendorCredit credit, PurchaseBill bill, BigDecimal amount) {
        UUID userId = TenantContext.getCurrentUserId();

        VendorCreditApplication application = VendorCreditApplication.builder()
                .vendorCreditId(credit.getId())
                .purchaseBillId(bill.getId())
                .amountApplied(amount)
                .appliedBy(userId)
                .build();
        application = applicationRepository.save(application);

        // Update credit balance
        credit.setBalance(credit.getBalance().subtract(amount));
        if (credit.getBalance().compareTo(BigDecimal.ZERO) <= 0) {
            credit.setStatus("APPLIED");
            credit.setBalance(BigDecimal.ZERO);
        }
        creditRepository.save(credit);

        // Update bill payment status
        billService.updatePaymentStatus(bill, amount);

        log.info("Vendor credit {} applied {} to bill {}", credit.getCreditNumber(),
                amount, bill.getBillNumber());
        return application;
    }

    // ── Queries ─────────────────────────────────────────────────

    public VendorCredit getCredit(UUID creditId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return creditRepository.findByIdAndOrgIdAndIsDeletedFalse(creditId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorCredit", creditId));
    }

    @Transactional(readOnly = true)
    public Page<VendorCredit> listCredits(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return creditRepository.findByOrgIdAndIsDeletedFalseOrderByCreditDateDesc(orgId, pageable);
    }

    @Transactional(readOnly = true)
    public Page<VendorCredit> listCreditsByVendor(UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return creditRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByCreditDateDesc(orgId, contactId, pageable);
    }

    @Transactional(readOnly = true)
    public List<VendorCredit> getOpenCreditsByVendor(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return creditRepository.findByOrgIdAndContactIdAndStatusAndIsDeletedFalse(orgId, contactId, "OPEN");
    }

    // ── Stock helpers ───────────────────────────────────────────

    private void recordStockReturnForCredit(VendorCredit credit) {
        UUID orgId = credit.getOrgId();
        Warehouse defaultWarehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElse(null);

        if (defaultWarehouse == null) {
            log.warn("No default warehouse for org {} — skipping stock return for credit {}",
                    orgId, credit.getCreditNumber());
            return;
        }

        for (VendorCreditLine line : credit.getLines()) {
            if (line.getItemId() == null) {
                continue;
            }

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    defaultWarehouse.getId(),
                    MovementType.RETURN_OUT,
                    line.getQuantity().negate(),
                    line.getUnitPrice(),
                    credit.getCreditDate(),
                    ReferenceType.DEBIT_NOTE,
                    credit.getId(),
                    credit.getCreditNumber(),
                    "Return to vendor: " + credit.getCreditNumber()));
        }
    }
}
