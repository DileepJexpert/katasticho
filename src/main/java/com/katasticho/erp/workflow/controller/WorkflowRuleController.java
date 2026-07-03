package com.katasticho.erp.workflow.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.workflow.dto.WorkflowRuleRequest;
import com.katasticho.erp.workflow.entity.WorkflowRule;
import com.katasticho.erp.workflow.service.WorkflowFieldMutator;
import com.katasticho.erp.workflow.service.WorkflowRuleService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * Admin CRUD for workflow rules + dry-run + execution log + a metadata endpoint
 * the UI builder reads for its dropdowns. Core admin feature (no module gate),
 * OWNER/ADMIN only for writes.
 */
@RestController
@RequestMapping("/api/v1/workflow-rules")
@RequiredArgsConstructor
public class WorkflowRuleController {

    private final WorkflowRuleService service;
    private final List<WorkflowFieldMutator> fieldMutators;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkflowRule>> create(@RequestBody WorkflowRuleRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.create(req.toEntity()), "Workflow rule created"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Page<WorkflowRule>>> list(
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(PageRequest.of(page, size))));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<WorkflowRule>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkflowRule>> update(
            @PathVariable UUID id, @RequestBody WorkflowRuleRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.update(id, req.toEntity()), "Workflow rule updated"));
    }

    @PostMapping("/{id}/toggle")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkflowRule>> toggle(
            @PathVariable UUID id, @RequestParam boolean active) {
        return ResponseEntity.ok(ApiResponse.ok(service.toggle(id, active),
                active ? "Rule activated" : "Rule deactivated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Workflow rule deleted"));
    }

    @PostMapping("/dry-run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dryRun(
            @RequestBody WorkflowRuleRequest req,
            @RequestParam(required = false) String entityType,
            @RequestParam(required = false) UUID sampleEntityId) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.dryRun(req.toEntity(), entityType, sampleEntityId)));
    }

    @GetMapping("/{id}/executions")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Page<?>>> executions(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(service.executions(id, PageRequest.of(page, size))));
    }

    /** Metadata for the UI rule-builder: trigger events, operators, action types, field-update allowlists. */
    @GetMapping("/metadata")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> metadata() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("triggerEvents", List.of("INVOICE_POSTED", "BILL_POSTED", "PAYMENT_RECORDED"));
        out.put("operators", List.of("EQ", "NE", "GT", "GTE", "LT", "LTE", "CONTAINS", "IN", "IS_EMPTY", "IS_NOT_EMPTY"));
        out.put("actionTypes", List.of("EMAIL", "WEBHOOK", "AI_SUGGESTION", "FIELD_UPDATE"));
        Map<String, Object> allow = new LinkedHashMap<>();
        for (WorkflowFieldMutator m : fieldMutators) {
            // best-effort: expose the allowlist keyed by a representative entity type
            for (String et : List.of("INVOICE", "PURCHASE_BILL", "PAYMENT", "CONTACT")) {
                if (m.supports(et)) allow.put(et, m.allowedFields());
            }
        }
        out.put("fieldUpdateAllowlist", allow);
        return ResponseEntity.ok(ApiResponse.ok(out));
    }
}
