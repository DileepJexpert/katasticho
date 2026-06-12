package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "shipment")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Shipment extends BaseEntity {

    @Column(name = "shipment_number", nullable = false, length = 30)
    private String shipmentNumber;

    /** OUTBOUND | INBOUND | TRANSFER */
    @Column(name = "shipment_type", nullable = false, length = 20)
    private String shipmentType;

    /** DRAFT | IN_TRANSIT | DELIVERED | CANCELLED */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "origin_warehouse_id")
    private UUID originWarehouseId;

    @Column(name = "destination_warehouse_id")
    private UUID destinationWarehouseId;

    @Column(length = 100)
    private String carrier;

    @Column(name = "tracking_number", length = 100)
    private String trackingNumber;

    @Column(name = "vehicle_number", length = 30)
    private String vehicleNumber;

    @Column(name = "estimated_departure")
    private Instant estimatedDeparture;

    @Column(name = "actual_departure")
    private Instant actualDeparture;

    @Column(name = "estimated_arrival")
    private Instant estimatedArrival;

    @Column(name = "actual_arrival")
    private Instant actualArrival;

    @Column(name = "total_weight")
    private BigDecimal totalWeight;

    @Column(name = "total_packages")
    private Integer totalPackages;

    @Column(name = "freight_cost", nullable = false)
    @Builder.Default
    private BigDecimal freightCost = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "shipment", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<ShipmentLine> lines = new ArrayList<>();
}
