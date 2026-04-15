package com.katasticho.erp.dashboard;

import com.katasticho.erp.ar.repository.InvoiceLineRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.dashboard.dto.BranchSalesRow;
import com.katasticho.erp.dashboard.dto.TodaySalesResponse;
import com.katasticho.erp.dashboard.dto.TopSellingItem;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Dashboard aggregation service. Read-only — reaches into AR/inventory
 * repositories and rolls numbers up for the owner-view dashboard.
 *
 * All queries are org-scoped via TenantContext and honour optional branch +
 * date-range filters supplied by the caller.
 */
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

    /**
     * Today-sales snapshot for the dashboard. Returns revenue + cash
     * collected for the date range, plus per-branch rollup.
     *
     * @param from          start of window (inclusive). null = today.
     * @param to            end of window (inclusive). null = today.
     * @param branchId      optional branch filter. null = all branches.
     */
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

        BigDecimal revenue;
        BigDecimal cashCollected;
        if (branchId != null) {
            // Validate the branch belongs to this org before using it.
            branchRepository.findByIdAndOrgIdAndIsDeletedFalse(branchId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Branch", branchId));
            revenue = invoiceRepository.sumRevenueByOrgBranchAndDateRange(
                    orgId, branchId, effectiveFrom, effectiveTo);
            cashCollected = paymentRepository.sumCollectedByOrgBranchAndDateRange(
                    orgId, branchId, effectiveFrom, effectiveTo);
        } else {
            revenue = invoiceRepository.sumRevenueByOrgAndDateRange(
                    orgId, effectiveFrom, effectiveTo);
            cashCollected = paymentRepository.sumCollectedByOrgAndDateRange(
                    orgId, effectiveFrom, effectiveTo);
        }

        // Build per-branch rollup. Even when a branch filter is active we
        // still return the filtered branch as a single row so the client
        // can render the breakdown widget uniformly.
        List<BranchSalesRow> byBranch = buildBranchRollup(orgId, effectiveFrom, effectiveTo, branchId, revenue);

        return new TodaySalesResponse(
                effectiveFrom, effectiveTo, branchId,
                revenue, cashCollected, org.getBaseCurrency(), byBranch);
    }

    private List<BranchSalesRow> buildBranchRollup(
            UUID orgId, LocalDate from, LocalDate to, UUID branchFilter, BigDecimal totalRevenue) {
        // Pull every branch (so we can show zero-sales branches too in the
        // "All branches" view) and attach aggregated revenue.
        List<Branch> branches = branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId);
        if (branches.isEmpty()) {
            return List.of();
        }

        Map<UUID, BigDecimal> revenueByBranchId = invoiceRepository
                .sumRevenueByBranch(orgId, from, to)
                .stream()
                .collect(Collectors.toMap(
                        InvoiceRepository.RevenueByBranchRow::getBranchId,
                        InvoiceRepository.RevenueByBranchRow::getTotal));

        BigDecimal denominator = totalRevenue != null && totalRevenue.signum() > 0
                ? totalRevenue
                : BigDecimal.ONE;

        return branches.stream()
                // If a branch filter is active, only return that single row.
                .filter(b -> branchFilter == null || branchFilter.equals(b.getId()))
                .map(b -> {
                    BigDecimal rev = revenueByBranchId.getOrDefault(b.getId(), BigDecimal.ZERO);
                    BigDecimal pct = totalRevenue != null && totalRevenue.signum() > 0
                            ? rev.multiply(BigDecimal.valueOf(100))
                                 .divide(denominator, 2, RoundingMode.HALF_UP)
                            : BigDecimal.ZERO;
                    return new BranchSalesRow(b.getId(), b.getCode(), b.getName(), rev, pct);
                })
                .sorted(Comparator.comparing(BranchSalesRow::revenue).reversed())
                .toList();
    }

    /**
     * Top-selling items by quantity over the given date range. Free-text
     * lines (no itemId) are excluded. Returns up to {@code limit} rows.
     */
    @Transactional(readOnly = true)
    public List<TopSellingItem> getTopSelling(LocalDate from, LocalDate to, int limit) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : today;
        LocalDate effectiveTo = to != null ? to : today;
        int cappedLimit = Math.max(1, Math.min(limit, 20));

        List<InvoiceLineRepository.TopSellingRow> rows = invoiceLineRepository.findTopSelling(
                orgId, effectiveFrom, effectiveTo, PageRequest.of(0, cappedLimit));

        if (rows.isEmpty()) {
            return List.of();
        }

        // Batch-load items for names, SKUs and units.
        List<UUID> itemIds = rows.stream()
                .map(InvoiceLineRepository.TopSellingRow::getItemId)
                .toList();
        Map<UUID, Item> itemsById = itemRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, i -> i));

        List<TopSellingItem> result = new java.util.ArrayList<>(rows.size());
        int rank = 1;
        for (InvoiceLineRepository.TopSellingRow row : rows) {
            Item item = itemsById.get(row.getItemId());
            result.add(new TopSellingItem(
                    rank++,
                    row.getItemId(),
                    item != null ? item.getSku() : null,
                    item != null ? item.getName() : row.getDescription(),
                    item != null ? item.getUnitOfMeasure() : null,
                    row.getTotalQty(),
                    row.getTotalRevenue()));
        }
        return result;
    }
}
