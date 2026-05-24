package com.katasticho.erp.pricing.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "schemes")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class Scheme {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(nullable = false)
    private String name;

    @Column(name = "scheme_type", nullable = false)
    private String schemeType; // BUY_X_GET_Y, PERCENT_DISCOUNT

    @Column(name = "item_id")
    private UUID itemId;

    @Column(name = "buy_quantity")
    private BigDecimal buyQuantity;

    @Column(name = "free_quantity")
    private BigDecimal freeQuantity;

    @Column(name = "discount_percent")
    private BigDecimal discountPercent;

    @Column(name = "min_order_quantity")
    @Builder.Default
    private BigDecimal minOrderQuantity = BigDecimal.ZERO;

    @Column(name = "valid_from")
    private LocalDate validFrom;

    @Column(name = "valid_to")
    private LocalDate validTo;

    @Column(name = "supplier_id")
    private UUID supplierId;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    @UpdateTimestamp
    private Instant updatedAt;
}
