package com.katasticho.erp.inventory.entity;

/**
 * What kind of thing this item is for the stock + pricing engines.
 *
 * <ul>
 *   <li>{@link #GOODS} — physical stock, flows through the inventory
 *       ledger (purchases receive, sales deduct). The default.</li>
 *   <li>{@link #SERVICE} — labour, consulting, fees. Never tracked;
 *       {@code trackInventory} is forced to {@code false} at persist
 *       time. Silently no-ops in {@code InventoryService.recordMovement}.</li>
 *   <li>{@link #COMPOSITE} — a kit/BOM assembled from other items. Has
 *       a {@code bom_component} row per child. On invoice send the
 *       parent itself does NOT post a stock movement — {@code
 *       InventoryService.deductStockForInvoice} explodes the BOM and
 *       deducts each child, and credit notes mirror the same path on
 *       restore. Composite items are REJECTED on stock receipts (you
 *       cannot "receive" a kit, only its components). v1 constraint:
 *       children must be simple {@link #GOODS} — nested BOMs are not
 *       supported in this release and are rejected at BOM save
 *       time.</li>
 * </ul>
 */
public enum ItemType {
    GOODS,
    SERVICE,
    COMPOSITE
}
