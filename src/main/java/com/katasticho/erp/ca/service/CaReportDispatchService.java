package com.katasticho.erp.ca.service;

import com.katasticho.erp.ca.dto.ReportDispatchRequest;
import com.katasticho.erp.ca.dto.ReportDispatchResponse;
import com.katasticho.erp.ca.entity.CaClientLink;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.entity.CaReportDispatch;
import com.katasticho.erp.ca.repository.CaClientLinkRepository;
import com.katasticho.erp.ca.repository.CaReportDispatchRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CaReportDispatchService {

    private final CaAccessService accessService;
    private final CaClientLinkRepository linkRepository;
    private final CaReportDispatchRepository dispatchRepository;

    @Transactional
    public List<ReportDispatchResponse> dispatch(ReportDispatchRequest request) {
        CaFirm firm = accessService.currentFirm();
        long todayCount = dispatchRepository.countByDispatchedByAndCreatedAtAfter(
                TenantContext.getCurrentUserId(), LocalDate.now().atStartOfDay(java.time.ZoneId.systemDefault()).toInstant());
        if (todayCount >= 5) {
            throw new BusinessException("Daily report dispatch limit reached", "CA_REPORT_RATE_LIMIT", HttpStatus.TOO_MANY_REQUESTS);
        }
        List<CaClientLink> links = linkRepository.findVisibleActive(firm.getId(), accessService.staffScopeUserId());
        Set<UUID> requested = request.clientOrgIds() == null ? Set.of() : Set.copyOf(request.clientOrgIds());
        if (!request.allClients()) {
            links = links.stream().filter(l -> requested.contains(l.getClientOrgId())).toList();
        }
        if (links.isEmpty()) {
            throw new BusinessException("No eligible clients selected", "CA_REPORT_NO_CLIENTS");
        }
        String sendVia = request.sendVia() == null || request.sendVia().isBlank()
                ? "EMAIL"
                : request.sendVia().trim().toUpperCase();
        List<String> reportTypes = request.reportTypes() == null || request.reportTypes().isEmpty()
                ? List.of("PL", "BS", "GST_SUMMARY")
                : request.reportTypes();
        return links.stream()
                .map(link -> dispatchRepository.save(CaReportDispatch.builder()
                        .caClientLinkId(link.getId())
                        .clientOrgId(link.getClientOrgId())
                        .dispatchedBy(TenantContext.getCurrentUserId())
                        .periodLabel(request.periodLabel())
                        .reportTypes(reportTypes)
                        .sentVia(sendVia)
                        .aiCommentary(request.includeAiCommentary())
                        .status("QUEUED")
                        .build()))
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ReportDispatchResponse> history() {
        return dispatchRepository.findTop50ByDispatchedByOrderByCreatedAtDesc(TenantContext.getCurrentUserId())
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public ReportDispatchResponse status(UUID id) {
        return dispatchRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new BusinessException("Report dispatch not found", "CA_REPORT_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private ReportDispatchResponse toResponse(CaReportDispatch dispatch) {
        return new ReportDispatchResponse(
                dispatch.getId(),
                dispatch.getClientOrgId(),
                dispatch.getPeriodLabel(),
                dispatch.getReportTypes(),
                dispatch.getSentVia(),
                dispatch.isAiCommentary(),
                dispatch.getStatus(),
                dispatch.getSentAt(),
                dispatch.getCreatedAt()
        );
    }
}
