package com.katasticho.erp.inventory.transit.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "transfer_order_dispatch")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransferOrderDispatch extends BaseEntity {

    @Column(name = "transfer_order_id", nullable = false)
    private UUID transferOrderId;

    @Column(name = "vehicle_number", nullable = false, length = 50)
    private String vehicleNumber;

    @Column(name = "driver_name", nullable = false, length = 100)
    private String driverName;

    @Column(name = "driver_phone", length = 30)
    private String driverPhone;

    @Column(name = "dispatched_at", nullable = false)
    @Builder.Default
    private Instant dispatchedAt = Instant.now();

    @Column(name = "expected_delivery_at")
    private Instant expectedDeliveryAt;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private String status = "DISPATCHED"; // DISPATCHED, IN_TRANSIT, DELIVERED, RECEIVED, CANCELLED

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "last_location_name", length = 255)
    private String lastLocationName;

    @Column(name = "last_ping_at")
    private Instant lastPingAt;

    @OneToMany(mappedBy = "dispatch", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<TransferOrderTransitEvent> events = new ArrayList<>();
}
