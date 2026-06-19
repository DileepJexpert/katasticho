package com.katasticho.erp.portal.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.service.PortalAuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Admin management of portal accounts: invite a contact, list, resend the
 * invite, suspend/reactivate, delete. Authenticated by the normal app JWT
 * (OWNER/ADMIN). Note the {@code /portal-users} path (not {@code /portal/}) so
 * the portal filter never intercepts it.
 */
@RestController
@RequestMapping("/api/v1/portal-users")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN')")
public class PortalUserAdminController {

    private final PortalAuthService service;

    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> invite(@RequestBody Map<String, Object> body) {
        UUID contactId = UUID.fromString(body.get("contactId").toString());
        String email = (String) body.get("email");
        String fullName = (String) body.get("fullName");
        return ResponseEntity.ok(ApiResponse.ok(service.invite(contactId, email, fullName),
                "Portal invite created"));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(service.list()));
    }

    @PostMapping("/{id}/resend-invite")
    public ResponseEntity<ApiResponse<Map<String, Object>>> resend(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.resendInvite(id), "Invite regenerated"));
    }

    @PostMapping("/{id}/suspend")
    public ResponseEntity<ApiResponse<PortalUser>> suspend(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.suspend(id), "Portal account suspended"));
    }

    @PostMapping("/{id}/reactivate")
    public ResponseEntity<ApiResponse<PortalUser>> reactivate(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.reactivate(id), "Portal account reactivated"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Portal account removed"));
    }
}
