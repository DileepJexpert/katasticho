package com.katasticho.erp.sales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "stock_reservation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockReservation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType;

    @Column(name = "source_id", nullable = false)
    private UUID sourceId;

    @Column(name = "source_line_id", nullable = false)
    private UUID sourceLineId;

    @Column(name = "quantity_reserved", nullable = false)
    private BigDecimal quantityReserved;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "reserved_at", nullable = false)
    @Builder.Default
    private Instant reservedAt = Instant.now();

    @Column(name = "fulfilled_at")
    private Instant fulfilledAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @PrePersist
    protected void onCreate() {
        if (this.reservedAt == null) {
            this.reservedAt = Instant.now();
        }
    }
}
