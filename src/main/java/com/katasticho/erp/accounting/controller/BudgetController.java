package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.service.BudgetService;
import com.katasticho.erp.accounting.service.BudgetService.BudgetLineDto;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Budgets: an annual amount per account per fiscal year. Saving replaces the
 * FY's lines with what's sent. fy = FY start year (2026 = FY 2026-27).
 * Variance: GET /api/v1/reports/budget-variance.
 */
@RestController
@RequestMapping("/api/v1/budgets")
@RequiredArgsConstructor
public class BudgetController {

    private final BudgetService budgetService;

    @GetMapping("/{fy}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<BudgetLineDto>>> list(@PathVariable int fy) {
        return ResponseEntity.ok(ApiResponse.ok(budgetService.list(fy)));
    }

    @PutMapping("/{fy}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<BudgetLineDto>>> save(
            @PathVariable int fy, @RequestBody List<BudgetLineDto> lines) {
        return ResponseEntity.ok(ApiResponse.ok(budgetService.save(fy, lines), "Budget saved"));
    }
}
