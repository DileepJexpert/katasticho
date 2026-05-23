package com.katasticho.erp.platform.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.platform.dto.PlatformApprovalRequest;
import com.katasticho.erp.platform.dto.PlatformOrgResponse;
import com.katasticho.erp.platform.dto.PlatformPasswordResetRequest;
import com.katasticho.erp.platform.dto.PlatformUserResponse;
import com.katasticho.erp.platform.service.PlatformAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/platform-admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('PLATFORM_ADMIN')")
public class PlatformAdminController {

    private final PlatformAdminService platformAdminService;

    @GetMapping("/organisations")
    public ResponseEntity<ApiResponse<List<PlatformOrgResponse>>> organisations(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String query
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.listOrganisations(status, query)));
    }

    @GetMapping("/organisations/{orgId}/users")
    public ResponseEntity<ApiResponse<List<PlatformUserResponse>>> users(@PathVariable UUID orgId) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.listUsers(orgId)));
    }

    @PostMapping("/organisations/{orgId}/approve")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> approve(
            @PathVariable UUID orgId,
            @RequestBody(required = false) PlatformApprovalRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.approveOrg(orgId, request), "Organisation approved"));
    }

    @PostMapping("/organisations/{orgId}/reject")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> reject(
            @PathVariable UUID orgId,
            @RequestBody(required = false) PlatformApprovalRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.rejectOrg(orgId, request), "Organisation rejected"));
    }

    @PostMapping("/users/{userId}/reset-password")
    public ResponseEntity<ApiResponse<PlatformUserResponse>> resetPassword(
            @PathVariable UUID userId,
            @Valid @RequestBody PlatformPasswordResetRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.ok(
                platformAdminService.resetUserPassword(userId, request),
                "Password reset"));
    }
}
