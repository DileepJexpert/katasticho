package com.katasticho.erp.reporting.controller;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.reporting.service.MsmeForm1Service;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.Map;

/**
 * MSME Form 1 annexure — supplier-wise MSME dues split at the statutory
 * 45-day limit, plus the payments made beyond 45 days in the half-year.
 * India-only: the MSMED Act + MCA filing order are Indian statute.
 */
@RestController
@RequestMapping("/api/v1/reports/msme-form1")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
@RequiresCountry("IN")
public class MsmeForm1Controller {

    private final MsmeForm1Service msmeForm1Service;

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> report(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(msmeForm1Service.report(asOf, from, to)));
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        byte[] body = msmeForm1Service.exportCsv(asOf, from, to);
        String filename = "msme-form1-" + (asOf != null ? asOf : LocalDate.now()) + ".csv";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv"))
                .body(body);
    }
}
