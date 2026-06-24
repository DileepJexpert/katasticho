package com.katasticho.erp.procurement.rfq.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record CompareQuotesResponse(
        UUID rfqId,
        UUID lowestTotalQuoteId,
        List<SupplierSummary> supplierSummaries,
        List<LineComparison> lineComparisons
) {
    public record SupplierSummary(
            UUID quoteId,
            UUID supplierContactId,
            String quoteNumber,
            BigDecimal totalAmount,
            Integer avgLeadTimeDays,
            String status
    ) {}

    public record LineComparison(
            UUID itemId,
            String description,
            BigDecimal quantity,
            UUID lowestPriceQuoteId,
            BigDecimal lowestUnitPrice,
            List<PerSupplierPrice> prices
    ) {
        public record PerSupplierPrice(
                UUID quoteId,
                UUID supplierContactId,
                BigDecimal unitPrice,
                Integer leadTimeDays
        ) {}
    }
}
