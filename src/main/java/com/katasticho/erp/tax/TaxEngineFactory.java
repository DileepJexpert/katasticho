package com.katasticho.erp.tax;

/**
 * @deprecated Replaced by {@link GenericTaxEngine} which is the sole
 * {@link TaxEngine} bean. No factory routing needed — one engine handles
 * all countries via database-driven tax_group / tax_rate tables.
 */
@Deprecated(forRemoval = true)
public class TaxEngineFactory {
    // Intentionally empty — inject TaxEngine directly instead.
}
