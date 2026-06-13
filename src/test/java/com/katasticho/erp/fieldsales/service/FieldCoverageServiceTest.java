package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
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
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FieldCoverageServiceTest {

    @Mock private TourPlanRepository tourPlanRepo;
    @Mock private TourPlanEntryRepository tourPlanEntryRepo;
    @Mock private RouteExecutionRepository routeExecutionRepo;
    @Mock private FieldVisitRepository fieldVisitRepo;
    @Mock private ContactRepository contactRepo;
    @Mock private DcrReportRepository dcrRepo;
    @Mock private FieldLocationPingRepository pingRepo;
    @Mock private AppUserRepository appUserRepo;
    @Mock private FieldHierarchyService fieldHierarchyService;

    private FieldCoverageService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID salespersonId = UUID.randomUUID();
    // A month fully in the past so no days get skipped as "future"
    private final LocalDate month = LocalDate.of(2026, 5, 1);

    @BeforeEach
    void setUp() {
        service = new FieldCoverageService(tourPlanRepo, tourPlanEntryRepo, routeExecutionRepo,
                fieldVisitRepo, contactRepo, dcrRepo, pingRepo, appUserRepo, fieldHierarchyService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        // Existing tests exercise the org-wide (admin) path.
        TenantContext.setCurrentRole("ADMIN");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void deviationReport_classifiesPlannedVsActual() {
        UUID planId = UUID.randomUUID();
        TourPlan plan = TourPlan.builder()
                .id(planId).orgId(orgId).salespersonId(salespersonId)
                .planMonth(month).status("APPROVED").build();
        when(tourPlanRepo.findByOrgIdAndSalespersonIdAndPlanMonthAndIsDeletedFalse(
                orgId, salespersonId, month)).thenReturn(Optional.of(plan));
        when(tourPlanEntryRepo.findByOrgIdAndTourPlanIdOrderByPlanDate(orgId, planId))
                .thenReturn(List.of(
                        entry(planId, month.plusDays(0), "FIELD_WORK"),   // worked → AS_PLANNED
                        entry(planId, month.plusDays(1), "FIELD_WORK"),   // not worked → MISSED
                        entry(planId, month.plusDays(2), "LEAVE")));      // not worked → AS_PLANNED
        when(routeExecutionRepo.findByOrgIdAndSalespersonIdAndExecutionDateBetweenAndIsDeletedFalse(
                eq(orgId), eq(salespersonId), any(), any()))
                .thenReturn(List.of(
                        execution(month.plusDays(0), "COMPLETED", 8),
                        execution(month.plusDays(3), "COMPLETED", 5)));   // no plan → UNPLANNED_WORK

        Map<String, Object> report = service.deviationReport(month, salespersonId);

        assertEquals(2, report.get("daysAsPlanned"));
        assertEquals(2, report.get("daysDeviated"));  // MISSED + UNPLANNED_WORK
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> days = (List<Map<String, Object>>) report.get("days");
        assertEquals(4, days.size());
        assertEquals("AS_PLANNED", days.get(0).get("status"));
        assertEquals("MISSED", days.get(1).get("status"));
        assertEquals("AS_PLANNED", days.get(2).get("status"));
        assertEquals("UNPLANNED_WORK", days.get(3).get("status"));
        assertEquals(8, days.get(0).get("visitsCompleted"));
    }

    @Test
    void frequencyCompliance_flagsUnderVisitedContacts() {
        Contact classA = contact("Dr. Sharma", 4);
        Contact classC = contact("City Chemist", 1);
        when(contactRepo.findByOrgIdAndVisitsPerMonthGreaterThanAndIsDeletedFalse(orgId, 0))
                .thenReturn(List.of(classA, classC));
        when(fieldVisitRepo.countCompletedVisitsByContact(eq(orgId), any(), any()))
                .thenReturn(List.<Object[]>of(
                        new Object[]{classA.getId(), 2L},   // needs 4, got 2 → non-compliant
                        new Object[]{classC.getId(), 1L})); // needs 1, got 1 → compliant

        Map<String, Object> report = service.frequencyCompliance(month, null);

        assertEquals(2, report.get("totalTargets"));
        assertEquals(1, report.get("compliant"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> rows = (List<Map<String, Object>>) report.get("contacts");
        // Non-compliant first
        assertEquals("Dr. Sharma", rows.get(0).get("contactName"));
        assertEquals(false, rows.get(0).get("compliant"));
    }

    @Test
    void teamDashboard_aggregatesPerSalesperson() {
        RouteExecution e1 = execution(month.plusDays(1), "COMPLETED", 8);
        e1.setPlannedVisits(10);
        e1.setTotalOrdersValue(new BigDecimal("5000"));
        e1.setTotalCollections(new BigDecimal("2000"));
        RouteExecution e2 = execution(month.plusDays(2), "COMPLETED", 6);
        e2.setPlannedVisits(10);
        e2.setTotalOrdersValue(new BigDecimal("3000"));
        e2.setTotalCollections(BigDecimal.ZERO);

        when(routeExecutionRepo.findByOrgIdAndExecutionDateBetweenAndIsDeletedFalse(
                eq(orgId), any(), any())).thenReturn(List.of(e1, e2));
        when(appUserRepo.findAllById(any())).thenReturn(List.of());
        when(dcrRepo.findByOrgIdAndSalespersonIdAndReportDateBetweenAndIsDeletedFalseOrderByReportDateDesc(
                eq(orgId), eq(salespersonId), any(), any()))
                .thenReturn(List.of(DcrReport.builder().status("APPROVED").build()));
        when(pingRepo.findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                eq(orgId), eq(salespersonId), any(), any())).thenReturn(List.of());

        List<Map<String, Object>> rows =
                service.teamDashboard(month, month.plusMonths(1).minusDays(1));

        assertEquals(1, rows.size());
        Map<String, Object> row = rows.get(0);
        assertEquals(salespersonId, row.get("salespersonId"));
        assertEquals(20, row.get("visitsPlanned"));
        assertEquals(14, row.get("visitsCompleted"));
        assertEquals(0, new BigDecimal("70.0").compareTo((BigDecimal) row.get("completionPct")));
        assertEquals(0, new BigDecimal("8000").compareTo((BigDecimal) row.get("ordersValue")));
        assertEquals(1L, row.get("dcrsSubmitted"));
    }

    @Test
    void teamDashboard_nonAdmin_scopesToDownline() {
        UUID managerId = UUID.randomUUID();
        UUID outsiderId = UUID.randomUUID();   // not in the manager's downline
        TenantContext.setCurrentUserId(managerId);
        TenantContext.setCurrentRole("OPERATOR");

        RouteExecution mine = execution(month.plusDays(1), "COMPLETED", 5); // salespersonId (in team)
        RouteExecution theirs = RouteExecution.builder()
                .salespersonId(outsiderId).status("COMPLETED")
                .routeId(UUID.randomUUID()).executionDate(month.plusDays(1)).build();
        theirs.setOrgId(orgId);
        theirs.setCompletedVisits(9);

        when(routeExecutionRepo.findByOrgIdAndExecutionDateBetweenAndIsDeletedFalse(
                eq(orgId), any(), any())).thenReturn(List.of(mine, theirs));
        when(fieldHierarchyService.downlineUserIds(managerId)).thenReturn(Set.of(salespersonId));
        when(appUserRepo.findAllById(any())).thenReturn(List.of());
        when(dcrRepo.findByOrgIdAndSalespersonIdAndReportDateBetweenAndIsDeletedFalseOrderByReportDateDesc(
                eq(orgId), eq(salespersonId), any(), any())).thenReturn(List.of());
        when(pingRepo.findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                eq(orgId), eq(salespersonId), any(), any())).thenReturn(List.of());

        List<Map<String, Object>> rows =
                service.teamDashboard(month, month.plusMonths(1).minusDays(1));

        assertEquals(1, rows.size());
        assertEquals(salespersonId, rows.get(0).get("salespersonId")); // outsider excluded
    }

    private TourPlanEntry entry(UUID planId, LocalDate date, String activity) {
        return TourPlanEntry.builder()
                .orgId(orgId).tourPlanId(planId).planDate(date).activityType(activity).build();
    }

    private RouteExecution execution(LocalDate date, String status, int completedVisits) {
        RouteExecution exec = RouteExecution.builder()
                .salespersonId(salespersonId).status(status)
                .routeId(UUID.randomUUID()).executionDate(date).build();
        exec.setId(UUID.randomUUID());
        exec.setOrgId(orgId);
        exec.setCompletedVisits(completedVisits);
        return exec;
    }

    private Contact contact(String name, int visitsPerMonth) {
        Contact c = new Contact();
        c.setId(UUID.randomUUID());
        c.setDisplayName(name);
        c.setVisitsPerMonth(visitsPerMonth);
        return c;
    }
}
