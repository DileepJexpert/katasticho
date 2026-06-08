package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.BaseEntity;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.JobWorkOrder;
import com.katasticho.erp.manufacturing.entity.JobWorkOrderLine;
import com.katasticho.erp.manufacturing.repository.JobWorkOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JobWorkServiceTest {

    @Mock private JobWorkOrderRepository jobWorkOrderRepo;
    @Mock private ItemRepository itemRepo;
    @Mock private InventoryService inventoryService;

    private JobWorkService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID vendorId = UUID.randomUUID();
    private final UUID warehouseId = UUID.randomUUID();
    private final UUID itemId1 = UUID.randomUUID();
    private final UUID itemId2 = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new JobWorkService(jobWorkOrderRepo, itemRepo, inventoryService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private Item buildItem(UUID id, String sku, String name, BigDecimal purchasePrice) {
        Item item = Item.builder()
                .sku(sku)
                .name(name)
                .itemType(ItemType.GOODS)
                .purchasePrice(purchasePrice)
                .salePrice(BigDecimal.ZERO)
                .build();
        item.setId(id);
        item.setOrgId(orgId);
        return item;
    }

    private void stubSaveAssignsId() {
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });
    }

    /**
     * Builds a JobWorkOrder with two MATERIAL lines already populated,
     * ready for send/receive/cancel tests.
     */
    private JobWorkOrder buildJobWorkOrder(String status) {
        JobWorkOrder jwo = JobWorkOrder.builder()
                .jobWorkNumber("JW-00001")
                .vendorId(vendorId)
                .warehouseId(warehouseId)
                .status(status)
                .processingCharges(BigDecimal.valueOf(500))
                .totalMaterialCost(BigDecimal.valueOf(2500))
                .totalCost(BigDecimal.valueOf(3000))
                .lines(new ArrayList<>())
                .build();
        jwo.setId(UUID.randomUUID());
        jwo.setOrgId(orgId);

        JobWorkOrderLine line1 = JobWorkOrderLine.builder()
                .jobWorkOrder(jwo)
                .itemId(itemId1)
                .lineType("MATERIAL")
                .sentQty(BigDecimal.TEN)
                .receivedQty(BigDecimal.ZERO)
                .wastageQty(BigDecimal.ZERO)
                .unitCost(BigDecimal.valueOf(100))
                .lineCost(BigDecimal.valueOf(1000))
                .status("PENDING")
                .build();
        line1.setId(UUID.randomUUID());
        line1.setOrgId(orgId);

        JobWorkOrderLine line2 = JobWorkOrderLine.builder()
                .jobWorkOrder(jwo)
                .itemId(itemId2)
                .lineType("MATERIAL")
                .sentQty(BigDecimal.valueOf(5))
                .receivedQty(BigDecimal.ZERO)
                .wastageQty(BigDecimal.ZERO)
                .unitCost(BigDecimal.valueOf(300))
                .lineCost(BigDecimal.valueOf(1500))
                .status("PENDING")
                .build();
        line2.setId(UUID.randomUUID());
        line2.setOrgId(orgId);

        jwo.getLines().add(line1);
        jwo.getLines().add(line2);
        return jwo;
    }

    // ── 1. createJobWorkOrder — success with correct costs ──────────────

    @Test
    void createJobWorkOrder_withMaterials_succeeds() {
        Item item1 = buildItem(itemId1, "RM-001", "Steel Rod", BigDecimal.valueOf(100));
        Item item2 = buildItem(itemId2, "RM-002", "Copper Wire", BigDecimal.valueOf(300));

        when(jobWorkOrderRepo.findMaxJobWorkNumber(orgId)).thenReturn(0);
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(itemId1, orgId)).thenReturn(Optional.of(item1));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(itemId2, orgId)).thenReturn(Optional.of(item2));
        stubSaveAssignsId();

        List<JobWorkService.JobWorkLineInput> materials = List.of(
                new JobWorkService.JobWorkLineInput(itemId1, BigDecimal.TEN),
                new JobWorkService.JobWorkLineInput(itemId2, BigDecimal.valueOf(5))
        );

        JobWorkOrder result = service.createJobWorkOrder(
                vendorId, warehouseId, materials,
                BigDecimal.valueOf(500),
                LocalDate.now(), LocalDate.now().plusDays(30), "Test JW");

        assertEquals("JW-00001", result.getJobWorkNumber());
        assertEquals("DRAFT", result.getStatus());
        assertEquals(2, result.getLines().size());
        assertEquals(vendorId, result.getVendorId());
        assertEquals(warehouseId, result.getWarehouseId());
        assertEquals("Test JW", result.getNotes());

        // Material cost: (100*10) + (300*5) = 1000 + 1500 = 2500
        assertEquals(0, BigDecimal.valueOf(2500).compareTo(result.getTotalMaterialCost()));
        // Total cost: 2500 + 500 (processing) = 3000
        assertEquals(0, BigDecimal.valueOf(3000).compareTo(result.getTotalCost()));
        assertEquals(0, BigDecimal.valueOf(500).compareTo(result.getProcessingCharges()));

        // Verify line details
        JobWorkOrderLine l1 = result.getLines().stream()
                .filter(l -> l.getItemId().equals(itemId1)).findFirst().orElseThrow();
        assertEquals(0, BigDecimal.TEN.compareTo(l1.getSentQty()));
        assertEquals(0, BigDecimal.valueOf(100).compareTo(l1.getUnitCost()));
        assertEquals(0, BigDecimal.valueOf(1000).setScale(2).compareTo(l1.getLineCost()));
        assertEquals("MATERIAL", l1.getLineType());

        verify(jobWorkOrderRepo, times(2)).save(any());
    }

    // ── 2. createJobWorkOrder — empty materials throws ──────────────────

    @Test
    void createJobWorkOrder_emptyMaterials_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createJobWorkOrder(
                        vendorId, warehouseId, List.of(),
                        BigDecimal.ZERO, null, null, null));
        assertEquals("JW_NO_MATERIALS", ex.getErrorCode());
    }

    @Test
    void createJobWorkOrder_nullMaterials_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createJobWorkOrder(
                        vendorId, warehouseId, null,
                        BigDecimal.ZERO, null, null, null));
        assertEquals("JW_NO_MATERIALS", ex.getErrorCode());
    }

    // ── 3. sendMaterials — DRAFT → SENT, stock movements ───────────────

    @Test
    void sendMaterials_draftOrder_sendsAndRecordsStock() {
        JobWorkOrder jwo = buildJobWorkOrder("DRAFT");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JobWorkOrder result = service.sendMaterials(jwo.getId());

        assertEquals("SENT", result.getStatus());
        assertNotNull(result.getActualSendDate());
        assertEquals(LocalDate.now(), result.getActualSendDate());
        assertEquals(LocalDate.now().plusYears(1), result.getGstReturnDeadline());
        assertEquals("JW-00001-DC", result.getChallanNumber());

        // Both MATERIAL lines should be SENT
        result.getLines().forEach(l -> assertEquals("SENT", l.getStatus()));

        // Two material lines → two recordMovement calls (negated qty)
        verify(inventoryService, times(2)).recordMovement(any());
    }

    // ── 4. sendMaterials — non-DRAFT throws ─────────────────────────────

    @Test
    void sendMaterials_sentOrder_throws() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.sendMaterials(jwo.getId()));
        assertEquals("JW_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void sendMaterials_completedOrder_throws() {
        JobWorkOrder jwo = buildJobWorkOrder("COMPLETED");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.sendMaterials(jwo.getId()));
        assertEquals("JW_NOT_DRAFT", ex.getErrorCode());
    }

    // ── 5. receiveGoods — SENT → receives goods, updates quantities ─────

    @Test
    void receiveGoods_sentOrder_receivesAndUpdatesQty() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");
        jwo.getLines().forEach(l -> l.setStatus("SENT"));

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // Receive partial on item1 only
        List<JobWorkService.JobWorkReceiveInput> inputs = List.of(
                new JobWorkService.JobWorkReceiveInput(itemId1, BigDecimal.valueOf(6), BigDecimal.ONE)
        );

        JobWorkOrder result = service.receiveGoods(jwo.getId(), inputs);

        // item1 line: received=6, wastage=1
        JobWorkOrderLine l1 = result.getLines().stream()
                .filter(l -> l.getItemId().equals(itemId1)).findFirst().orElseThrow();
        assertEquals(0, BigDecimal.valueOf(6).compareTo(l1.getReceivedQty()));
        assertEquals(0, BigDecimal.ONE.compareTo(l1.getWastageQty()));

        verify(inventoryService, times(1)).recordMovement(any());
    }

    // ── 6. receiveGoods — full receive → COMPLETED ──────────────────────

    @Test
    void receiveGoods_allLinesFullyReceived_completesOrder() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");
        jwo.getLines().forEach(l -> l.setStatus("SENT"));

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // Receive full qty for both items (received + wastage = sentQty)
        List<JobWorkService.JobWorkReceiveInput> inputs = List.of(
                new JobWorkService.JobWorkReceiveInput(itemId1, BigDecimal.valueOf(8), BigDecimal.valueOf(2)),
                new JobWorkService.JobWorkReceiveInput(itemId2, BigDecimal.valueOf(5), BigDecimal.ZERO)
        );

        JobWorkOrder result = service.receiveGoods(jwo.getId(), inputs);

        assertEquals("COMPLETED", result.getStatus());
        assertEquals(LocalDate.now(), result.getActualReturnDate());

        result.getLines().forEach(l -> assertEquals("RECEIVED", l.getStatus()));
    }

    // ── 7. receiveGoods — partial receive → PARTIALLY_RECEIVED ──────────

    @Test
    void receiveGoods_partialReceive_setsPartiallyReceived() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");
        jwo.getLines().forEach(l -> l.setStatus("SENT"));

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // Receive fully for item1 but nothing for item2
        List<JobWorkService.JobWorkReceiveInput> inputs = List.of(
                new JobWorkService.JobWorkReceiveInput(itemId1, BigDecimal.TEN, BigDecimal.ZERO)
        );

        JobWorkOrder result = service.receiveGoods(jwo.getId(), inputs);

        assertEquals("PARTIALLY_RECEIVED", result.getStatus());
        assertNull(result.getActualReturnDate());

        // item1 fully received
        JobWorkOrderLine l1 = result.getLines().stream()
                .filter(l -> l.getItemId().equals(itemId1)).findFirst().orElseThrow();
        assertEquals("RECEIVED", l1.getStatus());

        // item2 still SENT (untouched)
        JobWorkOrderLine l2 = result.getLines().stream()
                .filter(l -> l.getItemId().equals(itemId2)).findFirst().orElseThrow();
        assertEquals("SENT", l2.getStatus());
    }

    // ── 8. receiveGoods — exceeds sent qty throws ───────────────────────

    @Test
    void receiveGoods_exceedsSentQty_throws() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");
        jwo.getLines().forEach(l -> l.setStatus("SENT"));

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));

        // item1 sentQty=10, try to receive 11
        List<JobWorkService.JobWorkReceiveInput> inputs = List.of(
                new JobWorkService.JobWorkReceiveInput(itemId1, BigDecimal.valueOf(11), BigDecimal.ZERO)
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.receiveGoods(jwo.getId(), inputs));
        assertEquals("JW_EXCEEDS_SENT", ex.getErrorCode());

        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void receiveGoods_receivedPlusWastageExceedsSent_throws() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");
        jwo.getLines().forEach(l -> l.setStatus("SENT"));

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));

        // item1 sentQty=10, received=7 + wastage=5 = 12 > 10
        List<JobWorkService.JobWorkReceiveInput> inputs = List.of(
                new JobWorkService.JobWorkReceiveInput(itemId1, BigDecimal.valueOf(7), BigDecimal.valueOf(5))
        );

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.receiveGoods(jwo.getId(), inputs));
        assertEquals("JW_EXCEEDS_SENT", ex.getErrorCode());
    }

    // ── 9. cancelJobWorkOrder — SENT reverses unreceived stock ──────────

    @Test
    void cancelJobWorkOrder_sentOrder_reversesUnreceivedStock() {
        JobWorkOrder jwo = buildJobWorkOrder("SENT");
        jwo.getLines().forEach(l -> l.setStatus("SENT"));

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JobWorkOrder result = service.cancelJobWorkOrder(jwo.getId());

        assertEquals("CANCELLED", result.getStatus());
        result.getLines().forEach(l -> assertEquals("CANCELLED", l.getStatus()));

        // Both lines have receivedQty=0, wastageQty=0, so full sentQty is unreceived
        // → two ADJUSTMENT movements (one per line)
        verify(inventoryService, times(2)).recordMovement(any());
    }

    @Test
    void cancelJobWorkOrder_partiallyReceived_reversesOnlyUnreceived() {
        JobWorkOrder jwo = buildJobWorkOrder("PARTIALLY_RECEIVED");
        // item1: sent=10, received=6, wastage=1 → unreceived=3
        JobWorkOrderLine l1 = jwo.getLines().stream()
                .filter(l -> l.getItemId().equals(itemId1)).findFirst().orElseThrow();
        l1.setReceivedQty(BigDecimal.valueOf(6));
        l1.setWastageQty(BigDecimal.ONE);
        l1.setStatus("PARTIAL");

        // item2: sent=5, received=5, wastage=0 → unreceived=0 (no reversal needed)
        JobWorkOrderLine l2 = jwo.getLines().stream()
                .filter(l -> l.getItemId().equals(itemId2)).findFirst().orElseThrow();
        l2.setReceivedQty(BigDecimal.valueOf(5));
        l2.setWastageQty(BigDecimal.ZERO);
        l2.setStatus("RECEIVED");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JobWorkOrder result = service.cancelJobWorkOrder(jwo.getId());

        assertEquals("CANCELLED", result.getStatus());

        // Only one reversal: item1 has unreceived=3, item2 unreceived=0
        verify(inventoryService, times(1)).recordMovement(any());
    }

    @Test
    void cancelJobWorkOrder_draftOrder_cancelsWithoutStockReversal() {
        JobWorkOrder jwo = buildJobWorkOrder("DRAFT");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));
        when(jobWorkOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JobWorkOrder result = service.cancelJobWorkOrder(jwo.getId());

        assertEquals("CANCELLED", result.getStatus());
        result.getLines().forEach(l -> assertEquals("CANCELLED", l.getStatus()));

        // DRAFT → no stock was ever sent, so no reversal
        verify(inventoryService, never()).recordMovement(any());
    }

    // ── 10. cancelJobWorkOrder — COMPLETED throws ───────────────────────

    @Test
    void cancelJobWorkOrder_completedOrder_throws() {
        JobWorkOrder jwo = buildJobWorkOrder("COMPLETED");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancelJobWorkOrder(jwo.getId()));
        assertEquals("JW_ALREADY_COMPLETED", ex.getErrorCode());
    }

    // ── 11. cancelJobWorkOrder — already cancelled throws ───────────────

    @Test
    void cancelJobWorkOrder_alreadyCancelled_throws() {
        JobWorkOrder jwo = buildJobWorkOrder("CANCELLED");

        when(jobWorkOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(jwo.getId(), orgId))
                .thenReturn(Optional.of(jwo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancelJobWorkOrder(jwo.getId()));
        assertEquals("JW_ALREADY_CANCELLED", ex.getErrorCode());
    }
}
