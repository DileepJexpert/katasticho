package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.flux.FinancialFluxReportResponse;
import com.katasticho.erp.accounting.service.FluxCommentaryService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/reports/flux-commentary")
@RequiredArgsConstructor
public class FluxCommentaryController {

    private final FluxCommentaryService fluxCommentaryService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ApiResponse<FinancialFluxReportResponse> getFluxReport(
            @RequestParam(required = false, defaultValue = "MOM") String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate baseStart,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate baseEnd,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate compStart,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate compEnd,
            @RequestParam(required = false) BigDecimal minMaterialAmount,
            @RequestParam(required = false) BigDecimal minMaterialPercent) {

        FinancialFluxReportResponse response = fluxCommentaryService.analyzeFlux(
                periodType, baseStart, baseEnd, compStart, compEnd, minMaterialAmount, minMaterialPercent);
        return ApiResponse.ok(response);
    }
}