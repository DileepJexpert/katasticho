package com.katasticho.erp.gst.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * e-Way bill requirement + lifecycle for an outward document.
 *
 * <p>Rows are auto-created (status PENDING) when a posted invoice crosses the
 * e-way threshold (org setting {@code gst.eway_bill_threshold}, default
 * ₹50,000), or manually for delivery challans / sub-threshold documents that
 * trip the vehicle-aggregate rule. Once the EWB number is obtained on the NIC
 * portal (we generate the portal JSON), it is recorded here with its validity.
 */
@Entity
@Table(name = "eway_bill")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EwayBill extends BaseEntity {

    /** INVOICE or DELIVERY_CHALLAN. */
    @Column(name = "document_type", nullable = false, length = 20)
    private String documentType;

    @Column(name = "document_id", nullable = false)
    private UUID documentId;

    @Column(name = "document_number", nullable = false, length = 50)
    private String documentNumber;

    @Column(name = "document_date", nullable = false)
    private LocalDate documentDate;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "total_value", nullable = false)
    @Builder.Default
    private BigDecimal totalValue = BigDecimal.ZERO;

    /** PENDING → GENERATED → (CANCELLED). */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "ewb_number", length = 20)
    private String ewbNumber;

    @Column(name = "vehicle_number", length = 30)
    private String vehicleNumber;

    @Column(name = "transport_mode", nullable = false, length = 10)
    @Builder.Default
    private String transportMode = "ROAD";

    @Column(name = "transporter_id", length = 15)
    private String transporterId;

    @Column(name = "transporter_name")
    private String transporterName;

    @Column(name = "distance_km")
    private Integer distanceKm;

    @Column(name = "from_state_code", length = 5)
    private String fromStateCode;

    @Column(name = "to_state_code", length = 5)
    private String toStateCode;

    @Column(name = "generated_at")
    private Instant generatedAt;

    @Column(name = "valid_until")
    private Instant validUntil;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "cancel_reason", columnDefinition = "text")
    private String cancelReason;
}
