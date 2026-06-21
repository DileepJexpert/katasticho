package com.katasticho.erp.tax.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.tax.service.Form16PdfService;
import com.katasticho.erp.tax.service.Form24QExporter;
import com.katasticho.erp.tax.service.SalaryTdsService;
import com.katasticho.erp.tax.service.TdsService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * TDS compliance: deduction register (for the monthly deposit challan) and
 * quarterly Form 26Q data prep. Deduction itself happens automatically on
 * vendor bills via the vendor master (tdsApplicable/section/rate).
 *
 * <p>Salary-side TDS (Form 24Q / Form 16 / salary register) is derived from
 * posted payroll runs via {@link SalaryTdsService}.
 */
@RestController
@RequestMapping("/api/v1/tds")
@RequiredArgsConstructor
public class TdsController {

    private final TdsService tdsService;
    private final SalaryTdsService salaryTdsService;
    private final Form24QExporter form24QExporter;
    private final Form16PdfService form16PdfService;

    /** Bills with TDS deducted in the range — what to deposit via ITNS-281. */
    @GetMapping("/register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> register(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(tdsService.register(from, to)));
    }

    /** Quarterly Form 26Q data: deductee-wise summary. fy = FY start year (2026 = FY 2026-27). */
    @GetMapping("/26q")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> form26q(
            @RequestParam int fy,
            @RequestParam int quarter) {
        return ResponseEntity.ok(ApiResponse.ok(tdsService.form26q(fy, quarter)));
    }

    /** Quarterly Form 24Q data (salary TDS): deductee-wise summary from posted payroll runs. */
    @GetMapping("/24q")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> form24q(
            @RequestParam int fy,
            @RequestParam int quarter) {
        return ResponseEntity.ok(ApiResponse.ok(salaryTdsService.form24q(fy, quarter)));
    }

    /** Form 24Q downloadable CSV — register for auditors. */
    @GetMapping(value = "/24q/csv")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> form24qCsv(@RequestParam int fy, @RequestParam int quarter) {
        String body = form24QExporter.csv(fy, quarter);
        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.parseMediaType("text/csv"))
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + form24QExporter.filename(fy, quarter, "csv") + "\"")
                .body(body.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    /** Form 24Q FVU deductee-detail (DD) block — `^`-separated, prepend FH/BH/CH in your FVU tool. */
    @GetMapping(value = "/24q/fvu")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> form24qFvu(@RequestParam int fy, @RequestParam int quarter) {
        String body = form24QExporter.fvuDeducteeDetail(fy, quarter);
        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.TEXT_PLAIN)
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + form24QExporter.filename(fy, quarter, "txt") + "\"")
                .body(body.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    /** Annual Form 16 (employee TDS certificate): Part A (quarter-wise) + Part B (salary breakup). */
    @GetMapping("/form16/{employeeId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> form16(
            @PathVariable UUID employeeId,
            @RequestParam int fy) {
        return ResponseEntity.ok(ApiResponse.ok(salaryTdsService.form16(employeeId, fy)));
    }

    /** Form 16 PDF — the annual TDS certificate handed to the employee. */
    @GetMapping("/form16/{employeeId}/pdf")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> form16Pdf(@PathVariable UUID employeeId, @RequestParam int fy) {
        byte[] pdf = form16PdfService.generatePdf(employeeId, fy);
        @SuppressWarnings("unchecked")
        var data = (java.util.Map<String, Object>) salaryTdsService.form16(employeeId, fy);
        @SuppressWarnings("unchecked")
        var emp = (java.util.Map<String, Object>) data.getOrDefault("employee", java.util.Map.of());
        String filename = form16PdfService.filename(fy, String.valueOf(emp.get("name")));
        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.APPLICATION_PDF)
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + filename + "\"")
                .body(pdf);
    }

    /** Employee-wise salary TDS deducted in the range — for the monthly ITNS-281 deposit. */
    @GetMapping("/salary-register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> salaryRegister(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(salaryTdsService.register(from, to)));
    }
}
