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
 * Labour Welfare Fund (LWF) rule — state-wise. Platform-level reference data
 * seeded via Flyway (V4); every org reads from the same master.
 *
 * <p>LWF varies in three dimensions: amount (employee + employer), frequency
 * (monthly / half-yearly / annual), and the specific months in which the
 * collection happens (most states use Jun + Dec; Chhattisgarh is Mar + Sept;
 * monthly states cover all 12).
 *
 * <p>States with no LWF (most NE states, J&K, UP, Bihar, Jharkhand, …) have
 * no rows — the calculator returns ₹0 when no rule matches, which is
 * statutorily correct.
 */
@Entity
@Table(name = "lwf_rule")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LwfRule {

    @Id
    @Column(name = "id")
    private UUID id;

    @Column(name = "state_code", nullable = false, length = 2)
    private String stateCode;

    /** {@code MONTHLY} / {@code HALF_YEARLY} / {@code ANNUAL}. */
    @Column(name = "frequency", nullable = false, length = 20)
    private String frequency;

    /** Comma-separated month numbers 1-12 when LWF is collected (e.g. "6,12"). */
    @Column(name = "collection_months", nullable = false, length = 50)
    private String collectionMonths;

    @Column(name = "gross_from", nullable = false)
    private BigDecimal grossFrom;

    /** Null = unbounded upper. Most states are flat (no bracketing). */
    @Column(name = "gross_to")
    private BigDecimal grossTo;

    /** Per-collection amounts (NOT monthly unless frequency=MONTHLY). */
    @Column(name = "employee_amount", nullable = false)
    private BigDecimal employeeAmount;

    @Column(name = "employer_amount", nullable = false)
    private BigDecimal employerAmount;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "notes", columnDefinition = "text")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
