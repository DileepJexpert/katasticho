package com.katasticho.erp.inventory.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for the F2.2 FEFO-aware deduction path in
 * {@link InventoryService#deductStockForInvoice}. Four scenarios cover
 * the full branch matrix:
 *
 * <ol>
 *   <li>Non-batch item → single aggregate SALE (regression guard that
 *       the v1 path is untouched).</li>
 *   <li>Batch-tracked item with an explicit {@code line.batchId} →
 *       one movement against that batch, no FEFO walk.</li>
 *   <li>Batch-tracked item with NO pre-selected batch →
 *       FEFO auto-picks across multiple batches, producing one
 *       {@code stock_movement} row per batch consumed.</li>
 *   <li>Batch-tracked item with insufficient total stock →
 *       fails loud with {@code INV_INSUFFICIENT_BATCH_STOCK} and
 *       posts NOTHING (outer tx rolls back).</li>
 * </ol>
 *
 * Plus one credit-note test: batch-tracked restore without a batchId
 * must fail with {@code CN_BATCH_REQUIRED}.
 */
@ExtendWith(MockitoExtension.class)
class InventoryServiceFefoTest {

    @Mock private ItemRepository itemRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private StockMovementRepository stockMovementRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private BomComponentRepository bomComponentRepository;
    @Mock private BatchService batchService;
    @Mock private AuditService auditService;
    @Mock private com.katasticho.erp.common.cache.CacheInvalidationService cacheInvalidationService;

    private InventoryService inventoryService;
    private UUID orgId;
    private UUID userId;
    private Warehouse warehouse;
    private Item paracetamol;

    @BeforeEach
    void setUp() {
        inventoryService = new InventoryService(
                itemRepository, warehouseRepository, stockMovementRepository,
                stockBalanceRepository, bomComponentRepository, batchService, auditService,
                cacheInvalidationService);

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        warehouse = Warehouse.builder().code("MAIN").name("Main Store").build();
        warehouse.setId(UUID.randomUUID());
        warehouse.setOrgId(orgId);

        paracetamol = Item.builder()
                .sku("MED-001").name("Paracetamol 500mg")
                .itemType(ItemType.GOODS).unitOfMeasure("STRIP")
                .gstRate(new BigDecimal("12"))
                .purchasePrice(new BigDecimal("10"))
                .hsnCode("3004")
                .trackInventory(true)
                .build();
        paracetamol.setId(UUID.randomUUID());
        paracetamol.setOrgId(orgId);

        // Every successful path hits the default warehouse lookup.
        lenient().when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(warehouse));
        lenient().when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouse.getId(), orgId))
                .thenReturn(Optional.of(warehouse));
        // And the balance-cache lookup inside recordMovement().
        lenient().when(stockBalanceRepository
                .findByOrgIdAndItemIdAndWarehouseId(eq(orgId), any(UUID.class), eq(warehouse.getId())))
                .thenReturn(Optional.empty());
        lenient().when(stockBalanceRepository.save(any(StockBalance.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(stockMovementRepository.save(any(StockMovement.class)))
                .thenAnswer(inv -> {
                    StockMovement m = inv.getArgument(0);
                    if (m.getId() == null) m.setId(UUID.randomUUID());
                    return m;
                });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // --------------------------------------------------------------
    // 1. Non-batch item — regression guard
    // --------------------------------------------------------------
    @Test
    void deductStockForInvoice_nonBatchItem_singleAggregateMovement() {
        paracetamol.setTrackBatches(false);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));

        Invoice invoice = buildInvoice();
        InvoiceLine line = buildLine(paracetamol.getId(), new BigDecimal("15"),
                new BigDecimal("20"), null);
        invoice.addLine(line);

        inventoryService.deductStockForInvoice(invoice);

        ArgumentCaptor<StockMovement> captor = ArgumentCaptor.forClass(StockMovement.class);
        verify(stockMovementRepository, times(1)).save(captor.capture());
        StockMovement saved = captor.getValue();

        assertEquals(MovementType.SALE, saved.getMovementType());
        assertNull(saved.getBatchId(), "non-batch items must never carry a batchId");
        assertEquals(0, new BigDecimal("-15.0000").compareTo(saved.getQuantity()));
        assertEquals(ReferenceType.INVOICE, saved.getReferenceType());
        // Non-batch path must never touch the batch service.
        verify(batchService, never()).findFefoBatches(any(), any());
        verify(batchService, never()).applyDelta(any(), any(), any());
    }

    // --------------------------------------------------------------
    // 2. Explicit batch pick — honoured verbatim, no FEFO walk
    // --------------------------------------------------------------
    @Test
    void deductStockForInvoice_explicitBatchPick_honoured() {
        paracetamol.setTrackBatches(true);
        UUID pickedBatchId = UUID.randomUUID();

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));
        // The gate's per-batch balance update runs inside recordMovement —
        // applyDelta just needs to return something non-null.
        when(batchService.applyDelta(eq(pickedBatchId), eq(warehouse.getId()), any(BigDecimal.class)))
                .thenReturn(StockBatchBalance.builder().build());

        Invoice invoice = buildInvoice();
        InvoiceLine line = buildLine(paracetamol.getId(), new BigDecimal("25"),
                new BigDecimal("10"), pickedBatchId);
        invoice.addLine(line);

        inventoryService.deductStockForInvoice(invoice);

        ArgumentCaptor<StockMovement> captor = ArgumentCaptor.forClass(StockMovement.class);
        verify(stockMovementRepository, times(1)).save(captor.capture());
        assertEquals(pickedBatchId, captor.getValue().getBatchId());
        assertEquals(0, new BigDecimal("-25.0000").compareTo(captor.getValue().getQuantity()));

        // Explicit pick must skip the FEFO lookup entirely.
        verify(batchService, never()).findFefoBatches(any(), any());
        // But it DOES fan out the delta to the per-batch balance.
        verify(batchService).applyDelta(eq(pickedBatchId), eq(warehouse.getId()),
                eq(new BigDecimal("-25.0000")));
    }

    // --------------------------------------------------------------
    // 3. FEFO auto-pick splits across two batches
    // --------------------------------------------------------------
    @Test
    void deductStockForInvoice_fefoAutoPick_splitsAcrossBatches() {
        paracetamol.setTrackBatches(true);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));

        // Batch A: expires sooner, has 30 on hand.
        StockBatch batchA = StockBatch.builder()
                .itemId(paracetamol.getId()).batchNumber("LOT-A")
                .expiryDate(LocalDate.of(2026, 6, 30))
                .unitCost(new BigDecimal("10.00")).active(true).build();
        batchA.setId(UUID.randomUUID());
        batchA.setOrgId(orgId);

        // Batch B: expires later, has 40 on hand.
        StockBatch batchB = StockBatch.builder()
                .itemId(paracetamol.getId()).batchNumber("LOT-B")
                .expiryDate(LocalDate.of(2026, 9, 30))
                .unitCost(new BigDecimal("11.00")).active(true).build();
        batchB.setId(UUID.randomUUID());
        batchB.setOrgId(orgId);

        when(batchService.findFefoBatches(paracetamol.getId(), warehouse.getId()))
                .thenReturn(List.of(batchA, batchB));
        when(batchService.getBatchBalance(batchA.getId(), warehouse.getId()))
                .thenReturn(new BigDecimal("30"));
        when(batchService.getBatchBalance(batchB.getId(), warehouse.getId()))
                .thenReturn(new BigDecimal("40"));
        when(batchService.applyDelta(any(UUID.class), eq(warehouse.getId()), any(BigDecimal.class)))
                .thenReturn(StockBatchBalance.builder().build());

        Invoice invoice = buildInvoice();
        // Need 50: 30 from batch A, 20 from batch B.
        InvoiceLine line = buildLine(paracetamol.getId(), new BigDecimal("50"),
                new BigDecimal("15"), null);
        invoice.addLine(line);

        inventoryService.deductStockForInvoice(invoice);

        ArgumentCaptor<StockMovement> captor = ArgumentCaptor.forClass(StockMovement.class);
        verify(stockMovementRepository, times(2)).save(captor.capture());
        List<StockMovement> saved = captor.getAllValues();

        // First movement consumes the full 30 from batch A (earliest expiry).
        assertEquals(batchA.getId(), saved.get(0).getBatchId());
        assertEquals(0, new BigDecimal("-30.0000").compareTo(saved.get(0).getQuantity()));

        // Second movement takes the remaining 20 from batch B.
        assertEquals(batchB.getId(), saved.get(1).getBatchId());
        assertEquals(0, new BigDecimal("-20.0000").compareTo(saved.get(1).getQuantity()));

        // Both movements reference the same invoice.
        saved.forEach(m -> {
            assertEquals(invoice.getId(), m.getReferenceId());
            assertEquals(ReferenceType.INVOICE, m.getReferenceType());
            assertEquals(MovementType.SALE, m.getMovementType());
        });

        // Per-batch balance fan-out once per batch consumed.
        verify(batchService).applyDelta(eq(batchA.getId()), eq(warehouse.getId()),
                eq(new BigDecimal("-30.0000")));
        verify(batchService).applyDelta(eq(batchB.getId()), eq(warehouse.getId()),
                eq(new BigDecimal("-20.0000")));
    }

    // --------------------------------------------------------------
    // 4. FEFO shortfall fails loud and posts nothing
    // --------------------------------------------------------------
    @Test
    void deductStockForInvoice_fefoShortfall_throwsInsufficient() {
        paracetamol.setTrackBatches(true);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));

        StockBatch onlyBatch = StockBatch.builder()
                .itemId(paracetamol.getId()).batchNumber("LOT-A")
                .expiryDate(LocalDate.of(2026, 6, 30))
                .unitCost(new BigDecimal("10.00")).active(true).build();
        onlyBatch.setId(UUID.randomUUID());
        onlyBatch.setOrgId(orgId);

        when(batchService.findFefoBatches(paracetamol.getId(), warehouse.getId()))
                .thenReturn(List.of(onlyBatch));
        when(batchService.getBatchBalance(onlyBatch.getId(), warehouse.getId()))
                .thenReturn(new BigDecimal("10")); // only 10 available, line wants 50
        when(batchService.applyDelta(any(UUID.class), eq(warehouse.getId()), any(BigDecimal.class)))
                .thenReturn(StockBatchBalance.builder().build());

        Invoice invoice = buildInvoice();
        InvoiceLine line = buildLine(paracetamol.getId(), new BigDecimal("50"),
                new BigDecimal("15"), null);
        invoice.addLine(line);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> inventoryService.deductStockForInvoice(invoice));
        assertEquals("INV_INSUFFICIENT_BATCH_STOCK", ex.getErrorCode());
        // The message should name the short-by quantity so the operator
        // knows exactly how much is missing.
        assertTrue(ex.getMessage().contains("40"),
                "error message should surface the shortfall: " + ex.getMessage());
    }

    // --------------------------------------------------------------
    // 5. Credit note restore without batch on a tracked item
    // --------------------------------------------------------------
    @Test
    void restoreStockForCreditNote_trackedItemWithoutBatch_throwsCnBatchRequired() {
        paracetamol.setTrackBatches(true);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));

        UUID cnId = UUID.randomUUID();
        BusinessException ex = assertThrows(BusinessException.class,
                () -> inventoryService.restoreStockForCreditNote(
                        orgId, paracetamol.getId(),
                        new BigDecimal("5"), new BigDecimal("10"),
                        cnId, "CN-2026-000001", LocalDate.of(2026, 4, 20),
                        null));

        assertEquals("CN_BATCH_REQUIRED", ex.getErrorCode());
        // And no stock_movement row was even attempted.
        verify(stockMovementRepository, never()).save(any(StockMovement.class));
    }

    // --------------------------------------------------------------
    // 6. Composite item explosion — BOM is walked, children deducted
    //    at (childQty × lineQty), parent never posts its own movement
    // --------------------------------------------------------------
    @Test
    void deductStockForInvoice_compositeItem_explodesBom() {
        // Parent kit: 1 HAMPER = 2× CHOCOLATE + 1× CARD. Selling 3
        // hampers should deduct 6 chocolates and 3 cards — and NO
        // movement against the hamper itself.
        Item hamper = Item.builder()
                .sku("HAMPER-01").name("Gift Hamper")
                .itemType(ItemType.COMPOSITE).unitOfMeasure("PCS")
                .purchasePrice(new BigDecimal("100"))
                .salePrice(new BigDecimal("250"))
                .gstRate(BigDecimal.ZERO)
                .trackInventory(false) // composites never hold stock
                .build();
        hamper.setId(UUID.randomUUID());
        hamper.setOrgId(orgId);

        Item chocolate = Item.builder()
                .sku("CHOC-01").name("Chocolate Box")
                .itemType(ItemType.GOODS).unitOfMeasure("PCS")
                .purchasePrice(new BigDecimal("30"))
                .salePrice(new BigDecimal("50"))
                .gstRate(BigDecimal.ZERO)
                .trackInventory(true).trackBatches(false)
                .build();
        chocolate.setId(UUID.randomUUID());
        chocolate.setOrgId(orgId);

        Item card = Item.builder()
                .sku("CARD-01").name("Greeting Card")
                .itemType(ItemType.GOODS).unitOfMeasure("PCS")
                .purchasePrice(new BigDecimal("5"))
                .salePrice(new BigDecimal("10"))
                .gstRate(BigDecimal.ZERO)
                .trackInventory(true).trackBatches(false)
                .build();
        card.setId(UUID.randomUUID());
        card.setOrgId(orgId);

        BomComponent chocolateRow = BomComponent.builder()
                .parentItemId(hamper.getId())
                .childItemId(chocolate.getId())
                .quantity(new BigDecimal("2"))
                .build();
        chocolateRow.setId(UUID.randomUUID());
        chocolateRow.setOrgId(orgId);

        BomComponent cardRow = BomComponent.builder()
                .parentItemId(hamper.getId())
                .childItemId(card.getId())
                .quantity(new BigDecimal("1"))
                .build();
        cardRow.setId(UUID.randomUUID());
        cardRow.setOrgId(orgId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(hamper.getId(), orgId))
                .thenReturn(Optional.of(hamper));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(chocolate.getId(), orgId))
                .thenReturn(Optional.of(chocolate));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(card.getId(), orgId))
                .thenReturn(Optional.of(card));
        when(bomComponentRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, hamper.getId()))
                .thenReturn(List.of(chocolateRow, cardRow));

        Invoice invoice = buildInvoice();
        InvoiceLine line = buildLine(hamper.getId(), new BigDecimal("3"),
                new BigDecimal("250"), null);
        invoice.addLine(line);

        // Hamper itself has trackInventory=false, so recordMovement's
        // early-return guard would no-op the parent regardless. The
        // important assertion is that the explosion path fires and
        // saves exactly 2 child movements (one per BOM row), not 3
        // (parent + children).
        inventoryService.deductStockForInvoice(invoice);

        ArgumentCaptor<StockMovement> captor = ArgumentCaptor.forClass(StockMovement.class);
        verify(stockMovementRepository, times(2)).save(captor.capture());
        List<StockMovement> saved = captor.getAllValues();

        // Row 0: 2 chocolates × 3 hampers = 6 chocolates out.
        assertEquals(chocolate.getId(), saved.get(0).getItemId());
        assertEquals(0, new BigDecimal("-6.0000").compareTo(saved.get(0).getQuantity()));
        assertEquals(MovementType.SALE, saved.get(0).getMovementType());
        assertNull(saved.get(0).getBatchId());

        // Row 1: 1 card × 3 hampers = 3 cards out.
        assertEquals(card.getId(), saved.get(1).getItemId());
        assertEquals(0, new BigDecimal("-3.0000").compareTo(saved.get(1).getQuantity()));

        // Parent hamper never appears as the itemId on any movement.
        saved.forEach(m -> assertNotEquals(hamper.getId(), m.getItemId(),
                "composite parent must never post its own movement"));

        // No batch-service calls — BOM children are non-batch by v1 contract.
        verify(batchService, never()).findFefoBatches(any(), any());
        verify(batchService, never()).applyDelta(any(), any(), any());
    }

    // -------- helpers ---------------------------------------------

    private Invoice buildInvoice() {
        Invoice invoice = Invoice.builder()
                .orgId(orgId)
                .invoiceNumber("INV-2026-000001")
                .invoiceDate(LocalDate.of(2026, 4, 12))
                .build();
        invoice.setId(UUID.randomUUID());
        return invoice;
    }

    private InvoiceLine buildLine(UUID itemId, BigDecimal qty, BigDecimal unitPrice, UUID batchId) {
        InvoiceLine line = InvoiceLine.builder()
                .lineNumber(1)
                .description("test line")
                .itemId(itemId)
                .quantity(qty)
                .unitPrice(unitPrice)
                .taxableAmount(qty.multiply(unitPrice))
                .accountCode("4010")
                .batchId(batchId)
                .build();
        line.setId(UUID.randomUUID());
        return line;
    }
}
