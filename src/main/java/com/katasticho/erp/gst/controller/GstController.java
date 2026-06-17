package com.katasticho.erp.gst.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.gst.dto.EwayBillDtos.CreateEwayBillRequest;
import com.katasticho.erp.gst.dto.EwayBillDtos.EwayBillResponse;
import com.katasticho.erp.gst.dto.EwayBillDtos.RecordEwbRequest;
import com.katasticho.erp.gst.dto.EwayBillDtos.VehicleCheckRequest;
import com.katasticho.erp.gst.dto.GstReviewSummaryResponse;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.service.EwayBillService;
import com.katasticho.erp.gst.service.GstComplianceCalendarService;
import com.katasticho.erp.gst.service.GstReviewService;
import com.katasticho.erp.gst.service.GstService;
import com.katasticho.erp.gst.service.Gstr2bReconService;
import com.katasticho.erp.gst.service.ItcRiskMonitorService;
import com.katasticho.erp.gst.dto.ItcRiskDtos.ItcRiskReport;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/gst")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.GST)
public class GstController {

    private final GstService gstService;
    private final GstReviewService gstReviewService;
    private final Gstr2bReconService gstr2bReconService;
    private final ItcRiskMonitorService itcRiskMonitorService;
    private final EwayBillService ewayBillService;
    private final GstComplianceCalendarService complianceCalendarService;
    private final ObjectMapper objectMapper;

    @GetMapping("/review-center")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<GstReviewSummaryResponse>> reviewCenter(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.ok(gstReviewService.reviewCenter(status)));
    }

    @GetMapping("/gstr1")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getGstr1(
            @RequestParam int year,
            @RequestParam int month) {
        Map<String, Object> data = gstService.generateGstr1(year, month);
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    @GetMapping("/gstr3b")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getGstr3b(
            @RequestParam int year,
            @RequestParam int month) {
        Map<String, Object> data = gstService.generateGstr3b(year, month);
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    @GetMapping("/gstr1/export")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportGstr1(
            @RequestParam int year,
            @RequestParam int month) throws Exception {
        Map<String, Object> data = gstService.generateGstr1(year, month);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        String filename = String.format("GSTR1_%d_%02d.json", year, month);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }

    @GetMapping("/gstr3b/export")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportGstr3b(
            @RequestParam int year,
            @RequestParam int month) throws Exception {
        Map<String, Object> data = gstService.generateGstr3b(year, month);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        String filename = String.format("GSTR3B_%d_%02d.json", year, month);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }

    // ── GSTR-2B reconciliation ───────────────────────────────────────────

    /** Upload the portal's GSTR-2B JSON for a period; parses, matches, returns the summary. */
    @PostMapping("/gstr2b/upload")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> uploadGstr2b(
            @RequestParam String period,
            @RequestBody Map<String, Object> portalJson) {
        return ResponseEntity.ok(ApiResponse.ok(
                gstr2bReconService.upload(period, portalJson),
                "GSTR-2B uploaded and reconciled"));
    }

    /** One-click: pull the period's 2B from the configured GSP and reconcile it. */
    @PostMapping("/gstr2b/fetch")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> fetchGstr2b(@RequestParam String period) {
        return ResponseEntity.ok(ApiResponse.ok(
                gstr2bReconService.fetchAndReconcile(period),
                "GSTR-2B fetched from GSP and reconciled"));
    }

    @GetMapping("/gstr2b")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Gstr2bEntry>>> listGstr2b(@RequestParam String period) {
        return ResponseEntity.ok(ApiResponse.ok(gstr2bReconService.list(period)));
    }

    @GetMapping("/gstr2b/summary")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> gstr2bSummary(@RequestParam String period) {
        return ResponseEntity.ok(ApiResponse.ok(gstr2bReconService.summary(period)));
    }

    // ── ITC-at-risk monitor (preventive, pre-cutoff) ──────────────────────

    /** Per-supplier ITC at risk for a month: whose unfiled GSTR-1 would block your credit. */
    @GetMapping("/itc-risk")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<ItcRiskReport>> itcRisk(@RequestParam String period) {
        return ResponseEntity.ok(ApiResponse.ok(itcRiskMonitorService.assessRisk(period)));
    }

    /** Money rollup across recent cycles: ₹ITC still recoverable vs already lost. */
    @GetMapping("/itc-risk/rollup")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<com.katasticho.erp.gst.dto.ItcRiskDtos.RecoverableRollup>> itcRiskRollup(
            @RequestParam(defaultValue = "3") int months) {
        return ResponseEntity.ok(ApiResponse.ok(itcRiskMonitorService.recoverableRollup(months)));
    }

    /** Refresh real-time 2A via GSP (if configured) and raise an AI-Inbox alert per at-risk supplier. */
    @PostMapping("/itc-risk/alert")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> itcRiskAlert(@RequestParam String period) {
        int raised = itcRiskMonitorService.refreshAndAlert(period);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("period", period, "alertsRaised", raised),
                raised + " ITC-at-risk alert(s) raised"));
    }

    // ── e-Way bills ──────────────────────────────────────────────────────

    @GetMapping("/eway-bills")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<EwayBillResponse>>> listEwayBills(
            @RequestParam(required = false) String status) {
        return ResponseEntity.ok(ApiResponse.ok(ewayBillService.list(status)));
    }

    @PostMapping("/eway-bills")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EwayBillResponse>> createEwayBill(
            @Valid @RequestBody CreateEwayBillRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(ewayBillService.create(request)));
    }

    /** Record the EWB number obtained on the NIC portal. */
    @PostMapping("/eway-bills/{id}/record")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EwayBillResponse>> recordEwayBill(
            @PathVariable UUID id,
            @Valid @RequestBody RecordEwbRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(
                ewayBillService.recordGenerated(id, request), "e-Way bill recorded"));
    }

    /** One-click: generate the e-way bill directly via the configured GSP. */
    @PostMapping("/eway-bills/{id}/generate-gsp")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<EwayBillResponse>> generateEwayBillViaGsp(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                ewayBillService.generateViaGsp(id), "e-Way bill generated via GSP"));
    }

    @PostMapping("/eway-bills/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<EwayBillResponse>> cancelEwayBill(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok(
                ewayBillService.cancel(id, reason), "e-Way bill entry cancelled"));
    }

    /** NIC bulk-upload JSON for the document, ready for the e-way bill portal. */
    @GetMapping("/eway-bills/{id}/portal-json")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<byte[]> ewayBillPortalJson(@PathVariable UUID id) throws Exception {
        Map<String, Object> data = ewayBillService.portalJson(id);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"eway_bill.json\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }

    /**
     * Vehicle-aggregate rule: even when each document is below ₹50,000, if the
     * combined value in one vehicle crosses the threshold, every document in it
     * needs an e-way bill before transit.
     */
    @PostMapping("/eway-bills/check-vehicle")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkVehicle(
            @Valid @RequestBody VehicleCheckRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(ewayBillService.checkVehicle(request)));
    }

    // ── Compliance calendar ──────────────────────────────────────────────

    @GetMapping("/compliance-calendar")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> complianceCalendar() {
        return ResponseEntity.ok(ApiResponse.ok(complianceCalendarService.calendar()));
    }
}
