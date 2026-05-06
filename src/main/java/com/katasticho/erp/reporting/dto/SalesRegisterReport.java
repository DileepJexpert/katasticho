package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record SalesRegisterReport(
    LocalDate startDate,
    LocalDate endDate,
    BigDecimal totalTaxable,
    BigDecimal totalCgst,
    BigDecimal totalSgst,
    BigDecimal totalIgst,
    BigDecimal grandTotal,
    List<SalesRegisterReport.Line> lines
) {
    public record Line(
        String documentType,
        String documentNumber,
        LocalDate documentDate,
        String customerName,
        String itemDescription,
        String hsnCode,
        BigDecimal quantity,
        String unit,
        BigDecimal unitPrice,
        BigDecimal taxableAmount,
        BigDecimal cgstAmount,
        BigDecimal sgstAmount,
        BigDecimal igstAmount,
        BigDecimal totalAmount,
        BigDecimal gstRate,
        String placeOfSupply
    ) {}
}
