package com.katasticho.erp.platform.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.platform.service.PlatformAdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/platform-admin/v1/dashboard")
@RequiredArgsConstructor
@PreAuthorize("hasRole('PLATFORM_ADMIN')")
public class PlatformAdminDashboardController {

    private final PlatformAdminService platformAdminService;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<PlatformAdminService.DashboardStats>> stats() {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.getDashboardStats()));
    }
}
