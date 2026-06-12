package com.katasticho.erp.fieldsales.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.service.FieldCoverageService;
import com.katasticho.erp.fieldsales.service.MrReportingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;

/** Pharma MR reporting: monthly tour plans (MTP) and Daily Call Reports (DCR). */
@RestController
@RequestMapping("/api/v1/mr")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class MrReportingController {

    private final MrReportingService service;
    private final FieldCoverageService coverageService;

    // ══════════════════════════════════════════════════════════════
    // Tour Plan (MTP)
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/tour-plans")
    public ResponseEntity<ApiResponse<TourPlan>> createTourPlan(@RequestBody Map<String, Object> body) {
        LocalDate month = LocalDate.parse(body.get("planMonth").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.createTourPlan(month, (String) body.get("notes")), "Tour plan created"));
    }

    @GetMapping("/tour-plans/me")
    public ResponseEntity<ApiResponse<List<TourPlan>>> myTourPlans() {
        return ResponseEntity.ok(ApiResponse.ok(service.myTourPlans()));
    }

    @GetMapping("/tour-plans/pending")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<TourPlan>>> pendingTourPlans() {
        return ResponseEntity.ok(ApiResponse.ok(service.pendingTourPlans()));
    }

    @GetMapping("/tour-plans/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getTourPlan(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getTourPlan(id)));
    }

    @PostMapping("/tour-plans/{id}/entries")
    public ResponseEntity<ApiResponse<TourPlanEntry>> addEntry(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        TourPlanEntry entry = service.addEntry(id,
                LocalDate.parse(body.get("planDate").toString()),
                (String) body.get("activityType"),
                body.get("beatId") != null ? UUID.fromString(body.get("beatId").toString()) : null,
                (String) body.get("area"),
                (String) body.get("notes"));
        return ResponseEntity.ok(ApiResponse.ok(entry, "Entry added"));
    }

    @DeleteMapping("/tour-plans/entries/{entryId}")
    public ResponseEntity<ApiResponse<Void>> removeEntry(@PathVariable UUID entryId) {
        service.removeEntry(entryId);
        return ResponseEntity.ok(ApiResponse.ok(null, "Entry removed"));
    }

    @PostMapping("/tour-plans/{id}/submit")
    public ResponseEntity<ApiResponse<TourPlan>> submitTourPlan(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.submitTourPlan(id), "Tour plan submitted"));
    }

    @PostMapping("/tour-plans/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<TourPlan>> approveTourPlan(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approveTourPlan(id), "Tour plan approved"));
    }

    @PostMapping("/tour-plans/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<TourPlan>> rejectTourPlan(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.rejectTourPlan(id, (String) body.get("reason")), "Tour plan rejected"));
    }

    // ══════════════════════════════════════════════════════════════
    // Visit product log (detailing / samples / gifts)
    // ══════════════════════════════════════════════════════════════

    @PutMapping("/visits/{visitId}/products")
    public ResponseEntity<ApiResponse<List<VisitProductLog>>> logVisitProducts(
            @PathVariable UUID visitId, @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> raw = (List<Map<String, Object>>) body.get("products");
        List<MrReportingService.ProductLogRequest> products = new ArrayList<>();
        if (raw != null) {
            for (Map<String, Object> p : raw) {
                products.add(new MrReportingService.ProductLogRequest(
                        p.get("itemId") != null ? UUID.fromString(p.get("itemId").toString()) : null,
                        (String) p.get("productName"),
                        p.get("detailed") != null ? Boolean.valueOf(p.get("detailed").toString()) : null,
                        p.get("sampleQty") != null ? Integer.valueOf(p.get("sampleQty").toString()) : null,
                        (String) p.get("giftName"),
                        p.get("giftQty") != null ? Integer.valueOf(p.get("giftQty").toString()) : null));
            }
        }
        return ResponseEntity.ok(ApiResponse.ok(
                service.logVisitProducts(visitId, products), "Products logged"));
    }

    @GetMapping("/visits/{visitId}/products")
    public ResponseEntity<ApiResponse<List<VisitProductLog>>> getVisitProducts(@PathVariable UUID visitId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getVisitProducts(visitId)));
    }

    @PostMapping("/visits/{visitId}/joint-visit")
    public ResponseEntity<ApiResponse<FieldVisit>> markJointVisit(
            @PathVariable UUID visitId, @RequestBody Map<String, Object> body) {
        UUID jointUserId = body.get("userId") != null
                ? UUID.fromString(body.get("userId").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.markJointVisit(visitId, jointUserId), "Joint visit recorded"));
    }

    // ══════════════════════════════════════════════════════════════
    // DCR (Daily Call Report)
    // ══════════════════════════════════════════════════════════════

    @PostMapping("/dcr/build")
    public ResponseEntity<ApiResponse<DcrReport>> buildDcr(@RequestBody Map<String, Object> body) {
        LocalDate date = body.get("date") != null
                ? LocalDate.parse(body.get("date").toString()) : LocalDate.now();
        return ResponseEntity.ok(ApiResponse.ok(
                service.buildDcr(date, (String) body.get("workType"))));
    }

    @PostMapping("/dcr/submit")
    public ResponseEntity<ApiResponse<DcrReport>> submitDcr(@RequestBody Map<String, Object> body) {
        LocalDate date = body.get("date") != null
                ? LocalDate.parse(body.get("date").toString()) : LocalDate.now();
        return ResponseEntity.ok(ApiResponse.ok(
                service.submitDcr(date, (String) body.get("workType"), (String) body.get("remarks")),
                "DCR submitted"));
    }

    @GetMapping("/dcr/me")
    public ResponseEntity<ApiResponse<List<DcrReport>>> myDcrs(
            @RequestParam(required = false) LocalDate from,
            @RequestParam(required = false) LocalDate to) {
        LocalDate toDate = to != null ? to : LocalDate.now();
        LocalDate fromDate = from != null ? from : toDate.minusDays(30);
        return ResponseEntity.ok(ApiResponse.ok(service.myDcrs(fromDate, toDate)));
    }

    @GetMapping("/dcr/pending")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<DcrReport>>> pendingDcrs() {
        return ResponseEntity.ok(ApiResponse.ok(service.pendingDcrs()));
    }

    @PostMapping("/dcr/{id}/approve")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<DcrReport>> approveDcr(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approveDcr(id), "DCR approved"));
    }

    // ══════════════════════════════════════════════════════════════
    // Coverage reports (all verticals)
    // ══════════════════════════════════════════════════════════════

    @GetMapping("/reports/deviation")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> deviationReport(
            @RequestParam LocalDate month, @RequestParam UUID salespersonId) {
        return ResponseEntity.ok(ApiResponse.ok(
                coverageService.deviationReport(month, salespersonId)));
    }

    @GetMapping("/reports/frequency-compliance")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> frequencyCompliance(
            @RequestParam LocalDate month,
            @RequestParam(required = false) UUID salespersonId) {
        return ResponseEntity.ok(ApiResponse.ok(
                coverageService.frequencyCompliance(month, salespersonId)));
    }

    @GetMapping("/reports/team-dashboard")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> teamDashboard(
            @RequestParam LocalDate from, @RequestParam LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(coverageService.teamDashboard(from, to)));
    }

    @PostMapping("/dcr/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<DcrReport>> rejectDcr(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.rejectDcr(id, (String) body.get("reason")), "DCR rejected"));
    }
}
