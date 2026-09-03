package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.runway.CashRunwayReportResponse;
import com.katasticho.erp.accounting.dto.runway.CashRunwaySimulationRequest;
import com.katasticho.erp.accounting.service.CashRunwayService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/treasury/cash-runway")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.ACCOUNTING)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class CashRunwayController {

    private final CashRunwayService cashRunwayService;

    @GetMapping("/13-week")
    public ResponseEntity<ApiResponse<CashRunwayReportResponse>> get13WeekRunway(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        CashRunwayReportResponse report = cashRunwayService.generate13WeekRunway(asOfDate, null);
        return ResponseEntity.ok(ApiResponse.ok(report));
    }

    @PostMapping("/simulate")
    public ResponseEntity<ApiResponse<CashRunwayReportResponse>> simulateScenario(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate,
            @RequestBody CashRunwaySimulationRequest simulation) {
        CashRunwayReportResponse report = cashRunwayService.generate13WeekRunway(asOfDate, simulation);
        return ResponseEntity.ok(ApiResponse.ok(report, "Scenario simulated successfully"));
    }
}