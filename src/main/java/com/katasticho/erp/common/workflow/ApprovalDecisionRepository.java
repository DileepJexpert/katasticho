package com.katasticho.erp.common.workflow;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ApprovalDecisionRepository extends JpaRepository<ApprovalDecision, UUID> {

    List<ApprovalDecision> findByOrgIdAndApprovalRequest_IdInAndIsDeletedFalseOrderByDecidedAtAsc(
            UUID orgId, List<UUID> approvalRequestIds);
}
