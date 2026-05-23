package com.katasticho.erp.platform.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.platform.service.PlatformAdminAuthService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/platform-admin/v1/auth")
@RequiredArgsConstructor
public class PlatformAdminAuthController {

    private final PlatformAdminAuthService platformAdminAuthService;

    public record LoginRequest(String email, String password) {}

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<PlatformAdminAuthService.PlatformAdminAuthResponse>> login(
            @RequestBody LoginRequest request,
            HttpServletRequest httpRequest
    ) {
        String ipAddress = extractIp(httpRequest);
        PlatformAdminAuthService.PlatformAdminAuthResponse response =
                platformAdminAuthService.login(request.email(), request.password(), ipAddress);
        return ResponseEntity.ok(ApiResponse.ok(response, "Login successful"));
    }

    private String extractIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return forwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
