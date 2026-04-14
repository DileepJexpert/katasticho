package com.katasticho.erp.expense.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "expense")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Expense {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "expense_number", nullable = false, length = 30)
    private String expenseNumber;

    @Column(name = "expense_date", nullable = false)
    private LocalDate expenseDate;

    /** FK to account.id — Expense GL account. */
    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(length = 60)
    private String category;

    @Column(length = 500)
    private String description;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(name = "tax_amount", nullable = false)
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal total;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "gst_rate", nullable = false)
    @Builder.Default
    private BigDecimal gstRate = BigDecimal.ZERO;

    /** FK to contact.id — vendor (optional). */
    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "payment_mode", nullable = false, length = 20)
    @Builder.Default
    private String paymentMode = "CASH";

    /** FK to account.id — Cash/Bank GL paid from. */
    @Column(name = "paid_through_id", nullable = false)
    private UUID paidThroughId;

    @Column(name = "is_billable", nullable = false)
    @Builder.Default
    private boolean billable = false;

    @Column(name = "project_id")
    private UUID projectId;

    /** FK to contact.id — customer the expense is billable to. */
    @Column(name = "customer_contact_id")
    private UUID customerContactId;

    @Column(name = "receipt_url", length = 1000)
    private String receiptUrl;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "RECORDED";

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

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
