package com.katasticho.erp.pos.entity;

/**
 * Payment mode for POS sales receipts.
 */
public enum PaymentMode {
    CASH,
    UPI,
    CARD,
    MIXED,
    /**
     * Khata / udhaar sale: nothing collected at the counter — the total books
     * to Accounts Receivable against the receipt's contact. Gated by the org
     * setting {@code pos.allow_credit_sales} and requires a contact.
     */
    CREDIT
}
