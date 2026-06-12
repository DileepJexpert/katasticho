package com.katasticho.erp.supplychain.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "shipment_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShipmentLine extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shipment_id", nullable = false)
    @JsonIgnore
    private Shipment shipment;

    /** SALES_ORDER | PURCHASE_ORDER | TRANSFER_ORDER */
    @Column(name = "reference_type", length = 30)
    private String referenceType;

    @Column(name = "reference_id")
    private UUID referenceId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ZERO;

    @Column
    private BigDecimal weight;

    @Column(nullable = false)
    @Builder.Default
    private int packages = 1;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
