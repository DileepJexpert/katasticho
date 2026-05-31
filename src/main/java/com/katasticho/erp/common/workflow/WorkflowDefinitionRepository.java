package com.katasticho.erp.common.workflow;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WorkflowDefinitionRepository extends JpaRepository<WorkflowDefinition, UUID> {

    @EntityGraph(attributePaths = "steps")
    Optional<WorkflowDefinition> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    @EntityGraph(attributePaths = "steps")
    Optional<WorkflowDefinition> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    @EntityGraph(attributePaths = "steps")
    List<WorkflowDefinition> findByOrgIdAndDocumentTypeAndActiveTrueAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, String documentType);

    List<WorkflowDefinition> findByOrgIdAndIsDeletedFalseOrderByCreatedAtAsc(UUID orgId);
}
