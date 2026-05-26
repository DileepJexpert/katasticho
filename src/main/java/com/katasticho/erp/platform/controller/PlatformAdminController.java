package com.katasticho.erp.platform.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.platform.context.PlatformAdminContext;
import com.katasticho.erp.platform.dto.PlatformApprovalRequest;
import com.katasticho.erp.platform.dto.PlatformOrgResponse;
import com.katasticho.erp.platform.dto.PlatformPlanUpdateRequest;
import com.katasticho.erp.platform.dto.PlatformPasswordResetRequest;
import com.katasticho.erp.platform.dto.PlatformUserResponse;
import com.katasticho.erp.platform.entity.PlatformAdminAudit;
import com.katasticho.erp.platform.service.PlatformAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/platform-admin/v1")
@RequiredArgsConstructor
@PreAuthorize("hasRole('PLATFORM_ADMIN')")
public class PlatformAdminController {

    private final PlatformAdminService platformAdminService;

    @GetMapping("/orgs")
    public ResponseEntity<ApiResponse<List<PlatformOrgResponse>>> organisations(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String query
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.listOrganisations(status, query)));
    }

    @GetMapping("/orgs/{orgId}/users")
    public ResponseEntity<ApiResponse<List<PlatformUserResponse>>> users(@PathVariable UUID orgId) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.listUsers(orgId)));
    }

    @PostMapping("/orgs/{orgId}/approve")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> approve(
            @PathVariable UUID orgId,
            @RequestBody(required = false) PlatformApprovalRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.approveOrg(orgId, request), "Organisation approved"));
    }

    @PostMapping("/orgs/{orgId}/reject")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> reject(
            @PathVariable UUID orgId,
            @RequestBody(required = false) PlatformApprovalRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.rejectOrg(orgId, request), "Organisation rejected"));
    }

    @PostMapping("/orgs/{orgId}/suspend")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> suspend(
            @PathVariable UUID orgId,
            @RequestBody SuspendRequest request
    ) {
        UUID adminId = PlatformAdminContext.getAdminId();
        return ResponseEntity.ok(ApiResponse.ok(
                platformAdminService.suspendOrg(orgId, request.reason(), adminId),
                "Organisation suspended"));
    }

    @PostMapping("/orgs/{orgId}/reactivate")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> reactivate(@PathVariable UUID orgId) {
        UUID adminId = PlatformAdminContext.getAdminId();
        return ResponseEntity.ok(ApiResponse.ok(
                platformAdminService.reactivateOrg(orgId, adminId),
                "Organisation reactivated"));
    }

    @PutMapping("/orgs/{orgId}/plan")
    public ResponseEntity<ApiResponse<PlatformOrgResponse>> updatePlan(
            @PathVariable UUID orgId,
            @RequestBody PlatformPlanUpdateRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.ok(
                platformAdminService.updateOrgPlan(orgId, request),
                "Organisation plan updated"));
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

    @GetMapping("/audit-log")
    public ResponseEntity<ApiResponse<Page<PlatformAdminAudit>>> auditLog(
            @PageableDefault(size = 50) Pageable pageable
    ) {
        return ResponseEntity.ok(ApiResponse.ok(platformAdminService.getAuditLog(pageable)));
    }

    public record SuspendRequest(String reason) {}
}
