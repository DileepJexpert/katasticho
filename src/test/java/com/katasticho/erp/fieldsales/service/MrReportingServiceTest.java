package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MrReportingServiceTest {

    @Mock private TourPlanRepository tourPlanRepo;
    @Mock private TourPlanEntryRepository tourPlanEntryRepo;
    @Mock private DcrReportRepository dcrRepo;
    @Mock private VisitProductLogRepository vplRepo;
    @Mock private FieldVisitRepository fieldVisitRepo;
    @Mock private RouteExecutionRepository routeExecutionRepo;
    @Mock private ContactRepository contactRepo;
    @Mock private FieldHierarchyService fieldHierarchyService;

    private MrReportingService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID managerId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new MrReportingService(tourPlanRepo, tourPlanEntryRepo, dcrRepo,
                vplRepo, fieldVisitRepo, routeExecutionRepo, contactRepo, fieldHierarchyService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Tour Plan ──

    @Test
    void createTourPlan_normalizesToFirstOfMonth() {
        when(tourPlanRepo.findByOrgIdAndSalespersonIdAndPlanMonthAndIsDeletedFalse(
                orgId, userId, LocalDate.of(2026, 7, 1))).thenReturn(Optional.empty());
        when(tourPlanRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TourPlan plan = service.createTourPlan(LocalDate.of(2026, 7, 15), "July plan");

        assertEquals(LocalDate.of(2026, 7, 1), plan.getPlanMonth());
        assertEquals("DRAFT", plan.getStatus());
        assertEquals(userId, plan.getSalespersonId());
    }

    @Test
    void createTourPlan_duplicateMonth_throws() {
        when(tourPlanRepo.findByOrgIdAndSalespersonIdAndPlanMonthAndIsDeletedFalse(
                orgId, userId, LocalDate.of(2026, 7, 1)))
                .thenReturn(Optional.of(TourPlan.builder().status("SUBMITTED").build()));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createTourPlan(LocalDate.of(2026, 7, 1), null));
        assertEquals("MR_TOUR_PLAN_EXISTS", ex.getErrorCode());
    }

    @Test
    void addEntry_outsidePlanMonth_throws() {
        TourPlan plan = ownedDraftPlan(LocalDate.of(2026, 7, 1));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addEntry(plan.getId(), LocalDate.of(2026, 8, 2),
                        "FIELD_WORK", null, "Indore", null));
        assertEquals("MR_TOUR_ENTRY_OUTSIDE_MONTH", ex.getErrorCode());
    }

    @Test
    void addEntry_byNonOwner_throws() {
        TourPlan plan = ownedDraftPlan(LocalDate.of(2026, 7, 1));
        plan.setSalespersonId(managerId);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addEntry(plan.getId(), LocalDate.of(2026, 7, 2),
                        "FIELD_WORK", null, null, null));
        assertEquals("MR_NOT_PLAN_OWNER", ex.getErrorCode());
    }

    @Test
    void submitTourPlan_empty_throws() {
        TourPlan plan = ownedDraftPlan(LocalDate.of(2026, 7, 1));
        when(tourPlanEntryRepo.findByOrgIdAndTourPlanIdOrderByPlanDate(orgId, plan.getId()))
                .thenReturn(List.of());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.submitTourPlan(plan.getId()));
        assertEquals("MR_TOUR_PLAN_EMPTY", ex.getErrorCode());
    }

    @Test
    void submitTourPlan_withEntries_succeeds() {
        TourPlan plan = ownedDraftPlan(LocalDate.of(2026, 7, 1));
        when(tourPlanEntryRepo.findByOrgIdAndTourPlanIdOrderByPlanDate(orgId, plan.getId()))
                .thenReturn(List.of(TourPlanEntry.builder().build()));
        when(tourPlanRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TourPlan result = service.submitTourPlan(plan.getId());

        assertEquals("SUBMITTED", result.getStatus());
        assertNotNull(result.getSubmittedAt());
    }

    @Test
    void approveTourPlan_own_throws() {
        TourPlan plan = submittedPlan(userId);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approveTourPlan(plan.getId()));
        assertEquals("MR_SELF_APPROVAL_FORBIDDEN", ex.getErrorCode());
    }

    @Test
    void approveTourPlan_byManager_succeeds() {
        TourPlan plan = submittedPlan(managerId);
        when(fieldHierarchyService.isAncestor(userId, managerId)).thenReturn(true);
        when(tourPlanRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TourPlan result = service.approveTourPlan(plan.getId());

        assertEquals("APPROVED", result.getStatus());
        assertEquals(userId, result.getApprovedBy());
    }

    @Test
    void rejectTourPlan_setsReason_andAllowsResubmitAfterEdit() {
        TourPlan plan = submittedPlan(managerId);
        when(fieldHierarchyService.isAncestor(userId, managerId)).thenReturn(true);
        when(tourPlanRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TourPlan result = service.rejectTourPlan(plan.getId(), "Too few field days");

        assertEquals("REJECTED", result.getStatus());
        assertEquals("Too few field days", result.getRejectionReason());
    }

    // ── Visit product log ──

    @Test
    void logVisitProducts_beforeCheckIn_throws() {
        FieldVisit visit = visitOwnedByUser("PLANNED");

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.logVisitProducts(visit.getId(), List.of(
                        new MrReportingService.ProductLogRequest(null, "Crocin", true, 2, null, 0))));
        assertEquals("MR_VISIT_NOT_STARTED", ex.getErrorCode());
    }

    @Test
    void logVisitProducts_replacesExistingLog() {
        FieldVisit visit = visitOwnedByUser("IN_PROGRESS");
        when(vplRepo.saveAll(any())).thenAnswer(inv -> inv.getArgument(0));

        List<VisitProductLog> rows = service.logVisitProducts(visit.getId(), List.of(
                new MrReportingService.ProductLogRequest(null, "Crocin", true, 2, "Pen", 1),
                new MrReportingService.ProductLogRequest(null, "Azee", false, 0, null, null)));

        verify(vplRepo).deleteByOrgIdAndFieldVisitId(orgId, visit.getId());
        assertEquals(2, rows.size());
        assertEquals(2, rows.get(0).getSampleQty());
        assertTrue(rows.get(0).isDetailed());
        assertFalse(rows.get(1).isDetailed());
    }

    // ── DCR ──

    @Test
    void buildDcr_aggregatesVisitsByMedicalCategory() {
        LocalDate date = LocalDate.of(2026, 6, 12);
        UUID execId = UUID.randomUUID();
        UUID doctorId = UUID.randomUUID();
        UUID chemistId = UUID.randomUUID();

        RouteExecution exec = RouteExecution.builder()
                .salespersonId(userId).status("COMPLETED")
                .routeId(UUID.randomUUID()).executionDate(date).build();
        exec.setId(execId);
        exec.setOrgId(orgId);

        FieldVisit v1 = FieldVisit.builder().id(UUID.randomUUID()).orgId(orgId)
                .routeExecutionId(execId).contactId(doctorId)
                .status("COMPLETED").orderValue(new BigDecimal("3000")).build();
        FieldVisit v2 = FieldVisit.builder().id(UUID.randomUUID()).orgId(orgId)
                .routeExecutionId(execId).contactId(chemistId)
                .status("COMPLETED").orderValue(new BigDecimal("2000")).build();
        FieldVisit skipped = FieldVisit.builder().id(UUID.randomUUID()).orgId(orgId)
                .routeExecutionId(execId).contactId(UUID.randomUUID())
                .status("SKIPPED").orderValue(BigDecimal.ZERO).build();

        when(dcrRepo.findByOrgIdAndSalespersonIdAndReportDateAndIsDeletedFalse(orgId, userId, date))
                .thenReturn(Optional.empty());
        when(routeExecutionRepo.findAllByOrgIdAndSalespersonIdAndExecutionDateAndIsDeletedFalse(
                orgId, userId, date)).thenReturn(List.of(exec));
        when(fieldVisitRepo.findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, execId))
                .thenReturn(List.of(v1, v2, skipped));
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(doctorId, orgId))
                .thenReturn(Optional.of(contactWithCategory("DOCTOR")));
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(chemistId, orgId))
                .thenReturn(Optional.of(contactWithCategory("CHEMIST")));
        when(vplRepo.findByOrgIdAndFieldVisitIdIn(eq(orgId), any()))
                .thenReturn(List.of(
                        VisitProductLog.builder().sampleQty(3).productName("Crocin").build(),
                        VisitProductLog.builder().sampleQty(2).productName("Azee").build()));
        when(dcrRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DcrReport dcr = service.buildDcr(date, null);

        assertEquals(1, dcr.getDoctorsVisited());
        assertEquals(1, dcr.getChemistsVisited());
        assertEquals(0, dcr.getOthersVisited());
        assertEquals(2, dcr.getTotalVisits());
        assertEquals(0, new BigDecimal("5000").compareTo(dcr.getTotalPob()));
        assertEquals(5, dcr.getSamplesGiven());
        assertEquals(execId, dcr.getRouteExecutionId());
    }

    @Test
    void submitDcr_fieldWorkWithoutVisits_throws() {
        LocalDate date = LocalDate.of(2026, 6, 12);
        when(dcrRepo.findByOrgIdAndSalespersonIdAndReportDateAndIsDeletedFalse(orgId, userId, date))
                .thenReturn(Optional.empty());
        when(routeExecutionRepo.findAllByOrgIdAndSalespersonIdAndExecutionDateAndIsDeletedFalse(
                orgId, userId, date)).thenReturn(List.of());
        when(dcrRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.submitDcr(date, "FIELD_WORK", null));
        assertEquals("MR_DCR_NO_VISITS", ex.getErrorCode());
    }

    @Test
    void submitDcr_leaveDay_succeedsWithoutVisits() {
        LocalDate date = LocalDate.of(2026, 6, 12);
        when(dcrRepo.findByOrgIdAndSalespersonIdAndReportDateAndIsDeletedFalse(orgId, userId, date))
                .thenReturn(Optional.empty());
        when(routeExecutionRepo.findAllByOrgIdAndSalespersonIdAndExecutionDateAndIsDeletedFalse(
                orgId, userId, date)).thenReturn(List.of());
        when(dcrRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DcrReport dcr = service.submitDcr(date, "LEAVE", "Sick leave");

        assertEquals("SUBMITTED", dcr.getStatus());
        assertEquals("LEAVE", dcr.getWorkType());
        assertEquals("Sick leave", dcr.getRemarks());
    }

    @Test
    void approveDcr_own_throws() {
        DcrReport dcr = DcrReport.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .salespersonId(userId).reportDate(LocalDate.now())
                .status("SUBMITTED").build();
        when(dcrRepo.findByIdAndOrgIdAndIsDeletedFalse(dcr.getId(), orgId))
                .thenReturn(Optional.of(dcr));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approveDcr(dcr.getId()));
        assertEquals("MR_SELF_APPROVAL_FORBIDDEN", ex.getErrorCode());
    }

    @Test
    void approveDcr_byManager_succeeds() {
        DcrReport dcr = DcrReport.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .salespersonId(managerId).reportDate(LocalDate.now())
                .status("SUBMITTED").build();
        when(dcrRepo.findByIdAndOrgIdAndIsDeletedFalse(dcr.getId(), orgId))
                .thenReturn(Optional.of(dcr));
        when(fieldHierarchyService.isAncestor(userId, managerId)).thenReturn(true);
        when(dcrRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DcrReport result = service.approveDcr(dcr.getId());

        assertEquals("APPROVED", result.getStatus());
        assertEquals(userId, result.getApprovedBy());
    }

    @Test
    void approveDcr_byNonManagerNonAdmin_throws() {
        DcrReport dcr = DcrReport.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .salespersonId(managerId).reportDate(LocalDate.now())
                .status("SUBMITTED").build();
        when(dcrRepo.findByIdAndOrgIdAndIsDeletedFalse(dcr.getId(), orgId))
                .thenReturn(Optional.of(dcr));
        // current user is neither admin nor an ancestor (isAncestor defaults false)

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approveDcr(dcr.getId()));
        assertEquals("MR_NOT_MANAGER", ex.getErrorCode());
    }

    @Test
    void approveDcr_byAdmin_succeedsWithoutHierarchy() {
        TenantContext.setCurrentRole("ADMIN");
        DcrReport dcr = DcrReport.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .salespersonId(managerId).reportDate(LocalDate.now())
                .status("SUBMITTED").build();
        when(dcrRepo.findByIdAndOrgIdAndIsDeletedFalse(dcr.getId(), orgId))
                .thenReturn(Optional.of(dcr));
        when(dcrRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DcrReport result = service.approveDcr(dcr.getId());

        assertEquals("APPROVED", result.getStatus());
        // admin path must not consult the hierarchy
        verify(fieldHierarchyService, never()).isAncestor(any(), any());
    }

    // ── helpers ──

    private TourPlan ownedDraftPlan(LocalDate month) {
        TourPlan plan = TourPlan.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .salespersonId(userId).planMonth(month).build();
        when(tourPlanRepo.findByIdAndOrgIdAndIsDeletedFalse(plan.getId(), orgId))
                .thenReturn(Optional.of(plan));
        return plan;
    }

    private TourPlan submittedPlan(UUID owner) {
        TourPlan plan = TourPlan.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .salespersonId(owner).planMonth(LocalDate.of(2026, 7, 1))
                .status("SUBMITTED").build();
        when(tourPlanRepo.findByIdAndOrgIdAndIsDeletedFalse(plan.getId(), orgId))
                .thenReturn(Optional.of(plan));
        return plan;
    }

    private FieldVisit visitOwnedByUser(String status) {
        UUID execId = UUID.randomUUID();
        FieldVisit visit = FieldVisit.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .routeExecutionId(execId).contactId(UUID.randomUUID())
                .status(status).build();
        RouteExecution exec = RouteExecution.builder()
                .salespersonId(userId).status("IN_PROGRESS")
                .routeId(UUID.randomUUID()).executionDate(LocalDate.now()).build();
        exec.setId(execId);
        exec.setOrgId(orgId);
        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visit.getId(), orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        return visit;
    }

    private Contact contactWithCategory(String category) {
        Contact c = new Contact();
        c.setMedicalCategory(category);
        return c;
    }
}
