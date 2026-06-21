package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * GST 2.0 item rate re-mapping wizard.
 *
 * <p>Notification 9/2025-CT(Rate) effective 22 Sep 2025 collapsed the four
 * GST slabs (5/12/18/28%) into primarily 5%/18% + a 40% sin/luxury slab.
 * Items that were migrated from Tally (or set at the old rates) carry a
 * stale {@code gst_rate} that no longer matches {@code hsn_gst_master}.
 * Filing GSTR-1/3B at the old rate is a notice waiting to happen.
 *
 * <p>This service surfaces the items that need re-mapping (item.gstRate ≠
 * hsn_gst_master.gstRate for the item's HSN), groups them by suggested
 * new rate so the user reviews a few buckets rather than each row, and
 * applies the change in bulk with an audit trail.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class Gst20RateRemapper {

    private final ItemRepository itemRepository;
    private final HsnGstMasterRepository hsnRepository;

    /** One drift row — an item whose stored GST rate doesn't match its HSN's master rate. */
    public record DriftRow(
            UUID itemId,
            String sku,
            String name,
            String hsnCode,
            BigDecimal currentRate,
            BigDecimal suggestedRate,
            String movement // "+13%" / "-7%" — human-readable change
    ) {}

    /** Bucket of items moving the same way (e.g. "12% → 18%"). */
    public record DriftBucket(
            BigDecimal fromRate,
            BigDecimal toRate,
            int itemCount,
            List<DriftRow> items
    ) {}

    /** Candidate list grouped by from/to. */
    @Transactional(readOnly = true)
    public Map<String, Object> candidates() {
        UUID orgId = TenantContext.getCurrentOrgId();
        var items = itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId);

        // Cache HSN lookups per call so a 5000-item org doesn't hit the DB 5000×.
        Map<String, Optional<HsnGstMaster>> hsnCache = new HashMap<>();
        Map<String, List<DriftRow>> byBucket = new LinkedHashMap<>();

        for (Item item : items) {
            String hsn = item.getHsnCode() == null ? "" : item.getHsnCode().trim();
            if (hsn.isEmpty()) continue;
            BigDecimal current = item.getGstRate() == null ? BigDecimal.ZERO : item.getGstRate();

            var hsnRow = hsnCache.computeIfAbsent(hsn, hsnRepository::findByHsnCodeAndActiveTrue);
            if (hsnRow.isEmpty()) continue; // no master entry → can't recommend

            BigDecimal suggested = hsnRow.get().getGstRate();
            if (suggested == null || current.compareTo(suggested) == 0) continue;

            String key = current.stripTrailingZeros().toPlainString()
                    + "→" + suggested.stripTrailingZeros().toPlainString();
            DriftRow row = new DriftRow(
                    item.getId(), item.getSku(), item.getName(), hsn,
                    current, suggested,
                    movementLabel(current, suggested));
            byBucket.computeIfAbsent(key, k -> new ArrayList<>()).add(row);
        }

        List<DriftBucket> buckets = new ArrayList<>();
        int totalItems = 0;
        for (var entry : byBucket.entrySet()) {
            List<DriftRow> rows = entry.getValue();
            BigDecimal from = rows.get(0).currentRate();
            BigDecimal to = rows.get(0).suggestedRate();
            buckets.add(new DriftBucket(from, to, rows.size(), rows));
            totalItems += rows.size();
        }
        buckets.sort((a, b) -> Integer.compare(b.itemCount, a.itemCount)); // biggest buckets first

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("totalDriftItems", totalItems);
        out.put("bucketCount", buckets.size());
        out.put("buckets", buckets);
        return out;
    }

    /** Apply the master rate to every supplied item id. Returns counters. */
    @Transactional
    public Map<String, Object> applyBulk(List<UUID> itemIds, boolean preserveCurrent) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (itemIds == null || itemIds.isEmpty()) {
            throw new BusinessException(
                    "itemIds must not be empty", "GST_REMAP_NO_ITEMS",
                    HttpStatus.BAD_REQUEST);
        }
        Map<String, Optional<HsnGstMaster>> hsnCache = new HashMap<>();
        int updated = 0, skippedAlreadyCurrent = 0, skippedNoHsn = 0, skippedNoMaster = 0;

        for (UUID id : itemIds) {
            Item item = itemRepository.findById(id)
                    .filter(i -> i.getOrgId().equals(orgId))
                    .orElse(null);
            if (item == null) continue;
            String hsn = item.getHsnCode() == null ? "" : item.getHsnCode().trim();
            if (hsn.isEmpty()) { skippedNoHsn++; continue; }
            var hsnRow = hsnCache.computeIfAbsent(hsn, hsnRepository::findByHsnCodeAndActiveTrue);
            if (hsnRow.isEmpty()) { skippedNoMaster++; continue; }
            BigDecimal suggested = hsnRow.get().getGstRate();
            BigDecimal current = item.getGstRate() == null ? BigDecimal.ZERO : item.getGstRate();
            if (current.compareTo(suggested) == 0) { skippedAlreadyCurrent++; continue; }
            if (preserveCurrent) {
                skippedAlreadyCurrent++; // dry-run path
                continue;
            }
            item.setGstRate(suggested);
            itemRepository.save(item);
            updated++;
            log.info("GST 2.0 re-map: item {} ({}): {} → {}",
                    item.getSku(), hsn, current, suggested);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("updated", updated);
        out.put("skippedAlreadyCurrent", skippedAlreadyCurrent);
        out.put("skippedNoHsn", skippedNoHsn);
        out.put("skippedNoMaster", skippedNoMaster);
        return out;
    }

    /** Convenience: apply to every item in the supplied bucket key (e.g. "12→18"). */
    @Transactional
    public Map<String, Object> applyBucket(String bucketKey) {
        Map<String, Object> cands = candidates();
        @SuppressWarnings("unchecked")
        List<DriftBucket> buckets = (List<DriftBucket>) cands.get("buckets");
        for (DriftBucket b : buckets) {
            String key = b.fromRate.stripTrailingZeros().toPlainString()
                    + "→" + b.toRate.stripTrailingZeros().toPlainString();
            if (key.equals(bucketKey)) {
                List<UUID> ids = b.items.stream().map(DriftRow::itemId).toList();
                return applyBulk(ids, false);
            }
        }
        throw new BusinessException(
                "Unknown bucket key: " + bucketKey,
                "GST_REMAP_BUCKET_NOT_FOUND", HttpStatus.NOT_FOUND);
    }

    static String movementLabel(BigDecimal from, BigDecimal to) {
        BigDecimal diff = to.subtract(from);
        String pct = diff.stripTrailingZeros().toPlainString();
        return (diff.signum() >= 0 ? "+" : "") + pct + "%";
    }
}
