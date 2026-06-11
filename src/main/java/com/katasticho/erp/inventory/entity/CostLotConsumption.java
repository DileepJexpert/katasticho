package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Records that an outgoing stock movement consumed a slice of a {@link CostLot}.
 * Exists so a reversal can restore exactly the lots (and quantities) it drew
 * down. Internal bookkeeping — not an immutable ledger; reversals delete rows.
 */
@Entity
@Table(name = "cost_lot_consumption")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CostLotConsumption {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "lot_id", nullable = false, updatable = false)
    private UUID lotId;

    @Column(name = "movement_id", nullable = false, updatable = false)
    private UUID movementId;

    @Column(name = "qty", nullable = false, updatable = false)
    private BigDecimal qty;

    @Column(name = "unit_cost", nullable = false, updatable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }
}
