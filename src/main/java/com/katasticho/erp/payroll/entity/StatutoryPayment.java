package com.katasticho.erp.payroll.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Tracks payment of PF, ESI, PT, LWF, and TDS statutory liabilities.
 * Org-scoped.
 */
@Entity
@Table(name = "statutory_payment")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StatutoryPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "statutory_type", nullable = false, length = 20)
    private String statutoryType;

    @Column(name = "period_label", length = 20)
    private String periodLabel;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "payment_date")
    private LocalDate paymentDate;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(name = "payment_account_id")
    private UUID paymentAccountId;

    @Column(name = "reference_number", length = 100)
    private String referenceNumber;

    @Column(length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
