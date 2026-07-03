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
 * Template row for auto-generated vendor bills (rent, subscriptions,
 * retainers). Mirror of {@link RecurringInvoice}; generation drafts a
 * PurchaseBill each period and optionally posts it (auto_post).
 */
@Entity
@Table(name = "recurring_bill")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecurringBill {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "profile_name", nullable = false, length = 200)
    private String profileName;

    /** Vendor — unified contact (VENDOR or BOTH). */
    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(nullable = false, length = 20)
    private String frequency;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "next_bill_date", nullable = false)
    private LocalDate nextBillDate;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "line_items", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<RecurringBillLineItem> lineItems = new ArrayList<>();

    @Column(name = "payment_terms_days", nullable = false)
    @Builder.Default
    private int paymentTermsDays = 0;

    @Column(name = "reverse_charge", nullable = false)
    @Builder.Default
    private boolean reverseCharge = false;

    @Column(name = "place_of_supply", length = 2)
    private String placeOfSupply;

    @Column(name = "auto_post", nullable = false)
    @Builder.Default
    private boolean autoPost = false;

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
