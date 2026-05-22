package com.katasticho.erp.ca.service;

import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.banking.repository.BankTransactionRepository;
import com.katasticho.erp.ca.dto.CaClientSummaryResponse;
import com.katasticho.erp.ca.dto.CaDashboardResponse;
import com.katasticho.erp.ca.entity.CaClientLink;
import com.katasticho.erp.ca.entity.CaComplianceDeadline;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.repository.CaClientLinkRepository;
import com.katasticho.erp.ca.repository.CaComplianceDeadlineRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CaDashboardService {

    private final CaAccessService accessService;
    private final CaClientLinkRepository linkRepository;
    private final OrganisationRepository organisationRepository;
    private final AppUserRepository appUserRepository;
    private final CaComplianceDeadlineRepository deadlineRepository;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final BankTransactionRepository bankTransactionRepository;
    private final JournalEntryRepository journalEntryRepository;

    @Transactional(readOnly = true)
    public CaDashboardResponse dashboard() {
        List<CaClientSummaryResponse> clients = clients(null, null, null);
        long critical = clients.stream().filter(c -> "RED".equals(c.healthStatus())).count();
        long gstDueThisWeek = clients.stream()
                .filter(c -> c.nextDeadlineDate() != null && !c.nextDeadlineDate().isAfter(LocalDate.now().plusDays(7)))
                .count();
        return new CaDashboardResponse(clients.size(), critical, gstDueThisWeek, 0, clients);
    }

    @Transactional(readOnly = true)
    public List<CaClientSummaryResponse> clients(String healthStatus, UUID assignedUserId, String engagementType) {
        CaFirm firm = accessService.currentFirm();
        UUID staffScope = accessService.staffScopeUserId();
        List<CaClientLink> links = linkRepository.findVisibleActive(firm.getId(), staffScope);
        if (assignedUserId != null) {
            links = links.stream()
                    .filter(l -> assignedUserId.equals(l.getAssignedUserId()) || assignedUserId.equals(l.getBackupUserId()))
                    .toList();
        }
        if (engagementType != null && !engagementType.isBlank()) {
            String normalized = engagementType.trim().toUpperCase();
            links = links.stream().filter(l -> normalized.equals(l.getEngagementType())).toList();
        }

        Map<UUID, Organisation> orgs = organisationRepository.findAllById(
                        links.stream().map(CaClientLink::getClientOrgId).collect(Collectors.toSet()))
                .stream().collect(Collectors.toMap(Organisation::getId, Function.identity()));
        Map<UUID, AppUser> users = appUserRepository.findAllById(
                        links.stream()
                                .flatMap(l -> java.util.stream.Stream.of(l.getAssignedUserId(), l.getBackupUserId()))
                                .filter(Objects::nonNull)
                                .collect(Collectors.toSet()))
                .stream().collect(Collectors.toMap(AppUser::getId, Function.identity()));

        List<CaClientSummaryResponse> summaries = links.stream()
                .map(link -> toSummary(link, orgs.get(link.getClientOrgId()), users.get(link.getAssignedUserId())))
                .filter(Objects::nonNull)
                .toList();
        if (healthStatus == null || healthStatus.isBlank()) {
            return summaries;
        }
        String normalizedHealth = healthStatus.trim().toUpperCase();
        return summaries.stream().filter(c -> normalizedHealth.equals(c.healthStatus())).toList();
    }

    private CaClientSummaryResponse toSummary(CaClientLink link, Organisation org, AppUser assignedUser) {
        if (org == null || Boolean.TRUE.equals(org.getIsDeleted())) {
            return null;
        }
        UUID orgId = org.getId();
        LocalDate today = LocalDate.now();
        List<String> reasons = new ArrayList<>();
        long overdue = deadlineRepository.countByClientOrgIdAndStatusAndDueDateBefore(orgId, "PENDING", today);
        long dueSoon = deadlineRepository.countByClientOrgIdAndStatusAndDueDateBetween(orgId, "PENDING", today, today.plusDays(5));
        long oldBankUnmatched = bankTransactionRepository.countByOrgIdAndStatusAndTransactionDateBefore(
                orgId, "UNMATCHED", today.minusDays(30));
        long weekBankUnmatched = bankTransactionRepository.countByOrgIdAndStatusAndTransactionDateBefore(
                orgId, "UNMATCHED", today.minusDays(7));
        long criticalAi = aiSuggestionRepository.countByOrgIdAndStatusAndPriorityAndCreatedAtBefore(
                orgId, "PENDING", "CRITICAL", Instant.now().minusSeconds(3 * 86400L));
        long pendingAi = aiSuggestionRepository.countByOrgIdAndStatus(orgId, "PENDING");
        long oldDraftJournals = journalEntryRepository.countByOrgIdAndStatusAndCreatedAtBefore(
                orgId, "DRAFT", Instant.now().minusSeconds(7 * 86400L));

        String health = "GREEN";
        if (overdue > 0 || oldBankUnmatched > 0 || criticalAi > 0 || oldDraftJournals > 0) {
            health = "RED";
            if (overdue > 0) reasons.add("Compliance deadline overdue");
            if (oldBankUnmatched > 0) reasons.add("Bank reconciliation unmatched over 30 days");
            if (criticalAi > 0) reasons.add("Critical AI issue pending over 3 days");
            if (oldDraftJournals > 0) reasons.add("Draft journal older than 7 days");
        } else if (dueSoon > 0 || weekBankUnmatched > 0 || pendingAi > 5) {
            health = "AMBER";
            if (dueSoon > 0) reasons.add("GST/compliance due within 5 days");
            if (weekBankUnmatched > 0) reasons.add("Bank reconciliation unmatched over 7 days");
            if (pendingAi > 5) reasons.add("More than 5 AI Inbox issues pending");
        }

        CaComplianceDeadline nextDeadline = deadlineRepository
                .findTop3ByClientOrgIdAndStatusOrderByDueDateAsc(orgId, "PENDING")
                .stream().findFirst().orElse(null);
        return new CaClientSummaryResponse(
                link.getId(),
                orgId,
                org.getName(),
                org.getIndustry(),
                health,
                pendingAi + overdue + oldBankUnmatched + oldDraftJournals,
                nextDeadline == null ? null : nextDeadline.getDeadlineType(),
                nextDeadline == null ? null : nextDeadline.getDueDate(),
                org.getUpdatedAt(),
                link.getAssignedUserId(),
                assignedUser == null ? null : assignedUser.getFullName(),
                link.getEngagementType(),
                link.getStatus(),
                reasons
        );
    }
}
