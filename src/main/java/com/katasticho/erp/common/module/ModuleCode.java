package com.katasticho.erp.common.module;

public final class ModuleCode {

    private ModuleCode() {}

    /** Every module code, for callers that need to enumerate/validate them
     *  (test-account seed, per-org module-visibility overrides). */
    public static final java.util.List<String> ALL = java.util.List.of(
            "ACCOUNTING", "AR", "AP", "GST", "BANK_RECON", "AI_INBOX", "REPORTS",
            "COLLECTIONS", "POS", "INVENTORY", "DISTRIBUTION", "PHARMA", "MANUFACTURING",
            "RECURRING_BILLING", "MULTI_ENTITY", "PAYMENTS", "BATCH_EXPIRY", "CA_CONSOLE",
            "PAYROLL", "FIELD_SALES", "PARTNER_NETWORK", "SUPPLY_CHAIN", "COURIER", "TRANSPORT");

    public static final String ACCOUNTING = "ACCOUNTING";
    public static final String AR = "AR";
    public static final String AP = "AP";
    public static final String GST = "GST";
    public static final String BANK_RECON = "BANK_RECON";
    public static final String AI_INBOX = "AI_INBOX";
    public static final String REPORTS = "REPORTS";
    public static final String COLLECTIONS = "COLLECTIONS";
    public static final String POS = "POS";
    public static final String INVENTORY = "INVENTORY";
    public static final String DISTRIBUTION = "DISTRIBUTION";
    public static final String PHARMA = "PHARMA";
    public static final String MANUFACTURING = "MANUFACTURING";
    public static final String RECURRING_BILLING = "RECURRING_BILLING";
    public static final String MULTI_ENTITY = "MULTI_ENTITY";
    public static final String PAYMENTS = "PAYMENTS";
    public static final String BATCH_EXPIRY = "BATCH_EXPIRY";
    public static final String CA_CONSOLE = "CA_CONSOLE";
    public static final String PAYROLL = "PAYROLL";
    public static final String FIELD_SALES = "FIELD_SALES";
    public static final String PARTNER_NETWORK = "PARTNER_NETWORK";
    public static final String SUPPLY_CHAIN = "SUPPLY_CHAIN";
    public static final String COURIER = "COURIER";
    public static final String TRANSPORT = "TRANSPORT";
}
