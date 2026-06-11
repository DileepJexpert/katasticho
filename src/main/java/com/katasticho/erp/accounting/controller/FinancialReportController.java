package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.report.*;
import com.katasticho.erp.accounting.service.FinancialReportService;
import com.katasticho.erp.accounting.service.OperationalReportService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/reports")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.REPORTS)
public class FinancialReportController {

    private final FinancialReportService reportService;
    private final OperationalReportService operationalReportService;

    @GetMapping("/trial-balance")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<TrialBalanceResponse>> getTrialBalance(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        if (asOfDate == null) asOfDate = LocalDate.now();
        return ResponseEntity.ok(ApiResponse.ok(reportService.generateTrialBalance(asOfDate)));
    }

    @GetMapping("/profit-loss")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ProfitLossResponse>> getProfitLoss(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(reportService.generateProfitLoss(startDate, endDate)));
    }

    @GetMapping("/balance-sheet")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BalanceSheetResponse>> getBalanceSheet(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        if (asOfDate == null) asOfDate = LocalDate.now();
        return ResponseEntity.ok(ApiResponse.ok(reportService.generateBalanceSheet(asOfDate)));
    }

    @GetMapping("/general-ledger/{accountId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<GeneralLedgerResponse>> getGeneralLedger(
            @PathVariable UUID accountId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(
                reportService.generateGeneralLedger(accountId, startDate, endDate)));
    }

    @GetMapping("/sales-register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getSalesRegister(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.salesRegister(startDate, endDate)));
    }

    @GetMapping("/daily-sales")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getDailySales(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.dailySales(startDate, endDate)));
    }

    @GetMapping("/purchase-register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getPurchaseRegister(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.purchaseRegister(startDate, endDate)));
    }

    @GetMapping("/day-book")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getDayBook(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.dayBook(startDate, endDate)));
    }

    @GetMapping("/cash-flow")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getCashFlow(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.cashFlow(startDate, endDate)));
    }

    @GetMapping("/journal-register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getJournalRegister(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.journalRegister(startDate, endDate)));
    }

    @GetMapping("/cost-centres")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getCostCentres(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.costCentres(startDate, endDate)));
    }

    @GetMapping("/low-stock")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getLowStockAlert() {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.lowStockAlert()));
    }

    @GetMapping("/gst-summary")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getGstSummary(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.gstSummary(startDate, endDate)));
    }

    @GetMapping("/stock-summary")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getStockSummary() {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.stockSummary()));
    }

    @GetMapping("/stock-movement")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getStockMovement(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.stockMovement(startDate, endDate)));
    }

    @GetMapping("/pending-dispatch")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getPendingDispatch() {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.pendingDispatch()));
    }

    @GetMapping("/challan-not-invoiced")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<OperationalReportResponse>> getChallanNotInvoiced() {
        return ResponseEntity.ok(ApiResponse.ok(operationalReportService.challanNotInvoiced()));
    }
}
