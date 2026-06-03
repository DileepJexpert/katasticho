package com.katasticho.erp.sales.service;

import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalRequest;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SalesOrderWorkflowHandlerTest {

    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private DocumentStateEngine documentStateEngine;
    @Mock private CommentService commentService;

    @Test
    void onApproved_returnsPendingApprovalOrderToDraft() {
        UUID orgId = UUID.randomUUID();
        UUID salesOrderId = UUID.randomUUID();
        SalesOrder salesOrder = new SalesOrder();
        salesOrder.setId(salesOrderId);
        salesOrder.setOrgId(orgId);
        salesOrder.setStatus("PENDING_APPROVAL");
        ApprovalRequest request = approvalRequest(orgId, salesOrderId);

        SalesOrderWorkflowHandler handler =
                new SalesOrderWorkflowHandler(salesOrderRepository, documentStateEngine, commentService);
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId))
                .thenReturn(Optional.of(salesOrder));

        handler.onApproved(request);

        assertEquals("DRAFT", salesOrder.getStatus());
        verify(documentStateEngine).validateTransition(orgId, "SALES_ORDER", "PENDING_APPROVAL", "DRAFT");
        verify(salesOrderRepository).save(salesOrder);
        verify(commentService).addSystemComment(
                eq(orgId), eq("SALES_ORDER"), eq(salesOrderId), eq("Approval completed. Sales order returned to Draft."));
    }

    @Test
    void onRejected_marksPendingApprovalOrderRejected() {
        UUID orgId = UUID.randomUUID();
        UUID salesOrderId = UUID.randomUUID();
        SalesOrder salesOrder = new SalesOrder();
        salesOrder.setId(salesOrderId);
        salesOrder.setOrgId(orgId);
        salesOrder.setStatus("PENDING_APPROVAL");
        ApprovalRequest request = approvalRequest(orgId, salesOrderId);

        SalesOrderWorkflowHandler handler =
                new SalesOrderWorkflowHandler(salesOrderRepository, documentStateEngine, commentService);
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId))
                .thenReturn(Optional.of(salesOrder));

        handler.onRejected(request);

        assertEquals("REJECTED", salesOrder.getStatus());
        verify(documentStateEngine).validateTransition(orgId, "SALES_ORDER", "PENDING_APPROVAL", "REJECTED");
        verify(salesOrderRepository).save(salesOrder);
        verify(commentService).addSystemComment(
                eq(orgId), eq("SALES_ORDER"), eq(salesOrderId), eq("Approval rejected. Sales order marked Rejected."));
    }

    private ApprovalRequest approvalRequest(UUID orgId, UUID documentId) {
        ApprovalRequest request = ApprovalRequest.builder()
                .documentType("SALES_ORDER")
                .documentId(documentId)
                .build();
        request.setOrgId(orgId);
        return request;
    }
}
