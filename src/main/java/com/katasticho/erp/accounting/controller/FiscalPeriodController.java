package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.FiscalPeriodResponse;
import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.service.FiscalPeriodService;
import com.katasticho.erp.accounting.service.YearEndCloseService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/accounting/periods")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.ACCOUNTING)
public class FiscalPeriodController {

    private final FiscalPeriodService fiscalPeriodService;
    private final YearEndCloseService yearEndCloseService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<FiscalPeriodResponse>>> listPeriods() {
        List<FiscalPeriodResponse> periods = fiscalPeriodService.listPeriods().stream()
                .map(FiscalPeriodResponse::from)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(periods));
    }

    @PostMapping("/{year}/{month}/close")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<FiscalPeriodResponse>> closePeriod(
            @PathVariable int year,
            @PathVariable int month) {
        FiscalPeriod period = fiscalPeriodService.closePeriod(year, month);
        return ResponseEntity.ok(ApiResponse.ok(FiscalPeriodResponse.from(period), "Period closed"));
    }

    @PostMapping("/{year}/{month}/reopen")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<FiscalPeriodResponse>> reopenPeriod(
            @PathVariable int year,
            @PathVariable int month) {
        FiscalPeriod period = fiscalPeriodService.reopenPeriod(year, month);
        return ResponseEntity.ok(ApiResponse.ok(FiscalPeriodResponse.from(period), "Period reopened"));
    }

    @PostMapping("/{year}/{month}/lock")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<FiscalPeriodResponse>> lockPeriod(
            @PathVariable int year,
            @PathVariable int month) {
        FiscalPeriod period = fiscalPeriodService.lockPeriod(year, month);
        return ResponseEntity.ok(ApiResponse.ok(FiscalPeriodResponse.from(period), "Period locked"));
    }

    /**
     * Year-end close: post the closing entry that zeroes every P&L account into
     * Retained Earnings for {@code fiscalYear}. Idempotent — a second call after
     * a successful close throws YEAR_END_ALREADY_CLOSED.
     */
    @PostMapping("/year-end-close/{fiscalYear}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<YearEndCloseService.CloseResult>> closeYear(
            @PathVariable int fiscalYear) {
        YearEndCloseService.CloseResult result = yearEndCloseService.closeYear(fiscalYear);
        return ResponseEntity.ok(ApiResponse.ok(result, "Year-end close posted"));
    }
}
