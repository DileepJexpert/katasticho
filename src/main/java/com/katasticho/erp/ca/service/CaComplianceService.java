package com.katasticho.erp.ca.service;

import com.katasticho.erp.ca.dto.CaComplianceDeadlineResponse;
import com.katasticho.erp.ca.dto.MarkFiledRequest;
import com.katasticho.erp.ca.entity.CaClientLink;
import com.katasticho.erp.ca.entity.CaComplianceDeadline;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.repository.CaClientLinkRepository;
import com.katasticho.erp.ca.repository.CaComplianceDeadlineRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.TextStyle;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CaComplianceService {

    private final CaAccessService accessService;
    private final CaClientLinkRepository linkRepository;
    private final CaComplianceDeadlineRepository deadlineRepository;
    private final OrganisationRepository organisationRepository;

    @Transactional(readOnly = true)
    public List<CaComplianceDeadlineResponse> list(String deadlineType, String status,
                                                   LocalDate fromDate, LocalDate toDate, UUID clientOrgId) {
        List<CaClientLink> links = visibleLinks();
        Set<UUID> clientOrgIds = links.stream().map(CaClientLink::getClientOrgId).collect(Collectors.toSet());
        if (clientOrgIds.isEmpty()) {
            return List.of();
        }
        LocalDate from = fromDate == null ? LocalDate.now().minusDays(30) : fromDate;
        LocalDate to = toDate == null ? LocalDate.now().plusMonths(3) : toDate;
        List<CaComplianceDeadline> rows = deadlineRepository.search(
                clientOrgIds,
                blankToNull(status),
                blankToNull(deadlineType),
                clientOrgId,
                from,
                to
        );
        Map<UUID, Organisation> orgs = organisationRepository.findAllById(clientOrgIds)
                .stream().collect(Collectors.toMap(Organisation::getId, Function.identity()));
        return rows.stream().map(d -> toResponse(d, orgs.get(d.getClientOrgId()))).toList();
    }

    @Transactional
    public CaComplianceDeadlineResponse markFiled(UUID deadlineId, MarkFiledRequest request) {
        List<CaClientLink> links = visibleLinks();
        Set<UUID> clientOrgIds = links.stream().map(CaClientLink::getClientOrgId).collect(Collectors.toSet());
        CaComplianceDeadline deadline = deadlineRepository.findByIdAndClientOrgIdIn(deadlineId, clientOrgIds)
                .orElseThrow(() -> new BusinessException("Compliance deadline not found",
                        "CA_DEADLINE_NOT_FOUND", HttpStatus.NOT_FOUND));
        deadline.setStatus("FILED");
        deadline.setFiledAt(request.filedAt() == null ? Instant.now() : request.filedAt());
        deadline.setFiledBy(TenantContext.getCurrentUserId());
        deadline.setFilingReference(request.filingReference());
        CaComplianceDeadline saved = deadlineRepository.save(deadline);
        Organisation org = organisationRepository.findById(saved.getClientOrgId()).orElse(null);
        return toResponse(saved, org);
    }

    @Transactional
    public int generate() {
        accessService.requirePartner();
        List<CaClientLink> links = visibleLinks();
        int created = 0;
        YearMonth start = YearMonth.now();
        for (CaClientLink link : links) {
            for (int i = 0; i < 3; i++) {
                YearMonth month = start.plusMonths(i);
                created += createIfMissing(link, "GSTR1", month, month.plusMonths(1).atDay(11));
                created += createIfMissing(link, "GSTR3B", month, month.plusMonths(1).atDay(20));
            }
        }
        return created;
    }

    private int createIfMissing(CaClientLink link, String type, YearMonth period, LocalDate dueDate) {
        String label = period.getMonth().getDisplayName(TextStyle.SHORT, Locale.ENGLISH) + " " + period.getYear();
        if (deadlineRepository.existsByCaClientLinkIdAndDeadlineTypeAndPeriodLabel(link.getId(), type, label)) {
            return 0;
        }
        deadlineRepository.save(CaComplianceDeadline.builder()
                .caClientLinkId(link.getId())
                .clientOrgId(link.getClientOrgId())
                .deadlineType(type)
                .periodLabel(label)
                .dueDate(dueDate)
                .status("PENDING")
                .build());
        return 1;
    }

    private List<CaClientLink> visibleLinks() {
        CaFirm firm = accessService.currentFirm();
        return linkRepository.findVisibleActive(firm.getId(), accessService.staffScopeUserId());
    }

    private CaComplianceDeadlineResponse toResponse(CaComplianceDeadline deadline, Organisation org) {
        return new CaComplianceDeadlineResponse(
                deadline.getId(),
                deadline.getCaClientLinkId(),
                deadline.getClientOrgId(),
                org == null ? null : org.getName(),
                deadline.getDeadlineType(),
                deadline.getPeriodLabel(),
                deadline.getDueDate(),
                deadline.getStatus(),
                deadline.getFiledAt(),
                deadline.getFilingReference(),
                deadline.getNotes()
        );
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim().toUpperCase();
    }
}
