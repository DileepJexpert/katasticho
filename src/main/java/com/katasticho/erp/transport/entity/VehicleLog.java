package com.katasticho.erp.transport.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * One running-cost entry for an own-fleet vehicle — a fuel fill, a service, a
 * repair, an insurance/permit/fitness renewal, etc. Aggregated into per-vehicle
 * total-cost-of-ownership: ₹/km and (for fuel) km/litre.
 */
@Entity
@Table(name = "vehicle_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehicleLog extends BaseEntity {

    @Column(name = "vehicle_number", nullable = false, length = 30)
    private String vehicleNumber;

    /** Links to the field-sales Van master when one exists (optional). */
    @Column(name = "van_id")
    private UUID vanId;

    /** FUEL | SERVICE | REPAIR | INSURANCE | FITNESS | PERMIT | TYRE | OTHER */
    @Column(name = "log_type", nullable = false, length = 20)
    private String logType;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    @Column(name = "odometer_km", precision = 12, scale = 2)
    private BigDecimal odometerKm;

    /** Litres for FUEL entries. */
    @Column(precision = 12, scale = 3)
    private BigDecimal quantity;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal amount = BigDecimal.ZERO;

    @Column(name = "vendor_contact_id")
    private UUID vendorContactId;

    @Column(name = "reference_no", length = 60)
    private String referenceNo;

    private String notes;
}
