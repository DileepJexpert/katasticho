package com.katasticho.erp.audit.listener;

import java.util.List;
import java.util.Map;
import java.util.Set;

import static java.util.Map.entry;

/**
 * What the edit log audits and what it ignores.
 *
 * <p>Allowlist over denylist: only books documents and books-relevant masters
 * are audited. High-churn operational tables (stock_movement is already an
 * append-only ledger, GPS pings, tokens, AI suggestions...) stay out so the
 * trail remains signal, not noise. Keyed by fully-qualified entity name as
 * reported by the Hibernate persister.
 */
final class EditLogPolicy {

    private EditLogPolicy() {
    }

    /** Hibernate entity name (FQCN) → audit-trail entity type. */
    static final Map<String, String> AUDITED_ENTITIES = Map.ofEntries(
            entry("com.katasticho.erp.ar.entity.Invoice", "INVOICE"),
            entry("com.katasticho.erp.ar.entity.Payment", "PAYMENT"),
            entry("com.katasticho.erp.ar.entity.CreditNote", "CREDIT_NOTE"),
            entry("com.katasticho.erp.ar.entity.CustomerReceipt", "CUSTOMER_RECEIPT"),
            entry("com.katasticho.erp.ap.entity.PurchaseBill", "PURCHASE_BILL"),
            entry("com.katasticho.erp.ap.entity.VendorPayment", "VENDOR_PAYMENT"),
            entry("com.katasticho.erp.ap.entity.VendorCredit", "VENDOR_CREDIT"),
            entry("com.katasticho.erp.expense.entity.Expense", "EXPENSE"),
            entry("com.katasticho.erp.accounting.entity.JournalEntry", "JOURNAL_ENTRY"),
            entry("com.katasticho.erp.accounting.entity.Account", "ACCOUNT"),
            entry("com.katasticho.erp.sales.entity.SalesOrder", "SALES_ORDER"),
            entry("com.katasticho.erp.sales.entity.DeliveryChallan", "DELIVERY_CHALLAN"),
            entry("com.katasticho.erp.procurement.entity.PurchaseOrder", "PURCHASE_ORDER"),
            entry("com.katasticho.erp.procurement.entity.StockReceipt", "STOCK_RECEIPT"),
            entry("com.katasticho.erp.pos.entity.SalesReceipt", "POS_RECEIPT"),
            entry("com.katasticho.erp.estimate.entity.Estimate", "ESTIMATE"),
            entry("com.katasticho.erp.contact.entity.Contact", "CONTACT"),
            entry("com.katasticho.erp.inventory.entity.Item", "ITEM"));

    /**
     * Property names tried (in order) for a human-readable row label —
     * the document number for vouchers, display name for masters.
     */
    static final List<String> LABEL_PROPERTIES = List.of(
            "invoiceNumber", "billNumber", "receiptNumber", "paymentNumber",
            "creditNoteNumber", "creditNumber", "expenseNumber", "entryNumber",
            "salesorderNumber", "challanNumber", "poNumber", "estimateNumber",
            "displayName", "name");

    /**
     * Bookkeeping columns that change on every write and carry no audit
     * signal of their own. A dirty set consisting only of these is skipped
     * entirely (no log row).
     */
    static final Set<String> IGNORED_PROPERTIES = Set.of(
            "createdAt", "updatedAt", "createdBy", "updatedBy", "version");
}
