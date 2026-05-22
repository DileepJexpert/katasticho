package com.katasticho.erp.ca.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.ca.dto.*;
import com.katasticho.erp.ca.entity.CaClientLink;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.entity.DelegatedAccessToken;
import com.katasticho.erp.ca.repository.CaClientLinkRepository;
import com.katasticho.erp.ca.repository.DelegatedAccessTokenRepository;
import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CaClientLinkService {

    private final CaAccessService accessService;
    private final CaClientLinkRepository linkRepository;
    private final OrganisationRepository organisationRepository;
    private final AppUserRepository appUserRepository;
    private final DelegatedAccessTokenRepository delegatedTokenRepository;
    private final JwtService jwtService;

    @Value("${app.web.base-url:https://app.katixo.com}")
    private String webBaseUrl;

    @Transactional
    public CaClientSummaryResponse inviteOrLink(InviteClientRequest request, CaDashboardService dashboardService) {
        accessService.requirePartner();
        CaFirm firm = accessService.currentFirm();
        if (request.clientOrgId() == null) {
            throw new BusinessException("Existing client org id is required for the current MVP link flow",
                    "CA_CLIENT_ORG_REQUIRED");
        }
        Organisation client = organisationRepository.findById(request.clientOrgId())
                .filter(o -> !Boolean.TRUE.equals(o.getIsDeleted()))
                .orElseThrow(() -> BusinessException.notFound("Organisation", request.clientOrgId()));
        if (linkRepository.countByClientOrgIdAndStatus(client.getId(), "ACTIVE") >= 3) {
            throw new BusinessException("Client already has the maximum active external CA links",
                    "CA_CLIENT_LINK_LIMIT", HttpStatus.CONFLICT);
        }
        CaClientLink link = CaClientLink.builder()
                .caFirmId(firm.getId())
                .clientOrgId(client.getId())
                .assignedUserId(request.assignedUserId())
                .engagementType(normalize(request.engagementType(), "FULL_SERVICE"))
                .engagementStart(LocalDate.now())
                .status("ACTIVE")
                .notes(request.notes())
                .createdBy(TenantContext.getCurrentUserId())
                .build();
        linkRepository.save(link);
        return dashboardService.clients(null, null, null).stream()
                .filter(c -> c.linkId().equals(link.getId()))
                .findFirst()
                .orElseThrow();
    }

    @Transactional
    public void assign(UUID linkId, AssignClientRequest request) {
        accessService.requirePartner();
        CaFirm firm = accessService.currentFirm();
        CaClientLink link = loadLink(firm, linkId);
        link.setAssignedUserId(request.assignedUserId());
        link.setBackupUserId(request.backupUserId());
        linkRepository.save(link);
    }

    @Transactional
    public void end(UUID linkId) {
        accessService.requirePartner();
        CaFirm firm = accessService.currentFirm();
        CaClientLink link = loadLink(firm, linkId);
        link.setStatus("ENDED");
        link.setEngagementEnd(LocalDate.now());
        linkRepository.save(link);
    }

    @Transactional
    public DelegatedAccessResponse accessToken(UUID linkId) {
        CaFirm firm = accessService.currentFirm();
        CaClientLink link = linkRepository.findByIdAndCaFirmIdAndStatus(linkId, firm.getId(), "ACTIVE")
                .orElseThrow(() -> new BusinessException("Active client engagement not found",
                        "CA_CLIENT_LINK_NOT_FOUND", HttpStatus.NOT_FOUND));
        UUID staffScope = accessService.staffScopeUserId();
        if (staffScope != null && !staffScope.equals(link.getAssignedUserId()) && !staffScope.equals(link.getBackupUserId())) {
            throw new BusinessException("Client is not assigned to this CA staff user",
                    "CA_CLIENT_NOT_ASSIGNED", HttpStatus.FORBIDDEN);
        }
        UUID caUserId = TenantContext.getCurrentUserId();
        Instant expiresAt = Instant.now().plusSeconds(15 * 60L);
        String token = jwtService.generateAccessToken(caUserId, link.getClientOrgId(), "CA_EXTERNAL", 15);
        delegatedTokenRepository.save(DelegatedAccessToken.builder()
                .caUserId(caUserId)
                .clientOrgId(link.getClientOrgId())
                .tokenHash(jwtService.hashToken(token))
                .expiresAt(expiresAt)
                .build());
        return new DelegatedAccessResponse(
                token,
                webBaseUrl + "/delegated-access?token=" + token + "&orgId=" + link.getClientOrgId(),
                expiresAt
        );
    }

    @Transactional(readOnly = true)
    public List<CaStaffResponse> staff() {
        CaFirm firm = accessService.currentFirm();
        List<AppUser> users = appUserRepository.findByCaFirmIdAndIsDeletedFalseOrderByRoleAscFullNameAsc(firm.getId());
        return users.stream()
                .map(u -> new CaStaffResponse(
                        u.getId(),
                        u.getFullName(),
                        u.getEmail(),
                        u.getPhone(),
                        u.getRole(),
                        0,
                        u.isActive()
                ))
                .toList();
    }

    private CaClientLink loadLink(CaFirm firm, UUID linkId) {
        return linkRepository.findByIdAndCaFirmId(linkId, firm.getId())
                .orElseThrow(() -> new BusinessException("CA client link not found",
                        "CA_CLIENT_LINK_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private String normalize(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim().toUpperCase();
    }
}
