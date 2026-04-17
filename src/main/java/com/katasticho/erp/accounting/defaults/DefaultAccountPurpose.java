package com.katasticho.erp.accounting.defaults;

/**
 * Identifies the role an account plays in posting logic.
 *
 * Each purpose maps to ONE Chart-of-Accounts row per org via
 * {@code org_default_account}. Services should call
 * {@code DefaultAccountService.get(orgId, purpose)} instead of
 * looking up accounts by hardcoded GL code.
 *
 * The {@link #defaultCode} is the seed code used when no override
 * exists yet — it must exist in the CoA template seeded for the org.
 */
public enum DefaultAccountPurpose {

    // Codes below MUST exist in the CoA template seeded by V1
    // (coa_template, industry='TRADING' — cloned for RETAIL/SERVICES/F_AND_B).

    // ── Receivables / Payables ────────────────────────────────
    AR                  ("1100", "Accounts Receivable"),
    AP                  ("2010", "Accounts Payable"),

    // ── Cash & Bank ───────────────────────────────────────────
    CASH                ("1010", "Cash"),
    BANK                ("1020", "Bank Account"),

    // ── Revenue / Expense ─────────────────────────────────────
    SALES_REVENUE       ("4010", "Sales Revenue"),
    PURCHASE            ("5020", "Purchase Expense"),

    // ── Discounts ─────────────────────────────────────────────
    DISCOUNT_GIVEN      ("5290", "Discount Allowed"),
    DISCOUNT_RECEIVED   ("4120", "Discount Received"),

    // ── Adjustments ───────────────────────────────────────────
    ROUNDING_OFF        ("5600", "Rounding Adjustment"),
    BANK_CHARGES        ("5280", "Bank Charges"),

    // ── Advances ──────────────────────────────────────────────
    CUSTOMER_ADVANCE    ("2100", "Advance from Customers"),
    VENDOR_ADVANCE      ("1400", "Advances to Suppliers"),

    // ── Withholding (TDS) ─────────────────────────────────────
    TDS_PAYABLE         ("2030", "TDS Payable");

    private final String defaultCode;
    private final String label;

    DefaultAccountPurpose(String defaultCode, String label) {
        this.defaultCode = defaultCode;
        this.label = label;
    }

    public String defaultCode() { return defaultCode; }
    public String label()       { return label; }
}
