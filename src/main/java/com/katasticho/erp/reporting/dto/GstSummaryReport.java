package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record GstSummaryReport(
        LocalDate startDate,
        LocalDate endDate,
        BigDecimal totalTaxableSupplies,
        BigDecimal totalCgst,
        BigDecimal totalSgst,
        BigDecimal totalIgst,
        BigDecimal totalCess,
        BigDecimal totalOutputTax,
        BigDecimal totalInputCredit,
        BigDecimal netPayable,
        List<SupplyBreakdown> outputSupplies,
        List<InputBreakdown> inputCredits
) {
    public record SupplyBreakdown(
            String sourceType,
            long transactionCount,
            BigDecimal taxableAmount,
            BigDecimal cgst,
            BigDecimal sgst,
            BigDecimal igst
    ) {}

    public record InputBreakdown(
            String sourceType,
            long transactionCount,
            BigDecimal taxableAmount,
            BigDecimal cgst,
            BigDecimal sgst,
            BigDecimal igst
    ) {}
}
