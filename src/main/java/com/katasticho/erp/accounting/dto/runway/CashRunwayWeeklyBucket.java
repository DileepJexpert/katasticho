package com.katasticho.erp.accounting.dto.runway;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CashRunwayWeeklyBucket(
        int weekNumber,
        LocalDate startDate,
        LocalDate endDate,
        String weekLabel,
        BigDecimal openingBalance,
        
        // Inflows
        BigDecimal arInvoices,
        BigDecimal salesOrdersPipeline,
        BigDecimal recurringRevenue,
        BigDecimal totalInflows,
        
        // Outflows
        BigDecimal apBills,
        BigDecimal purchaseOrdersPipeline,
        BigDecimal payroll,
        BigDecimal statutoryTax,
        BigDecimal operatingExpenses,
        BigDecimal plannedCapex,
        BigDecimal totalOutflows,
        
        // Net & Closing
        BigDecimal netCashFlow,
        BigDecimal closingBalance,
        boolean isDeficit,
        BigDecimal deficitAmount
) {}