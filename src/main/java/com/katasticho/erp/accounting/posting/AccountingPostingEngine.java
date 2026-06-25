package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.entity.VendorCredit;
import com.katasticho.erp.ap.entity.VendorCreditLine;
import com.katasticho.erp.ar.entity.CreditNote;
import com.katasticho.erp.ar.entity.CreditNoteLine;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.expense.entity.Expense;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.service.CostResolverService;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import com.katasticho.erp.tax.TaxEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
@Slf4j
public class AccountingPostingEngine {

    private final JournalService journalService;
    private final DefaultAccountService defaultAccountService;
    private final TaxLineItemRepository taxLineItemRepository;
    private final AccountRepository accountRepository;
    private final SalesInvoicePostingRule salesInvoicePostingRule;
    private final CostResolverService costResolverService;

    // ── Sales Invoice ──────────────────────────────────────────

    public JournalEntry postSalesInvoice(Invoice invoice) {
        return journalService.postJournal(salesInvoicePostingRule.generate(PostingContext.salesInvoice(invoice)));
    }

    // ── POS Receipt ────────────────────────────────────────────

    public JournalEntry postPosReceipt(SalesReceipt receipt,
                                        List<TaxLineItem> taxLines,
                                        Map<UUID, Item> itemMap) {
        UUID orgId = receipt.getOrgId();
        List<JournalLineRequest> lines = new ArrayList<>();

        // DR: Paid-through account (Cash / Bank / UPI)
        String paidThroughCode = resolvePaidThroughAccount(orgId, receipt.getPaymentMode());
        lines.add(new JournalLineRequest(
                paidThroughCode,
                receipt.getTotal(), BigDecimal.ZERO,
                "POS Sale: " + receipt.getReceiptNumber(),
                null, null));

        // CR: Revenue
        String revenueCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE);
        lines.add(new JournalLineRequest(
                revenueCode,
                BigDecimal.ZERO, receipt.getSubtotal(),
                "Revenue: " + receipt.getReceiptNumber(),
                null, null));

