package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.BaseEntity;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.WarehouseZone;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseZoneRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.NonConformanceReport;
import com.katasticho.erp.manufacturing.entity.QcInspection;
import com.katasticho.erp.manufacturing.entity.QcInspectionResult;
import com.katasticho.erp.manufacturing.entity.QcParameter;
import com.katasticho.erp.manufacturing.entity.QcTemplate;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.NonConformanceReportRepository;
import com.katasticho.erp.manufacturing.repository.QcInspectionRepository;
import com.katasticho.erp.manufacturing.repository.QcInspectionResultRepository;
import com.katasticho.erp.manufacturing.repository.QcParameterRepository;
import com.katasticho.erp.manufacturing.repository.QcTemplateRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class QualityControlServiceTest {

    @Mock private QcTemplateRepository templateRepository;
    @Mock private QcParameterRepository parameterRepository;
    @Mock private QcInspectionRepository inspectionRepository;
    @Mock private QcInspectionResultRepository resultRepository;
    @Mock private NonConformanceReportRepository ncrRepository;
    @Mock private InventoryService inventoryService;
    @Mock private WorkOrderRepository workOrderRepository;
    @Mock private WarehouseZoneRepository warehouseZoneRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private StockBatchRepository stockBatchRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private com.katasticho.erp.auth.repository.AppUserRepository appUserRepository;

    private QualityControlService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID itemId = UUID.randomUUID();
    private final UUID templateId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new QualityControlService(
                templateRepository, parameterRepository, inspectionRepository, resultRepository,
                ncrRepository, inventoryService, workOrderRepository, warehouseZoneRepository,
                itemRepository, stockBatchRepository, organisationRepository, appUserRepository);
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

    // ── recordDisposition ────────────────────────────────────────

    @Test
    void recordDisposition_acceptOnFinalized_setsDispositionFields() {
        QcInspection inspection = buildInspection("PASSED");

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        QcInspection result = service.recordDisposition(inspection.getId(), "ACCEPT",
                BigDecimal.valueOf(100), BigDecimal.ZERO, BigDecimal.ZERO, null, "Looks good");

        assertEquals("ACCEPT", result.getDisposition());
        assertEquals(0, BigDecimal.valueOf(100).compareTo(result.getAcceptedQty()));
        assertEquals(0, BigDecimal.ZERO.compareTo(result.getRejectedQty()));
        assertEquals(0, BigDecimal.ZERO.compareTo(result.getHoldQty()));
        assertEquals("Looks good", result.getDispositionNotes());
        assertNotNull(result.getDispositionAt());
        assertEquals(userId, result.getDispositionBy());
        verifyNoInteractions(inventoryService);
        verifyNoInteractions(ncrRepository);
    }

    @Test
    void recordDisposition_reject_createsNcrAndStockMovement() {
        UUID workOrderId = UUID.randomUUID();
        UUID warehouseId = UUID.randomUUID();

        QcInspection inspection = buildInspection("PARTIAL");
        inspection.setReferenceType("WORK_ORDER");
        inspection.setReferenceId(workOrderId);

        WorkOrder wo = mock(WorkOrder.class);
        when(wo.getWarehouseId()).thenReturn(warehouseId);

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId))
                .thenReturn(Optional.of(wo));
        when(ncrRepository.findMaxNcrNumber(orgId)).thenReturn(0);
        when(ncrRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });

        QcInspection result = service.recordDisposition(inspection.getId(), "REJECT",
                BigDecimal.valueOf(80), BigDecimal.valueOf(20), BigDecimal.ZERO, null, "Cracked tablets");

        assertEquals("REJECT", result.getDisposition());

        ArgumentCaptor<StockMovementRequest> movementCaptor = ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(movementCaptor.capture());
        StockMovementRequest movement = movementCaptor.getValue();
        assertEquals(itemId, movement.itemId());
        assertEquals(warehouseId, movement.warehouseId());
        assertEquals(MovementType.ADJUSTMENT, movement.movementType());
        assertEquals(0, BigDecimal.valueOf(-20).compareTo(movement.quantity()));
        assertEquals(ReferenceType.STOCK_ADJUSTMENT, movement.referenceType());
        assertEquals(inspection.getId(), movement.referenceId());

        ArgumentCaptor<NonConformanceReport> ncrCaptor = ArgumentCaptor.forClass(NonConformanceReport.class);
        verify(ncrRepository).save(ncrCaptor.capture());
        NonConformanceReport ncr = ncrCaptor.getValue();
        assertEquals("NCR-00001", ncr.getNcrNumber());
        assertEquals("OPEN", ncr.getStatus());
        assertEquals("MAJOR", ncr.getSeverity());
        assertEquals(itemId, ncr.getItemId());
        assertEquals(inspection.getId(), ncr.getQcInspectionId());
        assertEquals("Cracked tablets", ncr.getReason());
    }

    @Test
    void recordDisposition_hold_recordsQuarantineZone_noMovement() {
        UUID zoneId = UUID.randomUUID();
        QcInspection inspection = buildInspection("FAILED");

        WarehouseZone zone = WarehouseZone.builder()
                .warehouseId(UUID.randomUUID()).code("QZ-1").name("Quarantine 1")
                .zoneType("QUARANTINE").build();
        zone.setId(zoneId);
        zone.setOrgId(orgId);

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(inspectionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(warehouseZoneRepository.findByIdAndOrgIdAndIsDeletedFalse(zoneId, orgId))
                .thenReturn(Optional.of(zone));

        QcInspection result = service.recordDisposition(inspection.getId(), "HOLD",
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.valueOf(100), zoneId, "Pending retest");

        assertEquals("HOLD", result.getDisposition());
        assertEquals(0, BigDecimal.valueOf(100).compareTo(result.getHoldQty()));
        assertEquals(zoneId, result.getQuarantineZoneId());
        verifyNoInteractions(inventoryService);
        verifyNoInteractions(ncrRepository);
    }

    @Test
    void recordDisposition_alreadyDispositioned_throws() {
        QcInspection inspection = buildInspection("PASSED");
        inspection.setDisposition("ACCEPT");

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordDisposition(inspection.getId(), "REJECT",
                        BigDecimal.ZERO, BigDecimal.valueOf(100), BigDecimal.ZERO, null, null));
        assertEquals("QC_ALREADY_DISPOSITIONED", ex.getErrorCode());
        verify(inspectionRepository, never()).save(any());
    }

    @Test
    void recordDisposition_qtySumMismatch_throws() {
        QcInspection inspection = buildInspection("PASSED"); // inspectedQty = 100

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordDisposition(inspection.getId(), "ACCEPT",
                        BigDecimal.valueOf(50), BigDecimal.valueOf(20), BigDecimal.ZERO, null, null));
        assertEquals("QC_DISPOSITION_QTY_MISMATCH", ex.getErrorCode());
        verify(inspectionRepository, never()).save(any());
        verifyNoInteractions(inventoryService);
    }

    @Test
    void recordDisposition_notFinalized_throws() {
        QcInspection inspection = buildInspection("IN_PROGRESS");

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordDisposition(inspection.getId(), "ACCEPT",
                        BigDecimal.valueOf(100), BigDecimal.ZERO, BigDecimal.ZERO, null, null));
        assertEquals("QC_NOT_FINALIZED", ex.getErrorCode());
    }

    // ── NCR lifecycle ────────────────────────────────────────────

    @Test
    void ncrLifecycle_createInProgressClose() {
        when(ncrRepository.findMaxNcrNumber(orgId)).thenReturn(7);
        when(ncrRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });

        // create
        NonConformanceReport ncr = service.createNcr(null, itemId, "B-001",
                "CRITICAL", "Contamination found", "Black specks in batch B-001");
        assertEquals("NCR-00008", ncr.getNcrNumber());
        assertEquals("OPEN", ncr.getStatus());
        assertEquals("CRITICAL", ncr.getSeverity());

        when(ncrRepository.findByIdAndOrgIdAndIsDeletedFalse(ncr.getId(), orgId))
                .thenReturn(Optional.of(ncr));

        // update → IN_PROGRESS with corrective action + root cause
        NonConformanceReport updated = service.updateNcr(ncr.getId(),
                "Re-clean mixing line", "Seal wear on mixer gasket", "IN_PROGRESS");
        assertEquals("IN_PROGRESS", updated.getStatus());
        assertEquals("Re-clean mixing line", updated.getCorrectiveAction());
        assertEquals("Seal wear on mixer gasket", updated.getRootCause());

        // close
        NonConformanceReport closed = service.closeNcr(ncr.getId());
        assertEquals("CLOSED", closed.getStatus());
        assertNotNull(closed.getClosedAt());
        assertEquals(userId, closed.getClosedBy());

        // closing again is rejected
        BusinessException ex = assertThrows(BusinessException.class, () -> service.closeNcr(ncr.getId()));
        assertEquals("NCR_ALREADY_CLOSED", ex.getErrorCode());
    }

    // ── Certificate of Analysis ──────────────────────────────────

    @Test
    void generateCoa_finalizedInspection_buildsDocument() {
        QcInspection inspection = buildInspection("PASSED");
        inspection.setDisposition("ACCEPT");
        inspection.setAcceptedQty(BigDecimal.valueOf(100));

        UUID paramId = UUID.randomUUID();
        QcInspectionResult result = buildResult(inspection, true);
        result.setParameterId(paramId);
        result.setMeasuredValue("98.5");
        result.setNumericValue(BigDecimal.valueOf(98.5));
        inspection.getResults().add(result);

        QcParameter param = QcParameter.builder()
                .name("Weight").unit("kg")
                .minValue(BigDecimal.valueOf(90)).maxValue(BigDecimal.valueOf(110))
                .build();
        param.setId(paramId);

        Item item = mock(Item.class);
        when(item.getName()).thenReturn("Paracetamol 500mg");
        when(item.getSku()).thenReturn("PARA-500");

        Organisation org = mock(Organisation.class);
        when(org.getName()).thenReturn("Acme Pharma");

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)).thenReturn(Optional.of(item));
        when(parameterRepository.findById(paramId)).thenReturn(Optional.of(param));

        Map<String, Object> coa = service.generateCoa(inspection.getId());

        assertEquals("CERTIFICATE_OF_ANALYSIS", coa.get("documentType"));
        assertEquals("Acme Pharma", coa.get("organisationName"));
        assertEquals("Paracetamol 500mg", coa.get("itemName"));
        assertEquals("PARA-500", coa.get("itemSku"));
        assertEquals("QC-00001", coa.get("inspectionNumber"));
        assertEquals("PASSED", coa.get("overallResult"));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> parameters = (List<Map<String, Object>>) coa.get("parameters");
        assertEquals(1, parameters.size());
        assertEquals("Weight", parameters.get(0).get("parameter"));
        assertEquals(BigDecimal.valueOf(90), parameters.get(0).get("specMin"));
        assertEquals(BigDecimal.valueOf(110), parameters.get(0).get("specMax"));
        assertEquals("98.5", parameters.get(0).get("measuredValue"));
        assertEquals(true, parameters.get(0).get("passed"));

        @SuppressWarnings("unchecked")
        Map<String, Object> disposition = (Map<String, Object>) coa.get("disposition");
        assertEquals("ACCEPT", disposition.get("decision"));
        assertEquals(0, BigDecimal.valueOf(100).compareTo((BigDecimal) disposition.get("acceptedQty")));
    }

    @Test
    void generateCoa_notFinalized_throws() {
        QcInspection inspection = buildInspection("IN_PROGRESS");

        when(inspectionRepository.findByIdAndOrgIdAndIsDeletedFalse(inspection.getId(), orgId))
                .thenReturn(Optional.of(inspection));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.generateCoa(inspection.getId()));
        assertEquals("QC_NOT_FINALIZED", ex.getErrorCode());
        verifyNoInteractions(organisationRepository);
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
