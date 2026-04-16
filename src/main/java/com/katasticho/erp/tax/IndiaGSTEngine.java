package com.katasticho.erp.tax;

/**
 * @deprecated Replaced by {@link GenericTaxEngine} which is database-driven
 * and works for any country. This class is kept only so existing Spring
 * component-scan references don't break during migration. It is never
 * used at runtime — GenericTaxEngine is the sole {@link TaxEngine} bean.
 */
@Deprecated(forRemoval = true)
public class IndiaGSTEngine {
    // Intentionally empty — all logic moved to GenericTaxEngine + tax_rate tables.
}
