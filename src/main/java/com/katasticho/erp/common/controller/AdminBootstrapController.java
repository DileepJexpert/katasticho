package com.katasticho.erp.common.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.BootstrapAllResult;
import com.katasticho.erp.common.service.BootstrapResult;
import com.katasticho.erp.common.service.OrgBootstrapService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminBootstrapController {

    private final OrgBootstrapService bootstrapService;
    private final OrganisationRepository organisationRepository;

    @PostMapping("/orgs/{orgId}/bootstrap")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<BootstrapResult> bootstrapOrg(@PathVariable UUID orgId) {
        UUID callerOrgId = TenantContext.getCurrentOrgId();
        if (!callerOrgId.equals(orgId)) {
            throw new BusinessException("Cannot bootstrap another organisation",
                    "BOOTSTRAP_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        return ResponseEntity.ok(bootstrapService.bootstrap(org));
    }

    @PostMapping("/orgs/bootstrap-all")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<BootstrapAllResult> bootstrapAll() {
        return ResponseEntity.ok(bootstrapService.bootstrapAll());
    }
}
