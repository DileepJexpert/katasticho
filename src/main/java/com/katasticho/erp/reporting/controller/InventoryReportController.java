package com.katasticho.erp.reporting.controller;

import com.katasticho.erp.reporting.dto.*;
import com.katasticho.erp.reporting.service.InventoryReportService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory-reports")
@RequiredArgsConstructor
public class InventoryReportController {

    private final InventoryReportService reportService;

    @GetMapping("/stock-summary")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<StockSummaryReport>> getStockSummary() {
        return ResponseEntity.ok(ApiResponse.ok(reportService.getStockSummary()));
    }

    @GetMapping("/stock-movements")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<StockMovementReport>> getStockMovement(
            @RequestParam(required = false) UUID itemId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(defaultValue = "0") int pageNo,
            @RequestParam(defaultValue = "100") int pageSize) {
        return ResponseEntity.ok(ApiResponse.ok(
            reportService.getStockMovement(itemId, startDate, endDate, pageNo, pageSize)
        ));
    }
}
