package com.katasticho.erp.common.module;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.FeatureFlagService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ModuleAccessService {

    private final FeatureFlagService featureFlagService;

    public boolean isEnabled(UUID orgId, String moduleCode) {
        if (orgId == null) {
            return false;
        }
        return featureFlagService.isEnabled(orgId, moduleCode);
    }

    public void requireEnabled(String moduleCode) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED", HttpStatus.FORBIDDEN);
        }
        requireEnabled(orgId, moduleCode);
    }

    public void requireEnabled(UUID orgId, String moduleCode) {
        if (!isEnabled(orgId, moduleCode)) {
            throw new BusinessException(
                    "Module is not enabled for this organisation: " + moduleCode,
                    "MODULE_NOT_ENABLED",
                    HttpStatus.FORBIDDEN
            );
        }
    }
}
