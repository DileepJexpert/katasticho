package com.katasticho.erp.sales.service;

import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.sales.dto.DeliveryChallanResponse;
import com.katasticho.erp.sales.entity.*;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.sales.repository.StockReservationRepository;
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
class DeliveryChallanServiceTest {

    @Mock private DeliveryChallanRepository challanRepository;
    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private StockReservationRepository reservationRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private StockBatchRepository batchRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private InventoryService inventoryService;
    @Mock private SalesOrderService salesOrderService;
    @Mock private CommentService commentService;

    private DeliveryChallanService deliveryChallanService;

    private UUID orgId;
    private UUID contactId;
    private UUID itemId;
    private UUID warehouseId;
    private UUID soId;
    private Item trackedItem;
    private Contact contact;
    private Warehouse warehouse;

    @BeforeEach
    void setUp() {
        deliveryChallanService = new DeliveryChallanService(
                challanRepository, salesOrderRepository, reservationRepository,
                contactRepository, itemRepository, warehouseRepository,
                batchRepository, branchRepository, sequenceRepository,
                inventoryService, salesOrderService, commentService);

        orgId = UUID.randomUUID();
        contactId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();
        soId = UUID.randomUUID();

        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        trackedItem = new Item();
        trackedItem.setId(itemId);
        trackedItem.setName("Widget A");
        trackedItem.setTrackInventory(true);

        contact = new Contact();
        contact.setId(contactId);
        contact.setCompanyName("ACME Corp");

        warehouse = new Warehouse();
        warehouse.setId(warehouseId);
        warehouse.setName("Main Warehouse");

        lenient().when(itemRepository.findById(itemId)).thenReturn(Optional.of(trackedItem));
        lenient().when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        lenient().when(warehouseRepository.findById(warehouseId)).thenReturn(Optional.of(warehouse));
        lenient().when(challanRepository.save(any(DeliveryChallan.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(salesOrderRepository.save(any(SalesOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(salesOrderRepository.findById(soId))
                .thenAnswer(inv -> {
                    SalesOrder s = new SalesOrder();
                    s.setId(soId);
                    s.setSalesorderNumber("SO-001");
                    return Optional.of(s);
                });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── dispatch() ───────────────────────────────────────────────

    @Test
    void dispatch_draftChallan_deductsStockAndFulfillsReservation() {
        UUID challanId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();

        SalesOrderLine soLine = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("10"))
                .rate(new BigDecimal("500"))
                .build();
        soLine.setId(soLineId);
        soLine.setQuantityShipped(BigDecimal.ZERO);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");
        so.addLine(soLine);

        DeliveryChallanLine challanLine = DeliveryChallanLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .salesOrderLineId(soLineId)
                .quantity(new BigDecimal("10"))
                .build();
        challanLine.setId(UUID.randomUUID());

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId)
                .contactId(contactId)
                .warehouseId(warehouseId)
                .challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.addLine(challanLine);

        StockReservation reservation = StockReservation.builder()
                .orgId(orgId)
                .itemId(itemId)
                .warehouseId(warehouseId)
                .sourceType("SALES_ORDER")
                .sourceId(soId)
                .sourceLineId(soLineId)
                .quantityReserved(new BigDecimal("10"))
                .build();
        reservation.setStatus("ACTIVE");

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(reservationRepository.findBySourceTypeAndSourceLineId("SALES_ORDER", soLineId))
                .thenReturn(Optional.of(reservation));
        when(reservationRepository.save(any(StockReservation.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        DeliveryChallanResponse result = deliveryChallanService.dispatch(challanId);

        assertEquals("DISPATCHED", result.status());

        // Stock movement created with SALE type and negative quantity
        ArgumentCaptor<StockMovementRequest> moveCaptor =
                ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(moveCaptor.capture());
        StockMovementRequest move = moveCaptor.getValue();
        assertEquals(itemId, move.itemId());
        assertEquals(warehouseId, move.warehouseId());
        assertEquals(0, new BigDecimal("-10").compareTo(move.quantity()));

        // Reservation marked fulfilled
        assertEquals("FULFILLED", reservation.getStatus());
        assertNotNull(reservation.getFulfilledAt());
        assertEquals(0, BigDecimal.ZERO.compareTo(reservation.getQuantityReserved()));

        // SO qty_shipped updated
        assertEquals(0, new BigDecimal("10").compareTo(soLine.getQuantityShipped()));

        // SO shipped status updated
        assertEquals("FULLY_SHIPPED", so.getShippedStatus());
    }

    @Test
    void dispatch_partialShipment_setsPartiallyShippedStatus() {
        UUID challanId = UUID.randomUUID();
        UUID soLine1Id = UUID.randomUUID();
        UUID soLine2Id = UUID.randomUUID();

        SalesOrderLine soLine1 = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("10"))
                .rate(new BigDecimal("500"))
                .build();
        soLine1.setId(soLine1Id);
        soLine1.setQuantityShipped(BigDecimal.ZERO);

        SalesOrderLine soLine2 = SalesOrderLine.builder()
                .lineNumber(2)
                .itemId(null)  // text-only line
                .description("Freight charges")
                .quantity(new BigDecimal("1"))
                .rate(new BigDecimal("200"))
                .build();
        soLine2.setId(soLine2Id);
        soLine2.setQuantityShipped(BigDecimal.ZERO);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");
        so.addLine(soLine1);
        so.addLine(soLine2);

        // Challan ships only 5 of 10 for line 1
        DeliveryChallanLine challanLine = DeliveryChallanLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .salesOrderLineId(soLine1Id)
                .quantity(new BigDecimal("5"))
                .build();
        challanLine.setId(UUID.randomUUID());

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId)
                .contactId(contactId)
                .warehouseId(warehouseId)
                .challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.addLine(challanLine);

        StockReservation reservation = StockReservation.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .sourceType("SALES_ORDER").sourceId(soId).sourceLineId(soLine1Id)
                .quantityReserved(new BigDecimal("10"))
                .build();
        reservation.setStatus("ACTIVE");

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(reservationRepository.findBySourceTypeAndSourceLineId("SALES_ORDER", soLine1Id))
                .thenReturn(Optional.of(reservation));
        when(reservationRepository.save(any(StockReservation.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        deliveryChallanService.dispatch(challanId);

        // Reservation still ACTIVE with reduced qty (partial fulfillment)
        assertEquals("ACTIVE", reservation.getStatus());
        assertEquals(0, new BigDecimal("5").compareTo(reservation.getQuantityReserved()));

        // SO shipped status = PARTIALLY_SHIPPED (line2 not shipped yet)
        assertEquals("PARTIALLY_SHIPPED", so.getShippedStatus());
    }

    @Test
    void dispatch_notDraftChallan_throwsBusinessException() {
        UUID challanId = UUID.randomUUID();

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId)
                .contactId(contactId)
                .challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.setStatus("DISPATCHED");

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> deliveryChallanService.dispatch(challanId));

        assertEquals("DC_NOT_DRAFT", ex.getErrorCode());
        verify(inventoryService, never()).recordMovement(any());
    }

    // ── cancel() ─────────────────────────────────────────────────

    @Test
    void cancel_draftChallan_setsCancelled() {
        UUID challanId = UUID.randomUUID();

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId)
                .contactId(contactId)
                .challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));

        deliveryChallanService.cancel(challanId);

        assertEquals("CANCELLED", challan.getStatus());
        verify(challanRepository).save(challan);
    }

    @Test
    void cancel_dispatchedChallan_throwsBusinessException() {
        UUID challanId = UUID.randomUUID();

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId)
                .contactId(contactId)
                .challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.setStatus("DISPATCHED");

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> deliveryChallanService.cancel(challanId));

        assertEquals("DC_CANNOT_CANCEL", ex.getErrorCode());
        verify(challanRepository, never()).save(any());
    }

    // ── create() ─────────────────────────────────────────────────

    @Test
    void create_salesOrderNotConfirmed_throwsBusinessException() {
        UUID draftSoId = UUID.randomUUID();

        SalesOrder draftSo = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        draftSo.setId(draftSoId);
        draftSo.setOrgId(orgId);
        // status = DRAFT (default)

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(draftSoId, orgId))
                .thenReturn(Optional.of(draftSo));

        var request = new com.katasticho.erp.sales.dto.CreateDeliveryChallanRequest(
                draftSoId, List.of(), null, null, null, null, null, null);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> deliveryChallanService.create(request));

        assertEquals("DC_INVALID_SO_STATUS", ex.getErrorCode());
    }
}
