package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.entity.CreditNote;
import com.katasticho.erp.ar.repository.CreditNoteRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalRequest;
import com.katasticho.erp.common.workflow.ApprovalWorkflowHandler;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CreditNoteWorkflowHandler implements ApprovalWorkflowHandler {

    private final CreditNoteRepository creditNoteRepository;
    private final ObjectProvider<CreditNoteService> creditNoteService;
    private final DocumentStateEngine documentStateEngine;
    private final CommentService commentService;

    @Override
    public String documentType() {
        return "CREDIT_NOTE";
    }

    @Override
    @Transactional
    public void onApproved(ApprovalRequest request) {
        CreditNote creditNote = creditNoteRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("CreditNote", request.getDocumentId()));
        creditNoteService.getObject().issueApprovedCreditNote(creditNote.getId());
        commentService.addSystemComment(request.getOrgId(), "CREDIT_NOTE", creditNote.getId(),
                "Approval completed. Credit note issued.");
    }

    @Override
    @Transactional
    public void onRejected(ApprovalRequest request) {
        CreditNote creditNote = creditNoteRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.getDocumentId(), request.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("CreditNote", request.getDocumentId()));
        documentStateEngine.validateTransition(request.getOrgId(), "CREDIT_NOTE", creditNote.getStatus(), "REJECTED");
        creditNote.setStatus("REJECTED");
        creditNoteRepository.save(creditNote);
        commentService.addSystemComment(request.getOrgId(), "CREDIT_NOTE", creditNote.getId(),
                "Approval rejected. Credit note marked Rejected.");
    }
}
