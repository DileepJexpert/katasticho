package com.katasticho.erp.dashboard;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceLineRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.dashboard.dto.*;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.repository.SalesReceiptLineRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class DashboardService {

    private final InvoiceRepository invoiceRepository;
    private final PaymentRepository paymentRepository;
    private final InvoiceLineRepository invoiceLineRepository;
    private final ItemRepository itemRepository;
    private final BranchRepository branchRepository;
    private final OrganisationRepository organisationRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final ContactRepository contactRepository;
    private final SalesReceiptRepository salesReceiptRepository;
    private final SalesReceiptLineRepository salesReceiptLineRepository;
    private final StockBatchRepository stockBatchRepository;
    private final StockBatchBalanceRepository stockBatchBalanceRepository;

    @Transactional(readOnly = true)
    public TodaySalesResponse getTodaySales(LocalDate from, LocalDate to, UUID branchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : today;
        LocalDate effectiveTo = to != null ? to : today;
        if (effectiveTo.isBefore(effectiveFrom)) {
            throw new BusinessException("'to' must be on or after 'from'",
                    "DASHBOARD_INVALID_RANGE",
                    org.springframework.http.HttpStatus.BAD_REQUEST);
        }

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        BigDecimal posSales;
        BigDecimal paidInvoices;
        BigDecimal creditSales;
        long posCount;
        long invoiceCount;

        if (branchId != null) {
            branchRepository.findByIdAndOrgIdAndIsDeletedFalse(branchId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Branch", branchId));
            posSales = salesReceiptRepository.sumTotalByOrgBranchAndDateRange(
                    orgId, branchId, effectiveFrom, effectiveTo);
            paidInvoices = invoiceRepository.sumPaidInvoicesByOrgBranchAndDateRange(
                    orgId, branchId, effectiveFrom, effectiveTo);
            creditSales = invoiceRepository.sumCreditSalesByOrgBranchAndDateRange(
                    orgId, branchId, effectiveFrom, effectiveTo);
        } else {
            posSales = salesReceiptRepository.sumTotalByOrgAndDateRange(
                    orgId, effectiveFrom, effectiveTo);
            paidInvoices = invoiceRepository.sumPaidInvoicesByOrgAndDateRange(
                    orgId, effectiveFrom, effectiveTo);
            creditSales = invoiceRepository.sumCreditSalesByOrgAndDateRange(
                    orgId, effectiveFrom, effectiveTo);
        }

        posCount = salesReceiptRepository.countByOrgAndDateRange(orgId, effectiveFrom, effectiveTo);
        invoiceCount = invoiceRepository.countByOrgAndDateRange(orgId, effectiveFrom, effectiveTo);

        BigDecimal cashUpiTotal = posSales.add(paidInvoices);
        BigDecimal totalSales = cashUpiTotal.add(creditSales);
        int transactionCount = (int) (posCount + invoiceCount);

        List<BranchSalesRow> byBranch = buildBranchRollup(
                orgId, effectiveFrom, effectiveTo, branchId, totalSales);

        return new TodaySalesResponse(
                effectiveFrom, effectiveTo, branchId,
                totalSales, cashUpiTotal, creditSales, transactionCount,
                org.getBaseCurrency(), byBranch);
    }

    private List<BranchSalesRow> buildBranchRollup(
            UUID orgId, LocalDate from, LocalDate to, UUID branchFilter, BigDecimal totalSales) {
        List<Branch> branches = branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId);
        if (branches.isEmpty()) {
            return List.of();
        }

        Map<UUID, BigDecimal> invoiceByBranch = invoiceRepository
                .sumRevenueByBranch(orgId, from, to)
                .stream()
                .collect(Collectors.toMap(
                        InvoiceRepository.RevenueByBranchRow::getBranchId,
                        InvoiceRepository.RevenueByBranchRow::getTotal));

        Map<UUID, BigDecimal> posByBranch = salesReceiptRepository
                .sumTotalByBranch(orgId, from, to)
                .stream()
                .collect(Collectors.toMap(
                        SalesReceiptRepository.RevenueByBranchRow::getBranchId,
                        SalesReceiptRepository.RevenueByBranchRow::getTotal));

        BigDecimal denominator = totalSales != null && totalSales.signum() > 0
                ? totalSales : BigDecimal.ONE;

        return branches.stream()
                .filter(b -> branchFilter == null || branchFilter.equals(b.getId()))
                .map(b -> {
                    BigDecimal invRev = invoiceByBranch.getOrDefault(b.getId(), BigDecimal.ZERO);
                    BigDecimal posRev = posByBranch.getOrDefault(b.getId(), BigDecimal.ZERO);
                    BigDecimal combined = invRev.add(posRev);
                    BigDecimal pct = totalSales != null && totalSales.signum() > 0
                            ? combined.multiply(BigDecimal.valueOf(100))
                                 .divide(denominator, 2, RoundingMode.HALF_UP)
                            : BigDecimal.ZERO;
                    return new BranchSalesRow(b.getId(), b.getCode(), b.getName(), combined, pct);
                })
                .sorted(Comparator.comparing(BranchSalesRow::revenue).reversed())
                .toList();
    }

    @Transactional(readOnly = true)
    public ApSummaryResponse getApSummary(LocalDate from, LocalDate to, UUID branchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate weekFromNow = today.plusDays(7);

        List<PurchaseBill> outstanding = purchaseBillRepository.findOutstandingBills(orgId);

        BigDecimal totalOutstanding = BigDecimal.ZERO;
        int overdueCount = 0;
        BigDecimal dueThisWeek = BigDecimal.ZERO;
        int dueThisWeekCount = 0;

        for (PurchaseBill bill : outstanding) {
            totalOutstanding = totalOutstanding.add(bill.getBalanceDue());

            if (bill.getDueDate() != null && bill.getDueDate().isBefore(today)) {
                overdueCount++;
            }
            if (bill.getDueDate() != null
                    && !bill.getDueDate().isBefore(today)
                    && !bill.getDueDate().isAfter(weekFromNow)) {
                dueThisWeek = dueThisWeek.add(bill.getBalanceDue());
                dueThisWeekCount++;
            }
        }

        List<Branch> branches = branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId);
        List<BranchPurchaseRow> byBranch;
        if (branches.isEmpty()) {
            byBranch = List.of();
        } else {
            Map<UUID, BigDecimal> purchasesByBranch = outstanding.stream()
                    .filter(b -> b.getBranchId() != null)
                    .collect(Collectors.groupingBy(
                            PurchaseBill::getBranchId,
                            Collectors.reducing(BigDecimal.ZERO, PurchaseBill::getBalanceDue, BigDecimal::add)));

            final BigDecimal finalOutstanding = totalOutstanding;
            BigDecimal denom = finalOutstanding.signum() > 0 ? finalOutstanding : BigDecimal.ONE;
            byBranch = branches.stream()
                    .filter(b -> branchId == null || branchId.equals(b.getId()))
                    .map(b -> {
                        BigDecimal amt = purchasesByBranch.getOrDefault(b.getId(), BigDecimal.ZERO);
                        BigDecimal pct = finalOutstanding.signum() > 0
                                ? amt.multiply(BigDecimal.valueOf(100)).divide(denom, 2, RoundingMode.HALF_UP)
                                : BigDecimal.ZERO;
                        return new BranchPurchaseRow(b.getId(), b.getCode(), b.getName(), amt, pct);
                    })
                    .sorted(Comparator.comparing(BranchPurchaseRow::purchases).reversed())
                    .toList();
        }

        return new ApSummaryResponse(totalOutstanding, overdueCount, dueThisWeek, dueThisWeekCount, byBranch);
    }

    @Transactional(readOnly = true)
    public List<RecentBillResponse> getRecentBills(int limit) {
        UUID orgId = TenantContext.getCurrentOrgId();
        int capped = Math.max(1, Math.min(limit, 20));

        Page<PurchaseBill> page = purchaseBillRepository
                .findByOrgIdAndIsDeletedFalseOrderByBillDateDesc(orgId, PageRequest.of(0, capped));

        Map<UUID, String> contactNames = new HashMap<>();

        return page.getContent().stream().map(bill -> {
            String vendorName = "Unknown";
            if (bill.getContactId() != null) {
                vendorName = contactNames.computeIfAbsent(bill.getContactId(), cid ->
                        contactRepository.findById(cid)
                                .map(Contact::getDisplayName)
                                .orElse("Unknown"));
            }
            return new RecentBillResponse(
                    bill.getId(),
                    bill.getBillNumber(),
                    vendorName,
                    bill.getStatus(),
                    bill.getTotalAmount(),
                    bill.getBillDate());
        }).toList();
    }

    @Transactional(readOnly = true)
    public ArSummaryResponse getArSummary() {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate weekFromNow = today.plusDays(7);

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<Invoice> outstanding = invoiceRepository.findOutstandingInvoices(orgId);

        int overdueCount = 0;
        BigDecimal dueThisWeek = BigDecimal.ZERO;
        int dueThisWeekCount = 0;

        for (Invoice inv : outstanding) {
            if (inv.getDueDate() != null && inv.getDueDate().isBefore(today)) {
                overdueCount++;
            }
            if (inv.getDueDate() != null
                    && !inv.getDueDate().isBefore(today)
                    && !inv.getDueDate().isAfter(weekFromNow)) {
                dueThisWeek = dueThisWeek.add(inv.getBalanceDue());
                dueThisWeekCount++;
            }
        }

        BigDecimal totalOutstanding = invoiceRepository.sumOutstandingAr(orgId);

        return new ArSummaryResponse(
                totalOutstanding, overdueCount, dueThisWeek, dueThisWeekCount,
                org.getBaseCurrency());
    }

    @Transactional(readOnly = true)
    public RevenueTrendResponse getRevenueTrend(int days) {
        UUID orgId = TenantContext.getCurrentOrgId();
        int cappedDays = Math.max(7, Math.min(days, 90));
        LocalDate today = LocalDate.now();
        LocalDate from = today.minusDays(cappedDays - 1);

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Map<LocalDate, BigDecimal> invoiceByDate = invoiceRepository
                .sumRevenueDailyByOrg(orgId, from, today)
                .stream()
                .collect(Collectors.toMap(
                        InvoiceRepository.DailyRevenueRow::getDate,
                        InvoiceRepository.DailyRevenueRow::getTotal));

        Map<LocalDate, BigDecimal> posByDate = salesReceiptRepository
                .sumTotalDailyByOrg(orgId, from, today)
                .stream()
                .collect(Collectors.toMap(
                        SalesReceiptRepository.DailyRevenueRow::getDate,
                        SalesReceiptRepository.DailyRevenueRow::getTotal));

        List<RevenueTrendResponse.DailyPoint> trend = from.datesUntil(today.plusDays(1))
                .map(d -> {
                    BigDecimal invRev = invoiceByDate.getOrDefault(d, BigDecimal.ZERO);
                    BigDecimal posRev = posByDate.getOrDefault(d, BigDecimal.ZERO);
                    return new RevenueTrendResponse.DailyPoint(d, invRev.add(posRev));
                })
                .toList();

        BigDecimal totalRevenue = trend.stream()
                .map(RevenueTrendResponse.DailyPoint::revenue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new RevenueTrendResponse(from, today, cappedDays, totalRevenue,
                org.getBaseCurrency(), trend);
    }

    @Transactional(readOnly = true)
    public MonthlyProfitResponse getMonthlyProfit(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate firstOfMonth = today.withDayOfMonth(1);
        LocalDate effectiveFrom = from != null ? from : firstOfMonth;
        LocalDate effectiveTo = to != null ? to : today;
        if (effectiveTo.isBefore(effectiveFrom)) {
            throw new BusinessException("'to' must be on or after 'from'",
                    "DASHBOARD_INVALID_RANGE",
                    org.springframework.http.HttpStatus.BAD_REQUEST);
        }

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        BigDecimal invoiceRevenue = invoiceRepository.sumRevenueByOrgAndDateRange(
                orgId, effectiveFrom, effectiveTo);
        BigDecimal posRevenue = salesReceiptRepository.sumTotalByOrgAndDateRange(
                orgId, effectiveFrom, effectiveTo);
        BigDecimal revenue = invoiceRevenue.add(posRevenue);
        BigDecimal cogs = purchaseBillRepository.sumCogsByOrgAndDateRange(
                orgId, effectiveFrom, effectiveTo);
        BigDecimal grossProfit = revenue.subtract(cogs);

        return new MonthlyProfitResponse(
                effectiveFrom, effectiveTo, revenue, cogs, grossProfit,
                org.getBaseCurrency());
    }

    @Transactional(readOnly = true)
    public List<TopSellingItem> getTopSelling(LocalDate from, LocalDate to, int limit) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : today;
        LocalDate effectiveTo = to != null ? to : today;
        int cappedLimit = Math.max(1, Math.min(limit, 20));

        List<InvoiceLineRepository.TopSellingRow> invoiceRows = invoiceLineRepository
                .findTopSelling(orgId, effectiveFrom, effectiveTo, PageRequest.of(0, cappedLimit));

        List<SalesReceiptLineRepository.TopSellingRow> posRows = salesReceiptLineRepository
                .findTopSelling(orgId, effectiveFrom, effectiveTo, PageRequest.of(0, cappedLimit));

        // Merge by itemId: combine qty + revenue from both sources
        Map<UUID, MergedTopSelling> merged = new LinkedHashMap<>();
        for (InvoiceLineRepository.TopSellingRow row : invoiceRows) {
            merged.computeIfAbsent(row.getItemId(), k -> new MergedTopSelling(k, row.getDescription()))
                    .add(row.getTotalQty(), row.getTotalRevenue());
        }
        for (SalesReceiptLineRepository.TopSellingRow row : posRows) {
            merged.computeIfAbsent(row.getItemId(), k -> new MergedTopSelling(k, row.getDescription()))
                    .add(row.getTotalQty(), row.getTotalRevenue());
        }

        if (merged.isEmpty()) {
            return List.of();
        }

        List<MergedTopSelling> sorted = merged.values().stream()
                .sorted(Comparator.comparing(MergedTopSelling::getTotalQty).reversed())
                .limit(cappedLimit)
                .toList();

        List<UUID> itemIds = sorted.stream().map(MergedTopSelling::getItemId).toList();
        Map<UUID, Item> itemsById = itemRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, i -> i));

        List<TopSellingItem> result = new ArrayList<>(sorted.size());
        int rank = 1;
        for (MergedTopSelling m : sorted) {
            Item item = itemsById.get(m.getItemId());
            result.add(new TopSellingItem(
                    rank++,
                    m.getItemId(),
                    item != null ? item.getSku() : null,
                    item != null ? item.getName() : m.getDescription(),
                    item != null ? item.getUnitOfMeasure() : null,
                    m.getTotalQty(),
                    m.getTotalRevenue()));
        }
        return result;
    }

    @Transactional(readOnly = true)
    public List<RecentTransactionResponse> getRecentTransactions(LocalDate from, LocalDate to, int limit) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : today;
        LocalDate effectiveTo = to != null ? to : today;
        int capped = Math.max(1, Math.min(limit, 20));

        List<SalesReceipt> receipts = salesReceiptRepository
                .findRecentByOrgAndDateRange(orgId, effectiveFrom, effectiveTo, PageRequest.of(0, capped));
        List<Invoice> invoices = invoiceRepository
                .findRecentByOrgAndDateRange(orgId, effectiveFrom, effectiveTo, PageRequest.of(0, capped));

        Map<UUID, String> contactNames = new HashMap<>();

        List<RecentTransactionResponse> all = new ArrayList<>();

        for (SalesReceipt r : receipts) {
            String name = "Walk-in";
            if (r.getContactId() != null) {
                name = contactNames.computeIfAbsent(r.getContactId(), cid ->
                        contactRepository.findById(cid)
                                .map(Contact::getDisplayName)
                                .orElse("Walk-in"));
            }
            all.add(new RecentTransactionResponse(
                    r.getId(), "POS", r.getReceiptNumber(), name,
                    r.getTotal(), r.getPaymentMode().name(), r.getCreatedAt()));
        }

        for (Invoice inv : invoices) {
            String name = contactNames.computeIfAbsent(inv.getContactId(), cid ->
                    contactRepository.findById(cid)
                            .map(Contact::getDisplayName)
                            .orElse("Unknown"));
            String mode = "PAID".equals(inv.getStatus()) ? "PAID" : "CREDIT";
            all.add(new RecentTransactionResponse(
                    inv.getId(), "INVOICE", inv.getInvoiceNumber(), name,
                    inv.getTotalAmount(), mode, inv.getCreatedAt()));
        }

        all.sort(Comparator.comparing(RecentTransactionResponse::createdAt).reversed());
        return all.stream().limit(capped).toList();
    }

    @Transactional(readOnly = true)
    public DailySummaryResponse getDailySummary(int days) {
        UUID orgId = TenantContext.getCurrentOrgId();
        int cappedDays = Math.max(1, Math.min(days, 30));
        LocalDate today = LocalDate.now();
        LocalDate weekStart = today.minusDays(6);
        LocalDate rangeStart = today.minusDays(cappedDays - 1);

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        // --- today snapshot ---
        BigDecimal posSalesToday = salesReceiptRepository.sumTotalByOrgAndDateRange(orgId, today, today);
        BigDecimal paidInvToday = invoiceRepository.sumPaidInvoicesByOrgAndDateRange(orgId, today, today);
        BigDecimal creditInvToday = invoiceRepository.sumCreditSalesByOrgAndDateRange(orgId, today, today);
        BigDecimal cashUpiToday = posSalesToday.add(paidInvToday);
        BigDecimal todaySale = cashUpiToday.add(creditInvToday);

        BigDecimal posCostToday = salesReceiptLineRepository.sumCostByOrgAndDateRange(orgId, today, today);
        BigDecimal invCostToday = invoiceLineRepository.sumCostByOrgAndDateRange(orgId, today, today);
        BigDecimal todayCost = posCostToday.add(invCostToday);
        BigDecimal todayEarning = todaySale.subtract(todayCost);

        long posCountToday = salesReceiptRepository.countByOrgAndDateRange(orgId, today, today);
        long invCountToday = invoiceRepository.countByOrgAndDateRange(orgId, today, today);
        int billCount = (int) (posCountToday + invCountToday);

        var todaySnapshot = new DailySummaryResponse.TodaySnapshot(
                todaySale, todayCost, todayEarning, cashUpiToday, creditInvToday, billCount);

        // --- daily trend ---
        Map<LocalDate, BigDecimal> posSaleByDate = salesReceiptRepository
                .sumTotalDailyByOrg(orgId, rangeStart, today).stream()
                .collect(Collectors.toMap(SalesReceiptRepository.DailyRevenueRow::getDate,
                        SalesReceiptRepository.DailyRevenueRow::getTotal));

        Map<LocalDate, BigDecimal> invSaleByDate = invoiceRepository
                .sumRevenueDailyByOrg(orgId, rangeStart, today).stream()
                .collect(Collectors.toMap(InvoiceRepository.DailyRevenueRow::getDate,
                        InvoiceRepository.DailyRevenueRow::getTotal));

        Map<LocalDate, BigDecimal> posCostByDate = salesReceiptLineRepository
                .sumCostDailyByOrg(orgId, rangeStart, today).stream()
                .collect(Collectors.toMap(SalesReceiptLineRepository.DailyCostRow::getDate,
                        SalesReceiptLineRepository.DailyCostRow::getCost));

        Map<LocalDate, BigDecimal> invCostByDate = invoiceLineRepository
                .sumCostDailyByOrg(orgId, rangeStart, today).stream()
                .collect(Collectors.toMap(InvoiceLineRepository.DailyCostRow::getDate,
                        InvoiceLineRepository.DailyCostRow::getCost));

        List<DailySummaryResponse.DailyRow> daily = rangeStart.datesUntil(today.plusDays(1))
                .map(d -> {
                    BigDecimal sale = posSaleByDate.getOrDefault(d, BigDecimal.ZERO)
                            .add(invSaleByDate.getOrDefault(d, BigDecimal.ZERO));
                    BigDecimal cost = posCostByDate.getOrDefault(d, BigDecimal.ZERO)
                            .add(invCostByDate.getOrDefault(d, BigDecimal.ZERO));
                    return new DailySummaryResponse.DailyRow(d, sale, cost, sale.subtract(cost));
                })
                .toList();

        // --- this week vs last week ---
        BigDecimal thisWeekSale = BigDecimal.ZERO;
        BigDecimal thisWeekEarning = BigDecimal.ZERO;
        for (DailySummaryResponse.DailyRow row : daily) {
            if (!row.date().isBefore(weekStart)) {
                thisWeekSale = thisWeekSale.add(row.sale());
                thisWeekEarning = thisWeekEarning.add(row.earning());
            }
        }

        LocalDate lastWeekStart = weekStart.minusDays(7);
        LocalDate lastWeekEnd = weekStart.minusDays(1);
        BigDecimal lastWeekSale = salesReceiptRepository.sumTotalByOrgAndDateRange(orgId, lastWeekStart, lastWeekEnd)
                .add(invoiceRepository.sumRevenueByOrgAndDateRange(orgId, lastWeekStart, lastWeekEnd));
        BigDecimal lastWeekCost = salesReceiptLineRepository.sumCostByOrgAndDateRange(orgId, lastWeekStart, lastWeekEnd)
                .add(invoiceLineRepository.sumCostByOrgAndDateRange(orgId, lastWeekStart, lastWeekEnd));
        BigDecimal lastWeekEarning = lastWeekSale.subtract(lastWeekCost);

        BigDecimal vsLastWeekSalePct = lastWeekSale.signum() > 0
                ? thisWeekSale.subtract(lastWeekSale)
                    .multiply(BigDecimal.valueOf(100))
                    .divide(lastWeekSale, 1, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal vsLastWeekEarningPct = lastWeekEarning.signum() > 0
                ? thisWeekEarning.subtract(lastWeekEarning)
                    .multiply(BigDecimal.valueOf(100))
                    .divide(lastWeekEarning, 1, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        var weekComp = new DailySummaryResponse.WeekComparison(
                thisWeekSale, thisWeekEarning, vsLastWeekSalePct, vsLastWeekEarningPct);

        return new DailySummaryResponse(todaySnapshot, daily, weekComp, org.getBaseCurrency());
    }

    @Transactional(readOnly = true)
    public List<ExpiringSoonResponse> getExpiringSoon(int withinDays) {
        UUID orgId = TenantContext.getCurrentOrgId();
        int capped = Math.max(1, Math.min(withinDays, 365));
        LocalDate horizon = LocalDate.now().plusDays(capped);

        List<StockBatch> batches = stockBatchRepository.findExpiringWithStock(orgId, horizon);
        if (batches.isEmpty()) {
            return List.of();
        }

        List<UUID> itemIds = batches.stream().map(StockBatch::getItemId).distinct().toList();
        Map<UUID, Item> itemsById = itemRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, i -> i));

        List<UUID> batchIds = batches.stream().map(StockBatch::getId).toList();
        Map<UUID, BigDecimal> qtyByBatch = new HashMap<>();
        for (UUID batchId : batchIds) {
            List<StockBatchBalance> balances = stockBatchBalanceRepository
                    .findByOrgIdAndBatchId(orgId, batchId);
            BigDecimal total = balances.stream()
                    .map(StockBatchBalance::getQuantityOnHand)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            qtyByBatch.put(batchId, total);
        }

        LocalDate today = LocalDate.now();
        return batches.stream()
                .map(b -> {
                    Item item = itemsById.get(b.getItemId());
                    long daysLeft = ChronoUnit.DAYS.between(today, b.getExpiryDate());
                    return new ExpiringSoonResponse(
                            b.getItemId(),
                            item != null ? item.getName() : "Unknown",
                            item != null ? item.getSku() : null,
                            b.getBatchNumber(),
                            b.getExpiryDate(),
                            daysLeft,
                            qtyByBatch.getOrDefault(b.getId(), BigDecimal.ZERO));
                })
                .toList();
    }

    private static class MergedTopSelling {
        private final UUID itemId;
        private final String description;
        private BigDecimal totalQty = BigDecimal.ZERO;
        private BigDecimal totalRevenue = BigDecimal.ZERO;

        MergedTopSelling(UUID itemId, String description) {
            this.itemId = itemId;
            this.description = description;
        }

        void add(BigDecimal qty, BigDecimal revenue) {
            this.totalQty = this.totalQty.add(qty);
            this.totalRevenue = this.totalRevenue.add(revenue);
        }

        UUID getItemId() { return itemId; }
        String getDescription() { return description; }
        BigDecimal getTotalQty() { return totalQty; }
        BigDecimal getTotalRevenue() { return totalRevenue; }
    }
}
