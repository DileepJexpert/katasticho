package com.katasticho.erp.tax;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Database-driven tax engine interface.
 *
 * Replaces the old per-country TaxEngine implementations (IndiaGSTEngine, etc.)
 * with a single GenericTaxEngine that reads tax_group / tax_rate tables.
 *
 * Services call:
 *   1. resolveGroupId()  — backward compat: maps legacy gstRate → taxGroupId
 *   2. calculate()       — computes tax components from the group's rates
 *
 * GL account codes come from the database (tax_rate.gl_output_account_id /
 * gl_input_account_id), never hardcoded.
 */
public interface TaxEngine {

    /**
     * Calculate tax for a given tax group, taxable amount, and transaction direction.
     *
     * @param orgId          the organisation
     * @param taxGroupId     the tax group (e.g. "GST 18%", "VAT 10%"); null = exempt
     * @param taxableAmount  the pre-tax line amount
     * @param type           SALE or PURCHASE — determines which GL account to use
     * @return               tax components with amounts and GL account codes
     */
    TaxCalculationResult calculate(UUID orgId, UUID taxGroupId,
                                   BigDecimal taxableAmount, TransactionType type);

    /**
     * Backward compatibility: resolve a legacy gstRate + seller/buyer state
     * to a taxGroupId. Used by services that still accept gstRate from the client.
     *
     * For India: rate=18, same state → "GST 18%"; different state → "IGST 18%"
     * For others: rate=10 → "VAT 10%", "SST 10%", etc.
     *
     * @return the taxGroupId, or empty if no matching group found
     */
    Optional<UUID> resolveGroupId(UUID orgId, BigDecimal rate,
                                  String sellerState, String buyerState);

    // ── Transaction direction ──────────────────────────────────

    enum TransactionType {
        /** Sales invoice, credit note — uses gl_output_account_id */
        SALE,
        /** Purchase bill, vendor credit, expense — uses gl_input_account_id (if recoverable) */
        PURCHASE
    }

    // ── Result records ─────────────────────────────────────────

    record TaxCalculationResult(
            List<TaxComponent> components,
            BigDecimal totalTaxAmount
    ) {}

    record TaxComponent(
            UUID rateId,
            String rateCode,
            String rateName,
            BigDecimal percentage,
            BigDecimal amount,
            UUID glAccountId,
            String glAccountCode,
            boolean recoverable
    ) {}
}
