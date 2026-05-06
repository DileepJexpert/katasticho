package com.katasticho.erp.reporting.controller;

import com.katasticho.erp.reporting.dto.*;
import com.katasticho.erp.reporting.service.OperationalReportService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/financial-reports")
@RequiredArgsConstructor
public class OperationalReportController {

    private final OperationalReportService reportService;

    @GetMapping("/cash-flow")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CashFlowStatement>> getCashFlowStatement(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(defaultValue = "DAILY") String period) {
        return ResponseEntity.ok(ApiResponse.ok(reportService.getCashFlowStatement(startDate, endDate, period)));
    }

    @GetMapping("/journal-register")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<JournalRegisterLine>>> getJournalRegister(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(required = false) String sourceModule,
            @RequestParam(defaultValue = "0") int pageNo,
            @RequestParam(defaultValue = "100") int pageSize) {
        return ResponseEntity.ok(ApiResponse.ok(
            reportService.getJournalRegister(startDate, endDate, sourceModule, pageNo, pageSize)
        ));
    }

    @GetMapping("/sales-register")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<SalesRegisterReport>> getSalesRegister(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(required = false) String documentType) {
        return ResponseEntity.ok(ApiResponse.ok(
            reportService.getSalesRegister(startDate, endDate, documentType)
        ));
    }
}
