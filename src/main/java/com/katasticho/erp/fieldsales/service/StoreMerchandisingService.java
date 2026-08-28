package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.dto.MerchandisingSummaryResponse;
import com.katasticho.erp.fieldsales.dto.StoreMerchandisingAuditRequest;
import com.katasticho.erp.fieldsales.dto.StoreMerchandisingAuditResponse;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.FieldVisitRepository;
import com.katasticho.erp.fieldsales.repository.RouteExecutionRepository;
import com.katasticho.erp.fieldsales.repository.StoreMerchandisingAuditRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class StoreMerchandisingService {

    private final StoreMerchandisingAuditRepository auditRepository;
    private final FieldVisitRepository fieldVisitRepository;
    private final RouteExecutionRepository routeExecutionRepository;
    private final ContactRepository contactRepository;
    private final AppUserRepository appUserRepository;

    @Transactional
    public StoreMerchandisingAuditResponse recordAudit(StoreMerchandisingAuditRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID currentUserId = TenantContext.getCurrentUserId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(req.fieldVisitId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", req.fieldVisitId()));

        RouteExecution execution = routeExecutionRepository.findByIdAndOrgIdAndIsDeletedFalse(req.routeExecutionId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", req.routeExecutionId()));

        // Ensure user ownership
        if (currentUserId != null && execution.getSalespersonId() != null &&
                !execution.getSalespersonId().equals(currentUserId)) {
            log.warn("User {} recording merchandising audit for salesperson {}", currentUserId, execution.getSalespersonId());
        }

        UUID salespersonId = execution.getSalespersonId() != null ? execution.getSalespersonId() : currentUserId;

        StoreMerchandisingAudit audit = StoreMerchandisingAudit.builder()
                .fieldVisitId(req.fieldVisitId())
                .routeExecutionId(req.routeExecutionId())
                .contactId(req.contactId())
                .salespersonId(salespersonId)
                .auditType(req.auditType() != null ? req.auditType() : MerchandisingAuditType.PRIMARY_SHELF)
                .photoUrl(req.photoUrl())
                .shelfSharePct(req.shelfSharePct())
                .facingCount(req.facingCount())
                .isStockOut(Boolean.TRUE.equals(req.isStockOut()))
                .competitorBrandNames(req.competitorBrandNames())
                .planogramCompliance(req.planogramCompliance() != null ? req.planogramCompliance() : PlanogramCompliance.COMPLIANT)
                .notes(req.notes())
                .auditedAt(Instant.now())
                .build();
        audit.setOrgId(orgId);

        audit = auditRepository.save(audit);

        // Update photo on field visit if visit doesn't have one
        if (visit.getPhotoUrl() == null && req.photoUrl() != null && !req.photoUrl().isBlank()) {
            visit.setPhotoUrl(req.photoUrl());
            fieldVisitRepository.save(visit);
        }

        return toResponse(audit);
    }

    @Transactional(readOnly = true)
    public List<StoreMerchandisingAuditResponse> getAuditsByVisit(UUID visitId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return auditRepository.findByOrgIdAndFieldVisitIdAndIsDeletedFalseOrderByAuditedAtDesc(orgId, visitId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<StoreMerchandisingAuditResponse> getAuditsByExecution(UUID executionId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return auditRepository.findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderByAuditedAtDesc(orgId, executionId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<StoreMerchandisingAuditResponse> getAuditsByContact(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return auditRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByAuditedAtDesc(orgId, contactId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<StoreMerchandisingAuditResponse> getRecentAudits(Instant from, Instant to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Instant fromInstant = from != null ? from : Instant.now().minus(30, ChronoUnit.DAYS);
        Instant toInstant = to != null ? to : Instant.now();

        return auditRepository.findByOrgIdAndAuditedAtBetweenAndIsDeletedFalseOrderByAuditedAtDesc(orgId, fromInstant, toInstant)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public MerchandisingSummaryResponse getSummary(Instant from, Instant to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Instant fromInstant = from != null ? from : Instant.now().minus(30, ChronoUnit.DAYS);
        Instant toInstant = to != null ? to : Instant.now();

        List<StoreMerchandisingAudit> audits =
                auditRepository.findByOrgIdAndAuditedAtBetweenAndIsDeletedFalseOrderByAuditedAtDesc(orgId, fromInstant, toInstant);

        long totalAudits = audits.size();
        long totalPhotos = audits.stream().filter(a -> a.getPhotoUrl() != null && !a.getPhotoUrl().isBlank()).count();
        long stockOuts = audits.stream().filter(StoreMerchandisingAudit::isStockOut).count();

        // Calculate Average Shelf Share %
        List<BigDecimal> shelfShares = audits.stream()
                .map(StoreMerchandisingAudit::getShelfSharePct)
                .filter(Objects::nonNull)
                .toList();
        BigDecimal avgShelfShare = BigDecimal.ZERO;
        if (!shelfShares.isEmpty()) {
            BigDecimal sum = shelfShares.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
            avgShelfShare = sum.divide(BigDecimal.valueOf(shelfShares.size()), 2, RoundingMode.HALF_UP);
        }

        // Calculate Compliance Rate %
        long compliantCount = audits.stream()
                .filter(a -> a.getPlanogramCompliance() == PlanogramCompliance.COMPLIANT)
                .count();
        double complianceRate = totalAudits > 0
                ? (compliantCount * 100.0) / totalAudits
                : 100.0;

        Map<MerchandisingAuditType, Long> byType = audits.stream()
                .collect(Collectors.groupingBy(StoreMerchandisingAudit::getAuditType, Collectors.counting()));

        Map<PlanogramCompliance, Long> byCompliance = audits.stream()
                .collect(Collectors.groupingBy(StoreMerchandisingAudit::getPlanogramCompliance, Collectors.counting()));

        return new MerchandisingSummaryResponse(
                totalAudits,
                totalPhotos,
                avgShelfShare,
                Math.round(complianceRate * 100.0) / 100.0,
                stockOuts,
                byType,
                byCompliance
        );
    }

    private StoreMerchandisingAuditResponse toResponse(StoreMerchandisingAudit audit) {
        String customerName = "";
        if (audit.getContactId() != null) {
            customerName = contactRepository.findById(audit.getContactId())
                    .map(Contact::getDisplayName)
                    .orElse("");
        }

        String repName = "";
        if (audit.getSalespersonId() != null) {
            repName = appUserRepository.findById(audit.getSalespersonId())
                    .map(AppUser::getFullName)
                    .orElse("");
        }

        return new StoreMerchandisingAuditResponse(
                audit.getId(),
                audit.getFieldVisitId(),
                audit.getRouteExecutionId(),
                audit.getContactId(),
                customerName,
                audit.getSalespersonId(),
                repName,
                audit.getAuditType(),
                audit.getPhotoUrl(),
                audit.getShelfSharePct(),
                audit.getFacingCount(),
                audit.isStockOut(),
                audit.getCompetitorBrandNames(),
                audit.getPlanogramCompliance(),
                audit.getNotes(),
                audit.getAuditedAt()
        );
    }
}
