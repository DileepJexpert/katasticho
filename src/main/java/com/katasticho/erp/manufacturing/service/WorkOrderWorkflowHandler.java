package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalRequest;
import com.katasticho.erp.common.workflow.ApprovalWorkflowHandler;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Wires WORK_ORDER documents into the shared approval workflow engine,
 * mirroring {@link com.katasticho.erp.sales.service.SalesOrderWorkflowHandler}.
 * Approval returns the WO to DRAFT (so production can start via the normal
 * issue-to-production path); rejection marks it REJECTED.
 */
@Service
@RequiredArgsConstructor
public class WorkOrderWorkflowHandler implements ApprovalWorkflowHandler {

    private final WorkOrderRepository workOrderRepository;
    private final DocumentStateEngine documentStateEngine;
    private final CommentService commentService;

    @Override
    public String documentType() {
        return "WORK_ORDER";
    }

    @Override
    @Transactional
    public void onApproved(ApprovalRequest request) {
        WorkOrder workOrder = workOrderRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", request.getDocumentId()));
        documentStateEngine.validateTransition(request.getOrgId(), "WORK_ORDER", workOrder.getStatus(), "DRAFT");
        workOrder.setStatus("DRAFT");
        workOrder.setApprovalStatus("APPROVED");
        workOrder.setApprovedBy(TenantContext.getCurrentUserId());
        workOrder.setApprovedAt(Instant.now());
        workOrderRepository.save(workOrder);
        commentService.addSystemComment(request.getOrgId(), "WORK_ORDER", workOrder.getId(),
                "Approval completed. Work order returned to Draft — production can start.");
    }

    @Override
    @Transactional
    public void onRejected(ApprovalRequest request) {
        WorkOrder workOrder = workOrderRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", request.getDocumentId()));
        documentStateEngine.validateTransition(request.getOrgId(), "WORK_ORDER", workOrder.getStatus(), "REJECTED");
        workOrder.setStatus("REJECTED");
        workOrder.setApprovalStatus("REJECTED");
        workOrderRepository.save(workOrder);
        commentService.addSystemComment(request.getOrgId(), "WORK_ORDER", workOrder.getId(),
                "Approval rejected. Work order marked Rejected.");
    }
}
