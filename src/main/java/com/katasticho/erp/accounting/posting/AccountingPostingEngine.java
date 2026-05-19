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

        // DR COGS / CR Inventory for tracked items
        BigDecimal totalCost = BigDecimal.ZERO;
        for (SalesReceiptLine line : receipt.getLines()) {
            if (line.getItemId() == null) continue;
            Item item = itemMap.get(line.getItemId());
            if (item == null || !item.isTrackInventory()) continue;
            if (item.getPurchasePrice() == null || item.getPurchasePrice().compareTo(BigDecimal.ZERO) <= 0) continue;
            BigDecimal qty = line.getBaseQuantity() != null ? line.getBaseQuantity() : line.getQuantity();
            totalCost = totalCost.add(
                    item.getPurchasePrice().multiply(qty).setScale(2, RoundingMode.HALF_UP));
        }
        appendCogsLines(lines, orgId, receipt.getReceiptNumber(), totalCost);

        return journalService.postJournal(new JournalPostRequest(
                receipt.getReceiptDate(),
                "POS Sale " + receipt.getReceiptNumber(),
                "POS",
                receipt.getId(),
                lines,
                true));
    }

    // ── Payment Received ───────────────────────────────────────

    public JournalEntry postPaymentReceived(UUID orgId,
                                             String paymentNumber,
                                             String invoiceNumber,
                                             java.time.LocalDate paymentDate,
                                             BigDecimal amount,
                                             String paymentMethod) {
        String debitCode = resolvePaymentMethodAccount(orgId, paymentMethod);

        List<JournalLineRequest> lines = List.of(
                new JournalLineRequest(
                        debitCode,
                        amount, BigDecimal.ZERO,
                        "Payment " + paymentNumber + " received",
                        null, null),
                new JournalLineRequest(
                        defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                        BigDecimal.ZERO, amount,
                        "AR cleared: " + invoiceNumber,
                        null, null)
        );

        return journalService.postJournal(new JournalPostRequest(
                paymentDate,
                "Payment " + paymentNumber + " for " + invoiceNumber,
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

    public JournalEntry postVendorPayment(UUID orgId,
                                           String paymentNumber,
                                           java.time.LocalDate paymentDate,
                                           BigDecimal amount,
                                           BigDecimal tdsAmount,
                                           String paidThroughAccountCode) {
        List<JournalLineRequest> lines = new ArrayList<>();

        BigDecimal apDebit = amount.subtract(tdsAmount);
        lines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP),
                apDebit, BigDecimal.ZERO,
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
                BigDecimal.ZERO, amount,
                "Payment " + paymentNumber + " to vendor",
                null, null));

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
                                  String docNumber, BigDecimal totalCost) {
        if (totalCost.compareTo(BigDecimal.ZERO) <= 0) return;
        try {
            String cogsCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.COGS);
            String inventoryCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.INVENTORY_ASSET);
            lines.add(new JournalLineRequest(
                    cogsCode, totalCost, BigDecimal.ZERO,
                    "COGS: " + docNumber, null, null));
            lines.add(new JournalLineRequest(
                    inventoryCode, BigDecimal.ZERO, totalCost,
                    "Inventory: " + docNumber, null, null));
        } catch (BusinessException e) {
            log.warn("COGS/Inventory accounts not configured — skipping: {}", e.getMessage());
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
