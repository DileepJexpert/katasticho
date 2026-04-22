package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Combined POS + Invoice sales snapshot for the owner dashboard.
 *
 *   totalSales     = cashUpiTotal + creditTotal
 *   cashUpiTotal   = SUM(sales_receipt.total) + SUM(invoice.total WHERE status=PAID)
 *   creditTotal    = SUM(invoice.total WHERE status NOT IN (DRAFT,PAID,CANCELLED))
 */
public record TodaySalesResponse(
        LocalDate from,
        LocalDate to,
        UUID branchFilter,
        BigDecimal totalSales,
        BigDecimal cashUpiTotal,
        BigDecimal creditTotal,
        int transactionCount,
        String currency,
        List<BranchSalesRow> byBranch
) {}
