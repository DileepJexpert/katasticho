package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.CustomerReceiptService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.expense.repository.ExpenseRepository;
import com.katasticho.erp.fieldsales.dto.BeatCustomerAssignmentRequest;
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
    @Mock private ContactRepository contactRepo;
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
    @Mock private InvoiceRepository invoiceRepo;
    @Mock private CustomerReceiptService customerReceiptService;
    @Mock private ExpenseRepository expenseRepo;
    @Mock private OrgSettingsService orgSettingsService;
    @Mock private com.katasticho.erp.auth.repository.AppUserRepository appUserRepository;
    @Mock private com.katasticho.erp.fieldsales.repository.FieldSalesExecutionAuditRepository executionAuditRepo;

    private FieldSalesService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID otherUserId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FieldSalesService(
                beatRepo, beatCustomerRepo, contactRepo, routeRepo, routeBeatRepo,
                vanRepo, vanStockBalanceRepo, assignmentRepo,
                vanStockTransferRepo, vanStockTransferLineRepo,
                routeExecutionRepo, fieldVisitRepo, dayCloseRepo,
                salesmanTargetRepo, inventoryService, stockBalanceRepo,
                salesOrderRepo, invoiceRepo, customerReceiptService, expenseRepo,
                orgSettingsService, appUserRepository, executionAuditRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        TenantContext.setCurrentRole("ADMIN");

        lenient().when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.of(com.katasticho.erp.auth.entity.AppUser.builder().active(true).build()));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ Beat CRUD ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬

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

    @Test
    void addCustomerToBeat_rejectsVendorContact() {
        UUID beatId = UUID.randomUUID();
        UUID vendorId = UUID.randomUUID();
        Beat beat = Beat.builder().code("B01").name("Market Area").build();
        beat.setId(beatId);
        Contact vendor = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName("Vendor only")
                .active(true)
                .build();
        vendor.setId(vendorId);

        when(beatRepo.findByIdAndOrgIdAndIsDeletedFalse(beatId, orgId))
                .thenReturn(Optional.of(beat));
        when(contactRepo.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, Set.of(vendorId)))
                .thenReturn(List.of(vendor));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addCustomerToBeat(beatId, vendorId, 1, "WEEKLY"));

        assertEquals("FS_BEAT_CONTACT_NOT_CUSTOMER", ex.getErrorCode());
        verify(beatCustomerRepo, never()).save(any());
    }

    @Test
    void createBeat_assignsActiveCustomerInSameTransaction() {
        UUID beatId = UUID.randomUUID();
        UUID customerId = UUID.randomUUID();
        Beat input = Beat.builder().code("B01").name("Market Area").build();
        Beat savedBeat = Beat.builder().code("B01").name("Market Area").build();
        savedBeat.setId(beatId);
        Contact customer = Contact.builder()
                .contactType(ContactType.CUSTOMER)
                .displayName("Retailer")
                .active(true)
                .build();
        customer.setId(customerId);

        when(beatRepo.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "B01")).thenReturn(false);
        when(beatRepo.save(any())).thenReturn(savedBeat);
        when(beatCustomerRepo.findByOrgIdAndBeatId(orgId, beatId)).thenReturn(List.of());
        when(contactRepo.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, Set.of(customerId)))
                .thenReturn(List.of(customer));

        service.createBeat(input, List.of(
                new BeatCustomerAssignmentRequest(customerId, null, null)));

        verify(beatCustomerRepo).saveAll(argThat(assignments -> {
            List<BeatCustomer> values = new ArrayList<>();
            assignments.forEach(values::add);
            return values.size() == 1
                    && values.getFirst().getContactId().equals(customerId)
                    && values.getFirst().getVisitSequence() == 1
                    && "WEEKLY".equals(values.getFirst().getVisitFrequency())
                    && values.getFirst().isActive();
        }));
    }

    // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ Visit ownership ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬

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

    // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ Geofence at check-in ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬

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

    // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ recordVisitOrder with SO validation ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬

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

    // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ Day Close lifecycle ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬

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

    // -- Salesman Target --

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
        // The van holds the item only in batches; the null-batch grain is empty ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢
        // available 0 < 3 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ clean FS_VAN_INSUFFICIENT_STOCK (not a 500 crash from a
        // multi-row match on the old findByOrgIdAndVanIdAndItemId lookup).
        when(vanStockBalanceRepo.findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(orgId, vanId, itemId))
                .thenReturn(Optional.empty());

        var ex = assertThrows(BusinessException.class, () -> service.confirmVanReturn(transferId));
        assertEquals("FS_VAN_INSUFFICIENT_STOCK", ex.getErrorCode());
    }


    @Test
    void startExecution_withActiveAssignment_succeeds_nonAdminPath() {
        // OPERATOR path - auto-populates van from assignment
        UUID routeId = UUID.randomUUID();
        UUID vanId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();
        TenantContext.setCurrentRole("OPERATOR");

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));
        when(vanRepo.findByIdAndOrgIdAndIsDeletedFalse(vanId, orgId)).thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Van.builder().vehicleNumber("KA-01-1234").build()));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment activeAssignment =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .vanId(vanId)
                        .effectiveFrom(executionDate.minusDays(1))
                        .isActive(true)
                        .build();

        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of(activeAssignment));
        when(routeBeatRepo.findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId))
                .thenReturn(List.of());
        when(routeExecutionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var exec = service.startExecution(routeId, userId, null, executionDate);
        assertNotNull(exec);
        assertEquals(routeId, exec.getRouteId());
        assertEquals(userId, exec.getSalespersonId());
        assertEquals(vanId, exec.getVanId());
        assertEquals("PLANNED", exec.getStatus());
    }

    // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ Field Sales Assignment Lifecycle Tests ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬

    @Test
    void createAssignment_validData_succeeds() {
        UUID routeId = UUID.randomUUID();
        UUID vanId = UUID.randomUUID();
        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("North Route").build()));
        when(vanRepo.findByIdAndOrgIdAndIsDeletedFalse(vanId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Van.builder().vehicleNumber("KA-01-1234").build()));
        when(assignmentRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment input =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .vanId(vanId)
                        .territory("North Zone")
                        .effectiveFrom(java.time.LocalDate.now())
                        .isActive(true)
                        .build();

        var created = service.createAssignment(input);
        assertNotNull(created);
        assertEquals(userId, created.getSalespersonId());
        assertEquals(routeId, created.getRouteId());
        assertEquals("North Zone", created.getTerritory());
        assertTrue(created.isActive());
    }

    @Test
    void createAssignment_invalidDates_throws() {
        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment input =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .effectiveFrom(java.time.LocalDate.now())
                        .effectiveTo(java.time.LocalDate.now().minusDays(5))
                        .build();

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.createAssignment(input));
        assertEquals("FS_INVALID_EFFECTIVE_DATES", ex.getErrorCode());
    }

    @Test
    void endAssignment_setsEffectiveToAndDeactivates() {
        UUID assignmentId = UUID.randomUUID();
        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment existing =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .effectiveFrom(java.time.LocalDate.now().minusDays(10))
                        .isActive(true)
                        .build();
        existing.setId(assignmentId);
        existing.setOrgId(orgId);

        when(assignmentRepo.findByIdAndOrgId(assignmentId, orgId)).thenReturn(Optional.of(existing));
        when(assignmentRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var ended = service.endAssignment(assignmentId, java.time.LocalDate.now());
        assertFalse(ended.isActive());
        assertEquals(java.time.LocalDate.now(), ended.getEffectiveTo());
    }

    @Test
    void endAssignment_endDateBeforeEffectiveFrom_throws() {
        UUID assignmentId = UUID.randomUUID();
        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment existing =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .effectiveFrom(java.time.LocalDate.now())
                        .isActive(true)
                        .build();
        existing.setId(assignmentId);
        existing.setOrgId(orgId);

        when(assignmentRepo.findByIdAndOrgId(assignmentId, orgId)).thenReturn(Optional.of(existing));

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.endAssignment(assignmentId, java.time.LocalDate.now().minusDays(5)));
        assertEquals("FS_INVALID_EFFECTIVE_DATES", ex.getErrorCode());
    }

    @Test
    void startExecution_noActiveAssignment_throws() {
        UUID routeId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();
        TenantContext.setCurrentRole("OPERATOR");

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));
        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of());

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.startExecution(routeId, userId, null, executionDate));
        assertEquals("FS_NO_ACTIVE_ASSIGNMENT", ex.getErrorCode());
    }

    @Test
    void startExecution_withActiveAssignment_succeeds() {
        UUID routeId = UUID.randomUUID();
        UUID vanId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));
        when(vanRepo.findByIdAndOrgIdAndIsDeletedFalse(vanId, orgId)).thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Van.builder().vehicleNumber("KA-01-1234").build()));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment activeAssignment =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .vanId(vanId)
                        .effectiveFrom(executionDate.minusDays(1))
                        .isActive(true)
                        .build();

        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of(activeAssignment));
        when(routeBeatRepo.findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId))
                .thenReturn(List.of());
        when(routeExecutionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var exec = service.startExecution(routeId, userId, null, executionDate);
        assertNotNull(exec);
        assertEquals(routeId, exec.getRouteId());
        assertEquals(userId, exec.getSalespersonId());
        assertEquals(vanId, exec.getVanId()); // Auto-populated from assignment!
        assertEquals("PLANNED", exec.getStatus());
    }

    @Test
    void createAssignment_inactiveSalesperson_throws() {
        when(appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(userId), eq(orgId)))
                .thenReturn(Optional.of(com.katasticho.erp.auth.entity.AppUser.builder().active(false).build()));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment input =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .effectiveFrom(java.time.LocalDate.now())
                        .isActive(true)
                        .build();

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.createAssignment(input));
        assertEquals("FS_SALESPERSON_INACTIVE", ex.getErrorCode());
    }

    @Test
    void createAssignment_overlappingActiveAssignment_throws() {
        UUID routeId = UUID.randomUUID();
        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("North Route").build()));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment existing =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .effectiveFrom(java.time.LocalDate.now().minusDays(10))
                        .effectiveTo(java.time.LocalDate.now().plusDays(10))
                        .isActive(true)
                        .build();

        when(assignmentRepo.findByOrgIdAndSalespersonIdAndRouteIdAndIsActiveTrue(orgId, userId, routeId))
                .thenReturn(List.of(existing));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment overlapping =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .effectiveFrom(java.time.LocalDate.now())
                        .effectiveTo(java.time.LocalDate.now().plusDays(20))
                        .isActive(true)
                        .build();

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.createAssignment(overlapping));
        assertEquals("FS_ASSIGNMENT_OVERLAP", ex.getErrorCode());
    }

    @Test
    void startExecution_adminNoAssignmentNoReason_throws() {
        UUID routeId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();
        TenantContext.setCurrentRole("ADMIN");

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));
        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of());

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.startExecution(routeId, userId, null, executionDate, null));
        assertEquals("FS_OVERRIDE_REASON_REQUIRED", ex.getErrorCode());
    }

    @Test
    void startExecution_adminNoAssignmentWithReason_succeeds() {
        UUID routeId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();
        TenantContext.setCurrentRole("ADMIN");

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));
        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of());
        when(routeBeatRepo.findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId))
                .thenReturn(List.of());
        when(routeExecutionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var exec = service.startExecution(routeId, userId, null, executionDate, "Emergency replacement");
        assertNotNull(exec);
        assertEquals("PLANNED", exec.getStatus());
        assertTrue(exec.getNotes().contains("ADMIN OVERRIDE"));
        assertTrue(exec.getNotes().contains("Emergency replacement"));
    }

    @Test
    void startExecution_vanMismatchNonAdmin_throws() {
        UUID routeId = UUID.randomUUID();
        UUID assignedVanId = UUID.randomUUID();
        UUID differentVanId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();
        TenantContext.setCurrentRole("OPERATOR");

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment activeAssignment =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .vanId(assignedVanId)
                        .effectiveFrom(executionDate.minusDays(1))
                        .isActive(true)
                        .build();

        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of(activeAssignment));

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.startExecution(routeId, userId, differentVanId, executionDate, null));
        assertEquals("FS_VAN_MISMATCH", ex.getErrorCode());
    }

    @Test
    void startExecution_vanMismatchAdminWithReason_succeeds() {
        UUID routeId = UUID.randomUUID();
        UUID assignedVanId = UUID.randomUUID();
        UUID differentVanId = UUID.randomUUID();
        java.time.LocalDate executionDate = java.time.LocalDate.now();
        TenantContext.setCurrentRole("ADMIN");

        when(routeRepo.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Route.builder().name("Downtown").build()));
        when(vanRepo.findByIdAndOrgIdAndIsDeletedFalse(differentVanId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.fieldsales.entity.Van.builder().vehicleNumber("KA-02-9999").build()));

        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment activeAssignment =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .routeId(routeId)
                        .vanId(assignedVanId)
                        .effectiveFrom(executionDate.minusDays(1))
                        .isActive(true)
                        .build();

        when(assignmentRepo.findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, userId, routeId, executionDate))
                .thenReturn(List.of(activeAssignment));
        when(routeBeatRepo.findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId))
                .thenReturn(List.of());
        when(routeExecutionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var exec = service.startExecution(routeId, userId, differentVanId, executionDate, "Van maintenance substitute");
        assertNotNull(exec);
        assertEquals(differentVanId, exec.getVanId());
        assertTrue(exec.getNotes().contains("ADMIN VAN OVERRIDE"));
    }

    @Test
    void deleteAssignment_deactivatesRecord() {
        UUID assignmentId = UUID.randomUUID();
        com.katasticho.erp.fieldsales.entity.FieldSalesAssignment existing =
                com.katasticho.erp.fieldsales.entity.FieldSalesAssignment.builder()
                        .salespersonId(userId)
                        .effectiveFrom(java.time.LocalDate.now().minusDays(5))
                        .isActive(true)
                        .build();
        existing.setId(assignmentId);
        existing.setOrgId(orgId);

        when(assignmentRepo.findByIdAndOrgId(assignmentId, orgId)).thenReturn(Optional.of(existing));
        when(assignmentRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.deleteAssignment(assignmentId);

        assertFalse(existing.isActive());
        assertEquals(java.time.LocalDate.now(), existing.getEffectiveTo());
        verify(assignmentRepo).save(existing);
        verify(assignmentRepo, never()).delete(any());
    }
}
