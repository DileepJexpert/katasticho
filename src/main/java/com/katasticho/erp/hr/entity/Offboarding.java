package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** An employee offboarding (exit/resignation) record. */
@Entity
@Table(name = "hr_offboarding")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Offboarding {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "employee_user_id", nullable = false)
    private UUID employeeUserId;

    @Column(name = "initiated_by")
    private UUID initiatedBy;

    @Column(name = "resignation_date")
    private LocalDate resignationDate;

    @Column(name = "last_working_day")
    private LocalDate lastWorkingDay;

    @Column(columnDefinition = "text")
    private String reason;

    /** INITIATED | COMPLETED | CANCELLED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "INITIATED";

    @Column(name = "fnf_amount", precision = 15, scale = 2)
    private BigDecimal fnfAmount;

    @Column(name = "fnf_settled", nullable = false)
    @Builder.Default
    private boolean fnfSettled = false;

    @Column(columnDefinition = "text")
    private String notes;

    // Gulf gratuity payout (V16). NULL for India offboardings, AE/OM under-1y,
    // and pending AE/OM payouts. `gratuityJournalEntryId` is the idempotency
    // key — OffboardingService.payGratuity refuses a second call when set.
    @Column(name = "gratuity_journal_entry_id")
    private UUID gratuityJournalEntryId;

    @Column(name = "gratuity_amount", precision = 15, scale = 2)
    private BigDecimal gratuityAmount;

    @Column(name = "gratuity_paid_at")
    private Instant gratuityPaidAt;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

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
