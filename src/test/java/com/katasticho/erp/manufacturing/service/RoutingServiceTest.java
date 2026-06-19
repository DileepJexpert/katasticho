package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.BaseEntity;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
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
class RoutingServiceTest {

    @Mock private WorkstationRepository workstationRepo;
    @Mock private OperationRepository operationRepo;
    @Mock private RoutingRepository routingRepo;
    @Mock private RoutingOperationRepository routingOperationRepo;
    @Mock private JobCardRepository jobCardRepo;
    @Mock private com.katasticho.erp.common.service.AttachmentService attachmentService;
    @Mock private com.katasticho.erp.manufacturing.repository.RoutingOperationDependencyRepository operationDependencyRepo;
    @Mock private com.katasticho.erp.manufacturing.repository.WorkstationAlternateRepository workstationAlternateRepo;

    private RoutingService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new RoutingService(
                workstationRepo, operationRepo, routingRepo, routingOperationRepo, jobCardRepo,
                attachmentService, operationDependencyRepo, workstationAlternateRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── createWorkstation ────────────────────────────────────────

    @Test
    void createWorkstation_success() {
        when(workstationRepo.save(any())).thenAnswer(inv -> {
            Workstation ws = inv.getArgument(0);
            if (ws.getId() == null) ws.setId(UUID.randomUUID());
            return ws;
        });

        Workstation result = service.createWorkstation(
                "WS-001", "Mixing Station", "Main mixer",
                BigDecimal.valueOf(150), BigDecimal.valueOf(10));

        assertNotNull(result.getId());
        assertEquals("WS-001", result.getCode());
        assertEquals("Mixing Station", result.getName());
        assertEquals("Main mixer", result.getDescription());
        assertEquals(0, BigDecimal.valueOf(150).compareTo(result.getHourlyRate()));
        assertEquals(0, BigDecimal.valueOf(10).compareTo(result.getCapacityHoursPerDay()));
        verify(workstationRepo).save(any(Workstation.class));
    }

    // ── createOperation ──────────────────────────────────────────

    @Test
    void createOperation_success() {
        UUID defaultWsId = UUID.randomUUID();

        when(operationRepo.save(any())).thenAnswer(inv -> {
            Operation op = inv.getArgument(0);
            if (op.getId() == null) op.setId(UUID.randomUUID());
            return op;
        });

        Operation result = service.createOperation(
                "OP-001", "Mixing", "Mix raw materials",
                defaultWsId, 15, BigDecimal.valueOf(2));

        assertNotNull(result.getId());
        assertEquals("OP-001", result.getCode());
        assertEquals("Mixing", result.getName());
        assertEquals("Mix raw materials", result.getDescription());
        assertEquals(defaultWsId, result.getDefaultWorkstationId());
        assertEquals(15, result.getSetupTimeMinutes());
        assertEquals(0, BigDecimal.valueOf(2).compareTo(result.getRunTimeMinutesPerUnit()));
        verify(operationRepo).save(any(Operation.class));
    }

    // ── createRouting ────────────────────────────────────────────

    @Test
    void createRouting_withOperations_success() {
        UUID itemId = UUID.randomUUID();
        UUID op1Id = UUID.randomUUID();
        UUID op2Id = UUID.randomUUID();
        UUID ws1Id = UUID.randomUUID();
        UUID ws2Id = UUID.randomUUID();

        List<RoutingService.RoutingOperationInput> inputs = List.of(
                new RoutingService.RoutingOperationInput(op1Id, ws1Id, 1, 10, BigDecimal.valueOf(3)),
                new RoutingService.RoutingOperationInput(op2Id, ws2Id, 2, null, null)
        );

        when(routingRepo.save(any())).thenAnswer(inv -> {
            Routing r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });

        Routing result = service.createRouting("Tablet Route", itemId, true, inputs);

        assertNotNull(result.getId());
        assertEquals("Tablet Route", result.getName());
        assertEquals(itemId, result.getItemId());
        assertTrue(result.isDefault());
        assertEquals(2, result.getOperations().size());

        RoutingOperation first = result.getOperations().get(0);
        assertEquals(op1Id, first.getOperationId());
        assertEquals(ws1Id, first.getWorkstationId());
        assertEquals(1, first.getSequenceNumber());
        assertEquals(10, first.getSetupTimeOverride());
        assertEquals(0, BigDecimal.valueOf(3).compareTo(first.getRunTimeOverride()));

        RoutingOperation second = result.getOperations().get(1);
        assertEquals(op2Id, second.getOperationId());
        assertEquals(ws2Id, second.getWorkstationId());
        assertEquals(2, second.getSequenceNumber());
        assertNull(second.getSetupTimeOverride());
        assertNull(second.getRunTimeOverride());

        // save called twice: once for the routing, once after adding operations
        verify(routingRepo, times(2)).save(any(Routing.class));
    }

    // ── createJobCardsForWorkOrder ───────────────────────────────

    @Test
    void createJobCardsForWorkOrder_success_generatesCorrectCount() {
        UUID workOrderId = UUID.randomUUID();
        UUID routingId = UUID.randomUUID();
        UUID op1Id = UUID.randomUUID();
        UUID op2Id = UUID.randomUUID();
        UUID op3Id = UUID.randomUUID();
        UUID ws1Id = UUID.randomUUID();
        UUID ws2Id = UUID.randomUUID();

        Routing routing = buildRouting(routingId, List.of(
                buildRoutingOperation(op1Id, ws1Id, 1),
                buildRoutingOperation(op2Id, ws2Id, 2),
                buildRoutingOperation(op3Id, null, 3)
        ));

        when(routingRepo.findByIdAndOrgIdAndIsDeletedFalse(routingId, orgId))
                .thenReturn(Optional.of(routing));
        when(jobCardRepo.saveAll(any())).thenAnswer(inv -> {
            List<JobCard> list = inv.getArgument(0);
            list.forEach(e -> {
                if (((BaseEntity) e).getId() == null)
                    ((BaseEntity) e).setId(UUID.randomUUID());
            });
            return list;
        });

        List<JobCard> result = service.createJobCardsForWorkOrder(
                workOrderId, routingId, BigDecimal.valueOf(100));

        assertEquals(3, result.size());

        // Verify first card
        JobCard card1 = result.get(0);
        assertNotNull(card1.getId());
        assertEquals(workOrderId, card1.getWorkOrderId());
        assertEquals(op1Id, card1.getOperationId());
        assertEquals(ws1Id, card1.getWorkstationId());
        assertEquals(1, card1.getSequenceNumber());
        assertEquals(0, BigDecimal.valueOf(100).compareTo(card1.getPlannedQty()));

        // Verify second card
        JobCard card2 = result.get(1);
        assertEquals(op2Id, card2.getOperationId());
        assertEquals(ws2Id, card2.getWorkstationId());
        assertEquals(2, card2.getSequenceNumber());

        // Verify third card (no workstation)
        JobCard card3 = result.get(2);
        assertEquals(op3Id, card3.getOperationId());
        assertNull(card3.getWorkstationId());
        assertEquals(3, card3.getSequenceNumber());

        verify(jobCardRepo).saveAll(any());
    }

    @Test
    void createJobCardsForWorkOrder_emptyRoutingOperations_throws() {
        UUID workOrderId = UUID.randomUUID();
        UUID routingId = UUID.randomUUID();

        Routing routing = buildRouting(routingId, new ArrayList<>());

        when(routingRepo.findByIdAndOrgIdAndIsDeletedFalse(routingId, orgId))
                .thenReturn(Optional.of(routing));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createJobCardsForWorkOrder(
                        workOrderId, routingId, BigDecimal.TEN));
        assertEquals("MFG_ROUTING_EMPTY", ex.getErrorCode());
    }

