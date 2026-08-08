package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** One TA/DA allowance claim per salesperson per day, backed by an expense. */
@Entity
@Table(name = "field_allowance_claim")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldAllowanceClaim {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "claim_date", nullable = false)
    private LocalDate claimDate;

    /** Km the salesperson actually claimed (may differ from GPS in FLEXIBLE/MANUAL modes). */
    @Column(name = "distance_km", nullable = false)
    @Builder.Default
    private BigDecimal distanceKm = BigDecimal.ZERO;

    /** Km recorded by the GPS trail that day â€” reference for approvers. */
    @Column(name = "gps_distance_km", nullable = false)
    @Builder.Default
    private BigDecimal gpsDistanceKm = BigDecimal.ZERO;

    @Column(name = "ta_amount", nullable = false)
    @Builder.Default
    private BigDecimal taAmount = BigDecimal.ZERO;

    @Column(name = "da_amount", nullable = false)
    @Builder.Default
    private BigDecimal daAmount = BigDecimal.ZERO;

    @Column(name = "total_amount", nullable = false)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "reimbursement_id")
    private UUID reimbursementId;

    @Column(name = "expense_id")
    private UUID expenseId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        if (this.orgId == null) {
            this.orgId = TenantContext.getCurrentOrgId();
        }
    }
}
