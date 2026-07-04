package com.katasticho.erp.accounting.forex.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * One period-end forex revaluation run — recorded for idempotency (unique per
 * org + as-of date) and audit. Append-only; a run is a financial fact.
 */
@Entity
@Table(name = "forex_revaluation_run")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ForexRevaluationRun {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "as_of_date", nullable = false)
    private LocalDate asOfDate;

    @Column(name = "base_currency", nullable = false, length = 3)
    private String baseCurrency;

    @Column(name = "ar_delta", nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal arDelta = BigDecimal.ZERO;

    @Column(name = "ap_delta", nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal apDelta = BigDecimal.ZERO;

    @Column(name = "net_gain_loss", nullable = false, precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal netGainLoss = BigDecimal.ZERO;

    @Column(name = "revalued_document_count", nullable = false)
    @Builder.Default
    private int revaluedDocumentCount = 0;

    @Column(name = "reval_journal_entry_id")
    private UUID revalJournalEntryId;

    @Column(name = "reversal_journal_entry_id")
    private UUID reversalJournalEntryId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "created_by")
    private UUID createdBy;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
