package com.katasticho.erp.transport.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Lorry Receipt / consignment note — the transport document for road (GTA)
 * shipments. Records the transporter, vehicle, route, the goods, and the freight
 * with its payment basis and GST treatment. When freight is our cost (PAID /
 * TO_BE_BILLED) it can be billed to AP as a DRAFT purchase bill to the transporter.
 */
@Entity
@Table(name = "lorry_receipt")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LorryReceipt extends BaseEntity {

    @Column(name = "lr_number", nullable = false, length = 40)
    private String lrNumber;

    @Column(name = "lr_date", nullable = false)
    private LocalDate lrDate;

    /** The GTA / transporter — a Contact(VENDOR). */
    @Column(name = "transporter_contact_id", nullable = false)
    private UUID transporterContactId;

    /** Consignee (customer). */
    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "delivery_challan_id")
    private UUID deliveryChallanId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "eway_bill_no", length = 30)
    private String ewayBillNo;

    @Column(name = "vehicle_number", length = 30)
    private String vehicleNumber;

    @Column(name = "driver_name", length = 120)
    private String driverName;

    @Column(name = "driver_phone", length = 20)
    private String driverPhone;

    @Column(length = 120)
    private String origin;

    @Column(length = 120)
    private String destination;

    @Column(name = "distance_km", precision = 10, scale = 2)
    private BigDecimal distanceKm;

    /** ROAD | RAIL | AIR */
    @Column(nullable = false, length = 10)
    @Builder.Default
    private String mode = "ROAD";

    @Column(name = "num_packages")
    private Integer numPackages;

    @Column(name = "weight_kg", precision = 12, scale = 3)
    private BigDecimal weightKg;

    @Column(name = "declared_value")
    private BigDecimal declaredValue;

    @Column(name = "freight_amount", nullable = false)
    @Builder.Default
    private BigDecimal freightAmount = BigDecimal.ZERO;

    /** PAID | TO_PAY | TO_BE_BILLED */
    @Column(name = "freight_basis", nullable = false, length = 15)
    @Builder.Default
    private String freightBasis = "TO_BE_BILLED";

    /** RCM | FORWARD | EXEMPT — GTA freight defaults to RCM (5% reverse charge). */
    @Column(name = "gst_treatment", nullable = false, length = 10)
    @Builder.Default
    private String gstTreatment = "RCM";

    @Column(name = "freight_gst_rate", nullable = false, precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal freightGstRate = new BigDecimal("5");

    /** The draft purchase bill raised for this freight, once billed. */
    @Column(name = "freight_bill_id")
    private UUID freightBillId;

    /** DRAFT | ISSUED | DELIVERED | CANCELLED */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    private String notes;
}
