package com.katasticho.erp.workflow.repository;

import com.katasticho.erp.workflow.entity.WorkflowRuleExecution;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface WorkflowRuleExecutionRepository extends JpaRepository<WorkflowRuleExecution, UUID> {

    boolean existsByOrgIdAndRuleIdAndEventIdAndIsDeletedFalse(UUID orgId, UUID ruleId, UUID eventId);

    Page<WorkflowRuleExecution> findByOrgIdAndRuleIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID ruleId, Pageable pageable);
}
