package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Per-batch per-warehouse on-hand quantity.
 *
 * <p>This is the grain FEFO picking queries against. Each row tracks how
 * much of one specific batch is sitting in one specific warehouse;
 * summing across warehouses gives total batch stock, and summing
 * across batches for an item gives the same total as
 * {@link StockBalance#getQuantityOnHand()}.
 *
 * <p>Updated synchronously inside
 * {@code InventoryService.recordMovement()} whenever a movement carries
 * a {@code batchId}, in the same transaction as the immutable
 * {@code stock_movement} insert.
 */
@Entity
@Table(name = "stock_batch_balance")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockBatchBalance {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "batch_id", nullable = false)
    private UUID batchId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "quantity_on_hand", nullable = false)
    @Builder.Default
    private BigDecimal quantityOnHand = BigDecimal.ZERO;

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
