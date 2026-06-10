package com.katasticho.erp.tax.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.tax.service.TdsService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * TDS compliance: deduction register (for the monthly deposit challan) and
 * quarterly Form 26Q data prep. Deduction itself happens automatically on
 * vendor bills via the vendor master (tdsApplicable/section/rate).
 */
@RestController
@RequestMapping("/api/v1/tds")
@RequiredArgsConstructor
public class TdsController {

    private final TdsService tdsService;

    /** Bills with TDS deducted in the range — what to deposit via ITNS-281. */
    @GetMapping("/register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> register(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(tdsService.register(from, to)));
    }

    /** Quarterly Form 26Q data: deductee-wise summary. fy = FY start year (2026 = FY 2026-27). */
    @GetMapping("/26q")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> form26q(
            @RequestParam int fy,
            @RequestParam int quarter) {
        return ResponseEntity.ok(ApiResponse.ok(tdsService.form26q(fy, quarter)));
    }
}
