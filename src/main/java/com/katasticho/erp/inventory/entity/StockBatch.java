package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Batch / lot master — one row per distinct batch received, org-scoped.
 *
 * <p>Together with {@link StockBatchBalance} this replaces the pre-V14
 * pattern of storing {@code batch_number} as a free-text string on GRN
 * and invoice lines. Only items with {@link Item#isTrackBatches()} ==
 * true consume through batch rows; non-batch items go through the
 * aggregate {@code stock_balance} path unchanged.
 *
 * <p>Uniqueness is enforced on {@code (org_id, item_id, batch_number)}
 * so re-receiving the same batch from the same supplier upserts into
 * the existing row rather than creating a duplicate.
 */
@Entity
@Table(name = "stock_batch")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockBatch extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "batch_number", nullable = false, length = 100)
    private String batchNumber;

    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    @Column(name = "manufacturing_date")
    private LocalDate manufacturingDate;

    /**
     * The original landed cost of this batch. Copied into
     * {@code stock_movement.unit_cost} on FEFO deduction so COGS reflects
     * the actual cost of the batch being sold, not the item's moving
     * average. Defaults to zero so manually-created batches (e.g. for
     * opening balances) don't NPE downstream math.
     */
    @Column(name = "unit_cost", nullable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "supplier_id")
    private UUID supplierId;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
