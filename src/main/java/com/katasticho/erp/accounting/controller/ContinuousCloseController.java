package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.service.ContinuousCloseService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Continuous close: live close checklist for a period and a guarded close that
 * won't shut the books while tasks are pending.
 */
@RestController
@RequestMapping("/api/v1/accounting/continuous-close")
@RequiredArgsConstructor
public class ContinuousCloseController {

    private final ContinuousCloseService service;

    @GetMapping("/{year}/{month}/checklist")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checklist(
            @PathVariable int year, @PathVariable int month) {
        return ResponseEntity.ok(ApiResponse.ok(service.checklist(year, month)));
    }

    @PostMapping("/{year}/{month}/close")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> close(
            @PathVariable int year, @PathVariable int month,
            @RequestParam(defaultValue = "false") boolean force) {
        return ResponseEntity.ok(ApiResponse.ok(service.closeGuarded(year, month, force),
                "Period closed"));
    }
}
