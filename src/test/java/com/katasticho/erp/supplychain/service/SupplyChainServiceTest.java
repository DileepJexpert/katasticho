package com.katasticho.erp.supplychain.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.supplychain.entity.*;
import com.katasticho.erp.supplychain.repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SupplyChainServiceTest {

    @Mock private ItemSupplierRepository itemSupplierRepo;
    @Mock private SupplierPerformanceRepository supplierPerfRepo;
    @Mock private DemandForecastRepository forecastRepo;
    @Mock private PurchaseRequisitionRepository requisitionRepo;
    @Mock private ReturnOrderRepository returnOrderRepo;
    @Mock private ReorderPolicyRepository reorderPolicyRepo;
    @Mock private SupplyChainAlertRepository alertRepo;
    @Mock private StockBalanceRepository stockBalanceRepo;
    @Mock private ItemRepository itemRepo;
    @Mock private com.katasticho.erp.procurement.repository.SupplierRepository supplierRepo;
    @Mock private EntityManager em;

    @InjectMocks private SupplyChainService service;

    private MockedStatic<TenantContext> tenantMock;
    private final UUID ORG_ID = UUID.randomUUID();
    private final UUID USER_ID = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        tenantMock = mockStatic(TenantContext.class);
        tenantMock.when(TenantContext::getCurrentOrgId).thenReturn(ORG_ID);
        tenantMock.when(TenantContext::getCurrentUserId).thenReturn(USER_ID);
    }

    @AfterEach
    void tearDown() {
        tenantMock.close();
    }

    // ── Item-Supplier ──

    @Test
    void addItemSupplier_createsMapping() {
        UUID itemId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();
        when(itemSupplierRepo.findByOrgIdAndItemIdAndSupplierIdAndIsDeletedFalse(ORG_ID, itemId, supplierId))
                .thenReturn(Optional.empty());
        when(itemSupplierRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ItemSupplier result = service.addItemSupplier(itemId, supplierId, 10,
                BigDecimal.TEN, new BigDecimal("50"), false, "SKU-001");

        assertEquals(itemId, result.getItemId());
        assertEquals(supplierId, result.getSupplierId());
        assertEquals(10, result.getLeadTimeDays());
        assertFalse(result.isPreferred());
    }

    @Test
    void addItemSupplier_duplicate_throws() {
        UUID itemId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();
        when(itemSupplierRepo.findByOrgIdAndItemIdAndSupplierIdAndIsDeletedFalse(ORG_ID, itemId, supplierId))
                .thenReturn(Optional.of(new ItemSupplier()));

        assertThrows(BusinessException.class, () ->
                service.addItemSupplier(itemId, supplierId, 7, BigDecimal.ONE, BigDecimal.ZERO, false, null));
    }

    @Test
    void setPreferredSupplier_clearsOldPreferred() {
        UUID itemId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();

        ItemSupplier oldPref = new ItemSupplier();
        oldPref.setPreferred(true);
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(ORG_ID, itemId))
                .thenReturn(Optional.of(oldPref));

        ItemSupplier target = new ItemSupplier();
        target.setItemId(itemId);
        target.setSupplierId(supplierId);
        when(itemSupplierRepo.findByOrgIdAndItemIdAndSupplierIdAndIsDeletedFalse(ORG_ID, itemId, supplierId))
                .thenReturn(Optional.of(target));
        when(itemSupplierRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ItemSupplier result = service.setPreferredSupplier(itemId, supplierId);

        assertTrue(result.isPreferred());
        assertFalse(oldPref.isPreferred());
        verify(itemSupplierRepo, times(2)).save(any());
    }

    // ── Purchase Requisition ──

    @Test
    void createRequisition_calculatesTotal() {
        when(requisitionRepo.findMaxRequisitionSequence(ORG_ID)).thenReturn(0);
        when(requisitionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UUID itemId = UUID.randomUUID();
        var lines = List.of(
                new SupplyChainService.RequisitionLineRequest(itemId, BigDecimal.TEN, new BigDecimal("100"))
        );
        PurchaseRequisition pr = service.createRequisition(null, null, null, "Test", lines);

        assertEquals("PR-00001", pr.getRequisitionNumber());
        assertEquals("DRAFT", pr.getStatus());
        assertEquals(new BigDecimal("1000"), pr.getTotalAmount());
        assertEquals(1, pr.getLines().size());
    }

    @Test
    void approveRequisition_changesStatus() {
        PurchaseRequisition pr = new PurchaseRequisition();
        pr.setStatus("DRAFT");
        pr.setOrgId(ORG_ID);
        UUID prId = UUID.randomUUID();
        when(requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(prId, ORG_ID)).thenReturn(Optional.of(pr));
        when(requisitionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PurchaseRequisition result = service.approveRequisition(prId);
        assertEquals("APPROVED", result.getStatus());
        assertEquals(USER_ID, result.getApprovedBy());
    }

    @Test
    void approveRequisition_alreadyApproved_throws() {
        PurchaseRequisition pr = new PurchaseRequisition();
        pr.setStatus("APPROVED");
        pr.setOrgId(ORG_ID);
        UUID prId = UUID.randomUUID();
        when(requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(prId, ORG_ID)).thenReturn(Optional.of(pr));

        assertThrows(BusinessException.class, () -> service.approveRequisition(prId));
    }

    @Test
    void autoCreateRequisition_fromLowStock() {
        UUID itemId = UUID.randomUUID();
        StockBalance sb = StockBalance.builder()
                .orgId(ORG_ID).itemId(itemId).quantityOnHand(new BigDecimal("5")).build();
        when(stockBalanceRepo.findLowStock(ORG_ID)).thenReturn(List.of(sb));

        Item item = Item.builder()
                .name("Test Item")
                .reorderLevel(new BigDecimal("20"))
                .reorderQuantity(new BigDecimal("50"))
                .purchasePrice(new BigDecimal("100"))
                .build();
        item.setId(itemId);
        item.setDeleted(false);
        when(itemRepo.findById(itemId)).thenReturn(Optional.of(item));
        when(requisitionRepo.findMaxRequisitionSequence(ORG_ID)).thenReturn(0);
        when(requisitionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PurchaseRequisition pr = service.autoCreateRequisition();

        assertNotNull(pr);
        assertEquals("Auto-generated from low stock alert", pr.getNotes());
        assertEquals(1, pr.getLines().size());
        assertEquals(new BigDecimal("50"), pr.getLines().get(0).getRequiredQty());
    }

    @Test
    void autoCreateRequisition_noLowStock_returnsNull() {
        when(stockBalanceRepo.findLowStock(ORG_ID)).thenReturn(List.of());
        assertNull(service.autoCreateRequisition());
    }

    // ── Return Orders ──

    @Test
    void createReturnOrder_calculatesTotal() {
        when(returnOrderRepo.findMaxReturnSequence(ORG_ID)).thenReturn(0);
        when(returnOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UUID itemId = UUID.randomUUID();
        var lines = List.of(
                new SupplyChainService.ReturnLineRequest(itemId, null, BigDecimal.TEN,
                        new BigDecimal("50"), "GOOD", true)
        );
        ReturnOrder ro = service.createReturnOrder("PURCHASE_RETURN", null, null,
                "DEFECTIVE", "Item is defective", lines);

        assertEquals("RET-00001", ro.getReturnNumber());
        assertEquals("DRAFT", ro.getStatus());
        assertEquals(new BigDecimal("500"), ro.getTotalAmount());
    }

    @Test
    void approveReturn_changesStatus() {
        ReturnOrder ro = new ReturnOrder();
        ro.setStatus("DRAFT");
        ro.setOrgId(ORG_ID);
        UUID roId = UUID.randomUUID();
        when(returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(roId, ORG_ID)).thenReturn(Optional.of(ro));
        when(returnOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ReturnOrder result = service.approveReturn(roId);
        assertEquals("APPROVED", result.getStatus());
    }

    @Test
    void cancelReturn_processed_throws() {
        ReturnOrder ro = new ReturnOrder();
        ro.setStatus("PROCESSED");
        ro.setOrgId(ORG_ID);
        UUID roId = UUID.randomUUID();
        when(returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(roId, ORG_ID)).thenReturn(Optional.of(ro));

        assertThrows(BusinessException.class, () -> service.cancelReturn(roId));
    }

    @Test
    void processReturn_requiresApproved() {
        ReturnOrder ro = new ReturnOrder();
        ro.setStatus("DRAFT");
        ro.setOrgId(ORG_ID);
        UUID roId = UUID.randomUUID();
        when(returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(roId, ORG_ID)).thenReturn(Optional.of(ro));

        assertThrows(BusinessException.class, () -> service.processReturn(roId));
    }

    // ── Alerts ──

    @Test
    void resolveAlert_setsResolved() {
        SupplyChainAlert alert = new SupplyChainAlert();
        alert.setStatus("OPEN");
        alert.setOrgId(ORG_ID);
        UUID alertId = UUID.randomUUID();
        when(alertRepo.findByIdAndOrgIdAndIsDeletedFalse(alertId, ORG_ID)).thenReturn(Optional.of(alert));
        when(alertRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SupplyChainAlert result = service.resolveAlert(alertId);
        assertEquals("RESOLVED", result.getStatus());
        assertNotNull(result.getResolvedAt());
        assertEquals(USER_ID, result.getResolvedBy());
    }

    // ── Dashboard ──

    @Test
    void getSupplyChainDashboard_returnsMetrics() {
        when(alertRepo.countByOrgIdAndStatusAndIsDeletedFalse(ORG_ID, "OPEN")).thenReturn(3L);
        when(stockBalanceRepo.findLowStock(ORG_ID)).thenReturn(List.of(
                StockBalance.builder().itemId(UUID.randomUUID()).quantityOnHand(BigDecimal.ONE).averageCost(BigDecimal.TEN).build()
        ));
        when(reorderPolicyRepo.findByOrgIdAndIsDeletedFalseOrderByAbcClassAsc(ORG_ID)).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(ORG_ID)).thenReturn(List.of());
        when(reorderPolicyRepo.findByOrgIdAndAutoReorderTrueAndIsDeletedFalse(ORG_ID)).thenReturn(List.of());

        Map<String, Object> dashboard = service.getSupplyChainDashboard();

        assertEquals(3L, dashboard.get("openAlerts"));
        assertEquals(1, dashboard.get("lowStockCount"));
    }

    // ── Submit/Reject requisition ──

    @Test
    void submitRequisition_changesStatus() {
        PurchaseRequisition pr = new PurchaseRequisition();
        pr.setStatus("DRAFT");
        pr.setOrgId(ORG_ID);
        UUID prId = UUID.randomUUID();
        when(requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(prId, ORG_ID)).thenReturn(Optional.of(pr));
        when(requisitionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PurchaseRequisition result = service.submitRequisition(prId);
        assertEquals("SUBMITTED", result.getStatus());
    }

    @Test
    void rejectRequisition_changesStatus() {
        PurchaseRequisition pr = new PurchaseRequisition();
        pr.setStatus("SUBMITTED");
        pr.setOrgId(ORG_ID);
        UUID prId = UUID.randomUUID();
        when(requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(prId, ORG_ID)).thenReturn(Optional.of(pr));
        when(requisitionRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PurchaseRequisition result = service.rejectRequisition(prId);
        assertEquals("REJECTED", result.getStatus());
    }
}
