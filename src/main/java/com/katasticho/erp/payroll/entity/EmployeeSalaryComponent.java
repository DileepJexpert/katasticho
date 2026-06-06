package com.katasticho.erp.payroll.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Line item under a salary structure — links a salary component to
 * a calculation method (fixed amount, percentage, or formula). Org-scoped.
 */
@Entity
@Table(name = "employee_salary_component")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeSalaryComponent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "salary_structure_id", nullable = false)
    @JsonIgnore
    private EmployeeSalaryStructure salaryStructure;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "salary_component_id", nullable = false)
    private SalaryComponent salaryComponent;

    @Column(name = "calculation_type", nullable = false, length = 20)
    private String calculationType;

    @Column
    private BigDecimal amount;

    @Column
    private BigDecimal percentage;

    @Column(name = "base_component_code", length = 50)
    private String baseComponentCode;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
