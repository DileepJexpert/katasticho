package com.katasticho.erp.courier.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A parcel sent via a third-party courier — the unit of work for the courier
 * module. Owns the AWB (tracking number), the lifecycle (DRAFT → BOOKED → IN_TRANSIT
 * → DELIVERED, with RTO branches), and the COD link back to AR.
 *
 * <p>Status transitions live in {@code CourierShipmentService}; the courier
 * webhook/poll path appends one {@code CourierShipmentEvent} per status update
 * and the latest status is reflected here.
 */
@Entity
@Table(name = "courier_shipment")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CourierShipment extends BaseEntity {

    @Column(name = "courier_shipment_number", nullable = false, length = 30)
    private String courierShipmentNumber;

    @Column(name = "delivery_challan_id")
    private UUID deliveryChallanId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    /** Customer the parcel is going to. */
    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    /** BLUEDART | DELHIVERY | INDIA_POST | DTDC | SHIPROCKET | OTHER */
    @Column(name = "courier_partner", nullable = false, length = 40)
    private String courierPartner;

    @Column(name = "courier_service", length = 60)
    private String courierService;

    @Column(name = "awb_number", length = 60)
    private String awbNumber;

    /** DRAFT | BOOKED | PICKED_UP | IN_TRANSIT | OUT_FOR_DELIVERY | DELIVERED
     *  | RTO_INITIATED | RTO_DELIVERED | CANCELLED */
    @Column(nullable = false, length = 30)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "is_cod", nullable = false)
    @Builder.Default
    private boolean cod = false;

    @Column(name = "cod_amount", nullable = false)
    @Builder.Default
    private BigDecimal codAmount = BigDecimal.ZERO;

    /** Set when a CodRemittanceLine settles this shipment's COD. */
    @Column(name = "cod_remittance_line_id")
    private UUID codRemittanceLineId;

    @Column(name = "freight_amount", nullable = false)
    @Builder.Default
    private BigDecimal freightAmount = BigDecimal.ZERO;

    @Column(name = "cod_fee", nullable = false)
    @Builder.Default
    private BigDecimal codFee = BigDecimal.ZERO;

    /** Courier-as-vendor — for AP posting of freight + COD fees. */
    @Column(name = "transporter_contact_id")
    private UUID transporterContactId;

    @Column(name = "weight_kg", precision = 10, scale = 3)
    private BigDecimal weightKg;

    @Column(name = "declared_value")
    private BigDecimal declaredValue;

    @Column(name = "pickup_address", columnDefinition = "jsonb")
    private String pickupAddress;

    @Column(name = "delivery_address", columnDefinition = "jsonb")
    private String deliveryAddress;

    @Column(name = "booked_at")
    private Instant bookedAt;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @Column(name = "rto_initiated_at")
    private Instant rtoInitiatedAt;

    @Column(name = "rto_delivered_at")
    private Instant rtoDeliveredAt;

    private String notes;
}
