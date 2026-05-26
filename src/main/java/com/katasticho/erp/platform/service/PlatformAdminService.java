package com.katasticho.erp.platform.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.notification.EmailService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.platform.context.PlatformAdminContext;
import com.katasticho.erp.platform.dto.PlatformApprovalRequest;
import com.katasticho.erp.platform.dto.PlatformOrgResponse;
import com.katasticho.erp.platform.dto.PlatformPlanUpdateRequest;
import com.katasticho.erp.platform.dto.PlatformPasswordResetRequest;
import com.katasticho.erp.platform.dto.PlatformUserResponse;
import com.katasticho.erp.platform.entity.PlatformAdminAudit;
import com.katasticho.erp.platform.repository.PlatformAdminAuditRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PlatformAdminService {

    private final OrganisationRepository organisationRepository;
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;
    private final PlatformAdminAuditRepository platformAdminAuditRepository;
    private final EmailService emailService;

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
        org.setApprovedBy(PlatformAdminContext.getAdminId());
        org = organisationRepository.save(org);

        auditService.logSync(org.getId(), null, "ORGANISATION", org.getId(),
                "APPROVE", "{\"approvalStatus\":\"" + oldStatus + "\"}",
                "{\"approvalStatus\":\"APPROVED\"}");

        logPlatformAdminAudit("APPROVE_ORG", "ORGANISATION", org.getId(), org.getName(),
                request != null ? request.note() : null, null);

        // Notify the org owner(s) by email
        notifyOrgOwners(org, user -> {
            if (user.getEmail() != null) {
                emailService.sendAccountApproved(user.getEmail(), user.getFullName());
            }
        });

        return PlatformOrgResponse.from(org);
    }

    @Transactional
    public PlatformOrgResponse rejectOrg(UUID orgId, PlatformApprovalRequest request) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        String oldStatus = org.getApprovalStatus();
        String rejectionReason = request != null ? request.note() : null;
        org.setApprovalStatus("REJECTED");
        org.setApprovalNote(rejectionReason);
        org.setRejectionReason(rejectionReason);
        org.setActive(false);
        org = organisationRepository.save(org);

        auditService.logSync(org.getId(), null, "ORGANISATION", org.getId(),
                "REJECT", "{\"approvalStatus\":\"" + oldStatus + "\"}",
                "{\"approvalStatus\":\"REJECTED\"}");

        logPlatformAdminAudit("REJECT_ORG", "ORGANISATION", org.getId(), org.getName(),
                rejectionReason, null);

        // Notify the org owner(s) by email
        String finalRejectionReason = rejectionReason;
        Organisation finalOrg = org;
        notifyOrgOwners(finalOrg, user -> {
            if (user.getEmail() != null) {
                emailService.sendAccountRejected(user.getEmail(), user.getFullName(), finalRejectionReason);
            }
        });

        return PlatformOrgResponse.from(org);
    }

    @Transactional
    public PlatformOrgResponse suspendOrg(UUID orgId, String reason, UUID adminId) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        String oldStatus = org.getApprovalStatus();
        org.setApprovalStatus("SUSPENDED");
        org.setSuspendedReason(reason);
        org.setActive(false);
        org = organisationRepository.save(org);

        // Increment tokenVersion for all users in this org to invalidate their sessions
        List<AppUser> orgUsers = userRepository.findByOrgIdAndIsDeletedFalse(orgId);
        for (AppUser user : orgUsers) {
            user.incrementTokenVersion();
            userRepository.save(user);
        }

        auditService.logSync(org.getId(), null, "ORGANISATION", org.getId(),
                "SUSPEND", "{\"approvalStatus\":\"" + oldStatus + "\"}",
                "{\"approvalStatus\":\"SUSPENDED\",\"reason\":\"" + safeJson(reason) + "\"}");

        logPlatformAdminAudit("SUSPEND_ORG", "ORGANISATION", org.getId(), org.getName(), reason, null);

        // Notify owners by email
        Organisation finalOrg = org;
        notifyOrgOwners(finalOrg, user -> {
            if (user.getEmail() != null) {
                emailService.sendAccountSuspended(user.getEmail(), user.getFullName(), reason);
            }
        });

        return PlatformOrgResponse.from(org);
    }

    @Transactional
    public PlatformOrgResponse reactivateOrg(UUID orgId, UUID adminId) {
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        String oldStatus = org.getApprovalStatus();
        org.setApprovalStatus("APPROVED");
        org.setSuspendedReason(null);
        org.setActive(true);
        org = organisationRepository.save(org);

        auditService.logSync(org.getId(), null, "ORGANISATION", org.getId(),
                "REACTIVATE", "{\"approvalStatus\":\"" + oldStatus + "\"}",
                "{\"approvalStatus\":\"APPROVED\"}");

        logPlatformAdminAudit("REACTIVATE_ORG", "ORGANISATION", org.getId(), org.getName(), null, null);

        return PlatformOrgResponse.from(org);
    }

    @Transactional
    public PlatformOrgResponse updateOrgPlan(UUID orgId, PlatformPlanUpdateRequest request) {
        if (request == null || isBlank(request.planTier())) {
            throw new BusinessException("Plan tier is required",
                    "PLAN_TIER_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        String oldPlan = org.getPlanTier();
        String newPlan = request.planTier().trim().toUpperCase();
        org.setPlanTier(newPlan);
        org = organisationRepository.save(org);

        auditService.logSync(org.getId(), null, "ORGANISATION", org.getId(),
                "UPDATE_PLAN_TIER",
                "{\"planTier\":\"" + safeJson(oldPlan) + "\"}",
                "{\"planTier\":\"" + safeJson(newPlan) + "\"}");

        logPlatformAdminAudit("UPDATE_ORG_PLAN", "ORGANISATION", org.getId(), org.getName(),
                request.note(), "{\"oldPlan\":\"" + safeJson(oldPlan) +
                        "\",\"newPlan\":\"" + safeJson(newPlan) + "\"}");

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
        user.incrementTokenVersion();
        user = userRepository.save(user);

        auditService.logSync(user.getOrgId(), null, "APP_USER", user.getId(),
                "PASSWORD_RESET", null,
                "{\"method\":\"platform_admin\",\"reason\":\"" + safeJson(request.reason()) + "\"}");

        logPlatformAdminAudit("RESET_USER_PASSWORD", "APP_USER", user.getId(), user.getFullName(),
                request.reason(), null);

        // Notify user by email
        if (user.getEmail() != null) {
            emailService.sendAdminPasswordReset(user.getEmail(), user.getFullName(), request.newPassword());
        }

        return PlatformUserResponse.from(user);
    }

    // ---- Dashboard Stats ----

    public DashboardStats getDashboardStats() {
        long totalOrgs = organisationRepository.count();
        long pendingApproval = organisationRepository.countByApprovalStatus("PENDING");
        long activeOrgs = organisationRepository.countByApprovalStatus("APPROVED");
        long suspendedOrgs = organisationRepository.countByApprovalStatus("SUSPENDED");
        long totalUsers = userRepository.count();
        long newSignupsToday = organisationRepository.countByCreatedAtAfter(
                java.time.LocalDate.now().atStartOfDay().toInstant(java.time.ZoneOffset.UTC));
        long newSignupsThisWeek = organisationRepository.countByCreatedAtAfter(
                java.time.LocalDate.now().minusWeeks(1).atStartOfDay().toInstant(java.time.ZoneOffset.UTC));

        return new DashboardStats(totalOrgs, pendingApproval, activeOrgs, suspendedOrgs,
                totalUsers, newSignupsToday, newSignupsThisWeek);
    }

    public record DashboardStats(
            long totalOrgs,
            long pendingApproval,
            long activeOrgs,
            long suspendedOrgs,
            long totalUsers,
            long newSignupsToday,
            long newSignupsThisWeek
    ) {}

    // ---- Audit Log ----

    public org.springframework.data.domain.Page<PlatformAdminAudit> getAuditLog(
            org.springframework.data.domain.Pageable pageable) {
        return platformAdminAuditRepository.findAll(pageable);
    }

    // ---- Helpers ----

    private void logPlatformAdminAudit(String actionType, String targetType, UUID targetId,
                                        String targetName, String reason, String ipAddress) {
        UUID adminId = PlatformAdminContext.getAdminId();
        if (adminId == null) {
            return; // Not in a platform-admin context (e.g., bootstrap)
        }
        PlatformAdminAudit audit = PlatformAdminAudit.builder()
                .platformAdminId(adminId)
                .actionType(actionType)
                .targetType(targetType)
                .targetId(targetId)
                .targetName(targetName)
                .reason(reason)
                .ipAddress(ipAddress)
                .build();
        platformAdminAuditRepository.save(audit);
    }

    private void notifyOrgOwners(Organisation org, java.util.function.Consumer<AppUser> notifier) {
        try {
            List<AppUser> owners = userRepository.findByOrgIdAndRoleAndIsDeletedFalse(org.getId(), "OWNER");
            owners.forEach(notifier);
        } catch (Exception e) {
            log.warn("Failed to send notification for org {}: {}", org.getId(), e.getMessage());
        }
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
