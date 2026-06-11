package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * A single FIFO cost lot: stock received at a known unit cost on a known date,
 * consumed oldest-first as it leaves. The remaining quantity × unit cost across
 * all active lots IS the FIFO inventory valuation for an item×warehouse.
 *
 * Opened by {@code FifoCostingService.recordReceipt()} for every incoming
 * movement when the org's valuation method is FIFO. Never written for
 * weighted-average orgs.
 */
@Entity
@Table(name = "cost_lot")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CostLot {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "item_id", nullable = false, updatable = false)
    private UUID itemId;

    @Column(name = "warehouse_id", nullable = false, updatable = false)
    private UUID warehouseId;

    /** Incoming movement that opened this lot; NULL for a lazy opening lot. */
    @Column(name = "source_movement_id", updatable = false)
    private UUID sourceMovementId;

    @Column(name = "received_date", nullable = false, updatable = false)
    private LocalDate receivedDate;

    @Column(name = "original_qty", nullable = false, updatable = false)
    private BigDecimal originalQty;

    @Column(name = "remaining_qty", nullable = false)
    private BigDecimal remainingQty;

    @Column(name = "unit_cost", nullable = false, updatable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }
}
