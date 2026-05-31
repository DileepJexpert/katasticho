package com.katasticho.erp.common.workflow;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WorkflowStepRepository extends JpaRepository<WorkflowStep, UUID> {

    List<WorkflowStep> findByWorkflowDefinition_IdAndIsDeletedFalseOrderByStepNumberAsc(UUID workflowDefinitionId);

    Optional<WorkflowStep> findFirstByWorkflowDefinition_IdAndStepNumberAndIsDeletedFalse(UUID workflowDefinitionId, short stepNumber);

    Optional<WorkflowStep> findFirstByWorkflowDefinition_IdAndStepNumberGreaterThanAndIsDeletedFalseOrderByStepNumberAsc(
            UUID workflowDefinitionId, short stepNumber);
}
