package com.katasticho.erp.payroll.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Per-employee, per-FY tax declaration. Drives:
 * <ul>
 *   <li>Regime choice (OLD vs NEW) — picked at FY start and locked for the year.</li>
 *   <li>HRA exemption + Section 80 deductions + home-loan interest + LTA
 *       (OLD regime only).</li>
 *   <li>Monthly salary TDS computation (the calculator picks the regime path
 *       from {@link #getTaxRegime()} and applies the declarations only when
 *       {@code status = SUBMITTED} or {@code VERIFIED}).</li>
 *   <li>Year-end Form 16 (TDS computation sheet).</li>
 * </ul>
 *
 * <p>Lifecycle: DRAFT (employee editing) → SUBMITTED (employee finalised
 * at FY start) → VERIFIED (payroll approved after IT-proof check in
 * Jan/Feb).
 */
@Entity
@Table(name = "employee_tax_declaration")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeTaxDeclaration {

    @Id
    @Column(name = "id")
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    /** "2026-27" — FY runs Apr 1 to Mar 31. */
    @Column(name = "fiscal_year", nullable = false, length = 9)
    private String fiscalYear;

    /** OLD | NEW */
    @Column(name = "tax_regime", nullable = false, length = 10)
    private String taxRegime;

    // ── HRA exemption (Section 10(13A)) — OLD regime only ─────────

    @Column(name = "hra_rent_paid")
    private BigDecimal hraRentPaid;

    @Column(name = "hra_metro_city", nullable = false)
    private boolean hraMetroCity = false;

    @Column(name = "landlord_pan", length = 20)
    private String landlordPan;

    // ── Section 80 deductions — OLD regime only ───────────────────

    @Column(name = "deduction_80c")          private BigDecimal deduction80c;
    @Column(name = "deduction_80ccd_1b")     private BigDecimal deduction80ccd1b;
    @Column(name = "deduction_80d_self")     private BigDecimal deduction80dSelf;
    @Column(name = "deduction_80d_parents")  private BigDecimal deduction80dParents;
    @Column(name = "deduction_80e")          private BigDecimal deduction80e;
    @Column(name = "deduction_80g")          private BigDecimal deduction80g;
    @Column(name = "deduction_80tta")        private BigDecimal deduction80tta;
    @Column(name = "deduction_80ttb")        private BigDecimal deduction80ttb;

    // ── Section 24(b) home loan + LTA + other income ──────────────

    @Column(name = "home_loan_interest")     private BigDecimal homeLoanInterest;
    @Column(name = "lta_claim")              private BigDecimal ltaClaim;
    @Column(name = "other_income")           private BigDecimal otherIncome;

    // ── Lifecycle ─────────────────────────────────────────────────

    @Column(name = "status", nullable = false, length = 20)
    private String status = "DRAFT";

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "verified_by")
    private UUID verifiedBy;

    @Column(name = "notes", columnDefinition = "text")
    private String notes;

    // ── Audit ─────────────────────────────────────────────────────

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "updated_by")
    private UUID updatedBy;

    @Column(name = "is_deleted", nullable = false)
    private boolean isDeleted = false;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
        if (updatedAt == null) updatedAt = createdAt;
    }

    @PreUpdate
    void onUpdate() { updatedAt = Instant.now(); }
}
