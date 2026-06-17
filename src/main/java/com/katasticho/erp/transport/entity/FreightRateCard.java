package com.katasticho.erp.transport.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * A transporter's freight rate for an origin→destination lane and weight slab.
 * Used to auto-fill the freight amount on a {@link LorryReceipt} so the operator
 * doesn't key it by hand. The transporter is a {@code Contact(VENDOR)}.
 */
@Entity
@Table(name = "freight_rate_card")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FreightRateCard extends BaseEntity {

    @Column(name = "transporter_contact_id", nullable = false)
    private UUID transporterContactId;

    @Column(nullable = false, length = 120)
    private String origin;

    @Column(nullable = false, length = 120)
    private String destination;

    /** ROAD | RAIL | AIR */
    @Column(nullable = false, length = 10)
    @Builder.Default
    private String mode = "ROAD";

    @Column(name = "weight_slab_min_kg", nullable = false, precision = 12, scale = 3)
    @Builder.Default
    private BigDecimal weightSlabMinKg = BigDecimal.ZERO;

    /** Null = open-ended top slab. */
    @Column(name = "weight_slab_max_kg", precision = 12, scale = 3)
    private BigDecimal weightSlabMaxKg;

    /** PER_KG | FLAT | PER_UNIT */
    @Column(name = "rate_type", nullable = false, length = 10)
    @Builder.Default
    private String rateType = "PER_KG";

    @Column(nullable = false)
    private BigDecimal rate;

    @Column(name = "min_charge", nullable = false)
    @Builder.Default
    private BigDecimal minCharge = BigDecimal.ZERO;

    @Column(name = "effective_from")
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    private String notes;
}
