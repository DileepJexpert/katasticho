package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/workflows")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class WorkflowAdminController {

    private final WorkflowAdminService workflowAdminService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<WorkflowDefinitionResponse>>> listWorkflows() {
        return ResponseEntity.ok(ApiResponse.ok(workflowAdminService.listWorkflows()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<WorkflowDefinitionResponse>> getWorkflow(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(workflowAdminService.getWorkflow(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkflowDefinitionResponse>> updateWorkflow(
            @PathVariable UUID id,
            @RequestBody WorkflowUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(workflowAdminService.updateWorkflow(id, request)));
    }

    @PutMapping("/{id}/steps")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkflowDefinitionResponse>> replaceSteps(
            @PathVariable UUID id,
            @RequestBody List<WorkflowStepRequest> request) {
        return ResponseEntity.ok(ApiResponse.ok(workflowAdminService.replaceSteps(id, request)));
    }

    @GetMapping("/document-transitions")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<DocumentStateConfigResponse>>> listTransitions() {
        return ResponseEntity.ok(ApiResponse.ok(workflowAdminService.listTransitions()));
    }
}
