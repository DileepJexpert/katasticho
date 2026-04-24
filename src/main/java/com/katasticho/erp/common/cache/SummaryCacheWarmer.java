package com.katasticho.erp.common.cache;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.cache.dto.CachedDailySummary;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class SummaryCacheWarmer {

    private final InvoiceRepository invoiceRepository;
    private final SalesReceiptRepository salesReceiptRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final StockBatchRepository stockBatchRepository;
    private final CacheService cacheService;

    private static final Duration SUMMARY_TTL = Duration.ofHours(12);

    public void warmDailySummary(UUID orgId) {
        log.info("[CacheWarmer] Warming daily summary for org={}", orgId);
        LocalDate today = LocalDate.now();

        BigDecimal posSales = salesReceiptRepository.sumTotalByOrgAndDateRange(orgId, today, today);
        BigDecimal paidInvoices = invoiceRepository.sumPaidInvoicesByOrgAndDateRange(orgId, today, today);
        BigDecimal creditSales = invoiceRepository.sumCreditSalesByOrgAndDateRange(orgId, today, today);
        BigDecimal cashUpi = posSales.add(paidInvoices);
        BigDecimal totalSales = cashUpi.add(creditSales);

        long posCount = salesReceiptRepository.countByOrgAndDateRange(orgId, today, today);
        long invCount = invoiceRepository.countByOrgAndDateRange(orgId, today, today);
        int txnCount = (int) (posCount + invCount);

        BigDecimal outstandingAr = invoiceRepository.sumOutstandingAr(orgId);

        List<Invoice> overdue = invoiceRepository.findOverdueInvoices(orgId, today);
        int overdueCount = overdue.size();
        BigDecimal overdueAmount = overdue.stream()
                .map(Invoice::getBalanceDue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        int lowStockCount = stockBalanceRepository.findLowStock(orgId).size();

        LocalDate expiryHorizon = today.plusDays(30);
        List<StockBatch> expiring = stockBatchRepository.findExpiringWithStock(orgId, expiryHorizon);
        int expiringCount = expiring.size();

        CachedDailySummary summary = new CachedDailySummary(
                today, totalSales, cashUpi, creditSales, txnCount,
                outstandingAr, overdueCount, overdueAmount,
                lowStockCount, expiringCount);

        cacheService.put(CacheKeys.dailySummary(orgId), summary, SUMMARY_TTL);
        log.info("[CacheWarmer] Daily summary cached for org={}: sales={}, outstanding={}, overdue={}, lowStock={}, expiring={}",
                orgId, totalSales, outstandingAr, overdueCount, lowStockCount, expiringCount);
    }
}
