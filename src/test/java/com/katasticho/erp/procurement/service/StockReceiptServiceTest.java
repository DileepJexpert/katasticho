package com.katasticho.erp.procurement.service;

import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.StockReceiptLineRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.entity.StockReceipt;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.StockReceiptRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
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
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StockReceiptServiceTest {

    @Mock private StockReceiptRepository receiptRepository;
    @Mock private SupplierRepository supplierRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private InventoryService inventoryService;
    @Mock private BatchService batchService;
    @Mock private AuditService auditService;

    private StockReceiptService stockReceiptService;
    private UUID orgId;
    private UUID userId;
    private Organisation org;
    private Supplier supplier;
    private Warehouse defaultWarehouse;
    private Item paracetamol;
    private Item crocin;

    @BeforeEach
    void setUp() {
        stockReceiptService = new StockReceiptService(
                receiptRepository, supplierRepository, itemRepository,
                warehouseRepository, organisationRepository, sequenceRepository,
                inventoryService, batchService, auditService);

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        org = Organisation.builder().name("Pharma Co").stateCode("MH").fiscalYearStart(4).build();
        org.setId(orgId);

        supplier = Supplier.builder().name("Sharma Distributors").gstin("27AAAAA0000A1Z5")
                .stateCode("MH").build();
        supplier.setId(UUID.randomUUID());
        supplier.setOrgId(orgId);

        defaultWarehouse = Warehouse.builder().code("MAIN").name("Main Store").build();
        defaultWarehouse.setId(UUID.randomUUID());
        defaultWarehouse.setOrgId(orgId);

        paracetamol = Item.builder().sku("MED-001").name("Paracetamol 500mg")
                .itemType(ItemType.GOODS).unitOfMeasure("STRIP").gstRate(new BigDecimal("12"))
                .purchasePrice(new BigDecimal("10")).hsnCode("3004").trackInventory(true).build();
        paracetamol.setId(UUID.randomUUID());
        paracetamol.setOrgId(orgId);

        crocin = Item.builder().sku("MED-002").name("Crocin Advance")
                .itemType(ItemType.GOODS).unitOfMeasure("STRIP").gstRate(new BigDecimal("12"))
                .purchasePrice(new BigDecimal("22")).hsnCode("3004").trackInventory(true).build();
        crocin.setId(UUID.randomUUID());
        crocin.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // T-GRN-01: Create draft from a multi-line GRN computes totals + GST correctly
    @Test
    void shouldCreateDraftWithMultipleLinesAndComputeTotals() {
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(supplier.getId(), orgId))
                .thenReturn(Optional.of(supplier));
        when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(defaultWarehouse));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(crocin.getId(), orgId))
                .thenReturn(Optional.of(crocin));
        when(sequenceRepository.findByOrgIdAndPrefixAndYear(eq(orgId), eq("GRN"), anyInt()))
                .thenReturn(Optional.empty());
        when(receiptRepository.save(any(StockReceipt.class))).thenAnswer(inv -> {
            StockReceipt r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
        // toResponse() does a bulk findAllById to load SKUs.
        when(itemRepository.findAllById(anyIterable())).thenReturn(List.of(paracetamol, crocin));

        var request = new CreateStockReceiptRequest(
                supplier.getId(),
                null, // default warehouse
                LocalDate.of(2026, 4, 12),
                "VEND-INV-4521",
                LocalDate.of(2026, 4, 11),
                "Monthly stock arrival",
                List.of(
                        new StockReceiptLineRequest(
                                paracetamol.getId(), null, null,
                                new BigDecimal("200"), "STRIP",
                                new BigDecimal("10"), null, null,
                                "BATCH-PARA-001", LocalDate.of(2027, 12, 31), null),
                        new StockReceiptLineRequest(
                                crocin.getId(), null, null,
                                new BigDecimal("150"), "STRIP",
                                new BigDecimal("22"), null, null,
                                null, null, null)
                )
        );

        StockReceiptResponse response = stockReceiptService.createDraft(request);

        assertNotNull(response);
        assertEquals("DRAFT", response.status());
        // 200 * 10 = 2000 ; 150 * 22 = 3300 → subtotal 5300
        assertEquals(0, new BigDecimal("5300.00").compareTo(response.subtotal()));
        // 12% GST on 5300 = 636
        assertEquals(0, new BigDecimal("636.00").compareTo(response.taxAmount()));
        assertEquals(0, new BigDecimal("5936.00").compareTo(response.totalAmount()));
        assertEquals(2, response.lines().size());
        assertEquals("BATCH-PARA-001", response.lines().get(0).batchNumber());

        // No stock movements yet — receipt is still DRAFT
        verifyNoInteractions(inventoryService);
    }

    // T-GRN-02: Receive posts one PURCHASE movement per line via the inventory gate
    @Test
    void shouldReceivePostsOneMovementPerLine() {
        StockReceipt draft = StockReceipt.builder()
                .orgId(orgId)
                .receiptNumber("GRN-2026-000001")
                .receiptDate(LocalDate.of(2026, 4, 12))
                .warehouseId(defaultWarehouse.getId())
                .supplierId(supplier.getId())
                .status("DRAFT")
                .currency("INR")
                .subtotal(new BigDecimal("5300.00"))
                .taxAmount(new BigDecimal("636.00"))
                .totalAmount(new BigDecimal("5936.00"))
                .build();
        draft.setId(UUID.randomUUID());

        var line1 = com.katasticho.erp.procurement.entity.StockReceiptLine.builder()
                .lineNumber(1).itemId(paracetamol.getId()).description("Paracetamol 500mg")
                .quantity(new BigDecimal("200")).unitOfMeasure("STRIP")
                .unitPrice(new BigDecimal("10")).taxableAmount(new BigDecimal("2000"))
                .gstRate(new BigDecimal("12")).taxAmount(new BigDecimal("240"))
                .lineTotal(new BigDecimal("2240")).batchNumber("BATCH-PARA-001").build();
        line1.setId(UUID.randomUUID());
        var line2 = com.katasticho.erp.procurement.entity.StockReceiptLine.builder()
                .lineNumber(2).itemId(crocin.getId()).description("Crocin Advance")
                .quantity(new BigDecimal("150")).unitOfMeasure("STRIP")
                .unitPrice(new BigDecimal("22")).taxableAmount(new BigDecimal("3300"))
                .gstRate(new BigDecimal("12")).taxAmount(new BigDecimal("396"))
                .lineTotal(new BigDecimal("3696")).build();
        line2.setId(UUID.randomUUID());
        draft.addLine(line1);
        draft.addLine(line2);

        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(draft.getId(), orgId))
                .thenReturn(Optional.of(draft));
        when(receiptRepository.save(any(StockReceipt.class))).thenAnswer(inv -> inv.getArgument(0));
        // receive() now re-fetches each line's item to check track_batches before
        // routing to the inventory gate — stub those lookups.
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(paracetamol.getId(), orgId))
                .thenReturn(Optional.of(paracetamol));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(crocin.getId(), orgId))
                .thenReturn(Optional.of(crocin));

        // recordMovement returns a movement with an id we can capture on the line
        StockMovement m1 = StockMovement.builder().itemId(paracetamol.getId()).build();
        m1.setId(UUID.randomUUID());
        StockMovement m2 = StockMovement.builder().itemId(crocin.getId()).build();
        m2.setId(UUID.randomUUID());
        when(inventoryService.recordMovement(any(StockMovementRequest.class)))
                .thenReturn(m1).thenReturn(m2);

        when(itemRepository.findAllById(anyIterable())).thenReturn(List.of(paracetamol, crocin));

        StockReceiptResponse response = stockReceiptService.receive(draft.getId());

        assertEquals("RECEIVED", response.status());

        ArgumentCaptor<StockMovementRequest> captor = ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService, times(2)).recordMovement(captor.capture());

        var movements = captor.getAllValues();
        // First line — Paracetamol
        assertEquals(paracetamol.getId(), movements.get(0).itemId());
        assertEquals(MovementType.PURCHASE, movements.get(0).movementType());
        assertEquals(0, new BigDecimal("200").compareTo(movements.get(0).quantity()));
        assertEquals(ReferenceType.STOCK_RECEIPT, movements.get(0).referenceType());
        assertEquals(draft.getId(), movements.get(0).referenceId());
        assertEquals("GRN-2026-000001", movements.get(0).referenceNumber());

        // Second line — Crocin
        assertEquals(crocin.getId(), movements.get(1).itemId());
        assertEquals(0, new BigDecimal("150").compareTo(movements.get(1).quantity()));

        // Lines now hold the resulting movement IDs
        assertEquals(m1.getId(), line1.getStockMovementId());
        assertEquals(m2.getId(), line2.getStockMovementId());
    }

    // T-GRN-03: Receive on a non-DRAFT receipt is rejected
    @Test
    void shouldRejectReceiveForNonDraftReceipt() {
        StockReceipt received = StockReceipt.builder().orgId(orgId).status("RECEIVED").build();
        received.setId(UUID.randomUUID());

        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(received.getId(), orgId))
                .thenReturn(Optional.of(received));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> stockReceiptService.receive(received.getId()));
        assertEquals("GRN_NOT_DRAFT", ex.getErrorCode());
        verifyNoInteractions(inventoryService);
    }

    // T-GRN-04: Cancelling a RECEIVED receipt reverses every stock movement
    @Test
    void shouldReverseAllMovementsWhenCancellingReceivedReceipt() {
        UUID m1Id = UUID.randomUUID();
        UUID m2Id = UUID.randomUUID();

        StockReceipt received = StockReceipt.builder()
                .orgId(orgId).receiptNumber("GRN-2026-000007").status("RECEIVED")
                .warehouseId(defaultWarehouse.getId()).supplierId(supplier.getId())
                .build();
        received.setId(UUID.randomUUID());
        var l1 = com.katasticho.erp.procurement.entity.StockReceiptLine.builder()
                .lineNumber(1).itemId(paracetamol.getId())
                .quantity(new BigDecimal("100")).unitPrice(new BigDecimal("10"))
                .taxableAmount(new BigDecimal("1000")).lineTotal(new BigDecimal("1120"))
                .stockMovementId(m1Id).build();
        var l2 = com.katasticho.erp.procurement.entity.StockReceiptLine.builder()
                .lineNumber(2).itemId(crocin.getId())
                .quantity(new BigDecimal("50")).unitPrice(new BigDecimal("22"))
                .taxableAmount(new BigDecimal("1100")).lineTotal(new BigDecimal("1232"))
                .stockMovementId(m2Id).build();
        received.addLine(l1);
        received.addLine(l2);

        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(received.getId(), orgId))
                .thenReturn(Optional.of(received));
        when(receiptRepository.save(any(StockReceipt.class))).thenAnswer(inv -> inv.getArgument(0));
        when(itemRepository.findAllById(anyIterable())).thenReturn(List.of(paracetamol, crocin));

        StockReceiptResponse response = stockReceiptService.cancel(received.getId(), "wrong batch");

        assertEquals("CANCELLED", response.status());
        assertEquals("wrong batch", response.cancelReason());

        verify(inventoryService).reverseMovement(eq(m1Id), contains("wrong batch"));
        verify(inventoryService).reverseMovement(eq(m2Id), contains("wrong batch"));
        verifyNoMoreInteractions(inventoryService);
    }
}
