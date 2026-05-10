package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record DailySalesReport(
    LocalDate date,
    BigDecimal totalGrossAmount,
    BigDecimal totalTax,
    BigDecimal totalNetAmount,
    List<DailySalesReport.ByMode> byPaymentMode,
    List<DailySalesReport.TopItem> topItems
) {
    public record ByMode(
        String paymentMode,
        int transactionCount,
        BigDecimal totalAmount
    ) {}

    public record TopItem(
        String itemName,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal totalAmount
    ) {}
}
