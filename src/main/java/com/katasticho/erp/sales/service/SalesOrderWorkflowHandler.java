package com.katasticho.erp.sales.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalRequest;
import com.katasticho.erp.common.workflow.ApprovalWorkflowHandler;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SalesOrderWorkflowHandler implements ApprovalWorkflowHandler {

    private final SalesOrderRepository salesOrderRepository;
    private final DocumentStateEngine documentStateEngine;
    private final CommentService commentService;

    @Override
    public String documentType() {
        return "SALES_ORDER";
    }

    @Override
    @Transactional
    public void onApproved(ApprovalRequest request) {
        SalesOrder salesOrder = salesOrderRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Sales Order", request.getDocumentId()));
        documentStateEngine.validateTransition(request.getOrgId(), "SALES_ORDER", salesOrder.getStatus(), "DRAFT");
        salesOrder.setStatus("DRAFT");
        salesOrderRepository.save(salesOrder);
        commentService.addSystemComment(request.getOrgId(), "SALES_ORDER", salesOrder.getId(),
                "Approval completed. Sales order returned to Draft.");
    }

    @Override
    @Transactional
    public void onRejected(ApprovalRequest request) {
        SalesOrder salesOrder = salesOrderRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Sales Order", request.getDocumentId()));
        documentStateEngine.validateTransition(request.getOrgId(), "SALES_ORDER", salesOrder.getStatus(), "REJECTED");
        salesOrder.setStatus("REJECTED");
        salesOrderRepository.save(salesOrder);
        commentService.addSystemComment(request.getOrgId(), "SALES_ORDER", salesOrder.getId(),
                "Approval rejected. Sales order marked Rejected.");
    }
}
