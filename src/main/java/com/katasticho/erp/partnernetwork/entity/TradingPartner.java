package com.katasticho.erp.partnernetwork.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "trading_partner")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class TradingPartner {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "seller_org_id", nullable = false)
    private UUID sellerOrgId;

    @Column(name = "buyer_org_id", nullable = false)
    private UUID buyerOrgId;

    @Column(name = "status", nullable = false)
    private String status;

    @Column(name = "requested_by_org_id", nullable = false)
    private UUID requestedByOrgId;

    @Column(name = "price_list_id")
    private UUID priceListId;

    @Column(name = "credit_limit")
    private BigDecimal creditLimit;

    @Column(name = "payment_terms")
    private String paymentTerms;

    @Column(name = "delivery_terms")
    private String deliveryTerms;

    @Column(name = "notes")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "is_deleted", nullable = false)
    private boolean isDeleted;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
