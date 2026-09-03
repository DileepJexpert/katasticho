package com.katasticho.erp.banking.reconciliation.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.banking.entity.BankAccount;
import com.katasticho.erp.banking.reconciliation.dto.AutoMatchRunRequest;
import com.katasticho.erp.banking.reconciliation.dto.AutoMatchSuggestionResponse;
import com.katasticho.erp.banking.reconciliation.entity.BankAutoMatchSuggestion;
import com.katasticho.erp.banking.reconciliation.entity.BankReconciliationRule;
import com.katasticho.erp.banking.reconciliation.repository.BankAutoMatchSuggestionRepository;
import com.katasticho.erp.banking.reconciliation.repository.BankReconciliationRuleRepository;
import com.katasticho.erp.banking.repository.BankAccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BankSmartAutoMatchService {

    private final BankAutoMatchSuggestionRepository suggestionRepository;
    private final BankReconciliationRuleRepository ruleRepository;
    private final BankAccountRepository bankAccountRepository;
    private final JournalEntryRepository journalEntryRepository;

    @Transactional(readOnly = true)
    public List<AutoMatchSuggestionResponse> listSuggestions(UUID bankAccountId, String status) {
        requireReconciliationLedger();
        UUID orgId = TenantContext.getCurrentOrgId();
        List<BankAutoMatchSuggestion> list;
        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            list = suggestionRepository.findByOrgIdAndBankAccountIdAndStatusAndIsDeletedFalseOrderByConfidenceScoreDesc(
                    orgId, bankAccountId, status.toUpperCase());
        } else {
            list = suggestionRepository.findByOrgIdAndBankAccountIdAndIsDeletedFalseOrderByStatementDateDesc(
                    orgId, bankAccountId);
        }
        return list.stream().map(AutoMatchSuggestionResponse::from).toList();
    }

    @Transactional
    public List<AutoMatchSuggestionResponse> runAutoMatch(AutoMatchRunRequest request) {
        requireReconciliationLedger();
        UUID orgId = TenantContext.getCurrentOrgId();
        bankAccountRepository.findById(request.getBankAccountId())
                .orElseThrow(() -> BusinessException.notFound("BankAccount", request.getBankAccountId()));

        List<BankReconciliationRule> rules = ruleRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByPriorityAsc(orgId);
        List<JournalEntry> candidateEntries = journalEntryRepository
                .findByOrgIdAndStatusOrderByEffectiveDateDesc(orgId, "POSTED", PageRequest.of(0, 100))
                .getContent();

        List<BankAutoMatchSuggestion> created = new ArrayList<>();

        if (request.getStatementLines() != null) {
            for (AutoMatchRunRequest.StatementLineInput line : request.getStatementLines()) {
                MatchResult match = evaluateBestMatch(line, candidateEntries, rules);

                BankAutoMatchSuggestion suggestion = BankAutoMatchSuggestion.builder()
                        .bankAccountId(request.getBankAccountId())
                        .statementDate(line.getDate())
                        .statementReference(line.getReference())
                        .statementDescription(line.getDescription())
                        .statementAmount(line.getAmount())
                        .credit(line.isCredit())
                        .matchedJournalEntryId(match.journalEntryId)
                        .confidenceScore(match.score)
                        .matchReason(match.reason)
                        .status("PENDING")
                        .build();
                suggestion.setOrgId(orgId);
                created.add(suggestionRepository.save(suggestion));
            }
        }

        log.info("Generated [{}] bank auto-match suggestions for org [{}] bankAccount [{}]", created.size(), orgId, request.getBankAccountId());
        return created.stream().map(AutoMatchSuggestionResponse::from).toList();
    }

    @Transactional
    public AutoMatchSuggestionResponse acceptSuggestion(UUID id) {
        requireReconciliationLedger();
        UUID orgId = TenantContext.getCurrentOrgId();
        BankAutoMatchSuggestion suggestion = suggestionRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, id)
                .orElseThrow(() -> BusinessException.notFound("BankAutoMatchSuggestion", id));

        suggestion.setStatus("ACCEPTED");
        BankAutoMatchSuggestion saved = suggestionRepository.save(suggestion);
        log.info("Accepted bank match suggestion [{}]", id);
        return AutoMatchSuggestionResponse.from(saved);
    }

    @Transactional
    public AutoMatchSuggestionResponse rejectSuggestion(UUID id) {
        requireReconciliationLedger();
        UUID orgId = TenantContext.getCurrentOrgId();
        BankAutoMatchSuggestion suggestion = suggestionRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, id)
                .orElseThrow(() -> BusinessException.notFound("BankAutoMatchSuggestion", id));

        suggestion.setStatus("REJECTED");
        BankAutoMatchSuggestion saved = suggestionRepository.save(suggestion);
        log.info("Rejected bank match suggestion [{}]", id);
        return AutoMatchSuggestionResponse.from(saved);
    }

    @Transactional
    public int acceptAllHighConfidence(UUID bankAccountId, int minScore) {
        requireReconciliationLedger();
        UUID orgId = TenantContext.getCurrentOrgId();
        List<BankAutoMatchSuggestion> pending = suggestionRepository
                .findByOrgIdAndBankAccountIdAndStatusAndIsDeletedFalseOrderByConfidenceScoreDesc(orgId, bankAccountId, "PENDING");

        int accepted = 0;
        for (BankAutoMatchSuggestion s : pending) {
            if (s.getConfidenceScore() >= minScore) {
                s.setStatus("ACCEPTED");
                suggestionRepository.save(s);
                accepted++;
            }
        }
        log.info("Bulk-accepted [{}] high confidence bank match suggestions (>= {}%)", accepted, minScore);
        return accepted;
    }

    private MatchResult evaluateBestMatch(
            AutoMatchRunRequest.StatementLineInput line,
            List<JournalEntry> candidateEntries,
            List<BankReconciliationRule> rules) {

        // 1. Check custom reconciliation rules
        if (line.getDescription() != null) {
            String descUpper = line.getDescription().toUpperCase();
            for (BankReconciliationRule rule : rules) {
                if ("DESCRIPTION".equalsIgnoreCase(rule.getMatchField())) {
                    if ("CONTAINS".equalsIgnoreCase(rule.getOperator()) && descUpper.contains(rule.getMatchPattern().toUpperCase())) {
                        return new MatchResult(null, 90, "Custom Rule Match: " + rule.getRuleName());
                    }
                }
            }
        }

        // 2. Evaluate candidate journal entries
        MatchResult best = new MatchResult(null, 0, "No confident match found");

        for (JournalEntry je : candidateEntries) {
            // Check Entry number / Reference substring match
            if (line.getReference() != null && !line.getReference().isBlank() && je.getEntryNumber() != null) {
                if (je.getEntryNumber().equalsIgnoreCase(line.getReference()) ||
                    je.getEntryNumber().toUpperCase().contains(line.getReference().toUpperCase()) ||
                    line.getReference().toUpperCase().contains(je.getEntryNumber().toUpperCase())) {
                    return new MatchResult(je.getId(), 95, "Exact Reference Substring Match (" + je.getEntryNumber() + ")");
                }
            }

            // Check Date proximity within +/- 3 days
            if (je.getEffectiveDate() != null && line.getDate() != null) {
                long daysDiff = Math.abs(ChronoUnit.DAYS.between(je.getEffectiveDate(), line.getDate()));
                if (daysDiff <= 3) {
                    if (best.score < 85) {
                        best = new MatchResult(je.getId(), 85, "Date Proximity Match (" + daysDiff + " days diff with " + je.getEntryNumber() + ")");
                    }
                }
            }
        }

        return best;
    }

    private record MatchResult(UUID journalEntryId, int score, String reason) {}

    private void requireReconciliationLedger() {
        throw new BusinessException(
                "Bank auto-match is unavailable until it is connected to imported bank transactions and the reconciliation ledger",
                "BANK_AUTO_MATCH_UNAVAILABLE",
                HttpStatus.SERVICE_UNAVAILABLE);
    }
}