        // CR: Tax payable per component
        for (TaxLineItem tli : taxLines) {
            requireTaxGlAccount(tli);
            lines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    BigDecimal.ZERO, tli.getTaxAmount(),
                    tli.getComponentCode() + " Payable",
                    tli.getComponentCode(), null));
        }

        // DR COGS / CR Inventory (real) + DR COGS / CR Stock-Out Suspense (provisional)
        // for tracked items. Items with a known purchase price take the real path;
        // items without (the "bill-freely" case — typical first-day shop) take the
        // provisional path so revenue and COGS book in the same period instead of
        // revenue at sale and COGS quietly skipped. The Stock-Out Suspense leg is
        // closed out later by ProvisionalCostReconciler when the GRN lands.
        BigDecimal realCogs = BigDecimal.ZERO;
        BigDecimal provisionalCogs = BigDecimal.ZERO;
        for (SalesReceiptLine line : receipt.getLines()) {
            if (line.getItemId() == null) continue;
            Item item = itemMap.get(line.getItemId());
            if (item == null || !item.isTrackInventory()) continue;

            CostResolverService.CostBasis basis = costResolverService.resolve(item, orgId);
            if (basis == null) continue;  // no cost basis at all — preserve legacy skip

            BigDecimal qty = line.getBaseQuantity() != null ? line.getBaseQuantity() : line.getQuantity();
            BigDecimal lineCost = basis.unitCost().multiply(qty).setScale(2, RoundingMode.HALF_UP);
            if (basis.provisional()) {
                provisionalCogs = provisionalCogs.add(lineCost);
            } else {
                realCogs = realCogs.add(lineCost);
            }
        }
        if (realCogs.signum() > 0) {
            appendCogsLines(lines, orgId, receipt.getReceiptNumber(), realCogs,
                    DefaultAccountPurpose.INVENTORY_ASSET, "Inventory");
        }
        if (provisionalCogs.signum() > 0) {
            appendCogsLines(lines, orgId, receipt.getReceiptNumber(), provisionalCogs,
                    DefaultAccountPurpose.STOCK_OUT_SUSPENSE, "Stock-Out Suspense (provisional)");
        }

        return journalService.postJournal(new JournalPostRequest(
                receipt.getReceiptDate(),
                "POS Sale " + receipt.getReceiptNumber(),
                "POS",
                receipt.getId(),
                lines,
                true));
    }

    // ── Payment Received ───────────────────────────────────────

    /** Forex Gain/Loss account from the seeded CoA template (all industries). */
    private static final String FOREX_GAIN_LOSS_CODE = "5500";

    /**
     * Payment-received journal with realized forex gain/loss.
     *
     * The AR was booked at the invoice's exchange rate; cash arrives at the
     * payment-date rate. Both legs post in base currency and the difference
     * goes to Forex Gain/Loss (5500): credit = gain, debit = loss. When both
     * rates are 1 (the INR-only path) the journal is identical to before.
     */
    public JournalEntry postPaymentReceived(UUID orgId,
                                             String paymentNumber,
                                             String invoiceNumber,
                                             java.time.LocalDate paymentDate,
                                             BigDecimal amount,
                                             String paymentMethod,
                                             BigDecimal invoiceExchangeRate,
                                             BigDecimal paymentExchangeRate) {
        String debitCode = resolvePaymentMethodAccount(orgId, paymentMethod);

        BigDecimal invRate = invoiceExchangeRate != null ? invoiceExchangeRate : BigDecimal.ONE;
        BigDecimal payRate = paymentExchangeRate != null ? paymentExchangeRate : BigDecimal.ONE;
        BigDecimal baseReceived = amount.multiply(payRate).setScale(2, java.math.RoundingMode.HALF_UP);
        BigDecimal baseArCleared = amount.multiply(invRate).setScale(2, java.math.RoundingMode.HALF_UP);
        BigDecimal forexDiff = baseReceived.subtract(baseArCleared);

        List<JournalLineRequest> lines = new ArrayList<>();
        lines.add(new JournalLineRequest(
                debitCode,
                baseReceived, BigDecimal.ZERO,
                "Payment " + paymentNumber + " received",
                null, null));
        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                BigDecimal.ZERO, baseArCleared,
                "AR cleared: " + invoiceNumber,
                null, null));
        if (forexDiff.signum() > 0) {
            lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE,
                    BigDecimal.ZERO, forexDiff,
                    "Realized forex gain on " + invoiceNumber, null, null));
        } else if (forexDiff.signum() < 0) {
            lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE,
                    forexDiff.negate(), BigDecimal.ZERO,
                    "Realized forex loss on " + invoiceNumber, null, null));
        }

        return journalService.postJournal(new JournalPostRequest(
                paymentDate,
                "Payment " + paymentNumber + " for " + invoiceNumber,
                "PAYMENT",
                null,
                lines,
                true));
    }

    // ── Customer Receipt (multi-invoice + advance) ─────────────

    /** Per-invoice share of a customer receipt with the rate the invoice was booked at. */
    public record ArAllocationFx(BigDecimal amount, BigDecimal invoiceExchangeRate) {}

    /**
     * Customer-receipt journal: a lump-sum collection allocated across multiple
     * invoices, with any unallocated excess parked as a Customer Advance (2100)
     * liability.
     *
     *   DR Cash/Bank (by method)   = received in base currency (amount × payRate)
     *   CR Accounts Receivable     = Σ(allocation × invoiceRate)   [AR cleared]
     *   CR Customer Advance (2100) = advance × payRate
     *   [Forex Gain/Loss 5500]     = balancer when invoice rates ≠ receipt rate
     *
     * When every rate is 1 (the domestic INR case) the AR + advance legs sum to
     * the cash leg exactly, so no forex line is produced. A receipt with no
     * advance and a single allocation reduces to the same shape as
     * {@link #postPaymentReceived}.
     */
    public JournalEntry postCustomerReceipt(UUID orgId,
                                            String receiptNumber,
                                            java.time.LocalDate receiptDate,
                                            BigDecimal amount,
                                            BigDecimal advanceAmount,
                                            String paymentMethod,
                                            BigDecimal receiptExchangeRate,
                                            List<ArAllocationFx> allocations) {
        String debitCode = resolvePaymentMethodAccount(orgId, paymentMethod);
        BigDecimal payRate = receiptExchangeRate != null ? receiptExchangeRate : BigDecimal.ONE;
        BigDecimal advance = advanceAmount != null ? advanceAmount : BigDecimal.ZERO;

        BigDecimal baseReceived = amount.multiply(payRate).setScale(2, java.math.RoundingMode.HALF_UP);
        BigDecimal arClearedBase = (allocations == null ? java.util.List.<ArAllocationFx>of() : allocations).stream()
                .map(a -> a.amount().multiply(
                        a.invoiceExchangeRate() != null ? a.invoiceExchangeRate() : BigDecimal.ONE))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, java.math.RoundingMode.HALF_UP);
        BigDecimal advanceBase = advance.multiply(payRate).setScale(2, java.math.RoundingMode.HALF_UP);

        List<JournalLineRequest> lines = new ArrayList<>();
        lines.add(new JournalLineRequest(
                debitCode,
                baseReceived, BigDecimal.ZERO,
                "Receipt " + receiptNumber + " received",
                null, null));
        if (arClearedBase.signum() > 0) {
            lines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                    BigDecimal.ZERO, arClearedBase,
                    "AR cleared: receipt " + receiptNumber,
                    null, null));
        }
        if (advanceBase.signum() > 0) {
            lines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.CUSTOMER_ADVANCE),
                    BigDecimal.ZERO, advanceBase,
                    "Customer advance: " + receiptNumber,
                    null, null));
        }

        BigDecimal forexDiff = baseReceived.subtract(arClearedBase).subtract(advanceBase);
        if (forexDiff.signum() > 0) {
            lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE,
                    BigDecimal.ZERO, forexDiff,
                    "Realized forex gain on " + receiptNumber, null, null));
        } else if (forexDiff.signum() < 0) {
            lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE,
                    forexDiff.negate(), BigDecimal.ZERO,
                    "Realized forex loss on " + receiptNumber, null, null));
        }

        return journalService.postJournal(new JournalPostRequest(
                receiptDate,
                "Customer Receipt " + receiptNumber,
                "PAYMENT",
                null,
                lines,
                true));
    }

    // ── Credit Note ────────────────────────────────────────────

    public JournalEntry postCreditNote(CreditNote cn) {
        UUID orgId = cn.getOrgId();
        List<JournalLineRequest> lines = new ArrayList<>();

        // DR: Revenue reversal per line
        for (CreditNoteLine line : cn.getLines()) {
            lines.add(new JournalLineRequest(
                    line.getAccountCode(),
                    line.getTaxableAmount(), BigDecimal.ZERO,
                    "CN Revenue reversal: " + line.getDescription(),
                    null, null));
        }

        // DR: Tax reversal per component
        List<TaxLineItem> taxLines = taxLineItemRepository
                .findBySourceTypeAndSourceId("CREDIT_NOTE", cn.getId());
        for (TaxLineItem tli : taxLines) {
            lines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    tli.getTaxAmount(), BigDecimal.ZERO,
                    tli.getComponentCode() + " reversal",
                    tli.getComponentCode(), null));
        }

        // CR: Accounts Receivable
        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                BigDecimal.ZERO, cn.getTotalAmount(),
                "AR credit: CN " + cn.getCreditNoteNumber(),
                null, null));

        return journalService.postJournal(new JournalPostRequest(
                cn.getCreditNoteDate(),
                "Credit Note " + cn.getCreditNoteNumber(),
                "SALES",
                cn.getId(),
                lines,
                true));
    }

    // ── Purchase Bill ──────────────────────────────────────────

    public JournalEntry postPurchaseBill(PurchaseBill bill) {
        UUID orgId = bill.getOrgId();
        List<JournalLineRequest> lines = new ArrayList<>();

        // DR: Expense / Inventory per line
        for (PurchaseBillLine line : bill.getLines()) {
            Account lineAccount = accountRepository
                    .findByOrgIdAndIdAndIsDeletedFalse(orgId, line.getAccountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", line.getAccountId()));
            lines.add(new JournalLineRequest(
                    lineAccount.getCode(),
                    line.getTaxableAmount(), BigDecimal.ZERO,
                    "Purchase: " + line.getDescription(),
                    null, null));
        }

        // DR: Tax input credit per component (recoverable only)
        BigDecimal recoverableTax = BigDecimal.ZERO;
        List<TaxLineItem> taxLines = taxLineItemRepository
                .findBySourceTypeAndSourceId("BILL", bill.getId());
        for (TaxLineItem tli : taxLines) {
            if (tli.getAccountCode() == null || tli.getAccountCode().isBlank()) continue;
            lines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    tli.getTaxAmount(), BigDecimal.ZERO,
                    tli.getComponentCode() + " Input Credit",
                    tli.getComponentCode(), null));
            recoverableTax = recoverableTax.add(tli.getTaxAmount());
        }

        // Non-recoverable tax absorbed into purchase account
        BigDecimal nonRecoverableTax = bill.getTaxAmount().subtract(recoverableTax);
        if (nonRecoverableTax.compareTo(BigDecimal.ZERO) > 0) {
            lines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.PURCHASE),
                    nonRecoverableTax, BigDecimal.ZERO,
                    "Non-recoverable tax: " + bill.getBillNumber(),
                    null, null));
        }

        // CR: Accounts Payable (net of TDS)
        BigDecimal apCredit = bill.getTotalAmount().subtract(bill.getTdsAmount());
        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP),
                BigDecimal.ZERO, apCredit,
                "AP: " + bill.getBillNumber(),
                null, null));

        // CR: TDS Payable
        if (bill.getTdsAmount().compareTo(BigDecimal.ZERO) > 0) {
            lines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.TDS_PAYABLE),
                    BigDecimal.ZERO, bill.getTdsAmount(),
                    "TDS: " + bill.getBillNumber(),
                    null, null));
        }

        return journalService.postJournal(new JournalPostRequest(
                bill.getBillDate(),
                "Purchase Bill " + bill.getBillNumber(),
                "PURCHASE",
                bill.getId(),
                lines,
                true));
    }

    // ── Vendor Payment ─────────────────────────────────────────

    /** Per-bill share of a vendor payment with the rate the bill was booked at. */
    public record VendorAllocationFx(BigDecimal amount, BigDecimal billExchangeRate) {}

    /**
     * Vendor-payment journal with realized forex gain/loss.
     *
     * Each allocated bill's AP was booked at that bill's exchange rate; the
     * cash leaves at the payment-date rate. The per-bill weighted difference
     * posts to Forex Gain/Loss (5500): paying fewer base units than booked is
     * a gain (credit), more is a loss (debit). Forex applies only when TDS is
     * zero — TDS sections govern resident INR payments, so an FX bill with
     * TDS keeps the legacy single-currency journal. When every rate is 1 the
     * journal is identical to before.
     */
    public JournalEntry postVendorPayment(UUID orgId,
                                           String paymentNumber,
                                           java.time.LocalDate paymentDate,
                                           BigDecimal amount,
                                           BigDecimal tdsAmount,
                                           String paidThroughAccountCode,
                                           BigDecimal paymentExchangeRate,
                                           List<VendorAllocationFx> allocations) {
        BigDecimal payRate = paymentExchangeRate != null ? paymentExchangeRate : BigDecimal.ONE;
        boolean fxApplies = tdsAmount.signum() == 0 && allocations != null && !allocations.isEmpty();

        BigDecimal apDebitBase;
        BigDecimal paidBase;
        if (fxApplies) {
            apDebitBase = allocations.stream()
                    .map(a -> a.amount().multiply(
                            a.billExchangeRate() != null ? a.billExchangeRate() : BigDecimal.ONE))
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .setScale(2, java.math.RoundingMode.HALF_UP);
            paidBase = amount.multiply(payRate).setScale(2, java.math.RoundingMode.HALF_UP);
        } else {
            apDebitBase = amount.subtract(tdsAmount);
            paidBase = amount;
        }

        List<JournalLineRequest> lines = new ArrayList<>();
        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP),
                apDebitBase, BigDecimal.ZERO,
                "AP cleared: " + paymentNumber,
                null, null));

        if (tdsAmount.compareTo(BigDecimal.ZERO) > 0) {
            lines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.TDS_PAYABLE),
                    tdsAmount, BigDecimal.ZERO,
                    "TDS: " + paymentNumber,
                    null, null));
        }

        lines.add(new JournalLineRequest(
                paidThroughAccountCode,
                BigDecimal.ZERO, paidBase,
                "Payment " + paymentNumber + " to vendor",
                null, null));

        if (fxApplies) {
            BigDecimal forexDiff = apDebitBase.subtract(paidBase);
            if (forexDiff.signum() > 0) {
                lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE,
                        BigDecimal.ZERO, forexDiff,
                        "Realized forex gain on " + paymentNumber, null, null));
            } else if (forexDiff.signum() < 0) {
                lines.add(new JournalLineRequest(FOREX_GAIN_LOSS_CODE,
                        forexDiff.negate(), BigDecimal.ZERO,
                        "Realized forex loss on " + paymentNumber, null, null));
            }
        }

        return journalService.postJournal(new JournalPostRequest(
                paymentDate,
                "Vendor Payment " + paymentNumber,
                "PAYMENT",
                null,
                lines,
                true));
    }

    // ── Vendor Credit ──────────────────────────────────────────

    public JournalEntry postVendorCredit(VendorCredit credit) {
        UUID orgId = credit.getOrgId();
        List<JournalLineRequest> lines = new ArrayList<>();

        // DR: AP (reduces what we owe)
        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP),
                credit.getTotalAmount(), BigDecimal.ZERO,
                "AP debit: VC " + credit.getCreditNumber(),
                null, null));

        // CR: Expense reversal per line
        for (VendorCreditLine line : credit.getLines()) {
            Account lineAccount = accountRepository
                    .findByOrgIdAndIdAndIsDeletedFalse(orgId, line.getAccountId())
                    .orElseThrow(() -> BusinessException.notFound("Account", line.getAccountId()));
            lines.add(new JournalLineRequest(
                    lineAccount.getCode(),
                    BigDecimal.ZERO, line.getTaxableAmount(),
                    "Expense reversal: " + line.getDescription(),
                    null, null));
        }

        // CR: Tax input credit reversal per component
        List<TaxLineItem> taxLines = taxLineItemRepository
                .findBySourceTypeAndSourceId("VENDOR_CREDIT", credit.getId());
        for (TaxLineItem tli : taxLines) {
            lines.add(new JournalLineRequest(
                    tli.getAccountCode(),
                    BigDecimal.ZERO, tli.getTaxAmount(),
                    tli.getComponentCode() + " Input Credit reversal",
                    tli.getComponentCode(), null));
        }

        return journalService.postJournal(new JournalPostRequest(
                credit.getCreditDate(),
                "Vendor Credit " + credit.getCreditNumber(),
                "PURCHASE",
                credit.getId(),
                lines,
                true));
    }

    // ── Expense ────────────────────────────────────────────────

    public JournalEntry postExpense(Expense expense,
                                     Account expenseAccount,
                                     Account paidThrough,
                                     TaxEngine.TaxCalculationResult taxResult) {
        List<JournalLineRequest> lines = new ArrayList<>();

        // DR: Expense GL (pre-tax amount)
        lines.add(new JournalLineRequest(
                expenseAccount.getCode(),
                expense.getAmount(), BigDecimal.ZERO,
                expenseAccount.getName() + ": " + expense.getExpenseNumber(),
                null, null));

        // DR: Recoverable tax input credit per component
        BigDecimal recoverableTax = BigDecimal.ZERO;
        for (TaxEngine.TaxComponent comp : taxResult.components()) {
            if (comp.glAccountCode() == null) continue;
            lines.add(new JournalLineRequest(
                    comp.glAccountCode(),
                    comp.amount(), BigDecimal.ZERO,
                    comp.rateCode() + " Input Credit: " + expense.getExpenseNumber(),
                    null, null));
            recoverableTax = recoverableTax.add(comp.amount());
        }

        // Non-recoverable tax absorbed into expense account
        BigDecimal nonRecoverable = taxResult.totalTaxAmount().subtract(recoverableTax);
        if (nonRecoverable.compareTo(BigDecimal.ZERO) > 0) {
            lines.add(new JournalLineRequest(
                    expenseAccount.getCode(),
                    nonRecoverable, BigDecimal.ZERO,
                    "Non-recoverable tax: " + expense.getExpenseNumber(),
                    null, null));
        }

        // CR: Paid-through (Cash / Bank)
        lines.add(new JournalLineRequest(
                paidThrough.getCode(),
                BigDecimal.ZERO, expense.getTotal(),
                paidThrough.getName() + ": " + expense.getExpenseNumber(),
                null, null));

        return journalService.postJournal(new JournalPostRequest(
                expense.getExpenseDate(),
                expenseAccount.getName() + ": " + expense.getExpenseNumber(),
                "EXPENSE",
                null,
                lines,
                true));
    }

    // ── Opening Stock ──────────────────────────────────────────

    public JournalEntry postOpeningStock(UUID orgId, String itemSku, BigDecimal totalCost) {
        if (totalCost == null || totalCost.compareTo(BigDecimal.ZERO) <= 0) return null;

        String inventoryCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.INVENTORY_ASSET);
        String equityCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.OPENING_BALANCE_EQUITY);

        List<JournalLineRequest> lines = List.of(
                new JournalLineRequest(
                        inventoryCode,
                        totalCost.setScale(2, RoundingMode.HALF_UP), BigDecimal.ZERO,
                        "Opening stock: " + itemSku,
                        null, null),
                new JournalLineRequest(
                        equityCode,
                        BigDecimal.ZERO, totalCost.setScale(2, RoundingMode.HALF_UP),
                        "Opening stock: " + itemSku,
                        null, null)
        );

        return journalService.postJournal(new JournalPostRequest(
                java.time.LocalDate.now(),
                "Opening stock: " + itemSku,
                "OPENING",
                null,
                lines,
                true));
    }

    // ── Shared helpers ─────────────────────────────────────────

    private void appendCogsLines(List<JournalLineRequest> lines, UUID orgId,
                                  String docNumber, BigDecimal totalCost,
                                  DefaultAccountPurpose creditPurpose, String creditLabel) {
        if (totalCost.compareTo(BigDecimal.ZERO) <= 0) return;
        try {
            String cogsCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.COGS);
            String creditCode = defaultAccountService.getCode(orgId, creditPurpose);
            lines.add(new JournalLineRequest(
                    cogsCode, totalCost, BigDecimal.ZERO,
                    "COGS: " + docNumber, null, null));
            lines.add(new JournalLineRequest(
                    creditCode, BigDecimal.ZERO, totalCost,
                    creditLabel + ": " + docNumber, null, null));
        } catch (BusinessException e) {
            // STOCK_OUT_SUSPENSE missing means the bill-freely V5 fix is broken
            // for this org — silently dropping the provisional COGS would
            // recreate the exact hole V5 was designed to close (revenue books,
            // COGS doesn't, profit overstated forever). Force the operator to
            // repair the CoA. The real-COGS path (INVENTORY_ASSET) keeps the
            // legacy log-and-skip so existing orgs with custom CoAs that lack
            // a 1200 don't suddenly start failing.
            if (creditPurpose == DefaultAccountPurpose.STOCK_OUT_SUSPENSE) {
                throw new BusinessException(
                        "Stock-Out Suspense account (2042) is missing from the chart of accounts "
                                + "for this org — provisional COGS for bill-freely sales cannot "
                                + "post until it is seeded. Re-run the CoA template seed or "
                                + "configure the STOCK_OUT_SUSPENSE default account in settings.",
                        "POS_PROVISIONAL_SUSPENSE_MISSING",
                        org.springframework.http.HttpStatus.PRECONDITION_FAILED);
            }
            log.warn("COGS/{} accounts not configured — skipping: {}", creditPurpose, e.getMessage());
        }
    }

    private String resolvePaidThroughAccount(UUID orgId, PaymentMode mode) {
        return switch (mode) {
            case CASH -> defaultAccountService.getCode(orgId, DefaultAccountPurpose.CASH);
            case UPI, CARD, MIXED -> defaultAccountService.getCode(orgId, DefaultAccountPurpose.BANK);
        };
    }

    private String resolvePaymentMethodAccount(UUID orgId, String paymentMethod) {
        DefaultAccountPurpose purpose = switch (paymentMethod) {
            case "CASH", "UPI" -> DefaultAccountPurpose.CASH;
            case "BANK_TRANSFER", "CHEQUE", "CARD" -> DefaultAccountPurpose.BANK;
            default -> DefaultAccountPurpose.CASH;
        };
        return defaultAccountService.getCode(orgId, purpose);
    }

    private void requireTaxGlAccount(TaxLineItem tli) {
        if (tli.getAccountCode() == null || tli.getAccountCode().isBlank()) {
            throw new BusinessException(
                    "Tax component " + tli.getComponentCode()
                            + " has no GL output account. Configure it in Settings → Tax Account Mapping.",
                    "TAX_GL_ACCOUNT_MISSING", HttpStatus.BAD_REQUEST);
        }
    }
}
