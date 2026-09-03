package com.katasticho.erp.reporting.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.reporting.dto.ReportScheduleRequest;
import com.katasticho.erp.reporting.dto.SavedReportRequest;
import com.katasticho.erp.reporting.entity.ReportSchedule;
import com.katasticho.erp.reporting.entity.SavedReport;
import com.katasticho.erp.reporting.service.SavedReportService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/saved-reports")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.REPORTS)
public class SavedReportController {

    private final SavedReportService savedReportService;

    // -----------------------------------------------------------------------
    // Saved Reports
    // -----------------------------------------------------------------------

    /**
     * GET /api/v1/saved-reports
     * Lists all saved reports visible to the current user in the current org.
     */
    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<SavedReport>>> list() {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(savedReportService.list(orgId, userId)));
    }

    /**
     * POST /api/v1/saved-reports
     * Creates a new saved report owned by the current user.
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SavedReport>> create(
            @RequestBody SavedReportRequest req) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        SavedReport created = savedReportService.create(orgId, userId, req);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(created));
    }

    /**
     * PUT /api/v1/saved-reports/{id}
     * Updates a saved report. Only the owner may update.
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SavedReport>> update(
            @PathVariable UUID id,
            @RequestBody SavedReportRequest req) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        SavedReport updated = savedReportService.update(orgId, userId, id, req);
        return ResponseEntity.ok(ApiResponse.ok(updated));
    }

    /**
     * DELETE /api/v1/saved-reports/{id}
     * Soft-deletes a saved report. Only the owner may delete.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        UUID orgId  = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        savedReportService.delete(orgId, userId, id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Deleted successfully"));
    }

    // -----------------------------------------------------------------------
    // Report Schedules
    // -----------------------------------------------------------------------

    /**
     * GET /api/v1/saved-reports/{id}/schedules
     * Lists all delivery schedules attached to the given saved report.
     */
    @GetMapping("/{id}/schedules")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<ReportSchedule>>> listSchedules(
            @PathVariable UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(savedReportService.listSchedules(orgId, id)));
    }

    /**
     * POST /api/v1/saved-reports/{id}/schedules
     * Creates a new delivery schedule for the given saved report.
     */
    @PostMapping("/{id}/schedules")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ReportSchedule>> addSchedule(
            @PathVariable UUID id,
            @RequestBody ReportScheduleRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ReportSchedule schedule = savedReportService.addSchedule(orgId, id, req);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(schedule));
    }

    /**
     * DELETE /api/v1/saved-reports/{id}/schedules/{scheduleId}
     * Removes a delivery schedule.
     */
    @DeleteMapping("/{id}/schedules/{scheduleId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteSchedule(
            @PathVariable UUID id,
            @PathVariable UUID scheduleId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        savedReportService.deleteSchedule(orgId, scheduleId);
        return ResponseEntity.ok(ApiResponse.ok(null, "Schedule deleted"));
    }
}
