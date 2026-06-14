package com.katasticho.erp.fieldsales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** One audited product line: an own or competitor brand and its sold quantity. */
@Entity
@Table(name = "rcpa_line")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RcpaLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "audit_id", nullable = false)
    private UUID auditId;

    @Column(name = "product_name", nullable = false)
    private String productName;

    /** OWN | COMPETITOR. */
    @Column(name = "brand_type", nullable = false, length = 12)
    @Builder.Default
    private String brandType = "OWN";

    @Column(name = "competitor_name")
    private String competitorName;

    /** Optional link to the org's item master when brandType = OWN. */
    @Column(name = "our_item_id")
    private UUID ourItemId;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal value = BigDecimal.ZERO;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
