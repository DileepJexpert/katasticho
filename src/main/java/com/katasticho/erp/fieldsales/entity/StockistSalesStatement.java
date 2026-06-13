package com.katasticho.erp.fieldsales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * A stockist's Stock &amp; Sales Statement for one month: the header. Lines
 * (per product) carry opening / purchase / sales / return / closing quantities.
 */
@Entity
@Table(name = "stockist_sales_statement")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StockistSalesStatement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "stockist_contact_id", nullable = false)
    private UUID stockistContactId;

    /** Normalised to the first day of the reporting month. */
    @Column(name = "period_month", nullable = false)
    private LocalDate periodMonth;

    /** DRAFT -> SUBMITTED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

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
