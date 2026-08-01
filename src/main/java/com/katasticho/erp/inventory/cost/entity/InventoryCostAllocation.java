package com.katasticho.erp.inventory.cost.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "inventory_cost_allocation")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class InventoryCostAllocation extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "event_id", nullable = false)
    private InventoryCostEvent event;

    @Column(name = "stock_movement_id", nullable = false)
    private UUID stockMovementId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(nullable = false)
    private BigDecimal quantity;

    @Column(name = "allocated_amount", nullable = false)
    private BigDecimal allocatedAmount;

    @Column(name = "unit_cost_addition", nullable = false)
    @Builder.Default
    private BigDecimal unitCostAddition = BigDecimal.ZERO;
}
