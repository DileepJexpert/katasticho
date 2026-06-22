package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.gst.service.MonthEndCloseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * One-click month-end close checklist endpoint. Aggregates readiness across
 * fiscal period, IMS actions, 2B reconciliation, GST 2.0 rate drift, and
 * GSTR-1/3B prep into a single response with an overall traffic-light state.
 */
@RestController
@RequestMapping("/api/v1/gst/close")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
@RequiresCountry("IN")
public class MonthEndCloseController {

    private final MonthEndCloseService closeService;

    @GetMapping("/checklist")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checklist(
            @RequestParam int year, @RequestParam int month) {
        return ResponseEntity.ok(ApiResponse.ok(closeService.checklist(year, month)));
    }

    @GetMapping("/checklist/now")
    public ResponseEntity<ApiResponse<Map<String, Object>>> current() {
        return ResponseEntity.ok(ApiResponse.ok(closeService.currentMonthChecklist()));
    }
}
