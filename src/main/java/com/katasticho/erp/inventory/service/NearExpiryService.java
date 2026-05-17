package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.dto.ExpiryBatchResponse;
import com.katasticho.erp.inventory.dto.ExpirySummaryResponse;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Read-only service for the near-expiry alert dashboard.
 *
 * <p>Queries batches with non-zero stock that expire within a caller-supplied
 * threshold (default 90 days) and enriches them with item names and total
 * on-hand across all warehouses. Results are sorted by urgency (expired first,
 * then soonest-expiring).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NearExpiryService {

    private final StockBatchRepository batchRepository;
    private final StockBatchBalanceRepository batchBalanceRepository;
    private final ItemRepository itemRepository;

    /**
     * Returns batches expiring within {@code daysThreshold} days that still
     * have positive stock. Also includes already-expired batches with stock.
     */
    @Transactional(readOnly = true)
    public List<ExpiryBatchResponse> getExpiringBatches(int daysThreshold) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate horizon = today.plusDays(daysThreshold);

        List<StockBatch> batches = batchRepository.findExpiringWithStock(orgId, horizon);

        // Collect item IDs for batch enrichment
        Set<UUID> itemIds = batches.stream()
                .map(StockBatch::getItemId)
                .collect(Collectors.toSet());
        Map<UUID, String> itemNames = itemRepository.findAllById(itemIds).stream()
                .collect(Collectors.toMap(Item::getId, Item::getName, (a, b) -> a));

        List<ExpiryBatchResponse> result = new ArrayList<>(batches.size());
        for (StockBatch batch : batches) {
            // Sum on-hand across all warehouses
            BigDecimal totalQty = batchBalanceRepository
                    .findByOrgIdAndBatchId(orgId, batch.getId())
                    .stream()
                    .map(StockBatchBalance::getQuantityOnHand)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            if (totalQty.compareTo(BigDecimal.ZERO) <= 0) continue;

            long daysUntilExpiry = ChronoUnit.DAYS.between(today, batch.getExpiryDate());
            String urgency;
            if (daysUntilExpiry < 0) {
                urgency = "EXPIRED";
            } else if (daysUntilExpiry <= 7) {
                urgency = "CRITICAL";
            } else if (daysUntilExpiry <= 30) {
                urgency = "WARNING";
            } else {
                urgency = "OK";
            }

            result.add(new ExpiryBatchResponse(
                    batch.getId(),
                    batch.getItemId(),
                    itemNames.getOrDefault(batch.getItemId(), "Unknown"),
                    batch.getBatchNumber(),
                    batch.getExpiryDate(),
                    totalQty,
                    daysUntilExpiry,
                    urgency
            ));
        }

        return result;
    }

    /**
     * Summary counts: expired, expiring in 7 days, 30 days, 90 days.
     * Only considers batches with positive on-hand stock.
     */
    @Transactional(readOnly = true)
    public ExpirySummaryResponse getExpirySummary() {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        // Fetch all batches expiring within 90 days (includes already expired)
        LocalDate horizon = today.plusDays(90);

        List<StockBatch> batches = batchRepository.findExpiringWithStock(orgId, horizon);

        int expired = 0;
        int within7Days = 0;
        int within30Days = 0;
        int within90Days = 0;

        for (StockBatch batch : batches) {
            BigDecimal totalQty = batchBalanceRepository
                    .findByOrgIdAndBatchId(orgId, batch.getId())
                    .stream()
                    .map(StockBatchBalance::getQuantityOnHand)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            if (totalQty.compareTo(BigDecimal.ZERO) <= 0) continue;

            long daysUntilExpiry = ChronoUnit.DAYS.between(today, batch.getExpiryDate());
            if (daysUntilExpiry < 0) {
                expired++;
            } else if (daysUntilExpiry <= 7) {
                within7Days++;
            } else if (daysUntilExpiry <= 30) {
                within30Days++;
            } else {
                within90Days++;
            }
        }

        return new ExpirySummaryResponse(expired, within7Days, within30Days, within90Days);
    }
}
