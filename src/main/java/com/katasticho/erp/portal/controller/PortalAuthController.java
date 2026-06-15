package com.katasticho.erp.portal.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.portal.service.PortalAuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Public portal authentication: accept an invite (set password) and log in.
 * No authentication required — this is how external customers/vendors get a
 * portal session. Mapped under {@code /api/v1/portal/auth/**}, which the portal
 * filter deliberately leaves open.
 */
@RestController
@RequestMapping("/api/v1/portal/auth")
@RequiredArgsConstructor
public class PortalAuthController {

    private final PortalAuthService service;

    @PostMapping("/accept-invite")
    public ResponseEntity<ApiResponse<Map<String, Object>>> acceptInvite(@RequestBody Map<String, Object> body) {
        String token = (String) body.get("token");
        String password = (String) body.get("password");
        return ResponseEntity.ok(ApiResponse.ok(service.acceptInvite(token, password), "Welcome to the portal"));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<Map<String, Object>>> login(@RequestBody Map<String, Object> body) {
        String email = (String) body.get("email");
        String password = (String) body.get("password");
        return ResponseEntity.ok(ApiResponse.ok(service.login(email, password), "Logged in"));
    }
}
