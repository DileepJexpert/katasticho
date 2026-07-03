package com.katasticho.erp.recurring.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.recurring.dto.RecurringBillDtos.*;
import com.katasticho.erp.recurring.service.RecurringBillService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/recurring-bills")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.RECURRING_BILLING)
public class RecurringBillController {

    private final RecurringBillService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringBillResponse>> create(
            @RequestBody CreateRecurringBillRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.createTemplate(req), "Recurring bill created"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<Page<RecurringBillResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(service.listTemplates(status, PageRequest.of(page, size))));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<RecurringBillResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTemplate(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringBillResponse>> update(
            @PathVariable UUID id, @RequestBody UpdateRecurringBillRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateTemplate(id, req), "Recurring bill updated"));
    }

    @PostMapping("/{id}/stop")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringBillResponse>> stop(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.stopTemplate(id), "Recurring bill stopped"));
    }

    @PostMapping("/{id}/resume")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<RecurringBillResponse>> resume(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.resumeTemplate(id), "Recurring bill resumed"));
    }

    @GetMapping("/{id}/generated-bills")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<GeneratedBillResponse>>> generated(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.listGenerated(id)));
    }

    @PostMapping("/{id}/generate-now")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> generateNow(@PathVariable UUID id) {
        UUID billId = service.generateFromTemplate(id);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("generated", billId != null, "billId", billId == null ? "" : billId.toString()),
                billId != null ? "Bill generated" : "Nothing generated (template inactive or empty)"));
    }
}
