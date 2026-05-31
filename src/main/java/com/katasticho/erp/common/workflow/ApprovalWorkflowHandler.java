package com.katasticho.erp.common.workflow;

public interface ApprovalWorkflowHandler {

    String documentType();

    void onApproved(ApprovalRequest request);

    void onRejected(ApprovalRequest request);
}
