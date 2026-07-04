package com.katasticho.erp.accounting.forex.controller;

import com.katasticho.erp.accounting.forex.dto.ForexRevaluationDtos.RevaluationResult;
import com.katasticho.erp.accounting.forex.dto.ForexRevaluationDtos.RevaluationRunResponse;
import com.katasticho.erp.accounting.forex.service.ForexRevaluationService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * Period-end forex revaluation (MASTER_GAP_TRACKER H8). Restates open
 * foreign-currency AR/AP to the closing rate and posts the unrealized gain/loss.
 */
@RestController
@RequestMapping("/api/v1/reports/forex-revaluation")
@RequiredArgsConstructor
public class ForexRevaluationController {

    private final ForexRevaluationService service;

    /** Compute the revaluation without posting — review before you run. */
    @GetMapping("/preview")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<RevaluationResult>> preview(
            @RequestParam("asOfDate") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        return ResponseEntity.ok(ApiResponse.ok(service.preview(asOfDate)));
    }

    /** Post the consolidated revaluation journal + its next-day reversal. */
    @PostMapping("/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<RevaluationRunResponse>> run(
            @RequestParam("asOfDate") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        return ResponseEntity.ok(ApiResponse.ok(service.revalue(asOfDate),
                "Forex revaluation posted"));
    }

    @GetMapping("/runs")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<RevaluationRunResponse>>> runs() {
        return ResponseEntity.ok(ApiResponse.ok(service.listRuns()));
    }
}
