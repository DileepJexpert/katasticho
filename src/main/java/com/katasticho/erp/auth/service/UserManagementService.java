package com.katasticho.erp.auth.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.auth.dto.InviteRequest;
import com.katasticho.erp.auth.dto.OrgUserResponse;
import com.katasticho.erp.auth.dto.PendingInviteResponse;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.entity.UserInvitation;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.repository.UserInvitationRepository;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserManagementService {

    private final AppUserRepository userRepository;
    private final UserInvitationRepository invitationRepository;
    private final AuthService authService;
    private final AuditService auditService;

    public List<OrgUserResponse> listUsers(UUID orgId) {
        return userRepository.findByOrgIdAndIsDeletedFalseOrderByRoleAscFullNameAsc(orgId)
                .stream()
                .map(OrgUserResponse::from)
                .toList();
    }

    public List<PendingInviteResponse> listPendingInvites(UUID orgId) {
        return invitationRepository.findByOrgIdAndAcceptedAtIsNullOrderByCreatedAtDesc(orgId)
                .stream()
                .map(PendingInviteResponse::from)
                .toList();
    }

    @Transactional
    public OrgUserResponse updateRole(UUID orgId, UUID targetUserId, String newRole, UUID requestingUserId, String requestingRole) {
        AppUser target = userRepository.findByIdAndOrgIdAndIsDeletedFalse(targetUserId, orgId)
                .orElseThrow(() -> BusinessException.notFound("User", targetUserId));

        if ("OWNER".equals(target.getRole())) {
            throw new BusinessException("Cannot change the role of the organisation owner",
                    "USER_MGMT_OWNER_PROTECTED", HttpStatus.FORBIDDEN);
        }

        // ADMIN can only manage roles below ADMIN (cannot elevate to ADMIN or above)
        if ("ADMIN".equals(requestingRole) && "ADMIN".equals(newRole)) {
            throw new BusinessException("ADMIN cannot assign the ADMIN role",
                    "USER_MGMT_INSUFFICIENT_PRIVILEGE", HttpStatus.FORBIDDEN);
        }

        String oldRole = target.getRole();
        target.setRole(newRole);
        userRepository.save(target);

        auditService.logSync(orgId, requestingUserId, "APP_USER", targetUserId,
                "UPDATE", "{\"role\":\"" + oldRole + "\"}", "{\"role\":\"" + newRole + "\"}");

        return OrgUserResponse.from(target);
    }

    @Transactional
    public OrgUserResponse setActive(UUID orgId, UUID targetUserId, boolean active, UUID requestingUserId) {
        AppUser target = userRepository.findByIdAndOrgIdAndIsDeletedFalse(targetUserId, orgId)
                .orElseThrow(() -> BusinessException.notFound("User", targetUserId));

        if ("OWNER".equals(target.getRole())) {
            throw new BusinessException("Cannot deactivate the organisation owner",
                    "USER_MGMT_OWNER_PROTECTED", HttpStatus.FORBIDDEN);
        }

        if (targetUserId.equals(requestingUserId)) {
            throw new BusinessException("Cannot deactivate your own account",
                    "USER_MGMT_SELF_DEACTIVATE", HttpStatus.FORBIDDEN);
        }

        target.setActive(active);
        userRepository.save(target);

        auditService.logSync(orgId, requestingUserId, "APP_USER", targetUserId,
                active ? "REACTIVATE" : "DEACTIVATE", null, null);

        return OrgUserResponse.from(target);
    }

    @Transactional
    public PendingInviteResponse resendInvite(UUID orgId, UUID inviteId, UUID requestingUserId) {
        UserInvitation invite = invitationRepository.findById(inviteId)
                .orElseThrow(() -> BusinessException.notFound("Invitation", inviteId));

        if (!invite.getOrgId().equals(orgId)) {
            throw new BusinessException("Invitation not found", "USER_MGMT_INVITE_NOT_FOUND", HttpStatus.NOT_FOUND);
        }

        if (invite.getAcceptedAt() != null) {
            throw new BusinessException("Invitation already accepted", "USER_MGMT_INVITE_ACCEPTED", HttpStatus.CONFLICT);
        }

        // Extend expiry by 72h from now
        invite.setExpiresAt(Instant.now().plus(72, ChronoUnit.HOURS));
        invite = invitationRepository.save(invite);

        auditService.logSync(orgId, requestingUserId, "USER_INVITATION", inviteId,
                "RESEND", null, null);

        return PendingInviteResponse.from(invite);
    }

    @Transactional
    public void cancelInvite(UUID orgId, UUID inviteId, UUID requestingUserId) {
        UserInvitation invite = invitationRepository.findById(inviteId)
                .orElseThrow(() -> BusinessException.notFound("Invitation", inviteId));

        if (!invite.getOrgId().equals(orgId)) {
            throw new BusinessException("Invitation not found", "USER_MGMT_INVITE_NOT_FOUND", HttpStatus.NOT_FOUND);
        }

        if (invite.getAcceptedAt() != null) {
            throw new BusinessException("Invitation already accepted", "USER_MGMT_INVITE_ACCEPTED", HttpStatus.CONFLICT);
        }

        invitationRepository.delete(invite);

        auditService.logSync(orgId, requestingUserId, "USER_INVITATION", inviteId,
                "CANCEL", null, null);
    }

    @Transactional
    public PendingInviteResponse sendInvite(UUID orgId, UUID requestingUserId, InviteRequest request) {
        UserInvitation invitation = authService.invite(request, orgId, requestingUserId);
        return PendingInviteResponse.from(invitation);
    }
}
