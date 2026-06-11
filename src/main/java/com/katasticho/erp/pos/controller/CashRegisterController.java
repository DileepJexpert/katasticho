package com.katasticho.erp.pos.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.pos.dto.AddExpenseRequest;
import com.katasticho.erp.pos.dto.CashRegisterSummary;
import com.katasticho.erp.pos.dto.CloseRegisterRequest;
import com.katasticho.erp.pos.dto.OpenRegisterRequest;
import com.katasticho.erp.pos.service.CashRegisterService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/pos/cash-register")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.POS)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class CashRegisterController {

    private final CashRegisterService cashRegisterService;

    @PostMapping("/open")
    public ResponseEntity<ApiResponse<CashRegisterSummary>> openRegister(
            @RequestBody OpenRegisterRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(
                cashRegisterService.openToday(orgId, userId, request.openingBalance(), request.notes())));
    }

    @GetMapping("/today")
    public ResponseEntity<ApiResponse<CashRegisterSummary>> getToday() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(cashRegisterService.getTodaySummary(orgId)));
    }

    @GetMapping("/history")
    public ResponseEntity<ApiResponse<List<CashRegisterSummary>>> getHistory(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(cashRegisterService.getHistory(orgId, from, to)));
    }

    @GetMapping("/{date}")
    public ResponseEntity<ApiResponse<CashRegisterSummary>> getByDate(
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(cashRegisterService.getSummary(orgId, date)));
    }

    @PostMapping("/expense")
    public ResponseEntity<ApiResponse<CashRegisterSummary>> addExpense(
            @RequestBody AddExpenseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(
                cashRegisterService.addExpense(orgId, userId, request.amount(), request.description())));
    }

    @DeleteMapping("/expense/{expenseId}")
    public ResponseEntity<ApiResponse<Void>> deleteExpense(@PathVariable UUID expenseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        cashRegisterService.deleteExpense(orgId, expenseId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @PostMapping("/close")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<CashRegisterSummary>> closeRegister(
            @RequestBody CloseRegisterRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return ResponseEntity.ok(ApiResponse.ok(
                cashRegisterService.closeRegister(orgId, userId, request.actualClosing(), request.notes())));
    }
}
