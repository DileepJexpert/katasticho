package com.katasticho.erp.pos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CashRegisterSummary(
        UUID id,
        LocalDate date,
        String status,
        BigDecimal openingBalance,
        BigDecimal cashSales,
        BigDecimal upiSales,
        BigDecimal cardSales,
        BigDecimal totalSales,
        BigDecimal totalExpenses,
        BigDecimal expectedClosing,
        BigDecimal actualClosing,
        BigDecimal variance,
        long transactionCount,
        List<ExpenseLine> expenses
) {
    public record ExpenseLine(UUID id, BigDecimal amount, String description, String expenseTime) {}
}
