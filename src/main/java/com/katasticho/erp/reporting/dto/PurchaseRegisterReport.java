package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record PurchaseRegisterReport(
    LocalDate startDate,
    LocalDate endDate,
    BigDecimal totalTaxable,
    BigDecimal totalCgst,
    BigDecimal totalSgst,
    BigDecimal totalIgst,
    BigDecimal grandTotal,
    List<PurchaseRegisterReport.Line> lines
) {
    public record Line(
        String billNumber,
        LocalDate billDate,
        String vendorName,
        String vendorGstin,
        String itemDescription,
        String hsnCode,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal taxableAmount,
        BigDecimal cgstAmount,
        BigDecimal sgstAmount,
        BigDecimal igstAmount,
        BigDecimal totalAmount
    ) {}
}
