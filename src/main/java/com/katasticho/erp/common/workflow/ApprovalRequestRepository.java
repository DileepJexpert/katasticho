package com.katasticho.erp.common.workflow;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ApprovalRequestRepository extends JpaRepository<ApprovalRequest, UUID> {

    Optional<ApprovalRequest> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<ApprovalRequest> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<ApprovalRequest> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, ApprovalStatus status, Pageable pageable);

    Optional<ApprovalRequest> findFirstByOrgIdAndWorkflowDefinition_IdAndDocumentTypeAndDocumentIdAndStatusAndIsDeletedFalse(
            UUID orgId, UUID workflowDefinitionId, String documentType, UUID documentId, ApprovalStatus status);

    Optional<ApprovalRequest> findFirstByOrgIdAndDocumentTypeAndDocumentIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String documentType, UUID documentId, ApprovalStatus status);

    List<ApprovalRequest> findByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String documentType, UUID documentId);
}
