package com.katasticho.erp.auth.controller;

import com.katasticho.erp.auth.dto.AuthResponse;
import com.katasticho.erp.auth.dto.OrgSummary;
import com.katasticho.erp.auth.dto.SwitchOrgRequest;
import com.katasticho.erp.auth.service.AuthService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final AuthService authService;

    @GetMapping("/me/organisations")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<List<OrgSummary>>> getMyOrganisations() {
        List<OrgSummary> orgs = authService.listMyOrgs(TenantContext.getCurrentUserId());
        return ResponseEntity.ok(ApiResponse.ok(orgs));
    }

    @PostMapping("/me/switch-org")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<AuthResponse>> switchOrg(@Valid @RequestBody SwitchOrgRequest request) {
        AuthResponse response = authService.switchOrg(request.targetOrgId(), TenantContext.getCurrentUserId());
        return ResponseEntity.ok(ApiResponse.ok(response, "Switched organisation"));
    }
}
