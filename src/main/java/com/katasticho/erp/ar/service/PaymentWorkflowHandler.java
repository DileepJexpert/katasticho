package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalRequest;
import com.katasticho.erp.common.workflow.ApprovalWorkflowHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PaymentWorkflowHandler implements ApprovalWorkflowHandler {

    private final PaymentRepository paymentRepository;
    private final ObjectProvider<PaymentService> paymentService;
    private final CommentService commentService;

    @Override
    public String documentType() {
        return "PAYMENT";
    }

    @Override
    @Transactional
    public void onApproved(ApprovalRequest request) {
        Payment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Payment", request.getDocumentId()));
        paymentService.getObject().postPayment(payment.getId());
        commentService.addSystemComment(request.getOrgId(), "PAYMENT", payment.getId(),
                "Approval completed. Payment posted.");
    }

    @Override
    @Transactional
    public void onRejected(ApprovalRequest request) {
        Payment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Payment", request.getDocumentId()));
        paymentService.getObject().voidPendingPayment(payment.getId(), "Approval rejected");
        commentService.addSystemComment(request.getOrgId(), "PAYMENT", payment.getId(),
                "Approval rejected. Payment voided.");
    }
}
