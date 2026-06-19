package com.katasticho.erp.manufacturing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.manufacturing.entity.BmrDeviation;
import com.katasticho.erp.manufacturing.entity.BmrSignoff;
import com.katasticho.erp.manufacturing.entity.BmrStepRecord;
import com.katasticho.erp.manufacturing.service.BmrPdfService;
import com.katasticho.erp.manufacturing.service.BmrService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/manufacturing/bmr")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.MANUFACTURING)
public class BmrController {

    private final BmrService service;
    private final BmrPdfService pdfService;
    private final com.katasticho.erp.manufacturing.repository.WorkOrderRepository workOrderRepository;

    // ── Step records ─────────────────────────────────────────────────

    @PostMapping("/step-records")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<BmrStepRecord>> recordStepParameter(
            @RequestBody Map<String, Object> body) {
        UUID woId = UUID.fromString((String) body.get("workOrderId"));
        UUID jcId = body.get("jobCardId") != null
                ? UUID.fromString((String) body.get("jobCardId")) : null;
        String key = (String) body.get("parameterKey");
        String value = (String) body.get("parameterValue");
        String unit = (String) body.get("unit");
        String notes = (String) body.get("notes");
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordStepParameter(woId, jcId, key, value, unit, notes),
                "Parameter recorded"));
    }

    @GetMapping("/work-orders/{workOrderId}/step-records")
    public ResponseEntity<ApiResponse<List<BmrStepRecord>>> listStepRecords(
            @PathVariable UUID workOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listStepRecords(workOrderId)));
    }

    // ── Signoffs ─────────────────────────────────────────────────────

    @PostMapping("/signoffs")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<BmrSignoff>> recordSignoff(
            @RequestBody Map<String, Object> body) {
        UUID woId = UUID.fromString((String) body.get("workOrderId"));
        UUID jcId = body.get("jobCardId") != null
                ? UUID.fromString((String) body.get("jobCardId")) : null;
        String role = (String) body.get("role");
        String notes = (String) body.get("notes");
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordSignoff(woId, jcId, role, notes),
                "Signoff recorded"));
    }

    @GetMapping("/work-orders/{workOrderId}/signoffs")
    public ResponseEntity<ApiResponse<List<BmrSignoff>>> listSignoffs(
            @PathVariable UUID workOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listSignoffs(workOrderId)));
    }

    // ── Deviations ───────────────────────────────────────────────────

    @PostMapping("/deviations")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<BmrDeviation>> logDeviation(
            @RequestBody Map<String, Object> body) {
        UUID woId = UUID.fromString((String) body.get("workOrderId"));
        UUID jcId = body.get("jobCardId") != null
                ? UUID.fromString((String) body.get("jobCardId")) : null;
        String severity = (String) body.get("severity");
        String title = (String) body.get("title");
        String description = (String) body.get("description");
        return ResponseEntity.ok(ApiResponse.ok(
                service.logDeviation(woId, jcId, severity, title, description),
                "Deviation logged"));
    }

    @PutMapping("/deviations/{deviationId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<BmrDeviation>> updateDeviation(
            @PathVariable UUID deviationId,
            @RequestBody Map<String, Object> body) {
        String status = (String) body.get("status");
        String resolution = (String) body.get("resolution");
        return ResponseEntity.ok(ApiResponse.ok(
                service.resolveDeviation(deviationId, status, resolution),
                "Deviation updated"));
    }

    @GetMapping("/work-orders/{workOrderId}/deviations")
    public ResponseEntity<ApiResponse<List<BmrDeviation>>> listDeviations(
            @PathVariable UUID workOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listDeviations(workOrderId)));
    }

    @GetMapping("/deviations/open")
    public ResponseEntity<ApiResponse<List<BmrDeviation>>> listOpenDeviations() {
        return ResponseEntity.ok(ApiResponse.ok(service.listOpenDeviations()));
    }

    // ── Yield reconciliation + snapshot ──────────────────────────────

    @GetMapping("/work-orders/{workOrderId}/yield-reconciliation")
    public ResponseEntity<ApiResponse<Map<String, Object>>> yieldReconciliation(
            @PathVariable UUID workOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(service.yieldReconciliation(workOrderId)));
    }

    @GetMapping("/work-orders/{workOrderId}/snapshot")
    public ResponseEntity<ApiResponse<Map<String, Object>>> bmrSnapshot(
            @PathVariable UUID workOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(service.bmrSnapshot(workOrderId)));
    }

    /**
     * Regulator-ready BMR PDF. Pulls the snapshot, resolves display
     * names, renders the standard Schedule M / WHO-GMP layout, and
     * returns the document as a download.
     */
    @GetMapping("/work-orders/{workOrderId}/pdf")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR','ACCOUNTANT','VIEWER')")
    public ResponseEntity<byte[]> downloadBmrPdf(@PathVariable UUID workOrderId) {
        com.katasticho.erp.manufacturing.entity.WorkOrder wo = workOrderRepository
                .findByIdAndOrgIdAndIsDeletedFalse(workOrderId,
                        com.katasticho.erp.common.context.TenantContext.getCurrentOrgId())
                .orElseThrow(() -> com.katasticho.erp.common.exception.BusinessException
                        .notFound("WorkOrder", workOrderId));
        byte[] pdf = pdfService.generatePdf(workOrderId);
        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.APPLICATION_PDF)
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + BmrPdfService.filename(wo) + "\"")
                .body(pdf);
    }
}
