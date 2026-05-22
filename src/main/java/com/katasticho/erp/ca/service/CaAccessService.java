package com.katasticho.erp.ca.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.repository.CaFirmRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CaAccessService {

    private final CaFirmRepository caFirmRepository;
    private final AppUserRepository appUserRepository;

    public CaFirm currentFirm() {
        requireCaRole();
        UUID orgId = TenantContext.getCurrentOrgId();
        AppUser user = currentUser();
        if (user.getCaFirmId() != null) {
            return caFirmRepository.findById(user.getCaFirmId())
                    .filter(CaFirm::isActive)
                    .orElseThrow(() -> new BusinessException("CA firm is inactive", "CA_FIRM_INACTIVE", HttpStatus.FORBIDDEN));
        }
        return caFirmRepository.findByOrgIdAndActiveTrue(orgId)
                .orElseThrow(() -> new BusinessException(
                        "Current organisation is not configured as a CA firm",
                        "CA_FIRM_NOT_CONFIGURED",
                        HttpStatus.FORBIDDEN
                ));
    }

    public AppUser currentUser() {
        UUID userId = TenantContext.getCurrentUserId();
        return appUserRepository.findById(userId)
                .filter(u -> !u.isDeleted() && u.isActive())
                .orElseThrow(() -> new BusinessException("User not found", "USER_NOT_FOUND", HttpStatus.UNAUTHORIZED));
    }

    public String currentRole() {
        String role = TenantContext.getCurrentRole();
        return role == null ? "" : role.toUpperCase();
    }

    public boolean isPartner() {
        String role = currentRole();
        return "CA_PARTNER".equals(role) || "OWNER".equals(role) || "ADMIN".equals(role);
    }

    public void requirePartner() {
        if (!isPartner()) {
            throw new BusinessException("Only CA partners can perform this action", "CA_PARTNER_REQUIRED", HttpStatus.FORBIDDEN);
        }
    }

    public UUID staffScopeUserId() {
        return isPartner() ? null : TenantContext.getCurrentUserId();
    }

    private void requireCaRole() {
        String role = currentRole();
        if (!"CA_PARTNER".equals(role) && !"CA_STAFF".equals(role) && !"OWNER".equals(role) && !"ADMIN".equals(role)) {
            throw new BusinessException("CA Console requires a CA role or CA firm owner/admin", "CA_ROLE_REQUIRED", HttpStatus.FORBIDDEN);
        }
    }
}
