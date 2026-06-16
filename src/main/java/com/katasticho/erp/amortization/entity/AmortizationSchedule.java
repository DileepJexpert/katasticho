package com.katasticho.erp.amortization.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A fixed amount recognised evenly over N periods — prepaid expense, deferred
 * income, or accrual. Each period posts DR debit_account / CR credit_account.
 */
@Entity
@Table(name = "amortization_schedule")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AmortizationSchedule {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    /** PREPAID | DEFERRED_INCOME | ACCRUAL. */
    @Column(name = "schedule_type", nullable = false, length = 20)
    private String scheduleType;

    @Column(nullable = false, length = 200)
    private String description;

    @Column(length = 60)
    private String reference;

    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount;

    @Column(name = "start_year", nullable = false)
    private int startYear;

    @Column(name = "start_month", nullable = false)
    private int startMonth;

    @Column(name = "number_of_periods", nullable = false)
    private int numberOfPeriods;

    @Column(name = "debit_account_code", nullable = false, length = 20)
    private String debitAccountCode;

    @Column(name = "credit_account_code", nullable = false, length = 20)
    private String creditAccountCode;

    @Column(name = "recognized_amount", nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal recognizedAmount = BigDecimal.ZERO;

    /** ACTIVE | COMPLETED | CANCELLED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "source_module", length = 40)
    private String sourceModule;

    @Column(name = "source_id")
    private UUID sourceId;

    @Column(columnDefinition = "text")
    private String notes;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
