package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FieldSalesServiceTest {

    @Mock private BeatRepository beatRepo;
    @Mock private BeatCustomerRepository beatCustomerRepo;
    @Mock private RouteRepository routeRepo;
    @Mock private RouteBeatRepository routeBeatRepo;
    @Mock private VanRepository vanRepo;
    @Mock private VanStockBalanceRepository vanStockBalanceRepo;
    @Mock private FieldSalesAssignmentRepository assignmentRepo;
    @Mock private VanStockTransferRepository vanStockTransferRepo;
    @Mock private VanStockTransferLineRepository vanStockTransferLineRepo;
    @Mock private RouteExecutionRepository routeExecutionRepo;
    @Mock private FieldVisitRepository fieldVisitRepo;
    @Mock private DayCloseRepository dayCloseRepo;
    @Mock private SalesmanTargetRepository salesmanTargetRepo;
    @Mock private InventoryService inventoryService;
    @Mock private StockBalanceRepository stockBalanceRepo;
    @Mock private SalesOrderRepository salesOrderRepo;
    @Mock private OrgSettingsService orgSettingsService;

    private FieldSalesService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID otherUserId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FieldSalesService(
                beatRepo, beatCustomerRepo, routeRepo, routeBeatRepo,
                vanRepo, vanStockBalanceRepo, assignmentRepo,
                vanStockTransferRepo, vanStockTransferLineRepo,
                routeExecutionRepo, fieldVisitRepo, dayCloseRepo,
                salesmanTargetRepo, inventoryService, stockBalanceRepo,
                salesOrderRepo, orgSettingsService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Beat CRUD ──

    @Test
    void createBeat_uniqueCode_succeeds() {
        when(beatRepo.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "B01")).thenReturn(false);
        when(beatRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Beat input = Beat.builder().code("B01").name("Market Area").build();
        Beat result = service.createBeat(input);

        assertEquals("B01", result.getCode());
        assertEquals("Market Area", result.getName());
        verify(beatRepo).save(any());
    }

    @Test
    void createBeat_duplicateCode_throws() {
        when(beatRepo.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "B01")).thenReturn(true);

        Beat input = Beat.builder().code("B01").name("Dup").build();
        BusinessException ex = assertThrows(BusinessException.class, () -> service.createBeat(input));
        assertEquals("FS_BEAT_CODE_EXISTS", ex.getErrorCode());
    }

    // ── Visit ownership ──

    @Test
    void checkIn_byAssignedSalesperson_succeeds() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("PLANNED").build();
        RouteExecution exec = buildExecution(execId, userId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        when(fieldVisitRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldVisit result = service.checkIn(visitId, BigDecimal.ONE, BigDecimal.TWO);

        assertEquals("IN_PROGRESS", result.getStatus());
        assertNotNull(result.getCheckInTime());
    }

    @Test
    void checkIn_byOtherUser_throws() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("PLANNED").build();
        RouteExecution exec = buildExecution(execId, otherUserId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.checkIn(visitId, BigDecimal.ONE, BigDecimal.TWO));
        assertEquals("FS_NOT_ASSIGNED_SALESPERSON", ex.getErrorCode());
    }

    @Test
    void checkOut_byOtherUser_throws() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("IN_PROGRESS").build();
        RouteExecution exec = buildExecution(execId, otherUserId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.checkOut(visitId, BigDecimal.ONE, BigDecimal.TWO, null));
        assertEquals("FS_NOT_ASSIGNED_SALESPERSON", ex.getErrorCode());
    }

    @Test
    void skipVisit_byOtherUser_throws() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("PLANNED").build();
        RouteExecution exec = buildExecution(execId, otherUserId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.skipVisit(visitId, "shop closed"));
        assertEquals("FS_NOT_ASSIGNED_SALESPERSON", ex.getErrorCode());
    }

    // ── Geofence at check-in ──

    @Test
    void checkIn_withinGeofence_setsVerifiedTrue() {
        FieldVisit visit = geofenceVisit();
        // ~50m north of the stored location
        stubGeofenceCustomer(visit, new BigDecimal("28.6139000"), new BigDecimal("77.2090000"));

        FieldVisit result = service.checkIn(visit.getId(),
                new BigDecimal("28.6143500"), new BigDecimal("77.2090000"));

        assertEquals(Boolean.TRUE, result.getGeoVerified());
        assertNotNull(result.getGeoDistanceM());
        assertTrue(result.getGeoDistanceM().doubleValue() < 250);
    }

    @Test
    void checkIn_outsideGeofence_setsVerifiedFalse() {
        FieldVisit visit = geofenceVisit();
        // ~1.1km away from the stored location
        stubGeofenceCustomer(visit, new BigDecimal("28.6139000"), new BigDecimal("77.2090000"));

        FieldVisit result = service.checkIn(visit.getId(),
                new BigDecimal("28.6239000"), new BigDecimal("77.2090000"));

        assertEquals(Boolean.FALSE, result.getGeoVerified());
        assertTrue(result.getGeoDistanceM().doubleValue() > 250);
    }

    @Test
    void checkIn_customerWithoutCoordinates_leavesGeoNull() {
        FieldVisit visit = geofenceVisit();
        stubGeofenceCustomer(visit, null, null);

        FieldVisit result = service.checkIn(visit.getId(),
                new BigDecimal("28.6139000"), new BigDecimal("77.2090000"));

        assertNull(result.getGeoVerified());
        assertNull(result.getGeoDistanceM());
    }

    private FieldVisit geofenceVisit() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();
        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .beatId(UUID.randomUUID()).contactId(UUID.randomUUID())
                .status("PLANNED").build();
        RouteExecution exec = buildExecution(execId, userId, "IN_PROGRESS");
        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        when(fieldVisitRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        return visit;
    }

    private void stubGeofenceCustomer(FieldVisit visit, BigDecimal geoLat, BigDecimal geoLng) {
        BeatCustomer bc = BeatCustomer.builder()
                .beatId(visit.getBeatId()).contactId(visit.getContactId())
                .geoLatitude(geoLat).geoLongitude(geoLng).build();
        when(beatCustomerRepo.findFirstByOrgIdAndBeatIdAndContactId(
                orgId, visit.getBeatId(), visit.getContactId()))
                .thenReturn(Optional.of(bc));
        if (geoLat != null) {
            when(orgSettingsService.get(orgId, "field_sales.geofence_radius_m", "250"))
                    .thenReturn("250");
        }
    }

    // ── recordVisitOrder with SO validation ──

    @Test
    void recordVisitOrder_validSO_succeeds() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();
        UUID soId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("IN_PROGRESS").build();
        RouteExecution exec = buildExecution(execId, userId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        when(salesOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(new SalesOrder()));
        when(fieldVisitRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldVisit result = service.recordVisitOrder(visitId, soId, BigDecimal.valueOf(5000));

        assertEquals(soId, result.getSalesOrderId());
        assertEquals(BigDecimal.valueOf(5000), result.getOrderValue());
    }

    @Test
    void recordVisitOrder_invalidSO_throws() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();
        UUID fakeSoId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("IN_PROGRESS").build();
        RouteExecution exec = buildExecution(execId, userId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        when(salesOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(fakeSoId, orgId))
                .thenReturn(Optional.empty());

        assertThrows(BusinessException.class,
                () -> service.recordVisitOrder(visitId, fakeSoId, BigDecimal.TEN));
    }

    @Test
    void recordVisitCollection_byOtherUser_throws() {
        UUID visitId = UUID.randomUUID();
        UUID execId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId).orgId(orgId).routeExecutionId(execId)
                .status("IN_PROGRESS").build();
        RouteExecution exec = buildExecution(execId, otherUserId, "IN_PROGRESS");

        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordVisitCollection(visitId, BigDecimal.valueOf(1000)));
        assertEquals("FS_NOT_ASSIGNED_SALESPERSON", ex.getErrorCode());
    }

    // ── Day Close lifecycle ──

    @Test
    void initiateDayClose_completedExecution_succeeds() {
        UUID execId = UUID.randomUUID();
        RouteExecution exec = buildExecution(execId, userId, "COMPLETED");
        exec.setVanId(UUID.randomUUID());
        exec.setExecutionDate(LocalDate.now());
        exec.setPlannedVisits(3);
        exec.setCompletedVisits(2);

        FieldVisit v1 = FieldVisit.builder()
                .status("COMPLETED").orderValue(BigDecimal.valueOf(1000))
                .collectionAmount(BigDecimal.valueOf(500)).build();
        FieldVisit v2 = FieldVisit.builder()
                .status("COMPLETED").orderValue(BigDecimal.ZERO)
                .collectionAmount(BigDecimal.valueOf(200)).build();
        FieldVisit v3 = FieldVisit.builder()
                .status("SKIPPED").orderValue(BigDecimal.ZERO)
                .collectionAmount(BigDecimal.ZERO).build();

        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        when(dayCloseRepo.findByOrgIdAndRouteExecutionIdAndIsDeletedFalse(orgId, execId))
                .thenReturn(Optional.empty());
        when(fieldVisitRepo.findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, execId))
                .thenReturn(List.of(v1, v2, v3));
        when(dayCloseRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DayClose result = service.initiateDayClose(execId);

        assertEquals("PENDING", result.getStatus());
        assertEquals(3, result.getVisitsPlanned());
        assertEquals(2, result.getVisitsCompleted());
        assertEquals(1, result.getVisitsProductive());
        assertEquals(0, BigDecimal.valueOf(1000).compareTo(result.getTotalOrdersValue()));
        assertEquals(0, BigDecimal.valueOf(700).compareTo(result.getTotalCollections()));
    }

    @Test
    void initiateDayClose_notCompleted_throws() {
        UUID execId = UUID.randomUUID();
        RouteExecution exec = buildExecution(execId, userId, "IN_PROGRESS");

        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.initiateDayClose(execId));
        assertEquals("FS_EXECUTION_NOT_COMPLETED", ex.getErrorCode());
    }

    @Test
    void approveDayClose_submitted_succeeds() {
        UUID dcId = UUID.randomUUID();
        DayClose dc = DayClose.builder().status("SUBMITTED").build();
        dc.setId(dcId);
        dc.setOrgId(orgId);

        when(dayCloseRepo.findByIdAndOrgIdAndIsDeletedFalse(dcId, orgId))
                .thenReturn(Optional.of(dc));
        when(dayCloseRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DayClose result = service.approveDayClose(dcId);

        assertEquals("APPROVED", result.getStatus());
        assertEquals(userId, result.getApprovedBy());
        assertNotNull(result.getApprovedAt());
    }

    @Test
    void rejectDayClose_submitted_succeeds() {
        UUID dcId = UUID.randomUUID();
        DayClose dc = DayClose.builder().status("SUBMITTED").build();
        dc.setId(dcId);
        dc.setOrgId(orgId);

        when(dayCloseRepo.findByIdAndOrgIdAndIsDeletedFalse(dcId, orgId))
                .thenReturn(Optional.of(dc));
        when(dayCloseRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DayClose result = service.rejectDayClose(dcId, "Cash mismatch");

        assertEquals("REJECTED", result.getStatus());
        assertEquals("Cash mismatch", result.getRejectionReason());
    }

    @Test
    void approveDayClose_notSubmitted_throws() {
        UUID dcId = UUID.randomUUID();
        DayClose dc = DayClose.builder().status("PENDING").build();
        dc.setId(dcId);
        dc.setOrgId(orgId);

        when(dayCloseRepo.findByIdAndOrgIdAndIsDeletedFalse(dcId, orgId))
                .thenReturn(Optional.of(dc));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approveDayClose(dcId));
        assertEquals("FS_DAY_CLOSE_NOT_SUBMITTED", ex.getErrorCode());
    }

    // ── Salesman Target ──

    @Test
    void updateAchievement_calculatesPercentAndIncentive() {
        UUID targetId = UUID.randomUUID();
        SalesmanTarget target = SalesmanTarget.builder()
                .salespersonId(userId)
                .targetType("REVENUE")
                .targetValue(BigDecimal.valueOf(100000))
                .achievedValue(BigDecimal.ZERO)
                .achievementPct(BigDecimal.ZERO)
                .incentiveRate(BigDecimal.valueOf(5))
                .incentiveAmount(BigDecimal.ZERO)
                .build();
        target.setId(targetId);
        target.setOrgId(orgId);

        when(salesmanTargetRepo.findById(targetId)).thenReturn(Optional.of(target));
        when(salesmanTargetRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SalesmanTarget result = service.updateAchievement(targetId, BigDecimal.valueOf(80000));

        assertEquals(0, BigDecimal.valueOf(80000).compareTo(result.getAchievedValue()));
        assertEquals(0, new BigDecimal("80.00").compareTo(result.getAchievementPct()));
        assertEquals(0, new BigDecimal("4000.00").compareTo(result.getIncentiveAmount()));
    }

    private RouteExecution buildExecution(UUID id, UUID salespersonId, String status) {
        RouteExecution exec = RouteExecution.builder()
                .salespersonId(salespersonId).status(status)
                .routeId(UUID.randomUUID()).executionDate(LocalDate.now())
                .build();
        exec.setId(id);
        exec.setOrgId(orgId);
        return exec;
    }

    @Test
    void confirmVanLoad_alreadyConfirmed_throwsViaLockAndPostsNothing() {
        UUID transferId = UUID.randomUUID();
        com.katasticho.erp.fieldsales.entity.VanStockTransfer transfer =
                com.katasticho.erp.fieldsales.entity.VanStockTransfer.builder()
                        .vanId(UUID.randomUUID()).warehouseId(UUID.randomUUID())
                        .transferType("LOAD").status("CONFIRMED").build();
        transfer.setId(transferId);
        transfer.setOrgId(orgId);
        // The locked re-read is the path exercised (serialises concurrent confirms).
        when(vanStockTransferRepo.findByIdAndOrgIdForUpdate(transferId, orgId))
                .thenReturn(Optional.of(transfer));

        var ex = assertThrows(BusinessException.class, () -> service.confirmVanLoad(transferId));
        assertEquals("FS_TRANSFER_NOT_DRAFT", ex.getErrorCode());
        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void submitDayClose_byNonOwnerOperator_throws() {
        UUID dayCloseId = UUID.randomUUID();
        com.katasticho.erp.fieldsales.entity.DayClose dayClose =
                com.katasticho.erp.fieldsales.entity.DayClose.builder()
                        .salespersonId(otherUserId).status("PENDING").build();
        dayClose.setId(dayCloseId);
        dayClose.setOrgId(orgId);
        when(dayCloseRepo.findByIdAndOrgIdAndIsDeletedFalse(dayCloseId, orgId))
                .thenReturn(Optional.of(dayClose));
        TenantContext.setCurrentRole("OPERATOR"); // caller is userId, not the owner

        var ex = assertThrows(BusinessException.class,
                () -> service.submitDayClose(dayCloseId, BigDecimal.TEN, BigDecimal.ZERO, "fake"));
        assertEquals("FS_NOT_ASSIGNED_SALESPERSON", ex.getErrorCode());
        verify(dayCloseRepo, never()).save(any());
    }

    @Test
    void confirmVanReturn_nullBatchLineAgainstBatchedVan_throwsInsufficientNotCrash() {
        UUID transferId = UUID.randomUUID();
        UUID vanId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        com.katasticho.erp.fieldsales.entity.VanStockTransfer transfer =
                com.katasticho.erp.fieldsales.entity.VanStockTransfer.builder()
                        .vanId(vanId).warehouseId(UUID.randomUUID())
                        .transferType("RETURN").status("DRAFT").build();
        transfer.setId(transferId);
        transfer.setOrgId(orgId);
        com.katasticho.erp.fieldsales.entity.VanStockTransferLine line =
                com.katasticho.erp.fieldsales.entity.VanStockTransferLine.builder()
                        .itemId(itemId).batchId(null).quantity(BigDecimal.valueOf(3)).build();

        when(vanStockTransferRepo.findByIdAndOrgIdForUpdate(transferId, orgId))
                .thenReturn(Optional.of(transfer));
        when(vanStockTransferLineRepo.findByOrgIdAndVanStockTransferId(orgId, transferId))
                .thenReturn(List.of(line));
        // The van holds the item only in batches; the null-batch grain is empty →
        // available 0 < 3 → clean FS_VAN_INSUFFICIENT_STOCK (not a 500 crash from a
        // multi-row match on the old findByOrgIdAndVanIdAndItemId lookup).
        when(vanStockBalanceRepo.findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(orgId, vanId, itemId))
                .thenReturn(Optional.empty());

        var ex = assertThrows(BusinessException.class, () -> service.confirmVanReturn(transferId));
        assertEquals("FS_VAN_INSUFFICIENT_STOCK", ex.getErrorCode());
    }
}
