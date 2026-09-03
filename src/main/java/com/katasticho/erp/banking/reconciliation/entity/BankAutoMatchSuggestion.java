package com.katasticho.erp.banking.reconciliation.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "bank_auto_match_suggestion")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BankAutoMatchSuggestion extends BaseEntity {

    @Column(name = "bank_account_id", nullable = false)
    private UUID bankAccountId;

    @Column(name = "statement_date", nullable = false)
    private LocalDate statementDate;

    @Column(name = "statement_reference", length = 100)
    private String statementReference;

    @Column(name = "statement_description", columnDefinition = "TEXT")
    private String statementDescription;

    @Column(name = "statement_amount", nullable = false, precision = 15, scale = 4)
    private BigDecimal statementAmount;

    @Column(name = "is_credit", nullable = false)
    @Builder.Default
    private boolean credit = true;

    @Column(name = "matched_journal_entry_id")
    private UUID matchedJournalEntryId;

    @Column(name = "confidence_score", nullable = false)
    @Builder.Default
    private int confidenceScore = 0;

    @Column(name = "match_reason", nullable = false, length = 255)
    private String matchReason;

    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private String status = "PENDING"; // PENDING, ACCEPTED, REJECTED
}