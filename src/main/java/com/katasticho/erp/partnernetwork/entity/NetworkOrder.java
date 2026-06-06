package com.katasticho.erp.partnernetwork.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "network_order")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class NetworkOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "order_number", nullable = false)
    private String orderNumber;

    @Column(name = "buyer_org_id", nullable = false)
    private UUID buyerOrgId;

    @Column(name = "seller_org_id", nullable = false)
    private UUID sellerOrgId;

    @Column(name = "trading_partner_id", nullable = false)
    private UUID tradingPartnerId;

    @Column(name = "buyer_po_id")
    private UUID buyerPoId;

    @Column(name = "seller_so_id")
    private UUID sellerSoId;

    @Column(name = "status", nullable = false)
    private String status;

    @Column(name = "total_amount")
    private BigDecimal totalAmount;

    @Column(name = "total_qty")
    private BigDecimal totalQty;

    @Column(name = "requested_delivery_date")
    private LocalDate requestedDeliveryDate;

    @Column(name = "buyer_notes")
    private String buyerNotes;

    @Column(name = "seller_notes")
    private String sellerNotes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "confirmed_at")
    private Instant confirmedAt;

    @Column(name = "dispatched_at")
    private Instant dispatchedAt;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "is_deleted", nullable = false)
    private boolean isDeleted;

    @OneToMany(mappedBy = "networkOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<NetworkOrderLine> lines = new ArrayList<>();

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
