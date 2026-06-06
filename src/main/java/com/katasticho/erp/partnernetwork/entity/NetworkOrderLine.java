package com.katasticho.erp.partnernetwork.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "network_order_line")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class NetworkOrderLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "network_order_id", nullable = false)
    private NetworkOrder networkOrder;

    @Column(name = "catalog_item_id")
    private UUID catalogItemId;

    @Column(name = "buyer_item_id")
    private UUID buyerItemId;

    @Column(name = "seller_item_id")
    private UUID sellerItemId;

    @Column(name = "drug_master_id")
    private UUID drugMasterId;

    @Column(name = "display_name")
    private String displayName;

    @Column(name = "hsn_code")
    private String hsnCode;

    @Column(name = "ordered_qty", nullable = false)
    private BigDecimal orderedQty;

    @Column(name = "confirmed_qty")
    private BigDecimal confirmedQty;

    @Column(name = "dispatched_qty")
    private BigDecimal dispatchedQty;

    @Column(name = "unit_price", nullable = false)
    private BigDecimal unitPrice;

    @Column(name = "line_total")
    private BigDecimal lineTotal;

    @Column(name = "status", nullable = false)
    private String status;

    @Column(name = "seller_notes")
    private String sellerNotes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

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
