package com.katasticho.erp.recurring.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** Audit link: one row per journal minted from a {@link RecurringJournal} template. */
@Entity
@Table(name = "recurring_journal_generation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecurringJournalGeneration {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "recurring_journal_id", nullable = false, updatable = false)
    private UUID recurringJournalId;

    @Column(name = "journal_entry_id", nullable = false, updatable = false)
    private UUID journalEntryId;

    @Column(name = "generated_at", nullable = false, updatable = false)
    private Instant generatedAt;

    @Column(name = "auto_posted", nullable = false)
    private boolean autoPosted;

    @PrePersist
    void onCreate() {
        if (generatedAt == null) generatedAt = Instant.now();
    }
}
