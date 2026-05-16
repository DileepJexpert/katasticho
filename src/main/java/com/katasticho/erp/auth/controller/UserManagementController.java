package com.katasticho.erp.auth.controller;

import com.katasticho.erp.auth.dto.*;
import com.katasticho.erp.auth.service.UserManagementService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Org-scoped user management: list, invite, update role, activate/deactivate.
 * OWNER: full access.
 * ADMIN: can invite, update roles below ADMIN, and toggle active state.
 */
@RestController
@RequestMapping("/api/v1/org/users")
@RequiredArgsConstructor
public class UserManagementController {

    private final UserManagementService userManagementService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<OrgUserResponse>>> listUsers() {
        return ResponseEntity.ok(ApiResponse.ok(
                userManagementService.listUsers(TenantContext.getCurrentOrgId())));
    }

    @GetMapping("/invites")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<PendingInviteResponse>>> listPendingInvites() {
        return ResponseEntity.ok(ApiResponse.ok(
                userManagementService.listPendingInvites(TenantContext.getCurrentOrgId())));
    }

    @PostMapping("/invite")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<PendingInviteResponse>> invite(
            @Valid @RequestBody InviteRequest request) {
        PendingInviteResponse invite = userManagementService.sendInvite(
                TenantContext.getCurrentOrgId(),
                TenantContext.getCurrentUserId(),
                request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(invite));
    }

    @PutMapping("/{userId}/role")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<OrgUserResponse>> updateRole(
            @PathVariable UUID userId,
            @Valid @RequestBody UpdateUserRoleRequest request) {
        OrgUserResponse updated = userManagementService.updateRole(
                TenantContext.getCurrentOrgId(),
                userId,
                request.role(),
                TenantContext.getCurrentUserId(),
                TenantContext.getCurrentRole());
        return ResponseEntity.ok(ApiResponse.ok(updated, "Role updated"));
    }

    @PutMapping("/{userId}/deactivate")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<OrgUserResponse>> deactivateUser(@PathVariable UUID userId) {
        OrgUserResponse updated = userManagementService.setActive(
                TenantContext.getCurrentOrgId(),
                userId,
                false,
                TenantContext.getCurrentUserId());
        return ResponseEntity.ok(ApiResponse.ok(updated, "User deactivated"));
    }

    @PutMapping("/{userId}/reactivate")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<OrgUserResponse>> reactivateUser(@PathVariable UUID userId) {
        OrgUserResponse updated = userManagementService.setActive(
                TenantContext.getCurrentOrgId(),
                userId,
                true,
                TenantContext.getCurrentUserId());
        return ResponseEntity.ok(ApiResponse.ok(updated, "User reactivated"));
    }

    @PostMapping("/invites/{inviteId}/resend")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<PendingInviteResponse>> resendInvite(
            @PathVariable UUID inviteId) {
        PendingInviteResponse invite = userManagementService.resendInvite(
                TenantContext.getCurrentOrgId(),
                inviteId,
                TenantContext.getCurrentUserId());
        return ResponseEntity.ok(ApiResponse.ok(invite, "Invitation resent"));
    }

    @DeleteMapping("/invites/{inviteId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> cancelInvite(@PathVariable UUID inviteId) {
        userManagementService.cancelInvite(
                TenantContext.getCurrentOrgId(),
                inviteId,
                TenantContext.getCurrentUserId());
        return ResponseEntity.ok(ApiResponse.ok(null, "Invitation cancelled"));
    }
}
