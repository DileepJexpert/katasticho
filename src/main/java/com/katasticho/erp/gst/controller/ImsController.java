package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.service.ImsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * IMS (Invoice Management System) action loop endpoints.
 *
 * <p>Under amended Sec 38 CGST (eff. 1 Oct 2025) every inward invoice on the
 * portal must be actioned; unactioned rows are deemed accepted into GSTR-2B.
 */
@RestController
@RequestMapping("/api/v1/gst/ims")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
@RequiresCountry("IN")
public class ImsController {

    private final ImsService imsService;

    /** Period summary: total / actioned / no-action / deemed-accepted ITC exposure. */
    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<Map<String, Object>>> summary(
            @RequestParam("period") String period) {
        return ResponseEntity.ok(ApiResponse.ok(imsService.periodSummary(period)));
    }

    /** Rows in the period that have no IMS action yet — the deemed-accepted risk surface. */
    @GetMapping("/no-action")
    public ResponseEntity<ApiResponse<List<Gstr2bEntry>>> noAction(
            @RequestParam("period") String period) {
        return ResponseEntity.ok(ApiResponse.ok(imsService.noActionRows(period)));
    }

    /** Action a single row — ACCEPT / REJECT / PENDING + optional remarks. */
    @PostMapping("/{id}/action")
    public ResponseEntity<ApiResponse<Gstr2bEntry>> action(
            @PathVariable UUID id,
            @RequestBody ActionRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(
                imsService.action(id, req.action(), req.remarks()),
                "IMS action recorded"));
    }

    /** Bulk action — the auditor's "Accept All MATCHED rows in one tap" surface. */
    @PostMapping("/bulk-action")
    public ResponseEntity<ApiResponse<Map<String, Object>>> bulk(@RequestBody BulkRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(
                imsService.bulkAction(req.entryIds(), req.action(), req.remarks()),
                "IMS bulk action processed"));
    }

    /** Compute AI recommendations for unactioned rows (rule-based, deterministic). */
    @PostMapping("/recommend")
    public ResponseEntity<ApiResponse<Map<String, Object>>> recommend(
            @RequestParam("period") String period) {
        return ResponseEntity.ok(ApiResponse.ok(
                imsService.recommendForPeriod(period),
                "IMS recommendations refreshed"));
    }

    /** Accept all the AI's recommendations in one tap. */
    @PostMapping("/apply-recommendations")
    public ResponseEntity<ApiResponse<Map<String, Object>>> applyAll(
            @RequestParam("period") String period) {
        return ResponseEntity.ok(ApiResponse.ok(
                imsService.applyAllAiRecommendations(period),
                "AI recommendations applied"));
    }

    public record ActionRequest(String action, String remarks) {}
    public record BulkRequest(List<UUID> entryIds, String action, String remarks) {}
}
