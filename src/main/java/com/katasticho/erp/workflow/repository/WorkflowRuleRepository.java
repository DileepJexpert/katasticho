package com.katasticho.erp.workflow.repository;

import com.katasticho.erp.workflow.entity.WorkflowRule;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkflowRuleRepository extends JpaRepository<WorkflowRule, UUID> {

    Optional<WorkflowRule> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<WorkflowRule> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    /** Dispatch lookup: active rules for a given (org, entity, trigger), in run order. */
    List<WorkflowRule> findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
            UUID orgId, String entityType, String triggerEvent);
}
