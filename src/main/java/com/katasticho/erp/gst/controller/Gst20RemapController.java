package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.gst.service.Gst20RateRemapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * GST 2.0 rate re-mapping wizard endpoints. Surfaces items whose stored GST
 * rate doesn't match their HSN's post-9/2025 master rate and applies the
 * change in bulk per the user's review.
 */
@RestController
@RequestMapping("/api/v1/gst/rate-remap")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class Gst20RemapController {

    private final Gst20RateRemapper remapper;

    @GetMapping("/candidates")
    public ResponseEntity<ApiResponse<Map<String, Object>>> candidates() {
        return ResponseEntity.ok(ApiResponse.ok(remapper.candidates()));
    }

    @PostMapping("/apply")
    public ResponseEntity<ApiResponse<Map<String, Object>>> applyBulk(
            @RequestBody ApplyRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(
                remapper.applyBulk(req.itemIds(), req.dryRun()),
                req.dryRun() ? "Dry-run completed" : "Rates updated"));
    }

    @PostMapping("/apply-bucket")
    public ResponseEntity<ApiResponse<Map<String, Object>>> applyBucket(
            @RequestParam("bucket") String bucketKey) {
        return ResponseEntity.ok(ApiResponse.ok(
                remapper.applyBucket(bucketKey),
                "Bucket re-mapped"));
    }

    public record ApplyRequest(List<UUID> itemIds, boolean dryRun) {}
}
