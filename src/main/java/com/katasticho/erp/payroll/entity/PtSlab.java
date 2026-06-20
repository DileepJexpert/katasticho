package com.katasticho.erp.payroll.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
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
 * Professional Tax (PT) slab — state-wise statutory bracket.
 *
 * <p>Platform-level reference data (no {@code org_id}). Seeded via Flyway
 * (V3); every org's payroll reads from the same master. A row defines:
 * "for state {@code stateCode}, gender {@code gender} (or all genders if
 * null), monthly gross in [{@code grossFrom}, {@code grossTo or +inf}],
 * deduct {@code monthlyAmount} (or {@code febAmount} in February if set)".
 *
 * <p>States with no PT (Delhi, Haryana, UP, …) simply have no rows — the
 * calculator returns ₹0 when no slab matches.
 */
@Entity
@Table(name = "pt_slab")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PtSlab {

    @Id
    @Column(name = "id")
    private UUID id;

    @Column(name = "state_code", nullable = false, length = 2)
    private String stateCode;

    /** {@code MALE} / {@code FEMALE} / null. Null = applies to all genders. */
    @Column(name = "gender", length = 10)
    private String gender;

    @Column(name = "gross_from", nullable = false)
    private BigDecimal grossFrom;

    /** Null = unbounded upper (e.g. "> ₹10,000"). */
    @Column(name = "gross_to")
    private BigDecimal grossTo;

    @Column(name = "monthly_amount", nullable = false)
    private BigDecimal monthlyAmount;

    /** Some states (MH, OR, MP) levy an extra amount in February. Null = same as monthly. */
    @Column(name = "feb_amount")
    private BigDecimal febAmount;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "notes", columnDefinition = "text")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
