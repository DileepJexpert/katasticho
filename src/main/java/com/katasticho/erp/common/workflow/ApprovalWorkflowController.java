package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/workflow/approval-requests")
@RequiredArgsConstructor
public class ApprovalWorkflowController {

    private final ApprovalWorkflowService approvalWorkflowService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<ApprovalRequestResponse>>> list(
            @RequestParam(required = false) ApprovalStatus status,
            Pageable pageable) {
        Page<ApprovalRequestResponse> page = approvalWorkflowService.list(status, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ApprovalRequestResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(approvalWorkflowService.get(id)));
    }

    @GetMapping("/document/{documentType}/{documentId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ApprovalRequestResponse>> getForDocument(
            @PathVariable String documentType,
            @PathVariable UUID documentId,
            @RequestParam(required = false) ApprovalStatus status) {
        return ResponseEntity.ok(ApiResponse.ok(
                approvalWorkflowService.findForDocument(documentType, documentId, status).orElse(null)));
    }

    @GetMapping("/document/{documentType}/{documentId}/history")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ApprovalHistoryResponse>> historyForDocument(
            @PathVariable String documentType,
            @PathVariable UUID documentId) {
        return ResponseEntity.ok(ApiResponse.ok(
                approvalWorkflowService.historyForDocument(documentType, documentId)));
    }

    @PostMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ApprovalRequestResponse>> approve(
            @PathVariable UUID id,
            @RequestBody(required = false) ApprovalDecisionRequest request) {
        ApprovalRequestResponse response = approvalWorkflowService.approve(id, note(request));
        return ResponseEntity.ok(ApiResponse.ok(response, "Approval request approved"));
    }

    @PostMapping("/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ApprovalRequestResponse>> reject(
            @PathVariable UUID id,
            @RequestBody(required = false) ApprovalDecisionRequest request) {
        ApprovalRequestResponse response = approvalWorkflowService.reject(id, note(request));
        return ResponseEntity.ok(ApiResponse.ok(response, "Approval request rejected"));
    }

    private String note(ApprovalDecisionRequest request) {
        return request != null ? request.note() : null;
    }
}
