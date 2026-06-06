package com.katasticho.erp.payroll.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Tracks payment of net salary for a payroll run. Org-scoped.
 */
@Entity
@Table(name = "payroll_payment")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PayrollPayment {

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

    @Column(name = "payment_date", nullable = false)
    private LocalDate paymentDate;

    @Column(name = "payment_account_id", nullable = false)
    private UUID paymentAccountId;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(name = "payment_mode", length = 30)
    private String paymentMode;

    @Column(name = "reference_number", length = 100)
    private String referenceNumber;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
