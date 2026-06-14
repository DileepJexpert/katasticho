package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.service.HrAnalyticsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/** HR Analytics — Core HR module 8: org-wide HR snapshot dashboard. */
@RestController
@RequestMapping("/api/v1/hr/analytics")
@RequiredArgsConstructor
public class HrAnalyticsController {

    private final HrAnalyticsService service;

    @GetMapping("/dashboard")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dashboard() {
        return ResponseEntity.ok(ApiResponse.ok(service.dashboard()));
    }
}
