package com.katasticho.erp.inventory.service;

import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;

/**
 * Resolves a unit cost basis for a sale movement when the item has no known
 * purchase price (the "bill-freely" scenario — a fresh shop sells before it
 * has booked any GRN).
 *
 * Precedence:
 *   1. {@code item.purchasePrice > 0} → real cost (non-provisional)
 *   2. {@code item.mrp > 0}          → MRP × (1 − margin)
 *   3. {@code item.salePrice > 0}    → salePrice × (1 − margin)
 *   4. nothing                        → null (caller falls back to legacy skip)
 *
 * Margin defaults to 25% and is org-tuneable via the
 * {@code inventory.provisional_margin_pct} org setting (0–1).
 *
 * Returning {@link CostBasis} (rather than just a BigDecimal) lets the caller
 * stamp {@code cost_provisional=true} on the stock_movement so the GRN-time
 * reconciler ({@code ProvisionalCostReconciler}) can find it later.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CostResolverService {

    public record CostBasis(BigDecimal unitCost, boolean provisional, String source) {}

    private static final BigDecimal DEFAULT_MARGIN = new BigDecimal("0.25");
    private static final String MARGIN_SETTING_KEY = "inventory.provisional_margin_pct";

    private final OrgSettingsService orgSettingsService;

    /** Returns {@code null} when no basis exists at all. */
    public CostBasis resolve(Item item, UUID orgId) {
        if (item == null) return null;

        if (item.getPurchasePrice() != null && item.getPurchasePrice().signum() > 0) {
            return new CostBasis(item.getPurchasePrice(), false, "PURCHASE_PRICE");
        }

        BigDecimal marginPct = readMargin(orgId);
        BigDecimal oneMinusMargin = BigDecimal.ONE.subtract(marginPct);

        if (item.getMrp() != null && item.getMrp().signum() > 0) {
            BigDecimal cost = item.getMrp().multiply(oneMinusMargin)
                    .setScale(4, RoundingMode.HALF_UP);
            return new CostBasis(cost, true, "MRP_MINUS_MARGIN");
        }

        if (item.getSalePrice() != null && item.getSalePrice().signum() > 0) {
            BigDecimal cost = item.getSalePrice().multiply(oneMinusMargin)
                    .setScale(4, RoundingMode.HALF_UP);
            return new CostBasis(cost, true, "SALE_PRICE_MINUS_MARGIN");
        }

        return null;
    }

    private BigDecimal readMargin(UUID orgId) {
        try {
            String raw = orgSettingsService.get(orgId, MARGIN_SETTING_KEY, "0.25");
            BigDecimal m = new BigDecimal(raw);
            if (m.signum() < 0 || m.compareTo(BigDecimal.ONE) >= 0) {
                log.debug("Out-of-range margin {} for org {} — falling back to default 0.25", raw, orgId);
                return DEFAULT_MARGIN;
            }
            return m;
        } catch (Exception e) {
            return DEFAULT_MARGIN;
        }
    }
}
