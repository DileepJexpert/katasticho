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
 * Current salary definition for an employee. Org-scoped.
 */
@Entity
@Table(name = "employee_salary_structure")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeSalaryStructure {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", insertable = false, updatable = false)
    @JsonIgnore
    private Employee employee;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(name = "ctc_monthly")
    private BigDecimal ctcMonthly;

    @Column(name = "gross_monthly")
    private BigDecimal grossMonthly;

    /**
     * Pay model — drives whether the payslip pulls from production data
     * (tracker #57): SALARY = fixed-monthly from structure (default,
     * legacy behaviour), HOURLY = pay = hours × {@link #hourlyRate} from
     * the period's completed job cards, PIECE_RATE = pay = completed
     * pieces × {@link #pieceRate}.
     */
    @Column(name = "pay_type", length = 20)
    @Builder.Default
    private String payType = "SALARY";

    @Column(name = "hourly_rate")
    private BigDecimal hourlyRate;

    @Column(name = "piece_rate")
    private BigDecimal pieceRate;

    @Column(length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "salaryStructure", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<EmployeeSalaryComponent> lines = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
