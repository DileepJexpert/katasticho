package com.katasticho.erp.payroll.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * One payslip per employee per payroll run. Org-scoped.
 */
@Entity
@Table(name = "payslip")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Payslip {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "payroll_run_id", nullable = false)
    private UUID payrollRunId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payroll_run_id", insertable = false, updatable = false)
    @JsonIgnore
    private PayrollRun payrollRun;

    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", insertable = false, updatable = false)
    @JsonIgnore
    private Employee employee;

    /** Loss-of-pay days from approved UNPAID leave in the run period. */
    @Column(name = "lop_days")
    @Builder.Default
    private BigDecimal lopDays = BigDecimal.ZERO;

    @Column(name = "gross_pay")
    @Builder.Default
    private BigDecimal grossPay = BigDecimal.ZERO;

    @Column(name = "total_deductions")
    @Builder.Default
    private BigDecimal totalDeductions = BigDecimal.ZERO;

    @Column(name = "employer_contributions")
    @Builder.Default
    private BigDecimal employerContributions = BigDecimal.ZERO;

    @Column(name = "net_pay")
    @Builder.Default
    private BigDecimal netPay = BigDecimal.ZERO;

    @Column(length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "pdf_url")
    private String pdfUrl;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "payslip", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<PayslipLine> lines = new ArrayList<>();

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
