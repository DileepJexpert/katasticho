package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.BmrDeviation;
import com.katasticho.erp.manufacturing.entity.BmrSignoff;
import com.katasticho.erp.manufacturing.entity.BmrStepRecord;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.BmrDeviationRepository;
import com.katasticho.erp.manufacturing.repository.BmrSignoffRepository;
import com.katasticho.erp.manufacturing.repository.BmrStepRecordRepository;
import com.katasticho.erp.manufacturing.repository.JobCardRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BmrServiceTest {

    @Mock private BmrStepRecordRepository stepRecordRepo;
    @Mock private BmrSignoffRepository signoffRepo;
    @Mock private BmrDeviationRepository deviationRepo;
    @Mock private WorkOrderRepository workOrderRepo;
    @Mock private JobCardRepository jobCardRepo;

    private BmrService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new BmrService(stepRecordRepo, signoffRepo, deviationRepo,
                workOrderRepo, jobCardRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private WorkOrder wo(String status, double planned, double produced) {
        WorkOrder w = WorkOrder.builder()
                .workOrderNumber("WO-0001")
                .quantityToProduce(BigDecimal.valueOf(planned))
                .quantityProduced(BigDecimal.valueOf(produced))
                .status(status)
                .lines(new java.util.ArrayList<>())
                .build();
        w.setId(UUID.randomUUID());
        w.setOrgId(orgId);
        return w;
    }

    // ── Step records ──────────────────────────────────────────────

    @Test
    void recordStepParameter_savesWithOrgAndObserver() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));
        when(stepRecordRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        BmrStepRecord saved = service.recordStepParameter(w.getId(), null,
                "granulation_temp", "65", "C", null);

        assertEquals("granulation_temp", saved.getParameterKey());
        assertEquals("65", saved.getParameterValue());
        assertEquals(orgId, saved.getOrgId());
        assertEquals(userId, saved.getObservedBy());
    }

    @Test
    void recordStepParameter_emptyKey_throws() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordStepParameter(w.getId(), null, "", "65", "C", null));
        assertEquals("BMR_PARAM_KEY_REQUIRED", ex.getErrorCode());
    }

    @Test
    void recordStepParameter_jobCardFromDifferentWo_throws() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));
        // Job card belongs to a DIFFERENT WO.
        UUID otherWoId = UUID.randomUUID();
        UUID jcId = UUID.randomUUID();
        JobCard jc = JobCard.builder()
                .workOrderId(otherWoId).operationId(UUID.randomUUID())
                .sequenceNumber(1).build();
        jc.setId(jcId);
        jc.setOrgId(orgId);
        when(jobCardRepo.findByIdAndOrgIdAndIsDeletedFalse(jcId, orgId))
                .thenReturn(Optional.of(jc));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordStepParameter(w.getId(), jcId, "temp", "65", "C", null));
        assertEquals("BMR_JC_WO_MISMATCH", ex.getErrorCode());
    }

    // ── Signoffs ──────────────────────────────────────────────────

    @Test
    void recordSignoff_validRole_savesWithUserAndOrg() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));
        when(signoffRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        BmrSignoff saved = service.recordSignoff(w.getId(), null, "supervisor", null);

        // Role is normalised to upper case.
        assertEquals("SUPERVISOR", saved.getRole());
        assertEquals(userId, saved.getSignedBy());
        assertEquals(orgId, saved.getOrgId());
    }

    @Test
    void recordSignoff_invalidRole_throws() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordSignoff(w.getId(), null, "JUNIOR_OPERATOR", null));
        assertEquals("BMR_SIGNOFF_INVALID_ROLE", ex.getErrorCode());
    }

    // ── Deviations ────────────────────────────────────────────────

    @Test
    void logDeviation_validSeverity_savesAsOPEN() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));
        when(deviationRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        BmrDeviation saved = service.logDeviation(w.getId(), null, "major",
                "Granulation temp exceeded", "Hit 75°C, spec is 65±3");

        assertEquals("MAJOR", saved.getSeverity());
        assertEquals("OPEN", saved.getStatus());
        assertEquals(userId, saved.getReportedBy());
    }

    @Test
    void logDeviation_emptyTitle_throws() {
        WorkOrder w = wo("IN_PROGRESS", 100, 0);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.logDeviation(w.getId(), null, "MINOR", "", "x"));
        assertEquals("BMR_DEVIATION_TITLE_REQUIRED", ex.getErrorCode());
    }

    @Test
    void resolveDeviation_RESOLVED_stampsResolvedByAndAt() {
        UUID devId = UUID.randomUUID();
        BmrDeviation dev = BmrDeviation.builder()
                .workOrderId(UUID.randomUUID())
                .severity("MAJOR").title("x")
                .status("INVESTIGATING")
                .build();
        dev.setId(devId);
        dev.setOrgId(orgId);
        when(deviationRepo.findByIdAndOrgIdAndIsDeletedFalse(devId, orgId))
                .thenReturn(Optional.of(dev));
        when(deviationRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        BmrDeviation saved = service.resolveDeviation(devId, "RESOLVED",
                "Recalibrated temp probe; re-validated step.");

        assertEquals("RESOLVED", saved.getStatus());
        assertEquals(userId, saved.getResolvedBy());
        assertNotNull(saved.getResolvedAt());
    }

    @Test
    void resolveDeviation_invalidStatus_throws() {
        UUID devId = UUID.randomUUID();
        BmrDeviation dev = BmrDeviation.builder()
                .workOrderId(UUID.randomUUID())
                .severity("MAJOR").title("x")
                .status("OPEN").build();
        dev.setId(devId);
        dev.setOrgId(orgId);
        when(deviationRepo.findByIdAndOrgIdAndIsDeletedFalse(devId, orgId))
                .thenReturn(Optional.of(dev));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.resolveDeviation(devId, "WONTFIX", null));
        assertEquals("BMR_DEVIATION_INVALID_STATUS", ex.getErrorCode());
    }

    // ── Yield reconciliation ──────────────────────────────────────

    @Test
    void yieldReconciliation_completedAtSpec_withinTolerance() {
        WorkOrder w = wo("COMPLETED", 100, 99);   // 1% under = within ±2%
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));

        Map<String, Object> result = service.yieldReconciliation(w.getId());

        assertEquals("WITHIN_TOLERANCE", result.get("status"));
        assertEquals(0, ((BigDecimal) result.get("yieldPercent"))
                .compareTo(new BigDecimal("99.00")));
        assertEquals(0, ((BigDecimal) result.get("deviationPercent"))
                .compareTo(new BigDecimal("1.00")));
    }

    @Test
    void yieldReconciliation_completedUnderYield_outOfTolerance() {
        WorkOrder w = wo("COMPLETED", 100, 90);  // 10% under
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));

        Map<String, Object> result = service.yieldReconciliation(w.getId());

        assertEquals("OUT_OF_TOLERANCE", result.get("status"));
        assertEquals(0, ((BigDecimal) result.get("deviationPercent"))
                .compareTo(new BigDecimal("10.00")));
    }

    @Test
    void yieldReconciliation_inProgress_pendingStatus() {
        WorkOrder w = wo("IN_PROGRESS", 100, 50);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));

        Map<String, Object> result = service.yieldReconciliation(w.getId());

        assertEquals("PENDING", result.get("status"));
    }

    // ── BMR snapshot ──────────────────────────────────────────────

    @Test
    void bmrSnapshot_bundlesAllSections() {
        WorkOrder w = wo("COMPLETED", 100, 99);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));
        when(jobCardRepo.findByWorkOrderIdAndOrgIdAndIsDeletedFalseOrderBySequenceNumberAsc(
                w.getId(), orgId)).thenReturn(List.of());
        when(stepRecordRepo.findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderByObservedAtAsc(
                orgId, w.getId())).thenReturn(List.of());
        when(signoffRepo.findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderBySignedAtAsc(
                orgId, w.getId())).thenReturn(List.of());
        when(deviationRepo.findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderByReportedAtAsc(
                orgId, w.getId())).thenReturn(List.of());

        Map<String, Object> snapshot = service.bmrSnapshot(w.getId());

        assertNotNull(snapshot.get("workOrder"));
        assertNotNull(snapshot.get("jobCards"));
        assertNotNull(snapshot.get("stepRecords"));
        assertNotNull(snapshot.get("signoffs"));
        assertNotNull(snapshot.get("deviations"));
        assertNotNull(snapshot.get("yieldReconciliation"));
        assertNotNull(snapshot.get("generatedAt"));
    }
}
