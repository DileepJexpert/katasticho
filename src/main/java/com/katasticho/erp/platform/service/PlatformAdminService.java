package com.katasticho.erp.platform.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.platform.dto.PlatformApprovalRequest;
import com.katasticho.erp.platform.dto.PlatformOrgResponse;
import com.katasticho.erp.platform.dto.PlatformPasswordResetRequest;
import com.katasticho.erp.platform.dto.PlatformUserResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PlatformAdminService {

    private final OrganisationRepository organisationRepository;
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    public List<PlatformOrgResponse> listOrganisations(String status, String query) {
        String normalizedStatus = isBlank(status) ? null : status.trim().toUpperCase();
        String normalizedQuery = isBlank(query) ? null : query.trim();
        return organisationRepository.searchForPlatformAdmin(normalizedStatus, normalizedQuery)
                .stream()
                .map(PlatformOrgResponse::from)
                .toList();
    }

    public List<PlatformUserResponse> listUsers(UUID orgId) {
        return userRepository.findByOrgIdAndIsDeletedFalse(orgId)
                .stream()
                .map(PlatformUserResponse::from)
                .toList();
    }

    @Transactional
    public PlatformOrgResponse approveOrg(UUID orgId, PlatformApprovalRequest request) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        String oldStatus = org.getApprovalStatus();
        org.setApprovalStatus("APPROVED");
        org.setApprovalNote(request != null ? request.note() : null);
        org.setApprovedAt(Instant.now());
        org.setApprovedBy(TenantContext.getCurrentUserId());
        org = organisationRepository.save(org);

        auditService.logSync(org.getId(), TenantContext.getCurrentUserId(), "ORGANISATION", org.getId(),
                "APPROVE", "{\"approvalStatus\":\"" + oldStatus + "\"}",
                "{\"approvalStatus\":\"APPROVED\"}");
        return PlatformOrgResponse.from(org);
    }

    @Transactional
    public PlatformOrgResponse rejectOrg(UUID orgId, PlatformApprovalRequest request) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        String oldStatus = org.getApprovalStatus();
        org.setApprovalStatus("REJECTED");
        org.setApprovalNote(request != null ? request.note() : null);
        org.setActive(false);
        org = organisationRepository.save(org);

        auditService.logSync(org.getId(), TenantContext.getCurrentUserId(), "ORGANISATION", org.getId(),
                "REJECT", "{\"approvalStatus\":\"" + oldStatus + "\"}",
                "{\"approvalStatus\":\"REJECTED\"}");
        return PlatformOrgResponse.from(org);
    }

    @Transactional
    public PlatformUserResponse resetUserPassword(UUID userId, PlatformPasswordResetRequest request) {
        AppUser user = userRepository.findById(userId)
                .filter(u -> !u.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("User", userId));
        if ("PLATFORM_ADMIN".equals(user.getRole())) {
            throw new BusinessException("Platform admin passwords cannot be reset from this screen",
                    "PLATFORM_ADMIN_PROTECTED", HttpStatus.FORBIDDEN);
        }

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        user.resetFailedLogins();
        user = userRepository.save(user);

        auditService.logSync(user.getOrgId(), TenantContext.getCurrentUserId(), "APP_USER", user.getId(),
                "PASSWORD_RESET", null,
                "{\"method\":\"platform_admin\",\"reason\":\"" + safeJson(request.reason()) + "\"}");
        return PlatformUserResponse.from(user);
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private String safeJson(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
