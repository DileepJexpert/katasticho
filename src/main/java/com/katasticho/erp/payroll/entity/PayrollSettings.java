package com.katasticho.erp.payroll.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Payroll settings — one row per organisation. NOT a BaseEntity
 * (no is_deleted, no org_id superclass) because this is a singleton
 * configuration record per tenant.
 */
@Entity
@Table(name = "payroll_settings")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PayrollSettings {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, unique = true)
    private UUID orgId;

    @Column(name = "payroll_start_month")
    private LocalDate payrollStartMonth;

    @Column(name = "pay_frequency", length = 20)
    @Builder.Default
    private String payFrequency = "MONTHLY";

    @Column(name = "default_salary_expense_account_id")
    private UUID defaultSalaryExpenseAccountId;

    @Column(name = "default_salary_payable_account_id")
    private UUID defaultSalaryPayableAccountId;

    @Column(name = "default_pf_payable_account_id")
    private UUID defaultPfPayableAccountId;

    @Column(name = "default_esi_payable_account_id")
    private UUID defaultEsiPayableAccountId;

    @Column(name = "default_pt_payable_account_id")
    private UUID defaultPtPayableAccountId;

    @Column(name = "default_lwf_payable_account_id")
    private UUID defaultLwfPayableAccountId;

    @Column(name = "default_tds_payable_account_id")
    private UUID defaultTdsPayableAccountId;

    @Column(name = "pf_enabled", nullable = false)
    @Builder.Default
    private boolean pfEnabled = false;

    @Column(name = "esi_enabled", nullable = false)
    @Builder.Default
    private boolean esiEnabled = false;

    @Column(name = "pt_enabled", nullable = false)
    @Builder.Default
    private boolean ptEnabled = false;

    @Column(name = "lwf_enabled", nullable = false)
    @Builder.Default
    private boolean lwfEnabled = false;

    @Column(name = "tds_enabled", nullable = false)
    @Builder.Default
    private boolean tdsEnabled = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

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
