package com.katasticho.erp.payroll.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Represents a monthly payroll processing run. Org-scoped.
 */
@Entity
@Table(name = "payroll_run")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PayrollRun {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Column(name = "period_end", nullable = false)
    private LocalDate periodEnd;

    @Column(length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "employee_count")
    @Builder.Default
    private Integer employeeCount = 0;

    @Column(name = "gross_total")
    @Builder.Default
    private BigDecimal grossTotal = BigDecimal.ZERO;

    @Column(name = "deduction_total")
    @Builder.Default
    private BigDecimal deductionTotal = BigDecimal.ZERO;

    @Column(name = "employer_contribution_total")
    @Builder.Default
    private BigDecimal employerContributionTotal = BigDecimal.ZERO;

    @Column(name = "net_pay_total")
    @Builder.Default
    private BigDecimal netPayTotal = BigDecimal.ZERO;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "posted_at")
    private Instant postedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "payrollRun", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    @JsonIgnore
    private List<Payslip> payslips = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
