package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.BaseEntity;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.QcInspection;
import com.katasticho.erp.manufacturing.entity.QcInspectionResult;
import com.katasticho.erp.manufacturing.entity.QcTemplate;
import com.katasticho.erp.manufacturing.repository.QcInspectionRepository;
import com.katasticho.erp.manufacturing.repository.QcInspectionResultRepository;
import com.katasticho.erp.manufacturing.repository.QcParameterRepository;
import com.katasticho.erp.manufacturing.repository.QcTemplateRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class QualityControlServiceTest {

    @Mock private QcTemplateRepository templateRepository;
    @Mock private QcParameterRepository parameterRepository;
    @Mock private QcInspectionRepository inspectionRepository;
    @Mock private QcInspectionResultRepository resultRepository;

    private QualityControlService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID itemId = UUID.randomUUID();
    private final UUID templateId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new QualityControlService(
                templateRepository, parameterRepository, inspectionRepository, resultRepository);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── createTemplate ───────────────────────────────────────────

    @Test
    void createTemplate_withParameters_correctCount() {
        List<QualityControlService.QcParameterInput> params = List.of(
                new QualityControlService.QcParameterInput(
                        "Weight", "Measure weight", "NUMERIC", "kg",
                        BigDecimal.valueOf(90), BigDecimal.valueOf(110), null, true),
                new QualityControlService.QcParameterInput(
                        "Color", "Visual check", "TEXT", null,
                        null, null, "WHITE,OFF_WHITE", true)
        );

        when(templateRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });

        QcTemplate result = service.createTemplate("Tablet QC", itemId, "INCOMING", params);

        assertNotNull(result.getId());
        assertEquals("Tablet QC", result.getName());
        assertEquals("INCOMING", result.getInspectionType());
        assertEquals(2, result.getParameters().size());
        assertEquals("Weight", result.getParameters().get(0).getName());
        assertEquals(1, result.getParameters().get(0).getSequenceNumber());
        assertEquals("Color", result.getParameters().get(1).getName());
        assertEquals(2, result.getParameters().get(1).getSequenceNumber());
        // save called twice: once for initial template, once after adding parameters
        verify(templateRepository, times(2)).save(any());
    }

    @Test
    void createTemplate_nullParameters_emptyList() {
        when(templateRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });

        QcTemplate result = service.createTemplate("Empty Template", itemId, "IN_PROCESS", null);

        assertNotNull(result.getId());
        assertEquals("Empty Template", result.getName());
        assertTrue(result.getParameters().isEmpty());
        // save called only once (no parameters to add)
        verify(templateRepository, times(1)).save(any());
    }

    // ── createInspection ─────────────────────────────────────────

    @Test
    void createInspection_generatesInspectionNumber() {
        when(inspectionRepository.count()).thenReturn(4L);
        when(inspectionRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });

        UUID batchId = UUID.randomUUID();
        UUID referenceId = UUID.randomUUID();

        QcInspection result = service.createInspection(
                templateId, "INCOMING", "WORK_ORDER", referenceId,
                itemId, batchId, BigDecimal.valueOf(100));

        assertNotNull(result.getId());
        assertEquals("QC-00005", result.getInspectionNumber());
        assertEquals("PENDING", result.getStatus());
        assertEquals(templateId, result.getTemplateId());
        assertEquals(itemId, result.getItemId());
        assertEquals(batchId, result.getBatchId());
        assertEquals(0, BigDecimal.valueOf(100).compareTo(result.getInspectedQty()));
        assertTrue(result.getResults().isEmpty());
    }

    // ── recordResults ────────────────────────────────────────────

    @Test
    void recordResults_addsResults_setsInProgress() {
        QcInspection inspection = buildInspection("PENDING");
        UUID paramId1 = UUID.randomUUID();
        UUID paramId2 = UUID.randomUUID();

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        List<QualityControlService.QcResultInput> inputs = List.of(
                new QualityControlService.QcResultInput(paramId1, "98.5", BigDecimal.valueOf(98.5), true, null),
                new QualityControlService.QcResultInput(paramId2, "WHITE", null, true, "Good color")
        );

        QcInspection result = service.recordResults(inspection.getId(), inputs);

        assertEquals("IN_PROGRESS", result.getStatus());
        assertEquals(userId, result.getInspectorId());
        assertEquals(2, result.getResults().size());
        assertEquals(paramId1, result.getResults().get(0).getParameterId());
        assertEquals(paramId2, result.getResults().get(1).getParameterId());
    }

    @Test
    void recordResults_alreadyFinalized_throws() {
        QcInspection inspection = buildInspection("PASSED");

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));

        List<QualityControlService.QcResultInput> inputs = List.of(
                new QualityControlService.QcResultInput(UUID.randomUUID(), "99", BigDecimal.valueOf(99), true, null)
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordResults(inspection.getId(), inputs));
        assertEquals("QC_ALREADY_FINALIZED", ex.getErrorCode());
    }

    // ── finalizeInspection ───────────────────────────────────────

    @Test
    void finalizeInspection_allPass_statusPassed() {
        QcInspection inspection = buildInspection("IN_PROGRESS");
        inspection.getResults().add(buildResult(inspection, true));
        inspection.getResults().add(buildResult(inspection, true));

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        QcInspection result = service.finalizeInspection(
                inspection.getId(), BigDecimal.valueOf(100), BigDecimal.ZERO, "All good");

        assertEquals("PASSED", result.getStatus());
        assertEquals(0, BigDecimal.valueOf(100).compareTo(result.getAcceptedQty()));
        assertEquals(0, BigDecimal.ZERO.compareTo(result.getRejectedQty()));
        assertNotNull(result.getInspectedAt());
        assertEquals("All good", result.getNotes());
    }

    @Test
    void finalizeInspection_anyFail_statusFailed() {
        QcInspection inspection = buildInspection("IN_PROGRESS");
        inspection.getResults().add(buildResult(inspection, true));
        inspection.getResults().add(buildResult(inspection, false));

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // No rejected qty passed, but a result has isPassed=false
        QcInspection result = service.finalizeInspection(
                inspection.getId(), BigDecimal.ZERO, BigDecimal.ZERO, null);

        assertEquals("FAILED", result.getStatus());
    }

    @Test
    void finalizeInspection_rejectedAndAccepted_statusPartial() {
        QcInspection inspection = buildInspection("IN_PROGRESS");
        inspection.getResults().add(buildResult(inspection, true));

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        QcInspection result = service.finalizeInspection(
                inspection.getId(), BigDecimal.valueOf(80), BigDecimal.valueOf(20), "Partial pass");

        assertEquals("PARTIAL", result.getStatus());
        assertEquals(0, BigDecimal.valueOf(80).compareTo(result.getAcceptedQty()));
        assertEquals(0, BigDecimal.valueOf(20).compareTo(result.getRejectedQty()));
    }

    // ── helpers ──────────────────────────────────────────────────

    private QcInspection buildInspection(String status) {
        QcInspection inspection = QcInspection.builder()
                .inspectionNumber("QC-00001")
                .templateId(templateId)
                .inspectionType("INCOMING")
                .itemId(itemId)
                .inspectedQty(BigDecimal.valueOf(100))
                .acceptedQty(BigDecimal.ZERO)
                .rejectedQty(BigDecimal.ZERO)
                .status(status)
                .results(new ArrayList<>())
                .build();
        inspection.setId(UUID.randomUUID());
        inspection.setOrgId(orgId);
        return inspection;
    }

    private QcInspectionResult buildResult(QcInspection inspection, boolean passed) {
        QcInspectionResult result = QcInspectionResult.builder()
                .inspection(inspection)
                .parameterId(UUID.randomUUID())
                .measuredValue(passed ? "OK" : "FAIL")
                .isPassed(passed)
                .build();
        result.setId(UUID.randomUUID());
        result.setOrgId(orgId);
        return result;
    }
}
