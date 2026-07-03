package com.katasticho.erp.asset.controller;

import com.katasticho.erp.asset.entity.FixedAsset;
import com.katasticho.erp.asset.service.FixedAssetService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Fixed Assets register + depreciation (book/Companies Act run that posts to
 * the GL, plus the income-tax block-of-assets schedule for the return).
 */
@RestController
@RequestMapping("/api/v1/fixed-assets")
@RequiredArgsConstructor
public class FixedAssetController {

    private final FixedAssetService service;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<FixedAsset>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(service.list()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    /** Forward-looking depreciation projection to end of schedule (posts nothing). */
    @GetMapping("/{id}/schedule-preview")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> schedulePreview(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.computeScheduleFor(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<FixedAsset>> create(@RequestBody Map<String, Object> b) {
        FixedAsset a = FixedAsset.builder()
                .assetCode((String) b.get("assetCode"))
                .name((String) b.get("name"))
                .category((String) b.get("category"))
                .acquisitionDate(LocalDate.parse(b.get("acquisitionDate").toString()))
                .cost(num(b.get("cost")))
                .residualValue(num(b.getOrDefault("residualValue", "0")))
                .bookMethod((String) b.get("bookMethod"))
                .bookUsefulLifeMonths(b.get("bookUsefulLifeMonths") != null
                        ? Integer.parseInt(b.get("bookUsefulLifeMonths").toString()) : null)
                .bookRatePct(b.get("bookRatePct") != null ? num(b.get("bookRatePct")) : null)
                .itBlock((String) b.get("itBlock"))
                .itRatePct(b.get("itRatePct") != null ? num(b.get("itRatePct")) : null)
                .assetAccountCode((String) b.get("assetAccountCode"))
                .accumulatedDepAccountCode((String) b.get("accumulatedDepAccountCode"))
                .depExpenseAccountCode((String) b.get("depExpenseAccountCode"))
                .notes((String) b.get("notes"))
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.create(a), "Asset added"));
    }

    /** Charge book depreciation for a month and post the journal. */
    @PostMapping("/depreciation/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> runDepreciation(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(service.runDepreciation(year, month),
                "Depreciation posted"));
    }

    @PostMapping("/{id}/dispose")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dispose(
            @PathVariable UUID id, @RequestBody Map<String, Object> b) {
        return ResponseEntity.ok(ApiResponse.ok(service.dispose(id,
                LocalDate.parse(b.get("disposalDate").toString()),
                num(b.getOrDefault("proceeds", "0")),
                (String) b.get("proceedsAccountCode"),
                (String) b.get("gainLossAccountCode")), "Asset disposed"));
    }

    /** Income-tax block-of-assets schedule. fy = FY start year (2026 = FY 2026-27). */
    @GetMapping("/income-tax-schedule")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> incomeTax(@RequestParam int fy) {
        return ResponseEntity.ok(ApiResponse.ok(service.incomeTaxSchedule(fy)));
    }

    private static BigDecimal num(Object o) {
        return o == null ? BigDecimal.ZERO : new BigDecimal(o.toString());
    }
}
