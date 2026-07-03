package com.katasticho.erp.inventory.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Effective-dated GST rate for an HSN code. Platform reference table (no
 * org_id, no BaseEntity) — statutory rates are shared across all tenants,
 * same as {@link HsnGstMaster}. Append-mostly: a rate change adds a new
 * open-ended period and closes the prior one's {@code effectiveTo}.
 */
@Entity
@Table(name = "hsn_gst_rate_history")
@Getter
@Setter
@NoArgsConstructor
@Builder
@AllArgsConstructor
public class HsnGstRateHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "hsn_code", nullable = false, length = 10)
    private String hsnCode;

    @Column(name = "gst_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal gstRate;

    /** Compensation cess, nullable — most codes carry none. */
    @Column(name = "cess_rate", precision = 5, scale = 2)
    private BigDecimal cessRate;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    /** Null = still current. */
    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(name = "notification_ref", length = 120)
    private String notificationRef;

    @Column(length = 40)
    private String source;

    @Column(length = 255)
    private String description;

    @Column(name = "created_at", nullable = false, updatable = false,
            insertable = false, columnDefinition = "TIMESTAMPTZ DEFAULT NOW()")
    private Instant createdAt;
}
