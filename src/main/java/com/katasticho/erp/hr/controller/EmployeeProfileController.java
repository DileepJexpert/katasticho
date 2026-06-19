package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.EmployeeProfile;
import com.katasticho.erp.hr.service.EmployeeProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * Employee management — Core HR module 2. Self-service profile endpoints
 * ({@code /me}) for any signed-in user; HR ({userId}) endpoints for OWNER/ADMIN.
 */
@RestController
@RequestMapping("/api/v1/hr/profile")
@RequiredArgsConstructor
public class EmployeeProfileController {

    private final EmployeeProfileService service;

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getMyProfile() {
        return ResponseEntity.ok(ApiResponse.ok(service.getMyProfile()));
    }

    @PutMapping("/me")
    public ResponseEntity<ApiResponse<EmployeeProfile>> updateMyProfile(
            @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.upsertMine(body), "Profile saved"));
    }

    @GetMapping("/{userId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getProfile(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getProfile(userId)));
    }

    @PutMapping("/{userId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeProfile>> updateProfile(
            @PathVariable UUID userId, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.upsertFor(userId, body), "Profile saved"));
    }
}
