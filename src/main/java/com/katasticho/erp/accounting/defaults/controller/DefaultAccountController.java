package com.katasticho.erp.accounting.defaults.controller;

import com.katasticho.erp.accounting.defaults.dto.DefaultAccountResponse;
import com.katasticho.erp.accounting.defaults.dto.UpdateDefaultAccountsRequest;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Settings → Accounting → Default Accounts.
 *
 * GET returns one row per {@link com.katasticho.erp.accounting.defaults.DefaultAccountPurpose}
 * with the currently bound CoA account and an {@code overridden} flag.
 *
 * PUT accepts a bulk list of (purpose, accountId) pairs and upserts them.
 * Owners and Accountants only — these mappings drive every journal post.
 */
@RestController
@RequestMapping("/api/v1/settings/default-accounts")
@RequiredArgsConstructor
public class DefaultAccountController {

    private final DefaultAccountService defaultAccountService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<DefaultAccountResponse>>> list() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(defaultAccountService.listForOrg(orgId)));
    }

    @PutMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<DefaultAccountResponse>>> update(
            @Valid @RequestBody UpdateDefaultAccountsRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        for (UpdateDefaultAccountsRequest.Mapping m : request.mappings()) {
            defaultAccountService.update(orgId, m.purpose(), m.accountId());
        }
        return ResponseEntity.ok(ApiResponse.ok(
                defaultAccountService.listForOrg(orgId),
                "Default accounts updated"));
    }
}
