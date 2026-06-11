package com.katasticho.erp.migration.tally;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Masters parsed from a TallyPrime "Export → Masters" XML file.
 *
 * <p>{@code groupParents} maps every Tally GROUP to its parent group, so a
 * ledger under a custom subgroup ("Local Debtors" → "Sundry Debtors") can be
 * resolved up to the predefined primary group that decides its mapping.
 *
 * <p>Sign convention: Tally XML writes <b>debit balances as negative</b>
 * (₹15,000 Dr exports as {@code -15000.00}). Values here are raw; the importer
 * normalizes per entity type.
 */
public record TallyMasters(
        Map<String, String> groupParents,
        List<TallyLedger> ledgers,
        List<TallyStockItem> stockItems
) {
    public record TallyLedger(
            String name,
            String parentGroup,
            BigDecimal openingBalance,   // raw Tally sign: negative = Dr
            String gstin,
            String stateName,
            String address,
            String email,
            String phone,
            String mobile,
            String pan
    ) {}

    public record TallyStockItem(
            String name,
            String parentGroup,          // stock group → category
            String baseUnit,
            String hsnCode,
            BigDecimal gstRate,
            BigDecimal openingQty,
            BigDecimal openingRate
    ) {}
}
