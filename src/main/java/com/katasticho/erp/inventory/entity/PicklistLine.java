package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "picklist_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PicklistLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "picklist_id", nullable = false)
    private Picklist picklist;

    @Column(name = "sales_order_line_id", nullable = false)
    private UUID salesOrderLineId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "required_quantity", nullable = false)
    private BigDecimal requiredQuantity;

    @Column(name = "picked_quantity", nullable = false)
    @Builder.Default
    private BigDecimal pickedQuantity = BigDecimal.ZERO;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(name = "rack_location_id")
    private UUID rackLocationId;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
