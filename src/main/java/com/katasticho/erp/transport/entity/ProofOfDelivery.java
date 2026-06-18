package com.katasticho.erp.transport.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Proof of delivery for a dispatched consignment — who received it, when, where
 * (GPS), and the signature/photo evidence (stored via {@code AttachmentService}
 * with {@code entityType='POD'}, {@code entityId=}this row). Linked flexibly to a
 * delivery challan, courier parcel, or invoice.
 */
@Entity
@Table(name = "proof_of_delivery")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProofOfDelivery extends BaseEntity {

    @Column(name = "delivery_challan_id")
    private UUID deliveryChallanId;

    @Column(name = "courier_shipment_id")
    private UUID courierShipmentId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "recipient_name", length = 120)
    private String recipientName;

    @Column(name = "recipient_phone", length = 20)
    private String recipientPhone;

    @Column(name = "delivered_at", nullable = false)
    @Builder.Default
    private Instant deliveredAt = Instant.now();

    @Column(name = "geo_latitude", precision = 10, scale = 7)
    private BigDecimal geoLatitude;

    @Column(name = "geo_longitude", precision = 10, scale = 7)
    private BigDecimal geoLongitude;

    private String notes;
}
