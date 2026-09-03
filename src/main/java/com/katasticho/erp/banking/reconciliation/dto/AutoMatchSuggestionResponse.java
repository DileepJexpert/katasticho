package com.katasticho.erp.banking.reconciliation.dto;

import com.katasticho.erp.banking.reconciliation.entity.BankAutoMatchSuggestion;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Builder
public record AutoMatchSuggestionResponse(
        UUID id,
        UUID orgId,
        UUID bankAccountId,
        LocalDate statementDate,
        String statementReference,
        String statementDescription,
        BigDecimal statementAmount,
        boolean isCredit,
        UUID matchedJournalEntryId,
        int confidenceScore,
        String matchReason,
        String status,
        Instant createdAt,
        Instant updatedAt
) {
    public static AutoMatchSuggestionResponse from(BankAutoMatchSuggestion s) {
        return new AutoMatchSuggestionResponse(
                s.getId(),
                s.getOrgId(),
                s.getBankAccountId(),
                s.getStatementDate(),
                s.getStatementReference(),
                s.getStatementDescription(),
                s.getStatementAmount(),
                s.isCredit(),
                s.getMatchedJournalEntryId(),
                s.getConfidenceScore(),
                s.getMatchReason(),
                s.getStatus(),
                s.getCreatedAt(),
                s.getUpdatedAt()
        );
    }
}