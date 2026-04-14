package com.katasticho.erp.recurring.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Template row for auto-generated invoices. See
 * {@code V20__recurring_invoices.sql} and {@code RecurringInvoiceJob}
 * for the scheduler that consumes these rows.
 */
@Entity
@Table(name = "recurring_invoice")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecurringInvoice {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "profile_name", nullable = false, length = 200)
    private String profileName;

    /** Buyer — unified contact (CUSTOMER or BOTH). */
    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(nullable = false, length = 20)
    private String frequency;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "next_invoice_date", nullable = false)
    private LocalDate nextInvoiceDate;

    /**
     * JSONB payload of template lines. Stored/loaded as a {@link List}
     * via the Hibernate JSON type — no converter boilerplate needed.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "line_items", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<RecurringLineItem> lineItems = new ArrayList<>();

    @Column(name = "payment_terms_days", nullable = false)
    @Builder.Default
    private int paymentTermsDays = 0;

    @Column(name = "auto_send", nullable = false)
    @Builder.Default
    private boolean autoSend = false;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "total_generated", nullable = false)
    @Builder.Default
    private int totalGenerated = 0;

    @Column(name = "last_generated_at")
    private Instant lastGeneratedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(columnDefinition = "TEXT")
    private String terms;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

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
