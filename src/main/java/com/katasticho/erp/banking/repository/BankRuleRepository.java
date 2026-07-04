package com.katasticho.erp.banking.repository;

import com.katasticho.erp.banking.entity.BankRule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BankRuleRepository extends JpaRepository<BankRule, UUID> {

    Optional<BankRule> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BankRule> findByOrgIdAndIsDeletedFalseOrderByPriorityAscCreatedAtAsc(UUID orgId);

    List<BankRule> findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByPriorityAscCreatedAtAsc(UUID orgId);
}
