package com.katasticho.erp.dashboard;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.dashboard.dto.TodaySalesResponse;
import com.katasticho.erp.dashboard.dto.TopSellingItem;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Owner-view dashboard aggregation endpoints.
 *
 * Both endpoints accept optional {@code from} / {@code to} date range
 * parameters (ISO-8601, e.g. 2026-04-15) and default to "today" when
 * omitted. The today-sales endpoint additionally accepts an optional
 * {@code branchId} filter for single-branch rollups.
 */
@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping("/today-sales")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<TodaySalesResponse>> todaySales(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) UUID branchId) {
        return ResponseEntity.ok(ApiResponse.ok(dashboardService.getTodaySales(from, to, branchId)));
    }

    @GetMapping("/top-selling")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<TopSellingItem>>> topSelling(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false, defaultValue = "5") int limit) {
        return ResponseEntity.ok(ApiResponse.ok(dashboardService.getTopSelling(from, to, limit)));
    }
}
