package com.katasticho.erp.common.cache.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CachedDailySummary(
        LocalDate date,
        BigDecimal totalSales,
        BigDecimal cashUpiSales,
        BigDecimal creditSales,
        int transactionCount,
        BigDecimal outstandingAr,
        int overdueInvoiceCount,
        BigDecimal overdueAmount,
        int lowStockItemCount,
        int expiringSoonBatchCount
) {}
