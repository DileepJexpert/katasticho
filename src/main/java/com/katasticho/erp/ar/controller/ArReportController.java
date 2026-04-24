package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.AgeingReportResponse;
import com.katasticho.erp.ar.service.ArReportService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/ar/reports")
@RequiredArgsConstructor
public class ArReportController {

    private final ArReportService reportService;

    @GetMapping("/ageing")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AgeingReportResponse>> getAgeingReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        if (asOfDate == null) asOfDate = LocalDate.now();
        return ResponseEntity.ok(ApiResponse.ok(reportService.getAgeingReport(asOfDate)));
    }

    @GetMapping("/gstr1")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getGstr1(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(reportService.generateGstr1(year, month)));
    }

    @GetMapping("/gstr3b")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getGstr3b(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(reportService.generateGstr3b(year, month)));
    }
}
