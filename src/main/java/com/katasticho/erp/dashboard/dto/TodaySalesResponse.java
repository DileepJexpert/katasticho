package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Today's sales snapshot for the owner dashboard.
 *
 *   Revenue           = SUM(invoice.total)        over [from..to]
 *   Cash collected    = SUM(payment.amount)       over [from..to]
 *   Per-branch split  = group by invoice.branchId over [from..to]
 *
 * When a specific branchId filter is applied, byBranch contains only
 * that one row and the top-level revenue / cashCollected already reflect
 * the filter.
 */
public record TodaySalesResponse(
        LocalDate from,
        LocalDate to,
        UUID branchFilter,
        BigDecimal revenue,
        BigDecimal cashCollected,
        String currency,
        List<BranchSalesRow> byBranch
) {}
