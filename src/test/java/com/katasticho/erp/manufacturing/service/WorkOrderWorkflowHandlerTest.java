package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalRequest;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkOrderWorkflowHandlerTest {

    @Mock private WorkOrderRepository workOrderRepository;
    @Mock private DocumentStateEngine documentStateEngine;
    @Mock private CommentService commentService;

    private final UUID orgId = UUID.randomUUID();
    private final UUID approverId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(approverId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void onApproved_returnsPendingApprovalOrderToDraft() {
        UUID workOrderId = UUID.randomUUID();
        WorkOrder workOrder = new WorkOrder();
        workOrder.setId(workOrderId);
        workOrder.setOrgId(orgId);
        workOrder.setStatus("PENDING_APPROVAL");
        workOrder.setApprovalStatus("PENDING");
        ApprovalRequest request = approvalRequest(orgId, workOrderId);

        WorkOrderWorkflowHandler handler =
                new WorkOrderWorkflowHandler(workOrderRepository, documentStateEngine, commentService);
        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId))
                .thenReturn(Optional.of(workOrder));

        handler.onApproved(request);

        assertEquals("DRAFT", workOrder.getStatus());
        assertEquals("APPROVED", workOrder.getApprovalStatus());
        assertEquals(approverId, workOrder.getApprovedBy());
        assertNotNull(workOrder.getApprovedAt());
        verify(documentStateEngine).validateTransition(orgId, "WORK_ORDER", "PENDING_APPROVAL", "DRAFT");
        verify(workOrderRepository).save(workOrder);
        verify(commentService).addSystemComment(
                eq(orgId), eq("WORK_ORDER"), eq(workOrderId),
                eq("Approval completed. Work order returned to Draft — production can start."));
    }

    @Test
    void onRejected_marksPendingApprovalOrderRejected() {
        UUID workOrderId = UUID.randomUUID();
        WorkOrder workOrder = new WorkOrder();
        workOrder.setId(workOrderId);
        workOrder.setOrgId(orgId);
        workOrder.setStatus("PENDING_APPROVAL");
        workOrder.setApprovalStatus("PENDING");
        ApprovalRequest request = approvalRequest(orgId, workOrderId);

        WorkOrderWorkflowHandler handler =
                new WorkOrderWorkflowHandler(workOrderRepository, documentStateEngine, commentService);
        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId))
                .thenReturn(Optional.of(workOrder));

        handler.onRejected(request);

        assertEquals("REJECTED", workOrder.getStatus());
        assertEquals("REJECTED", workOrder.getApprovalStatus());
        verify(documentStateEngine).validateTransition(orgId, "WORK_ORDER", "PENDING_APPROVAL", "REJECTED");
        verify(workOrderRepository).save(workOrder);
        verify(commentService).addSystemComment(
                eq(orgId), eq("WORK_ORDER"), eq(workOrderId),
                eq("Approval rejected. Work order marked Rejected."));
    }

    private ApprovalRequest approvalRequest(UUID orgId, UUID documentId) {
        ApprovalRequest request = ApprovalRequest.builder()
                .documentType("WORK_ORDER")
                .documentId(documentId)
                .build();
        request.setOrgId(orgId);
        return request;
    }
}
