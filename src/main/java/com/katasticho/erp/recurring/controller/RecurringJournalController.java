package com.katasticho.erp.recurring.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.recurring.dto.RecurringJournalDtos.*;
import com.katasticho.erp.recurring.service.RecurringJournalService;
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
@RequestMapping("/api/v1/recurring-journals")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.RECURRING_BILLING)
public class RecurringJournalController {

    private final RecurringJournalService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<RecurringJournalResponse>> create(
            @RequestBody CreateRecurringJournalRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.createTemplate(req), "Recurring journal created"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Page<RecurringJournalResponse>>> list(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(service.listTemplates(status, PageRequest.of(page, size))));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<RecurringJournalResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTemplate(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<RecurringJournalResponse>> update(
            @PathVariable UUID id, @RequestBody UpdateRecurringJournalRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateTemplate(id, req), "Recurring journal updated"));
    }

    @PostMapping("/{id}/stop")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<RecurringJournalResponse>> stop(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.stopTemplate(id), "Recurring journal stopped"));
    }

    @PostMapping("/{id}/resume")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<RecurringJournalResponse>> resume(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.resumeTemplate(id), "Recurring journal resumed"));
    }

    @GetMapping("/{id}/generated-journals")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<GeneratedJournalResponse>>> generated(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.listGenerated(id)));
    }

    @PostMapping("/{id}/generate-now")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> generateNow(@PathVariable UUID id) {
        UUID entryId = service.generateFromTemplate(id);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("generated", entryId != null, "journalEntryId", entryId == null ? "" : entryId.toString()),
                entryId != null ? "Journal generated" : "Nothing generated (template inactive or empty)"));
    }
}
