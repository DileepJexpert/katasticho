package com.katasticho.erp.banking.reconciliation.repository;

import com.katasticho.erp.banking.reconciliation.entity.BankReconciliationRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface BankReconciliationRuleRepository extends JpaRepository<BankReconciliationRule, UUID> {
    List<BankReconciliationRule> findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByPriorityAsc(UUID orgId);
    List<BankReconciliationRule> findByOrgIdAndIsDeletedFalseOrderByPriorityAsc(UUID orgId);
}
