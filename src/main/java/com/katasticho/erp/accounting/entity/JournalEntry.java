package com.katasticho.erp.accounting.entity;

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
 * IMMUTABLE once posted. Status: DRAFT -> POSTED (one-way).
 * Corrections via reversal entries ONLY.
 * Does NOT extend BaseEntity because it has special immutability rules.
 */
@Entity
@Table(name = "journal_entry")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JournalEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "entry_number", nullable = false)
    private String entryNumber;

    @Column(name = "effective_date", nullable = false)
    private LocalDate effectiveDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(length = 500)
    private String description;

    @Column(name = "source_module", nullable = false, length = 30)
    private String sourceModule;

    @Column(name = "source_id")
    private UUID sourceId;

    @Column(nullable = false, length = 10)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "reversal_of_id")
    private UUID reversalOfId;

    @Column(name = "is_reversal", nullable = false)
    @Builder.Default
    private boolean reversal = false;

    @Column(name = "is_reversed", nullable = false)
    @Builder.Default
    private boolean reversed = false;

    @Column(name = "approval_status", nullable = false, length = 15)
    @Builder.Default
    private String approvalStatus = "NONE";

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "period_year", nullable = false)
    private Integer periodYear;

    @Column(name = "period_month", nullable = false)
    private Integer periodMonth;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    @Builder.Default
    private String tags = "{}";

    @OneToMany(mappedBy = "journalEntry", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<JournalLine> lines = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }

    public void addLine(JournalLine line) {
        lines.add(line);
        line.setJournalEntry(this);
    }
}
