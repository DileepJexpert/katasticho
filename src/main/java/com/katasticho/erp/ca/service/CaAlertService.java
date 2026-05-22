package com.katasticho.erp.ca.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ca.dto.AssignAlertRequest;
import com.katasticho.erp.ca.dto.CaAlertResponse;
import com.katasticho.erp.ca.entity.CaAlertDismissal;
import com.katasticho.erp.ca.entity.CaClientLink;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.repository.CaAlertDismissalRepository;
import com.katasticho.erp.ca.repository.CaClientLinkRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CaAlertService {

    private final CaAccessService accessService;
    private final CaClientLinkRepository linkRepository;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final CaAlertDismissalRepository dismissalRepository;
    private final OrganisationRepository organisationRepository;

    @Transactional(readOnly = true)
    public List<CaAlertResponse> list(String severity, UUID clientOrgId, String suggestionType, String status) {
        CaFirm firm = accessService.currentFirm();
        Set<UUID> clientOrgIds = visibleClientOrgIds(firm);
        if (clientOrgId != null) {
            if (!clientOrgIds.contains(clientOrgId)) {
                throw new BusinessException("Client is not assigned to this CA user", "CA_CLIENT_NOT_ASSIGNED", HttpStatus.FORBIDDEN);
            }
            clientOrgIds = Set.of(clientOrgId);
        }
        if (clientOrgIds.isEmpty()) {
            return List.of();
        }
        List<AiSuggestion> suggestions = blank(status)
                ? aiSuggestionRepository.findByOrgIdInOrderByPriorityScoreDescCreatedAtDesc(clientOrgIds)
                : aiSuggestionRepository.findByOrgIdInAndStatusOrderByPriorityScoreDescCreatedAtDesc(clientOrgIds, status.trim().toUpperCase());
        if (!blank(severity)) {
            String p = severity.trim().toUpperCase();
            suggestions = suggestions.stream().filter(s -> p.equals(s.getPriority())).toList();
        }
        if (!blank(suggestionType)) {
            String t = suggestionType.trim().toUpperCase();
            suggestions = suggestions.stream().filter(s -> t.equals(s.getSuggestionType())).toList();
        }
        Map<UUID, Organisation> orgs = organisationRepository.findAllById(clientOrgIds)
                .stream().collect(Collectors.toMap(Organisation::getId, Function.identity()));
        Map<UUID, CaAlertDismissal> dismissals = dismissalRepository
                .findByCaFirmIdAndSuggestionIdIn(firm.getId(), suggestions.stream().map(AiSuggestion::getId).toList())
                .stream()
                .collect(Collectors.toMap(CaAlertDismissal::getSuggestionId, Function.identity()));
        return suggestions.stream()
                .filter(s -> !dismissals.containsKey(s.getId()) || dismissals.get(s.getId()).getDismissedAt() == null)
                .map(s -> toResponse(s, orgs.get(s.getOrgId()), dismissals.get(s.getId())))
                .toList();
    }

    @Transactional
    public void dismiss(UUID suggestionId) {
        CaFirm firm = accessService.currentFirm();
        assertVisibleSuggestion(suggestionId, firm);
        CaAlertDismissal dismissal = dismissalRepository.findByCaFirmIdAndSuggestionId(firm.getId(), suggestionId)
                .orElseGet(() -> CaAlertDismissal.builder()
                        .caFirmId(firm.getId())
                        .suggestionId(suggestionId)
                        .dismissedBy(TenantContext.getCurrentUserId())
                        .build());
        dismissal.setDismissedAt(Instant.now());
        dismissal.setDismissedBy(TenantContext.getCurrentUserId());
        dismissalRepository.save(dismissal);
    }

    @Transactional
    public void assign(UUID suggestionId, AssignAlertRequest request) {
        accessService.requirePartner();
        CaFirm firm = accessService.currentFirm();
        assertVisibleSuggestion(suggestionId, firm);
        CaAlertDismissal row = dismissalRepository.findByCaFirmIdAndSuggestionId(firm.getId(), suggestionId)
                .orElseGet(() -> CaAlertDismissal.builder()
                        .caFirmId(firm.getId())
                        .suggestionId(suggestionId)
                        .dismissedBy(TenantContext.getCurrentUserId())
                        .build());
        row.setAssignedUserId(request.assignedUserId());
        dismissalRepository.save(row);
    }

    private void assertVisibleSuggestion(UUID suggestionId, CaFirm firm) {
        AiSuggestion suggestion = aiSuggestionRepository.findById(suggestionId)
                .orElseThrow(() -> new BusinessException("AI alert not found", "CA_ALERT_NOT_FOUND", HttpStatus.NOT_FOUND));
        if (!visibleClientOrgIds(firm).contains(suggestion.getOrgId())) {
            throw new BusinessException("AI alert is not visible to this CA user", "CA_ALERT_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
    }

    private Set<UUID> visibleClientOrgIds(CaFirm firm) {
        return linkRepository.findVisibleActive(firm.getId(), accessService.staffScopeUserId())
                .stream().map(CaClientLink::getClientOrgId).collect(Collectors.toSet());
    }

    private CaAlertResponse toResponse(AiSuggestion s, Organisation org, CaAlertDismissal dismissal) {
        Object title = s.getSuggestedValue() == null ? null : s.getSuggestedValue().get("title");
        return new CaAlertResponse(
                s.getId(),
                s.getOrgId(),
                org == null ? null : org.getName(),
                s.getEntityType(),
                s.getEntityId(),
                s.getSuggestionType(),
                title == null ? s.getSuggestionType().replace('_', ' ') : title.toString(),
                s.getReasoning(),
                s.getPriority(),
                s.getPriorityScore(),
                s.getStatus(),
                dismissal != null && dismissal.getDismissedAt() != null,
                dismissal == null ? null : dismissal.getAssignedUserId(),
                s.getSuggestedValue(),
                s.getCreatedAt()
        );
    }

    private boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