    // ── startJobCard ─────────────────────────────────────────────

    @Test
    void startJobCard_pending_transitionsToInProgress() {
        UUID jobCardId = UUID.randomUUID();
        JobCard card = buildJobCard(jobCardId, "PENDING", BigDecimal.valueOf(50));

        when(jobCardRepo.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId))
                .thenReturn(Optional.of(card));
        when(jobCardRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JobCard result = service.startJobCard(jobCardId);

        assertEquals("IN_PROGRESS", result.getStatus());
        assertNotNull(result.getActualStart());
        verify(jobCardRepo).save(any(JobCard.class));
    }

    @Test
    void startJobCard_nonPending_throws() {
        UUID jobCardId = UUID.randomUUID();
        JobCard card = buildJobCard(jobCardId, "IN_PROGRESS", BigDecimal.valueOf(50));

        when(jobCardRepo.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId))
                .thenReturn(Optional.of(card));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.startJobCard(jobCardId));
        assertEquals("MFG_JOB_CARD_NOT_PENDING", ex.getErrorCode());
    }

    // ── completeJobCard ──────────────────────────────────────────

    @Test
    void completeJobCard_inProgress_completesWithQty() {
        UUID jobCardId = UUID.randomUUID();
        JobCard card = buildJobCard(jobCardId, "IN_PROGRESS", BigDecimal.valueOf(100));

        when(jobCardRepo.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId))
                .thenReturn(Optional.of(card));
        when(jobCardRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JobCard result = service.completeJobCard(
                jobCardId, BigDecimal.valueOf(95), BigDecimal.valueOf(5), 120, "Batch complete");

        assertEquals("COMPLETED", result.getStatus());
        assertEquals(0, BigDecimal.valueOf(95).compareTo(result.getCompletedQty()));
        assertEquals(0, BigDecimal.valueOf(5).compareTo(result.getScrapQty()));
        assertEquals(120, result.getTimeLoggedMinutes());
        assertEquals("Batch complete", result.getNotes());
        assertNotNull(result.getActualEnd());
        verify(jobCardRepo).save(any(JobCard.class));
    }

    @Test
    void completeJobCard_nonInProgress_throws() {
        UUID jobCardId = UUID.randomUUID();
        JobCard card = buildJobCard(jobCardId, "PENDING", BigDecimal.valueOf(100));

        when(jobCardRepo.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId))
                .thenReturn(Optional.of(card));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.completeJobCard(
                        jobCardId, BigDecimal.valueOf(100), BigDecimal.ZERO, 60, null));
        assertEquals("MFG_JOB_CARD_NOT_IN_PROGRESS", ex.getErrorCode());
    }

    // ── Helpers ──────────────────────────────────────────────────

    private Routing buildRouting(UUID routingId, List<RoutingOperation> operations) {
        Routing routing = Routing.builder()
                .name("Test Routing")
                .itemId(UUID.randomUUID())
                .isDefault(true)
                .operations(operations)
                .build();
        routing.setId(routingId);
        routing.setOrgId(orgId);
        return routing;
    }

    private RoutingOperation buildRoutingOperation(UUID operationId, UUID workstationId, int sequence) {
        RoutingOperation ro = RoutingOperation.builder()
                .operationId(operationId)
                .workstationId(workstationId)
                .sequenceNumber(sequence)
                .build();
        ro.setOrgId(orgId);
        return ro;
    }

    private JobCard buildJobCard(UUID id, String status, BigDecimal plannedQty) {
        JobCard card = JobCard.builder()
                .workOrderId(UUID.randomUUID())
                .operationId(UUID.randomUUID())
                .workstationId(UUID.randomUUID())
                .sequenceNumber(1)
                .status(status)
                .plannedQty(plannedQty)
                .build();
        card.setId(id);
        card.setOrgId(orgId);
        return card;
    }

    // ── tracker #13 — operation work instructions ──────────────────

    @Test
    void attachOperationFile_delegatesToAttachmentService_withOperationEntityType() {
        UUID opId = UUID.randomUUID();
        Operation op = Operation.builder().code("OP-MIX").name("Mix").build();
        op.setId(opId);
        op.setOrgId(orgId);
        when(operationRepo.findByIdAndOrgIdAndIsDeletedFalse(opId, orgId)).thenReturn(Optional.of(op));
        org.springframework.web.multipart.MultipartFile file =
                org.mockito.Mockito.mock(org.springframework.web.multipart.MultipartFile.class);
        com.katasticho.erp.common.entity.EntityAttachment stored =
                com.katasticho.erp.common.entity.EntityAttachment.builder()
                        .entityType(RoutingService.OPERATION_ATTACHMENT_ENTITY_TYPE)
                        .entityId(opId)
                        .build();
        when(attachmentService.upload(RoutingService.OPERATION_ATTACHMENT_ENTITY_TYPE, opId, file))
                .thenReturn(stored);

        com.katasticho.erp.common.entity.EntityAttachment result =
                service.attachOperationFile(opId, file);

        assertSame(stored, result);
        verify(attachmentService).upload(
                org.mockito.ArgumentMatchers.eq("OPERATION"),
                org.mockito.ArgumentMatchers.eq(opId),
                org.mockito.ArgumentMatchers.eq(file));
    }

    @Test
    void attachOperationFile_unknownOperation_throwsBeforeUpload() {
        UUID opId = UUID.randomUUID();
        when(operationRepo.findByIdAndOrgIdAndIsDeletedFalse(opId, orgId))
                .thenReturn(Optional.empty());
        org.springframework.web.multipart.MultipartFile file =
                org.mockito.Mockito.mock(org.springframework.web.multipart.MultipartFile.class);

        assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.attachOperationFile(opId, file));
        verify(attachmentService, org.mockito.Mockito.never())
                .upload(org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any());
    }

    @Test
    void listOperationAttachments_filtersByOperationEntityType() {
        UUID opId = UUID.randomUUID();
        Operation op = Operation.builder().code("OP-DRY").name("Dry").build();
        op.setId(opId);
        op.setOrgId(orgId);
        when(operationRepo.findByIdAndOrgIdAndIsDeletedFalse(opId, orgId)).thenReturn(Optional.of(op));
        when(attachmentService.list("OPERATION", opId)).thenReturn(List.of());

        assertTrue(service.listOperationAttachments(opId).isEmpty());
        verify(attachmentService).list("OPERATION", opId);
    }

    // ── tracker #16 — operation dependencies ───────────────────────

    private RoutingOperation buildRoutingOp(UUID id, UUID routingId) {
        RoutingOperation ro = RoutingOperation.builder()
                .operationId(UUID.randomUUID())
                .sequenceNumber(1)
                .build();
        ro.setId(id);
        ro.setOrgId(orgId);
        // routingId is read-only on the entity (FK column has insertable=false),
        // so we reflectively set it for the test fixture.
        try {
            java.lang.reflect.Field f = RoutingOperation.class.getDeclaredField("routingId");
            f.setAccessible(true);
            f.set(ro, routingId);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException(e);
        }
        return ro;
    }

    @Test
    void addOperationDependency_normalEdge_savesWithCorrectIds() {
        UUID routingId = UUID.randomUUID();
        UUID succId = UUID.randomUUID();
        UUID predId = UUID.randomUUID();
        when(routingOperationRepo.findById(succId))
                .thenReturn(Optional.of(buildRoutingOp(succId, routingId)));
        when(routingOperationRepo.findById(predId))
                .thenReturn(Optional.of(buildRoutingOp(predId, routingId)));
        when(operationDependencyRepo
                .existsByOrgIdAndRoutingOperationIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
                        orgId, succId, predId)).thenReturn(false);
        when(operationDependencyRepo
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(orgId, predId))
                .thenReturn(List.of());        // predecessor has no upstream deps → no cycle
        when(operationDependencyRepo.save(org.mockito.ArgumentMatchers.any()))
                .thenAnswer(inv -> inv.getArgument(0));

        com.katasticho.erp.manufacturing.entity.RoutingOperationDependency dep =
                service.addOperationDependency(succId, predId);

        assertEquals(succId, dep.getRoutingOperationId());
        assertEquals(predId, dep.getPredecessorRoutingOperationId());
        assertEquals(orgId, dep.getOrgId());
    }

    @Test
    void addOperationDependency_selfLoop_throws() {
        UUID id = UUID.randomUUID();
        com.katasticho.erp.common.exception.BusinessException ex = assertThrows(
                com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.addOperationDependency(id, id));
        assertEquals("ROUTING_DEP_SELF_LOOP", ex.getErrorCode());
        verify(operationDependencyRepo, org.mockito.Mockito.never())
                .save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void addOperationDependency_crossRouting_throws() {
        UUID succ = UUID.randomUUID();
        UUID pred = UUID.randomUUID();
        when(routingOperationRepo.findById(succ))
                .thenReturn(Optional.of(buildRoutingOp(succ, UUID.randomUUID())));
        when(routingOperationRepo.findById(pred))
                .thenReturn(Optional.of(buildRoutingOp(pred, UUID.randomUUID())));   // different routing

        com.katasticho.erp.common.exception.BusinessException ex = assertThrows(
                com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.addOperationDependency(succ, pred));
        assertEquals("ROUTING_DEP_CROSS_ROUTING", ex.getErrorCode());
    }

    @Test
    void addOperationDependency_wouldFormCycle_throws() {
        // Graph: A → B already exists. Adding B → A would close a loop.
        UUID routingId = UUID.randomUUID();
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();
        when(routingOperationRepo.findById(a)).thenReturn(Optional.of(buildRoutingOp(a, routingId)));
        when(routingOperationRepo.findById(b)).thenReturn(Optional.of(buildRoutingOp(b, routingId)));
        when(operationDependencyRepo
                .existsByOrgIdAndRoutingOperationIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
                        orgId, a, b)).thenReturn(false);
        // Walking up from b: b has predecessor a → cycle.
        com.katasticho.erp.manufacturing.entity.RoutingOperationDependency existing =
                com.katasticho.erp.manufacturing.entity.RoutingOperationDependency.builder()
                        .routingOperationId(b)
                        .predecessorRoutingOperationId(a)
                        .build();
        when(operationDependencyRepo
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(orgId, b))
                .thenReturn(List.of(existing));

        com.katasticho.erp.common.exception.BusinessException ex = assertThrows(
                com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.addOperationDependency(a, b));
        assertEquals("ROUTING_DEP_CYCLE", ex.getErrorCode());
    }

    @Test
    void addOperationDependency_duplicate_returnsExisting_withoutSaving() {
        UUID routingId = UUID.randomUUID();
        UUID succ = UUID.randomUUID();
        UUID pred = UUID.randomUUID();
        when(routingOperationRepo.findById(succ))
                .thenReturn(Optional.of(buildRoutingOp(succ, routingId)));
        when(routingOperationRepo.findById(pred))
                .thenReturn(Optional.of(buildRoutingOp(pred, routingId)));
        when(operationDependencyRepo
                .existsByOrgIdAndRoutingOperationIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
                        orgId, succ, pred)).thenReturn(true);
        com.katasticho.erp.manufacturing.entity.RoutingOperationDependency existing =
                com.katasticho.erp.manufacturing.entity.RoutingOperationDependency.builder()
                        .routingOperationId(succ)
                        .predecessorRoutingOperationId(pred)
                        .build();
        existing.setOrgId(orgId);
        when(operationDependencyRepo
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(orgId, succ))
                .thenReturn(List.of(existing));

        assertSame(existing, service.addOperationDependency(succ, pred));
        verify(operationDependencyRepo, org.mockito.Mockito.never())
                .save(org.mockito.ArgumentMatchers.any());
    }

    // ── tracker #15 — alternative work centers ─────────────────────

    private Workstation buildWorkstation(UUID id, boolean active, double capacityHours) {
        Workstation ws = Workstation.builder()
                .code("WS-" + id.toString().substring(0, 4))
                .name("Machine")
                .capacityHoursPerDay(java.math.BigDecimal.valueOf(capacityHours))
                .isActive(active)
                .build();
        ws.setId(id);
        ws.setOrgId(orgId);
        return ws;
    }

    @Test
    void addWorkstationAlternate_happyPath_savesWithOrgAndPriority() {
        UUID routingId = UUID.randomUUID();
        UUID opId = UUID.randomUUID();
        UUID primaryWs = UUID.randomUUID();
        UUID altWs = UUID.randomUUID();
        RoutingOperation op = buildRoutingOp(opId, routingId);
        op.setWorkstationId(primaryWs);
        when(routingOperationRepo.findById(opId)).thenReturn(Optional.of(op));
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(altWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(altWs, true, 8)));
        when(workstationAlternateRepo
                .existsByOrgIdAndRoutingOperationIdAndWorkstationIdAndIsDeletedFalse(orgId, opId, altWs))
                .thenReturn(false);
        when(workstationAlternateRepo.save(org.mockito.ArgumentMatchers.any()))
                .thenAnswer(inv -> inv.getArgument(0));

        com.katasticho.erp.manufacturing.entity.WorkstationAlternate row =
                service.addWorkstationAlternate(opId, altWs, 2, "Backup mixer");

        assertEquals(opId, row.getRoutingOperationId());
        assertEquals(altWs, row.getWorkstationId());
        assertEquals(2, row.getPriority());
        assertEquals(orgId, row.getOrgId());
    }

    @Test
    void addWorkstationAlternate_sameAsPrimary_throws() {
        UUID routingId = UUID.randomUUID();
        UUID opId = UUID.randomUUID();
        UUID primaryWs = UUID.randomUUID();
        RoutingOperation op = buildRoutingOp(opId, routingId);
        op.setWorkstationId(primaryWs);
        when(routingOperationRepo.findById(opId)).thenReturn(Optional.of(op));
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(primaryWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(primaryWs, true, 8)));

        com.katasticho.erp.common.exception.BusinessException ex = assertThrows(
                com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.addWorkstationAlternate(opId, primaryWs, 1, null));
        assertEquals("MFG_WS_ALT_SAME_AS_PRIMARY", ex.getErrorCode());
    }

    @Test
    void addWorkstationAlternate_duplicate_throws() {
        UUID routingId = UUID.randomUUID();
        UUID opId = UUID.randomUUID();
        UUID altWs = UUID.randomUUID();
        RoutingOperation op = buildRoutingOp(opId, routingId);
        op.setWorkstationId(UUID.randomUUID());
        when(routingOperationRepo.findById(opId)).thenReturn(Optional.of(op));
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(altWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(altWs, true, 8)));
        when(workstationAlternateRepo
                .existsByOrgIdAndRoutingOperationIdAndWorkstationIdAndIsDeletedFalse(orgId, opId, altWs))
                .thenReturn(true);

        com.katasticho.erp.common.exception.BusinessException ex = assertThrows(
                com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.addWorkstationAlternate(opId, altWs, 1, null));
        assertEquals("MFG_WS_ALT_DUPLICATE", ex.getErrorCode());
    }

    @Test
    void pickAvailableWorkstation_primaryHasCapacity_returnsPrimary() {
        UUID routingId = UUID.randomUUID();
        UUID opId = UUID.randomUUID();
        UUID primaryWs = UUID.randomUUID();
        RoutingOperation op = buildRoutingOp(opId, routingId);
        op.setWorkstationId(primaryWs);
        when(routingOperationRepo.findById(opId)).thenReturn(Optional.of(op));
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(primaryWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(primaryWs, true, 8)));
        when(workstationAlternateRepo
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalseOrderByPriorityAsc(orgId, opId))
                .thenReturn(List.of());

        Workstation chosen = service.pickAvailableWorkstation(opId, java.math.BigDecimal.valueOf(6));
        assertEquals(primaryWs, chosen.getId());
    }

    @Test
    void pickAvailableWorkstation_primaryDown_fallsBackToAlternate() {
        UUID routingId = UUID.randomUUID();
        UUID opId = UUID.randomUUID();
        UUID primaryWs = UUID.randomUUID();
        UUID altWs = UUID.randomUUID();
        RoutingOperation op = buildRoutingOp(opId, routingId);
        op.setWorkstationId(primaryWs);
        when(routingOperationRepo.findById(opId)).thenReturn(Optional.of(op));
        // Primary is inactive (down).
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(primaryWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(primaryWs, false, 8)));
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(altWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(altWs, true, 8)));
        com.katasticho.erp.manufacturing.entity.WorkstationAlternate alt =
                com.katasticho.erp.manufacturing.entity.WorkstationAlternate.builder()
                        .routingOperationId(opId).workstationId(altWs).priority(1).build();
        when(workstationAlternateRepo
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalseOrderByPriorityAsc(orgId, opId))
                .thenReturn(List.of(alt));

        Workstation chosen = service.pickAvailableWorkstation(opId, java.math.BigDecimal.valueOf(6));
        assertEquals(altWs, chosen.getId());
    }

    @Test
    void pickAvailableWorkstation_noneQualify_throws() {
        UUID routingId = UUID.randomUUID();
        UUID opId = UUID.randomUUID();
        UUID primaryWs = UUID.randomUUID();
        RoutingOperation op = buildRoutingOp(opId, routingId);
        op.setWorkstationId(primaryWs);
        when(routingOperationRepo.findById(opId)).thenReturn(Optional.of(op));
        // Primary active but only 4h capacity; required is 6h.
        when(workstationRepo.findByIdAndOrgIdAndIsDeletedFalse(primaryWs, orgId))
                .thenReturn(Optional.of(buildWorkstation(primaryWs, true, 4)));
        when(workstationAlternateRepo
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalseOrderByPriorityAsc(orgId, opId))
                .thenReturn(List.of());

        com.katasticho.erp.common.exception.BusinessException ex = assertThrows(
                com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.pickAvailableWorkstation(opId, java.math.BigDecimal.valueOf(6)));
        assertEquals("MFG_NO_AVAILABLE_WORKSTATION", ex.getErrorCode());
    }
}
