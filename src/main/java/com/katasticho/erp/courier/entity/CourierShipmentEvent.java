package com.katasticho.erp.courier.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Append-only status feed for a {@link CourierShipment}. The webhook /poll job
 * inserts one row per status update the courier reports; corrections come as new
 * events, never as updates — same rule as stock movements.
 */
@Entity
@Table(name = "courier_shipment_event")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CourierShipmentEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "courier_shipment_id", nullable = false)
    private UUID courierShipmentId;

    /** PICKED_UP | IN_TRANSIT | OUT_FOR_DELIVERY | DELIVERED | RTO_INITIATED | RTO_DELIVERED | EXCEPTION */
    @Column(name = "event_status", nullable = false, length = 40)
    private String eventStatus;

    @Column(name = "event_at", nullable = false)
    private Instant eventAt;

    @Column(length = 200)
    private String location;

    @Column(name = "raw_payload", columnDefinition = "jsonb")
    private String rawPayload;

    /** WEBHOOK | POLL | MANUAL */
    @Column(nullable = false, length = 20)
    private String source;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }
}
