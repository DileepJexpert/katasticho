package com.katasticho.erp.payroll.india;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

/**
 * India-only gratuity endpoints (Payment of Gratuity Act 1972) — the Indian
 * parallel to {@code GulfPayrollController}. Class-level
 * {@code @RequiresCountry("IN")} keeps a Gulf org off the 15/26 formula.
 */
@RestController
@RequestMapping("/api/v1/payroll/gratuity/india")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.PAYROLL)
@RequiresCountry("IN")
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class IndiaPayrollController {

    private final IndiaGratuityService indiaGratuityService;

    /** Preview an employee's gratuity entitlement (asOf = future exit date or today). */
    @GetMapping("/{employeeId}")
    public ResponseEntity<ApiResponse<IndiaGratuityResult>> gratuity(
            @PathVariable UUID employeeId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf) {
        return ResponseEntity.ok(ApiResponse.ok(indiaGratuityService.computeFor(employeeId, asOf)));
    }

    /** Preview the monthly provision for a period without posting. */
    @GetMapping("/accrual/preview")
    public ResponseEntity<ApiResponse<Map<String, Object>>> previewAccrual(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(indiaGratuityService.previewAccrual(year, month)));
    }

    /** Post the monthly provision journal (DR 5130 / CR 2080). Idempotent per period. */
    @PostMapping("/accrual")
    public ResponseEntity<ApiResponse<Map<String, Object>>> postAccrual(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(
                indiaGratuityService.postAccrual(year, month),
                "Gratuity provision posted for " + year + "-" + month));
    }
}
