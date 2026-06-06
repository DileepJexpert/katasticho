package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "stock_count_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockCountLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "stock_count_id", nullable = false)
    private StockCount stockCount;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "expected_quantity", nullable = false)
    @Builder.Default
    private BigDecimal expectedQuantity = BigDecimal.ZERO;

    @Column(name = "counted_quantity", nullable = false)
    @Builder.Default
    private BigDecimal countedQuantity = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal variance = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.variance = countedQuantity.subtract(expectedQuantity);
    }
}
