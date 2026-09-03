package com.katasticho.erp.banking.reconciliation.repository;

import com.katasticho.erp.banking.reconciliation.entity.BankAutoMatchSuggestion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BankAutoMatchSuggestionRepository extends JpaRepository<BankAutoMatchSuggestion, UUID> {
    List<BankAutoMatchSuggestion> findByOrgIdAndBankAccountIdAndIsDeletedFalseOrderByStatementDateDesc(UUID orgId, UUID bankAccountId);
    List<BankAutoMatchSuggestion> findByOrgIdAndBankAccountIdAndStatusAndIsDeletedFalseOrderByConfidenceScoreDesc(UUID orgId, UUID bankAccountId, String status);
    Optional<BankAutoMatchSuggestion> findByOrgIdAndIdAndIsDeletedFalse(UUID orgId, UUID id);
}