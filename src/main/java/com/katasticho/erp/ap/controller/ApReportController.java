package com.katasticho.erp.ap.controller;

import com.katasticho.erp.ap.dto.ApAgeingReportResponse;
import com.katasticho.erp.ap.service.ApReportService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/ap/reports")
@RequiredArgsConstructor
public class ApReportController {

    private final ApReportService reportService;

    @GetMapping("/ageing")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ApAgeingReportResponse>> getAgeingReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        if (asOfDate == null) asOfDate = LocalDate.now();
        return ResponseEntity.ok(ApiResponse.ok(reportService.getAgeingReport(asOfDate)));
    }
}
