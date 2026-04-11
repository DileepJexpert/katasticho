package com.katasticho.erp.tax;

import java.math.BigDecimal;
import java.util.List;

/**
 * Strategy Pattern: all tax calculation goes through this interface.
 * v1 has ONE implementation: IndiaGSTEngine.
 * v3 adds: KenyaVATEngine, NigeriaVATEngine, UAEVATEngine, etc.
 * Selection: TaxEngineFactory.getEngine(org.getTaxRegime())
 *
 * NEVER hardcode tax rates or CGST/SGST logic in service code.
 */
public interface TaxEngine {

    TaxResult calculateTax(TaxableItem item, TaxContext context);

    String getTaxRegimeCode();

    String getTaxLabel();

    String getTaxIdLabel();

    List<String> getComponentLabels();

    record TaxableItem(
            String description,
            String hsnCode,
            BigDecimal amount,
            BigDecimal gstRate
    ) {}

    record TaxContext(
            String sellerCountry,
            String sellerRegion,
            String buyerCountry,
            String buyerRegion,
            String itemHsnCode,
            TransactionType transactionType,
            java.time.LocalDate transactionDate,
            boolean isReverseCharge
    ) {}

    record TaxResult(
            List<TaxComponentResult> components,
            BigDecimal totalTaxAmount,
            String taxRegime,
            List<String> warnings
    ) {}

    record TaxComponentResult(
            String componentCode,
            BigDecimal rate,
            BigDecimal amount,
            String accountCode
    ) {}

    enum TransactionType {
        DOMESTIC, EXPORT, IMPORT
    }
}
