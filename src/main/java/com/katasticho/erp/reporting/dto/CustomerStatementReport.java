package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CustomerStatementReport(
    UUID customerId,
    String customerName,
    LocalDate startDate,
    LocalDate endDate,
    BigDecimal openingBalance,
    BigDecimal totalInvoices,
    BigDecimal totalPayments,
    BigDecimal closingBalance,
    List<CustomerStatementReport.Line> lines
) {
    public record Line(
        String transactionType,
        String documentNumber,
        LocalDate transactionDate,
        BigDecimal debitAmount,
        BigDecimal creditAmount,
        BigDecimal runningBalance
    ) {}
}
