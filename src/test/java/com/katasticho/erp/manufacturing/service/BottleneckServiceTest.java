package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.entity.Operation;
import com.katasticho.erp.manufacturing.entity.Workstation;
import com.katasticho.erp.manufacturing.repository.JobCardRepository;
import com.katasticho.erp.manufacturing.repository.OperationRepository;
import com.katasticho.erp.manufacturing.repository.WorkstationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BottleneckServiceTest {

    @Mock private JobCardRepository jobCardRepo;
    @Mock private OperationRepository operationRepo;
    @Mock private WorkstationRepository workstationRepo;

    private BottleneckService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID wsAId = UUID.randomUUID();
    private final UUID wsBId = UUID.randomUUID();
    private final UUID opAId = UUID.randomUUID();
    private final UUID opBId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new BottleneckService(jobCardRepo, operationRepo, workstationRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private Workstation ws(UUID id, String code, BigDecimal capacity) {
        Workstation w = Workstation.builder()
                .code(code).name("WS-" + code)
                .capacityHoursPerDay(capacity)
                .hourlyRate(BigDecimal.valueOf(200))
                .build();
        w.setId(id);
        w.setOrgId(orgId);
        return w;
    }

    private Operation op(UUID id, int setupMin, BigDecimal runMinPerUnit) {
        Operation o = Operation.builder()
                .code("OP-" + id.toString().substring(0, 4))
                .name("Op")
                .setupTimeMinutes(setupMin)
                .runTimeMinutesPerUnit(runMinPerUnit)
                .build();
        o.setId(id);
        o.setOrgId(orgId);
        return o;
    }

    private JobCard jc(UUID wsId, UUID opId, String status, BigDecimal plannedQty) {
        JobCard j = JobCard.builder()
                .workOrderId(UUID.randomUUID())
                .operationId(opId)
                .workstationId(wsId)
                .plannedQty(plannedQty)
                .status(status)
                .build();
        j.setOrgId(orgId);
        return j;
    }

    @Test
    void workstationLoadReport_sumsHoursPerWorkstation_andSortsByQueueDesc() {
        // Workstation A: 8h/day. Workstation B: 8h/day.
        Workstation a = ws(wsAId, "A", BigDecimal.valueOf(8));
        Workstation b = ws(wsBId, "B", BigDecimal.valueOf(8));
        // Op A: 30min setup + 5min/unit. Op B: 0 setup + 1min/unit.
        Operation opA = op(opAId, 30, new BigDecimal("5"));
        Operation opB = op(opBId, 0, new BigDecimal("1"));

        // 2 JCs on A: 100 units each → 30 + 500 = 530 min each → 1060 min = 17.67h
        JobCard jc1 = jc(wsAId, opAId, "PENDING", new BigDecimal("100"));
        JobCard jc2 = jc(wsAId, opAId, "IN_PROGRESS", new BigDecimal("100"));
        // 1 JC on B: 100 units → 100 min = 1.67h
        JobCard jc3 = jc(wsBId, opBId, "PENDING", new BigDecimal("100"));

        when(jobCardRepo.findOpenForOrg(orgId)).thenReturn(List.of(jc1, jc2, jc3));
        when(operationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(opA, opB));
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a, b));

        List<Map<String, Object>> rows = service.workstationLoadReport();

        assertEquals(2, rows.size());
        // A first (heavier load)
        assertEquals(wsAId, rows.get(0).get("workstationId"));
        assertEquals(0, ((BigDecimal) rows.get(0).get("queuedHours"))
                .compareTo(new BigDecimal("17.67")));
        assertEquals(2, rows.get(0).get("openJobCards"));
        assertEquals(1, rows.get(0).get("inProgressJobCards"));
        // 17.67h / 8h = 2.21 days
        assertEquals(0, ((BigDecimal) rows.get(0).get("daysOfWork"))
                .compareTo(new BigDecimal("2.21")));
        // 2.21 days > 1 → BUSY (not yet 5 days → BOTTLENECK)
        assertEquals("BUSY", rows.get(0).get("status"));

        // B second
        assertEquals(wsBId, rows.get(1).get("workstationId"));
        assertEquals(0, ((BigDecimal) rows.get(1).get("queuedHours"))
                .compareTo(new BigDecimal("1.67")));
        assertEquals("OK", rows.get(1).get("status"));
    }

    @Test
    void workstationLoadReport_workstationWithNoOpenJobs_appearsAsIdle() {
        Workstation a = ws(wsAId, "A", BigDecimal.valueOf(8));

        when(jobCardRepo.findOpenForOrg(orgId)).thenReturn(List.of());
        when(operationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of());
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a));

        List<Map<String, Object>> rows = service.workstationLoadReport();

        assertEquals(1, rows.size());
        assertEquals("IDLE", rows.get(0).get("status"));
        assertEquals(0, rows.get(0).get("openJobCards"));
    }

    @Test
    void workstationLoadReport_workstationOverFiveDaysQueued_markedBottleneck() {
        Workstation a = ws(wsAId, "A", BigDecimal.valueOf(8)); // 8h/day
        Operation opA = op(opAId, 0, new BigDecimal("1"));

        // 3000 units × 1 min = 3000 min = 50h → 50/8 = 6.25 days
        JobCard jc1 = jc(wsAId, opAId, "PENDING", new BigDecimal("3000"));

        when(jobCardRepo.findOpenForOrg(orgId)).thenReturn(List.of(jc1));
        when(operationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(opA));
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a));

        List<Map<String, Object>> rows = service.workstationLoadReport();

        assertEquals(1, rows.size());
        assertEquals("BOTTLENECK", rows.get(0).get("status"));
        assertEquals(0, ((BigDecimal) rows.get(0).get("daysOfWork"))
                .compareTo(new BigDecimal("6.25")));
    }

    @Test
    void topBottlenecks_filtersOutIdleWorkstations() {
        Workstation a = ws(wsAId, "A", BigDecimal.valueOf(8));
        Workstation b = ws(wsBId, "B", BigDecimal.valueOf(8));
        Operation opA = op(opAId, 0, new BigDecimal("1"));
        // Only A has work, B is idle
        JobCard jc1 = jc(wsAId, opAId, "PENDING", new BigDecimal("60"));

        when(jobCardRepo.findOpenForOrg(orgId)).thenReturn(List.of(jc1));
        when(operationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(opA));
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a, b));

        List<Map<String, Object>> top = service.topBottlenecks(5);

        // B (IDLE) filtered out; A surfaces only
        assertEquals(1, top.size());
        assertEquals(wsAId, top.get(0).get("workstationId"));
    }

    @Test
    void workstationLoadReport_jobCardWithUnknownOperation_skipped() {
        Workstation a = ws(wsAId, "A", BigDecimal.valueOf(8));
        // JobCard refers to opAId but the operation map is empty
        JobCard jc1 = jc(wsAId, opAId, "PENDING", new BigDecimal("100"));

        when(jobCardRepo.findOpenForOrg(orgId)).thenReturn(List.of(jc1));
        when(operationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of());
        when(workstationRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a));

        List<Map<String, Object>> rows = service.workstationLoadReport();

        // A appears (idle) — orphan job card silently dropped
        assertEquals(1, rows.size());
        assertEquals(0, rows.get(0).get("openJobCards"));
        assertEquals("IDLE", rows.get(0).get("status"));
    }
}
