package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * DENORMALISED CACHE — never the source of truth.
 *
 * The canonical on-hand quantity is always
 *   SELECT SUM(quantity) FROM stock_movement WHERE item_id=? AND warehouse_id=?
 *
 * This row exists purely so list / dashboard queries don't have to scan the
 * ledger every time. {@link com.katasticho.erp.inventory.service.InventoryService#recordMovement}
 * updates the cache synchronously inside the same transaction as the
 * stock_movement insert; a nightly verification job re-derives the cache
 * from the ledger and logs any drift.
 */
@Entity
@Table(name = "stock_balance")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockBalance {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "quantity_on_hand", nullable = false)
    @Builder.Default
    private BigDecimal quantityOnHand = BigDecimal.ZERO;

    @Column(name = "average_cost", nullable = false)
    @Builder.Default
    private BigDecimal averageCost = BigDecimal.ZERO;

    @Column(name = "last_movement_at")
    private Instant lastMovementAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    protected void touch() {
        this.updatedAt = Instant.now();
    }
}
