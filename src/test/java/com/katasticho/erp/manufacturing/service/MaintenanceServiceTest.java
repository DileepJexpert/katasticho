package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.MaintenanceSchedule;
import com.katasticho.erp.manufacturing.entity.MaintenanceWorkOrder;
import com.katasticho.erp.manufacturing.entity.Workstation;
import com.katasticho.erp.manufacturing.repository.MaintenanceScheduleRepository;
import com.katasticho.erp.manufacturing.repository.MaintenanceWorkOrderRepository;
import com.katasticho.erp.manufacturing.repository.WorkstationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.*;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MaintenanceServiceTest {

    @Mock private MaintenanceScheduleRepository scheduleRepo;
    @Mock private MaintenanceWorkOrderRepository woRepo;
    @Mock private WorkstationRepository workstationRepo;

    private MaintenanceService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID wsId = UUID.randomUUID();

    // Fixed clock at 2026-06-17 10:00 UTC so date math is deterministic.
    private final Clock clock = Clock.fixed(
            Instant.parse("2026-06-17T10:00:00Z"), ZoneOffset.UTC);

    @BeforeEach
    void setUp() {
        service = new MaintenanceService(scheduleRepo, woRepo, workstationRepo, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        Workstation ws = Workstation.builder()
                .code("WS-01").name("CNC Lathe").build();
        ws.setId(wsId);
        ws.setOrgId(orgId);
        lenient().when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(wsId, orgId))
                .thenReturn(Optional.of(ws));
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    // ─────── Schedules ───────

    @Test
    void createSchedule_defaultsNextDueFromToday_plusFrequency() {
        when(scheduleRepo.save(any(MaintenanceSchedule.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        MaintenanceSchedule input = MaintenanceSchedule.builder()
                .workstationId(wsId)
                .code("PM-CNC-01")
                .title("Spindle lube")
                .frequencyDays(30)
                .build();

        MaintenanceSchedule saved = service.createSchedule(input);

        assertEquals(orgId, saved.getOrgId());
        assertEquals(LocalDate.of(2026, 7, 17), saved.getNextDueDate(),
                "nextDueDate should default to today+frequency");
        assertTrue(saved.isActive());
    }

    @Test
    void createSchedule_badFrequency_throws() {
        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.createSchedule(MaintenanceSchedule.builder()
                        .workstationId(wsId).title("X").frequencyDays(0).build()));
        assertEquals("MAINTENANCE_BAD_FREQUENCY", ex.getErrorCode());
    }

    @Test
    void createSchedule_duplicateCode_throwsConflict() {
        MaintenanceSchedule existing = MaintenanceSchedule.builder()
                .workstationId(wsId).code("PM-1").title("X").frequencyDays(7).build();
        when(scheduleRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "PM-1"))
                .thenReturn(Optional.of(existing));

        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.createSchedule(MaintenanceSchedule.builder()
                        .workstationId(wsId).code("PM-1").title("Y").frequencyDays(7).build()));
        assertEquals("MAINTENANCE_DUPLICATE_CODE", ex.getErrorCode());
    }

    @Test
    void generateWorkOrdersForDueSchedules_createsDraftWoPerDueSchedule() {
        MaintenanceSchedule s1 = scheduleWithId(UUID.randomUUID(), "PM-1", 30,
                LocalDate.of(2026, 6, 17));
        MaintenanceSchedule s2 = scheduleWithId(UUID.randomUUID(), "PM-2", 30,
                LocalDate.of(2026, 6, 10));
        when(scheduleRepo
                .findByOrgIdAndIsDeletedFalseAndActiveTrueAndNextDueDateLessThanEqualOrderByNextDueDateAsc(
                        any(), any()))
                .thenReturn(List.of(s1, s2));
        when(woRepo.findByOrgIdAndIsDeletedFalseOrderByReportedAtDesc(orgId))
                .thenReturn(List.of());
        when(woRepo.findTopByOrgIdAndMwoNumberStartingWithOrderByMwoNumberDesc(any(), any()))
                .thenReturn(Optional.empty());
        when(woRepo.save(any(MaintenanceWorkOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        List<MaintenanceWorkOrder> created = service.generateWorkOrdersForDueSchedules(
                LocalDate.of(2026, 6, 17));

        assertEquals(2, created.size());
        assertEquals("PREVENTIVE", created.get(0).getMaintenanceType());
        assertEquals("DRAFT", created.get(0).getStatus());
        assertEquals(s1.getId(), created.get(0).getScheduleId());
        assertTrue(created.get(0).getMwoNumber().startsWith("MWO-2026-"));
    }

    @Test
    void generateWorkOrdersForDueSchedules_skipsSchedulesWithOpenWo() {
        MaintenanceSchedule s = scheduleWithId(UUID.randomUUID(), "PM-1", 30,
                LocalDate.of(2026, 6, 17));
        when(scheduleRepo
                .findByOrgIdAndIsDeletedFalseAndActiveTrueAndNextDueDateLessThanEqualOrderByNextDueDateAsc(
                        any(), any()))
                .thenReturn(List.of(s));

        MaintenanceWorkOrder existingOpen = MaintenanceWorkOrder.builder()
                .scheduleId(s.getId()).status("DRAFT")
                .build();
        existingOpen.setOrgId(orgId);
        when(woRepo.findByOrgIdAndIsDeletedFalseOrderByReportedAtDesc(orgId))
                .thenReturn(List.of(existingOpen));

        List<MaintenanceWorkOrder> created = service.generateWorkOrdersForDueSchedules(null);

        assertTrue(created.isEmpty());
        verify(woRepo, never()).save(any());
    }

    // ─────── Work order lifecycle ───────

    @Test
    void createWorkOrder_assignsNumberAndDraftStatus() {
        when(woRepo.findTopByOrgIdAndMwoNumberStartingWithOrderByMwoNumberDesc(any(), any()))
                .thenReturn(Optional.empty());
        when(woRepo.save(any(MaintenanceWorkOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                .workstationId(wsId)
                .maintenanceType("BREAKDOWN")
                .title("Pump leak")
                .build();

        MaintenanceWorkOrder saved = service.createWorkOrder(wo);

        assertEquals(orgId, saved.getOrgId());
        assertEquals("DRAFT", saved.getStatus());
        assertEquals("NORMAL", saved.getPriority());
        assertEquals("MWO-2026-00001", saved.getMwoNumber());
        assertNull(saved.getStartedAt());
        assertNull(saved.getCompletedAt());
    }

    @Test
    void createWorkOrder_badType_throws() {
        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.createWorkOrder(MaintenanceWorkOrder.builder()
                        .workstationId(wsId).maintenanceType("EMERGENCY").title("X").build()));
        assertEquals("MAINTENANCE_BAD_TYPE", ex.getErrorCode());
    }

    @Test
    void startWorkOrder_setsStartedAtAndInProgress() {
        UUID woId = UUID.randomUUID();
        MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                .workstationId(wsId).maintenanceType("PREVENTIVE")
                .title("X").status("DRAFT").build();
        wo.setId(woId);
        wo.setOrgId(orgId);
        when(woRepo.findByIdAndOrgIdAndIsDeletedFalse(woId, orgId))
                .thenReturn(Optional.of(wo));
        when(woRepo.save(any(MaintenanceWorkOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        MaintenanceWorkOrder started = service.startWorkOrder(woId);

        assertEquals("IN_PROGRESS", started.getStatus());
        assertEquals(Instant.parse("2026-06-17T10:00:00Z"), started.getStartedAt());
    }

    @Test
    void startWorkOrder_notDraft_throws() {
        UUID woId = UUID.randomUUID();
        MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                .workstationId(wsId).maintenanceType("PREVENTIVE")
                .title("X").status("IN_PROGRESS").build();
        wo.setId(woId);
        wo.setOrgId(orgId);
        when(woRepo.findByIdAndOrgIdAndIsDeletedFalse(woId, orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.startWorkOrder(woId));
        assertEquals("MAINTENANCE_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void completeWorkOrder_computesDowntime_andRollsScheduleForward() {
        UUID woId = UUID.randomUUID();
        UUID schId = UUID.randomUUID();

        // Started 45 minutes before the fixed clock now (2026-06-17T10:00Z).
        MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                .workstationId(wsId).maintenanceType("PREVENTIVE")
                .title("Spindle lube")
                .scheduleId(schId)
                .status("IN_PROGRESS")
                .startedAt(Instant.parse("2026-06-17T09:15:00Z"))
                .build();
        wo.setId(woId);
        wo.setOrgId(orgId);

        MaintenanceSchedule sch = MaintenanceSchedule.builder()
                .workstationId(wsId).code("PM-1").title("Spindle lube")
                .frequencyDays(30).nextDueDate(LocalDate.of(2026, 6, 17))
                .build();
        sch.setId(schId);
        sch.setOrgId(orgId);

        when(woRepo.findByIdAndOrgIdAndIsDeletedFalse(woId, orgId)).thenReturn(Optional.of(wo));
        when(scheduleRepo.findByIdAndOrgIdAndIsDeletedFalse(schId, orgId)).thenReturn(Optional.of(sch));
        when(woRepo.save(any(MaintenanceWorkOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(scheduleRepo.save(any(MaintenanceSchedule.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        MaintenanceWorkOrder done = service.completeWorkOrder(woId, "Replaced filter", new BigDecimal("250"));

        assertEquals("COMPLETED", done.getStatus());
        assertEquals(45, done.getDowntimeMinutes());
        assertEquals(0, done.getCost().compareTo(new BigDecimal("250")));
        assertEquals(userId, done.getCompletedBy());

        // Schedule rolled forward
        ArgumentCaptor<MaintenanceSchedule> cap = ArgumentCaptor.forClass(MaintenanceSchedule.class);
        verify(scheduleRepo).save(cap.capture());
        MaintenanceSchedule updated = cap.getValue();
        assertEquals(LocalDate.of(2026, 6, 17), updated.getLastCompletedDate());
        assertEquals(LocalDate.of(2026, 7, 17), updated.getNextDueDate());
    }

    @Test
    void completeWorkOrder_notInProgress_throws() {
        UUID woId = UUID.randomUUID();
        MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                .workstationId(wsId).maintenanceType("PREVENTIVE")
                .title("X").status("DRAFT").build();
        wo.setId(woId);
        wo.setOrgId(orgId);
        when(woRepo.findByIdAndOrgIdAndIsDeletedFalse(woId, orgId)).thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.completeWorkOrder(woId, null, null));
        assertEquals("MAINTENANCE_NOT_IN_PROGRESS", ex.getErrorCode());
    }

    @Test
    void cancelWorkOrder_completed_throws() {
        UUID woId = UUID.randomUUID();
        MaintenanceWorkOrder wo = MaintenanceWorkOrder.builder()
                .workstationId(wsId).maintenanceType("PREVENTIVE")
                .title("X").status("COMPLETED").build();
        wo.setId(woId);
        wo.setOrgId(orgId);
        when(woRepo.findByIdAndOrgIdAndIsDeletedFalse(woId, orgId)).thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancelWorkOrder(woId, null));
        assertEquals("MAINTENANCE_FINAL_STATE", ex.getErrorCode());
    }

    // ─────── Downtime report ───────

    @Test
    void downtimeReport_aggregatesByWorkstation_sortedByMinutesDesc() {
        UUID wsId2 = UUID.randomUUID();
        Workstation ws2 = Workstation.builder().code("WS-02").name("Press").build();
        ws2.setId(wsId2);
        ws2.setOrgId(orgId);
        lenient().when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(wsId2, orgId))
                .thenReturn(Optional.of(ws2));

        MaintenanceWorkOrder a = completed(wsId, "PREVENTIVE", 60, "100");
        MaintenanceWorkOrder b = completed(wsId, "BREAKDOWN", 120, "500");
        MaintenanceWorkOrder c = completed(wsId2, "PREVENTIVE", 30, "50");
        when(woRepo
                .findByOrgIdAndStatusAndCompletedAtBetweenAndIsDeletedFalseOrderByCompletedAtAsc(
                        any(), any(), any(), any()))
                .thenReturn(List.of(a, b, c));

        Map<String, Object> report = service.downtimeReport(
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30));

        assertEquals(210L, ((Long) report.get("totalMinutes")));
        assertEquals(3, report.get("totalCount"));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) report.get("items");
        assertEquals(2, items.size());
        // wsId has 60 + 120 = 180 -> first
        assertEquals(wsId, items.get(0).get("workstationId"));
        assertEquals(180L, items.get(0).get("totalMinutes"));
        assertEquals(2, items.get(0).get("count"));
        @SuppressWarnings("unchecked")
        Map<String, Integer> types = (Map<String, Integer>) items.get(0).get("types");
        assertEquals(1, types.get("PREVENTIVE"));
        assertEquals(1, types.get("BREAKDOWN"));
        assertEquals(0, ((BigDecimal) items.get(0).get("totalCost")).compareTo(new BigDecimal("600")));
        // wsId2 with 30 minutes -> second
        assertEquals(wsId2, items.get(1).get("workstationId"));
        assertEquals(30L, items.get(1).get("totalMinutes"));
    }

    // ─────── Reliability report (#86 MTBF/MTTR) ───────

    @Test
    void reliabilityReport_computesMttrMtbfAndAvailability() {
        // Workstation has 1 BREAKDOWN (90 min) + 1 PREVENTIVE (30 min) in the window
        Workstation ws = Workstation.builder().code("WS-01").name("CNC Lathe").build();
        ws.setId(wsId); ws.setOrgId(orgId);
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(ws));

        MaintenanceWorkOrder breakdown = completed(wsId, "BREAKDOWN", 90, "500");
        MaintenanceWorkOrder preventive = completed(wsId, "PREVENTIVE", 30, "100");
        when(woRepo
                .findByOrgIdAndStatusAndCompletedAtBetweenAndIsDeletedFalseOrderByCompletedAtAsc(
                        any(), any(), any(), any()))
                .thenReturn(List.of(breakdown, preventive));

        // 1-day window = 1440 minutes
        Map<String, Object> report = service.reliabilityReport(
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 1));

        assertEquals(1440L, report.get("windowMinutes"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) report.get("items");
        assertEquals(1, items.size());
        Map<String, Object> row = items.get(0);

        assertEquals(1, row.get("breakdownCount"));
        assertEquals(1, row.get("preventiveCount"));
        // Downtime = 90 + 30 = 120 min
        assertEquals(120L, row.get("totalDowntimeMinutes"));
        // Uptime = 1440 − 120 = 1320 min
        assertEquals(1320L, row.get("uptimeMinutes"));
        // MTTR = 90 / 1 = 90 (uses BREAKDOWN downtime only)
        assertEquals(90L, row.get("mttrMinutes"));
        // MTBF = 1320 / 1 = 1320
        assertEquals(1320L, row.get("mtbfMinutes"));
        // Availability = 1320 / 1440 * 100 = 91.67
        assertEquals(0, ((BigDecimal) row.get("availabilityPct"))
                .compareTo(new BigDecimal("91.67")));
    }

    @Test
    void reliabilityReport_workstationWithNoBreakdowns_returns100PctAvailabilityAndNullMtbf() {
        Workstation ws = Workstation.builder().code("WS-01").name("CNC Lathe").build();
        ws.setId(wsId); ws.setOrgId(orgId);
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(ws));
        when(woRepo
                .findByOrgIdAndStatusAndCompletedAtBetweenAndIsDeletedFalseOrderByCompletedAtAsc(
                        any(), any(), any(), any()))
                .thenReturn(List.of());

        Map<String, Object> report = service.reliabilityReport(
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) report.get("items");
        assertEquals(1, items.size());
        assertEquals(0, items.get(0).get("breakdownCount"));
        assertNull(items.get(0).get("mttrMinutes"));
        assertNull(items.get(0).get("mtbfMinutes"));
        assertEquals(0, ((BigDecimal) items.get(0).get("availabilityPct"))
                .compareTo(new BigDecimal("100.00")));
    }

    @Test
    void reliabilityReport_sortsByAvailabilityAsc_worstMachineFirst() {
        UUID wsB = UUID.randomUUID();
        Workstation a = Workstation.builder().code("WS-A").name("A").build();
        a.setId(wsId); a.setOrgId(orgId);
        Workstation b = Workstation.builder().code("WS-B").name("B").build();
        b.setId(wsB); b.setOrgId(orgId);
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a, b));

        // A: 240 min downtime (worse)
        // B: 60 min downtime
        MaintenanceWorkOrder aBreak = completed(wsId, "BREAKDOWN", 240, "100");
        MaintenanceWorkOrder bBreak = completed(wsB, "BREAKDOWN", 60, "50");
        when(woRepo
                .findByOrgIdAndStatusAndCompletedAtBetweenAndIsDeletedFalseOrderByCompletedAtAsc(
                        any(), any(), any(), any()))
                .thenReturn(List.of(aBreak, bBreak));

        Map<String, Object> report = service.reliabilityReport(
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 1));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> items = (List<Map<String, Object>>) report.get("items");
        // Worst (lowest availability) first → A
        assertEquals(wsId, items.get(0).get("workstationId"));
        assertEquals(wsB, items.get(1).get("workstationId"));
    }

    // ─────── Helpers ───────

    private MaintenanceSchedule scheduleWithId(UUID id, String code, int freq, LocalDate due) {
        MaintenanceSchedule s = MaintenanceSchedule.builder()
                .workstationId(wsId).code(code).title("Schedule " + code)
                .frequencyDays(freq).nextDueDate(due).active(true).build();
        s.setId(id);
        s.setOrgId(orgId);
        return s;
    }

    private MaintenanceWorkOrder completed(UUID workstation, String type, int minutes, String cost) {
        MaintenanceWorkOrder w = MaintenanceWorkOrder.builder()
                .workstationId(workstation)
                .maintenanceType(type)
                .status("COMPLETED")
                .title("X")
                .downtimeMinutes(minutes)
                .cost(new BigDecimal(cost))
                .build();
        w.setOrgId(orgId);
        return w;
    }
}
