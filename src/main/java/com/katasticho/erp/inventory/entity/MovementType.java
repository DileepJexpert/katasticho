package com.katasticho.erp.inventory.entity;

/**
 * Stock movement classification. Mirrors the journal entry source_module
 * pattern: every movement carries a clear "why" tag for reporting.
 *
 * The sign of {@code stock_movement.quantity} is independent of this enum —
 * SALE with quantity=-3 means three units left the warehouse, but SALE with
 * quantity=+3 (impossible in normal flow) would be a reversal.
 */
public enum MovementType {
    PURCHASE,
    SALE,
    ADJUSTMENT,
    TRANSFER_IN,
    TRANSFER_OUT,
    OPENING,
    RETURN_IN,
    RETURN_OUT,
    STOCK_COUNT,
    REVERSAL
}
