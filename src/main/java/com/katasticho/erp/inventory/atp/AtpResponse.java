package com.katasticho.erp.inventory.atp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Available-to-Promise snapshot for one (item, warehouse) at a point in time.
 *
 * <p>Decisions live in {@link #status} and {@link #shortfall}; everything else
 * is provenance so the order taker can see WHY the answer is what it is. The
 * cashier may quote 100 units thinking on-hand=100 but 80 are already
 * committed to other SOs — ATP is the only honest answer for a NEW order.
 *
 * <p>Status taxonomy:
 * <ul>
 *   <li>{@code ATP_OK}        — {@code availableNow >= requestedQty}; ship now.</li>
 *   <li>{@code ATP_PARTIAL}   — {@code 0 < availableNow < requestedQty}; mix of
 *       now-shippable + backorder.</li>
 *   <li>{@code ATP_BACKORDER} — {@code availableNow = 0}; entire order waits on
 *       the next inflow ({@link #nextInflowDate}).</li>
 * </ul>
 */
public record AtpResponse(
        UUID itemId,
        String itemName,
        UUID warehouseId,
        String warehouseName,

        /** Current {@code stock_balance.quantity_on_hand}, clamped at zero. */
        BigDecimal onHand,

        /** Σ(qty − quantityShipped) on CONFIRMED/BACKORDER SOs for this item. */
        BigDecimal committed,

        /** {@code max(0, onHand − committed)}. Never returns a negative quote. */
        BigDecimal availableNow,

        /** Σ(qty − receivedQty) on SENT POs targeting this warehouse for this item. */
        BigDecimal openPurchaseQty,

        /** Σ(qty − producedQty) on IN_PROGRESS WOs for this item. */
        BigDecimal openProductionQty,

        /** Earliest expected date across the open PO / WO inflows. */
        LocalDate nextInflowDate,

        BigDecimal requestedQty,

        String status,

        BigDecimal shortfall
) {
    public static final String STATUS_OK = "ATP_OK";
    public static final String STATUS_PARTIAL = "ATP_PARTIAL";
    public static final String STATUS_BACKORDER = "ATP_BACKORDER";
}
