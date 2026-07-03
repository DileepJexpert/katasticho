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
 * Template row for auto-generated journal entries (depreciation, prepaid
 * amortisation, standing accruals). Generation posts a JournalEntry each
 * period — DRAFT by default, auto_post opt-in.
 */
@Entity
@Table(name = "recurring_journal")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecurringJournal {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "profile_name", nullable = false, length = 200)
    private String profileName;

    @Column(nullable = false, length = 20)
    private String frequency;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "next_run_date", nullable = false)
    private LocalDate nextRunDate;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String narration;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<RecurringJournalLine> lines = new ArrayList<>();

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
