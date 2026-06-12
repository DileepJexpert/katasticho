package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * Pharma MR reporting on top of the field-sales module:
 * monthly tour plans (MTP) with manager approval, and Daily Call Reports
 * (DCR) summarised from the day's field visits + per-visit product
 * detailing / sample / gift logs.
 *
 * Visits, check-ins and executions stay in {@link FieldSalesService};
 * this service only layers the MR reporting artefacts over them.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MrReportingService {

    private final TourPlanRepository tourPlanRepository;
    private final TourPlanEntryRepository tourPlanEntryRepository;
    private final DcrReportRepository dcrReportRepository;
    private final VisitProductLogRepository visitProductLogRepository;
    private final FieldVisitRepository fieldVisitRepository;
    private final RouteExecutionRepository routeExecutionRepository;
    private final ContactRepository contactRepository;

    // =====================================================================
    // Tour Plan (MTP)
    // =====================================================================

    /** Creates a DRAFT tour plan for the current user for the given month. */
    @Transactional
    public TourPlan createTourPlan(LocalDate planMonth, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        LocalDate month = planMonth.withDayOfMonth(1);

        tourPlanRepository.findByOrgIdAndSalespersonIdAndPlanMonthAndIsDeletedFalse(orgId, userId, month)
                .ifPresent(existing -> {
                    throw new BusinessException(
                            "A tour plan for " + month + " already exists (status " + existing.getStatus() + ")",
                            "MR_TOUR_PLAN_EXISTS", HttpStatus.CONFLICT);
                });

        TourPlan plan = tourPlanRepository.save(TourPlan.builder()
                .orgId(orgId).salespersonId(userId)
                .planMonth(month).notes(notes)
                .build());
        log.info("Created tour plan {} for {} by {} (org {})", plan.getId(), month, userId, orgId);
        return plan;
    }

    /** Adds a planned day to a DRAFT (or REJECTED, for rework) plan owned by the current user. */
    @Transactional
    public TourPlanEntry addEntry(UUID planId, LocalDate planDate, String activityType,
                                  UUID beatId, String area, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TourPlan plan = loadOwnedEditablePlan(planId, orgId);

        if (planDate == null
                || !planDate.withDayOfMonth(1).equals(plan.getPlanMonth())) {
            throw new BusinessException(
                    "Entry date must fall inside the plan month " + plan.getPlanMonth(),
                    "MR_TOUR_ENTRY_OUTSIDE_MONTH", HttpStatus.BAD_REQUEST);
        }

        return tourPlanEntryRepository.save(TourPlanEntry.builder()
                .orgId(orgId).tourPlanId(plan.getId())
                .planDate(planDate)
                .activityType(activityType != null ? activityType : "FIELD_WORK")
                .beatId(beatId).area(area).notes(notes)
                .build());
    }

    @Transactional
    public void removeEntry(UUID entryId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TourPlanEntry entry = tourPlanEntryRepository.findByIdAndOrgId(entryId, orgId)
                .orElseThrow(() -> BusinessException.notFound("TourPlanEntry", entryId));
        loadOwnedEditablePlan(entry.getTourPlanId(), orgId);
        tourPlanEntryRepository.delete(entry);
    }

    /** Submits the plan for approval. Rejected plans can be resubmitted after edits. */
    @Transactional
    public TourPlan submitTourPlan(UUID planId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TourPlan plan = loadOwnedEditablePlan(planId, orgId);

        if (tourPlanEntryRepository.findByOrgIdAndTourPlanIdOrderByPlanDate(orgId, planId).isEmpty()) {
            throw new BusinessException("Cannot submit an empty tour plan",
                    "MR_TOUR_PLAN_EMPTY", HttpStatus.BAD_REQUEST);
        }

        plan.setStatus("SUBMITTED");
        plan.setSubmittedAt(Instant.now());
        plan.setRejectionReason(null);
        return tourPlanRepository.save(plan);
    }

    @Transactional
    public TourPlan approveTourPlan(UUID planId) {
        TourPlan plan = loadSubmittedPlan(planId);
        ensureNotSelfApproval(plan.getSalespersonId());
        plan.setStatus("APPROVED");
        plan.setApprovedBy(TenantContext.getCurrentUserId());
        plan.setApprovedAt(Instant.now());
        return tourPlanRepository.save(plan);
    }

    @Transactional
    public TourPlan rejectTourPlan(UUID planId, String reason) {
        TourPlan plan = loadSubmittedPlan(planId);
        ensureNotSelfApproval(plan.getSalespersonId());
        plan.setStatus("REJECTED");
        plan.setRejectionReason(reason);
        return tourPlanRepository.save(plan);
    }

    @Transactional(readOnly = true)
    public List<TourPlan> myTourPlans() {
        return tourPlanRepository.findByOrgIdAndSalespersonIdAndIsDeletedFalseOrderByPlanMonthDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    @Transactional(readOnly = true)
    public List<TourPlan> pendingTourPlans() {
        return tourPlanRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByPlanMonthDesc(
                TenantContext.getCurrentOrgId(), "SUBMITTED");
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getTourPlan(UUID planId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TourPlan plan = tourPlanRepository.findByIdAndOrgIdAndIsDeletedFalse(planId, orgId)
                .orElseThrow(() -> BusinessException.notFound("TourPlan", planId));
        List<TourPlanEntry> entries =
                tourPlanEntryRepository.findByOrgIdAndTourPlanIdOrderByPlanDate(orgId, planId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("plan", plan);
        result.put("entries", entries);
        return result;
    }

    private TourPlan loadOwnedEditablePlan(UUID planId, UUID orgId) {
        TourPlan plan = tourPlanRepository.findByIdAndOrgIdAndIsDeletedFalse(planId, orgId)
                .orElseThrow(() -> BusinessException.notFound("TourPlan", planId));
        if (!plan.getSalespersonId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException("Only the plan owner can modify this tour plan",
                    "MR_NOT_PLAN_OWNER", HttpStatus.FORBIDDEN);
        }
        if (!"DRAFT".equals(plan.getStatus()) && !"REJECTED".equals(plan.getStatus())) {
            throw new BusinessException(
                    "Tour plan can only be edited in DRAFT or REJECTED status, current: " + plan.getStatus(),
                    "MR_TOUR_PLAN_NOT_EDITABLE", HttpStatus.BAD_REQUEST);
        }
        return plan;
    }

    private TourPlan loadSubmittedPlan(UUID planId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TourPlan plan = tourPlanRepository.findByIdAndOrgIdAndIsDeletedFalse(planId, orgId)
                .orElseThrow(() -> BusinessException.notFound("TourPlan", planId));
        if (!"SUBMITTED".equals(plan.getStatus())) {
            throw new BusinessException(
                    "Tour plan must be SUBMITTED to decide, current: " + plan.getStatus(),
                    "MR_TOUR_PLAN_NOT_SUBMITTED", HttpStatus.BAD_REQUEST);
        }
        return plan;
    }

    // =====================================================================
    // Visit product log (detailing / samples / gifts)
    // =====================================================================

    /** One product line recorded during a visit. */
    public record ProductLogRequest(UUID itemId, String productName, Boolean detailed,
                                    Integer sampleQty, String giftName, Integer giftQty) {}

    /**
     * Replaces the product/sample/gift log of a visit. Only the assigned
     * salesperson may write, and only on a visit that has been started.
     */
    @Transactional
    public List<VisitProductLog> logVisitProducts(UUID visitId, List<ProductLogRequest> products) {
        UUID orgId = TenantContext.getCurrentOrgId();
        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        if ("PLANNED".equals(visit.getStatus()) || "SKIPPED".equals(visit.getStatus())) {
            throw new BusinessException(
                    "Products can only be logged after check-in, visit status: " + visit.getStatus(),
                    "MR_VISIT_NOT_STARTED", HttpStatus.BAD_REQUEST);
        }

        visitProductLogRepository.deleteByOrgIdAndFieldVisitId(orgId, visitId);

        List<VisitProductLog> rows = new ArrayList<>();
        for (ProductLogRequest p : products != null ? products : List.<ProductLogRequest>of()) {
            if (p.productName() == null || p.productName().isBlank()) {
                throw new BusinessException("Product name is required",
                        "MR_PRODUCT_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            rows.add(VisitProductLog.builder()
                    .orgId(orgId).fieldVisitId(visitId)
                    .itemId(p.itemId())
                    .productName(p.productName().trim())
                    .detailed(p.detailed() == null || p.detailed())
                    .sampleQty(p.sampleQty() != null ? p.sampleQty() : 0)
                    .giftName(p.giftName())
                    .giftQty(p.giftQty() != null ? p.giftQty() : 0)
                    .build());
        }
        return visitProductLogRepository.saveAll(rows);
    }

    @Transactional(readOnly = true)
    public List<VisitProductLog> getVisitProducts(UUID visitId) {
        return visitProductLogRepository.findByOrgIdAndFieldVisitId(
                TenantContext.getCurrentOrgId(), visitId);
    }

    /** Marks a visit as a joint visit with the given manager/colleague. */
    @Transactional
    public FieldVisit markJointVisit(UUID visitId, UUID jointUserId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);
        visit.setJointVisitUserId(jointUserId);
        return fieldVisitRepository.save(visit);
    }

    // =====================================================================
    // DCR (Daily Call Report)
    // =====================================================================

    /**
     * Creates or refreshes the current user's DRAFT DCR for a date by
     * summarising that day's visits: doctor/chemist split (via the
     * contact's medical_category), POB total and samples given.
     * Submitted/approved DCRs are returned untouched.
     */
    @Transactional
    public DcrReport buildDcr(LocalDate date, String workType) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        DcrReport dcr = dcrReportRepository
                .findByOrgIdAndSalespersonIdAndReportDateAndIsDeletedFalse(orgId, userId, date)
                .orElseGet(() -> DcrReport.builder()
                        .orgId(orgId).salespersonId(userId).reportDate(date)
                        .build());

        if (!"DRAFT".equals(dcr.getStatus()) && !"REJECTED".equals(dcr.getStatus())) {
            return dcr;
        }

        if (workType != null && !workType.isBlank()) {
            dcr.setWorkType(workType);
        }

        // Collect the day's visits across this salesperson's executions
        List<RouteExecution> executions = routeExecutionRepository
                .findAllByOrgIdAndSalespersonIdAndExecutionDateAndIsDeletedFalse(orgId, userId, date);
        List<FieldVisit> visits = new ArrayList<>();
        for (RouteExecution exec : executions) {
            visits.addAll(fieldVisitRepository
                    .findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, exec.getId()));
            if (dcr.getRouteExecutionId() == null) {
                dcr.setRouteExecutionId(exec.getId());
            }
        }

        int doctors = 0, chemists = 0, others = 0, completed = 0;
        BigDecimal pob = BigDecimal.ZERO;
        List<UUID> visitIds = new ArrayList<>();
        for (FieldVisit v : visits) {
            if (!"COMPLETED".equals(v.getStatus()) && !"IN_PROGRESS".equals(v.getStatus())) continue;
            completed++;
            visitIds.add(v.getId());
            pob = pob.add(v.getOrderValue() != null ? v.getOrderValue() : BigDecimal.ZERO);
            String category = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(v.getContactId(), orgId)
                    .map(Contact::getMedicalCategory).orElse(null);
            if ("DOCTOR".equalsIgnoreCase(category)) doctors++;
            else if ("CHEMIST".equalsIgnoreCase(category)) chemists++;
            else others++;
        }

        int samples = visitIds.isEmpty() ? 0
                : visitProductLogRepository.findByOrgIdAndFieldVisitIdIn(orgId, visitIds).stream()
                        .mapToInt(VisitProductLog::getSampleQty).sum();

        dcr.setDoctorsVisited(doctors);
        dcr.setChemistsVisited(chemists);
        dcr.setOthersVisited(others);
        dcr.setTotalVisits(completed);
        dcr.setTotalPob(pob);
        dcr.setSamplesGiven(samples);
        return dcrReportRepository.save(dcr);
    }

    /** Submits the day's DCR (rebuilding the summary first so it reflects final visit data). */
    @Transactional
    public DcrReport submitDcr(LocalDate date, String workType, String remarks) {
        DcrReport dcr = buildDcr(date, workType);

        if (!"DRAFT".equals(dcr.getStatus()) && !"REJECTED".equals(dcr.getStatus())) {
            throw new BusinessException(
                    "DCR already " + dcr.getStatus() + " for " + date,
                    "MR_DCR_ALREADY_SUBMITTED", HttpStatus.CONFLICT);
        }
        if ("FIELD_WORK".equals(dcr.getWorkType()) && dcr.getTotalVisits() == 0) {
            throw new BusinessException(
                    "A field-work DCR needs at least one completed visit; use work type LEAVE/MEETING/OFFICE otherwise",
                    "MR_DCR_NO_VISITS", HttpStatus.BAD_REQUEST);
        }

        dcr.setRemarks(remarks);
        dcr.setStatus("SUBMITTED");
        dcr.setSubmittedAt(Instant.now());
        dcr.setRejectionReason(null);
        return dcrReportRepository.save(dcr);
    }

    @Transactional
    public DcrReport approveDcr(UUID dcrId) {
        DcrReport dcr = loadSubmittedDcr(dcrId);
        ensureNotSelfApproval(dcr.getSalespersonId());
        dcr.setStatus("APPROVED");
        dcr.setApprovedBy(TenantContext.getCurrentUserId());
        dcr.setApprovedAt(Instant.now());
        return dcrReportRepository.save(dcr);
    }

    @Transactional
    public DcrReport rejectDcr(UUID dcrId, String reason) {
        DcrReport dcr = loadSubmittedDcr(dcrId);
        ensureNotSelfApproval(dcr.getSalespersonId());
        dcr.setStatus("REJECTED");
        dcr.setRejectionReason(reason);
        return dcrReportRepository.save(dcr);
    }

    @Transactional(readOnly = true)
    public List<DcrReport> myDcrs(LocalDate from, LocalDate to) {
        return dcrReportRepository
                .findByOrgIdAndSalespersonIdAndReportDateBetweenAndIsDeletedFalseOrderByReportDateDesc(
                        TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId(), from, to);
    }

    @Transactional(readOnly = true)
    public List<DcrReport> pendingDcrs() {
        return dcrReportRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByReportDateDesc(
                TenantContext.getCurrentOrgId(), "SUBMITTED");
    }

    private DcrReport loadSubmittedDcr(UUID dcrId) {
        DcrReport dcr = dcrReportRepository
                .findByIdAndOrgIdAndIsDeletedFalse(dcrId, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("DcrReport", dcrId));
        if (!"SUBMITTED".equals(dcr.getStatus())) {
            throw new BusinessException(
                    "DCR must be SUBMITTED to decide, current: " + dcr.getStatus(),
                    "MR_DCR_NOT_SUBMITTED", HttpStatus.BAD_REQUEST);
        }
        return dcr;
    }

    // =====================================================================
    // Shared guards
    // =====================================================================

    private void ensureNotSelfApproval(UUID requesterId) {
        if (requesterId.equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException("You cannot approve or reject your own submission",
                    "MR_SELF_APPROVAL_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
    }

    private void ensureVisitOwnership(FieldVisit visit, UUID orgId) {
        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(visit.getRouteExecutionId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", visit.getRouteExecutionId()));
        if (!execution.getSalespersonId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException(
                    "Only the assigned salesperson can perform this visit action",
                    "FS_NOT_ASSIGNED_SALESPERSON", HttpStatus.FORBIDDEN);
        }
    }
}
