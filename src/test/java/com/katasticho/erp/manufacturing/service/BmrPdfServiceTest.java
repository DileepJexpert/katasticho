package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.manufacturing.entity.BmrDeviation;
import com.katasticho.erp.manufacturing.entity.BmrSignoff;
import com.katasticho.erp.manufacturing.entity.BmrStepRecord;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.entity.Operation;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.OperationRepository;
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
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BmrPdfServiceTest {

    @Mock private BmrService bmrService;
    @Mock private DocumentPdfService pdfService;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private OperationRepository operationRepository;
    @Mock private AppUserRepository appUserRepository;

    private BmrPdfService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID woId = UUID.randomUUID();
    private final UUID fgId = UUID.randomUUID();
    private final UUID operatorId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new BmrPdfService(bmrService, pdfService, organisationRepository,
                itemRepository, operationRepository, appUserRepository);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private Map<String, Object> snapshotWith(WorkOrder wo,
                                             List<JobCard> jobCards,
                                             List<BmrStepRecord> steps,
                                             List<BmrSignoff> signoffs,
                                             List<BmrDeviation> deviations,
                                             String yieldStatus,
                                             double yieldPercent) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("workOrder", wo);
        m.put("jobCards", jobCards);
        m.put("stepRecords", steps);
        m.put("signoffs", signoffs);
        m.put("deviations", deviations);
        Map<String, Object> y = new LinkedHashMap<>();
        y.put("status", yieldStatus);
        y.put("plannedQty", new BigDecimal("100"));
        y.put("producedQty", new BigDecimal("99"));
        y.put("yieldPercent", new BigDecimal(yieldPercent));
        y.put("deviationPercent", new BigDecimal("1"));
        m.put("yieldReconciliation", y);
        m.put("generatedAt", Instant.now());
        return m;
    }

    private WorkOrder wo() {
        WorkOrder w = WorkOrder.builder()
                .workOrderNumber("WO-0001")
                .finishedGoodId(fgId)
                .warehouseId(UUID.randomUUID())
                .quantityToProduce(new BigDecimal("100"))
                .quantityProduced(new BigDecimal("99"))
                .status("COMPLETED")
                .plannedStartDate(LocalDate.now().minusDays(5))
                .actualStartDate(LocalDate.now().minusDays(4))
                .actualEndDate(LocalDate.now())
                .lines(new java.util.ArrayList<>())
                .build();
        w.setId(woId);
        w.setOrgId(orgId);
        return w;
    }

    @Test
    void generatePdf_minimalBatch_passesHtmlToRendererWithRequiredSections() {
        when(bmrService.bmrSnapshot(woId)).thenReturn(
                snapshotWith(wo(), List.of(), List.of(), List.of(), List.of(),
                        "WITHIN_TOLERANCE", 99.00));
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(Organisation.builder()
                        .name("Test Pharma Pvt Ltd").gstin("27AAAAA0000A1Z5").build()));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(fgId, orgId))
                .thenReturn(Optional.of(Item.builder()
                        .name("Atorva 10mg Tab").composition("Atorvastatin 10mg")
                        .unitOfMeasure("Tab").build()));
        when(pdfService.render(any())).thenReturn(new byte[]{1, 2, 3});

        byte[] pdf = service.generatePdf(woId);

        assertArrayEquals(new byte[]{1, 2, 3}, pdf);
        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        // Required Schedule M / WHO-GMP sections all present:
        assertTrue(body.contains("BATCH MANUFACTURING RECORD"));
        assertTrue(body.contains("1. Yield Reconciliation"));
        assertTrue(body.contains("2. In-process Parameter Records"));
        assertTrue(body.contains("3. Sign-offs"));
        assertTrue(body.contains("4. Deviations"));
        // Header carries org + product + batch + qty:
        assertTrue(body.contains("Test Pharma Pvt Ltd"));
        assertTrue(body.contains("WO-0001"));
        assertTrue(body.contains("Atorva 10mg Tab"));
        assertTrue(body.contains("Atorvastatin 10mg"));
        assertTrue(body.contains("WITHIN_TOLERANCE"));
    }

    @Test
    void generatePdf_withParametersAndSignoffsAndDeviations_rendersFullRecord() {
        UUID opId = UUID.randomUUID();
        UUID jcId = UUID.randomUUID();
        JobCard jc = JobCard.builder()
                .workOrderId(woId).operationId(opId).sequenceNumber(1)
                .build();
        jc.setId(jcId);
        jc.setOrgId(orgId);

        BmrStepRecord step = BmrStepRecord.builder()
                .workOrderId(woId).jobCardId(jcId)
                .parameterKey("granulation_temp").parameterValue("65")
                .unit("C").observedAt(Instant.now()).observedBy(operatorId).build();
        BmrSignoff sig = BmrSignoff.builder()
                .workOrderId(woId).jobCardId(jcId)
                .role("SUPERVISOR").signedBy(operatorId).signedAt(Instant.now()).build();
        BmrDeviation dev = BmrDeviation.builder()
                .workOrderId(woId).severity("MAJOR").title("Temp drift")
                .description("Exceeded 70°C briefly").status("RESOLVED")
                .resolution("Recalibrated probe; re-validated step.")
                .reportedBy(operatorId).reportedAt(Instant.now())
                .resolvedBy(operatorId).resolvedAt(Instant.now())
                .build();

        when(bmrService.bmrSnapshot(woId)).thenReturn(snapshotWith(
                wo(), List.of(jc), List.of(step), List.of(sig), List.of(dev),
                "WITHIN_TOLERANCE", 99.00));
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(Organisation.builder().name("Plant").build()));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(fgId, orgId))
                .thenReturn(Optional.of(Item.builder().name("Drug X").build()));
        when(operationRepository.findByIdAndOrgIdAndIsDeletedFalse(opId, orgId))
                .thenReturn(Optional.of(operationBuilder("Granulation")));
        AppUser u = AppUser.builder().fullName("Asha Operator").build();
        u.setId(operatorId);
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(operatorId, orgId))
                .thenReturn(Optional.of(u));
        when(pdfService.render(any())).thenReturn(new byte[]{9});

        service.generatePdf(woId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        // Operation name resolved + stamped on the parameter row:
        assertTrue(body.contains("Granulation"));
        // User name resolved on observed/signed/reported:
        assertTrue(body.contains("Asha Operator"));
        // Parameter shows up:
        assertTrue(body.contains("granulation_temp"));
        // Sign-off role shows up:
        assertTrue(body.contains("SUPERVISOR"));
        // Deviation severity + status + resolution all rendered:
        assertTrue(body.contains("[MAJOR]"));
        assertTrue(body.contains("Temp drift"));
        assertTrue(body.contains("RESOLVED"));
        assertTrue(body.contains("Recalibrated probe"));
    }

    @Test
    void generatePdf_emptyOptionalSections_rendersFriendlyEmptyMessages() {
        when(bmrService.bmrSnapshot(woId)).thenReturn(snapshotWith(
                wo(), List.of(), List.of(), List.of(), List.of(),
                "PENDING", 0));
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(Organisation.builder().name("Plant").build()));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(fgId, orgId))
                .thenReturn(Optional.empty());
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generatePdf(woId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        // Friendly empty messages — auditor sees "nothing logged" not blank
        // sections (which look like the report was truncated):
        assertTrue(body.contains("No in-process parameter readings recorded"));
        assertTrue(body.contains("No sign-offs recorded"));
        assertTrue(body.contains("No deviations logged for this batch"));
    }

    @Test
    void generatePdf_escapesUserSuppliedStringsInHtml() {
        BmrDeviation dev = BmrDeviation.builder()
                .workOrderId(woId).severity("MINOR")
                .title("<script>alert(1)</script>")
                .description("Bad & <chars>").status("OPEN")
                .reportedBy(operatorId).reportedAt(Instant.now()).build();

        when(bmrService.bmrSnapshot(woId)).thenReturn(snapshotWith(
                wo(), List.of(), List.of(), List.of(), List.of(dev),
                "WITHIN_TOLERANCE", 99));
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(Organisation.builder().name("Plant").build()));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(fgId, orgId))
                .thenReturn(Optional.empty());
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generatePdf(woId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        // Tags escaped, raw <script> NOT present:
        assertFalse(body.contains("<script>alert(1)</script>"),
                "Raw <script> tag must not survive into the PDF HTML");
        assertTrue(body.contains("&lt;script&gt;alert(1)&lt;/script&gt;"));
        assertTrue(body.contains("Bad &amp; &lt;chars&gt;"));
    }

    @Test
    void filename_stripsReservedChars() {
        WorkOrder w = WorkOrder.builder().workOrderNumber("WO/2026-07?").build();
        assertEquals("BMR-WO-2026-07-.pdf", BmrPdfService.filename(w));
    }

    private Operation operationBuilder(String name) {
        Operation o = Operation.builder().code("OP-1").name(name).build();
        o.setId(UUID.randomUUID());
        o.setOrgId(orgId);
        return o;
    }
}
