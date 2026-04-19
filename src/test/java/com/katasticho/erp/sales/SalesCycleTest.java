package com.katasticho.erp.sales;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import java.time.Instant;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.estimate.repository.EstimateRepository;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.*;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.sales.dto.*;
import com.katasticho.erp.sales.entity.*;
import com.katasticho.erp.sales.repository.*;
import com.katasticho.erp.sales.service.DeliveryChallanService;
import com.katasticho.erp.sales.service.SalesOrderService;
import com.katasticho.erp.tax.GenericTaxEngine;
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

/**
 * Full B2B sales cycle: SO confirm → Delivery Challan dispatch (PGI)
 * → SO convert-to-invoice (skip stock) → edge cases.
 *
 * All collaborators are mocked; no Spring context or database needed.
 */
@ExtendWith(MockitoExtension.class)
class SalesCycleTest {

    // ── SalesOrderService mocks ───────────────────────────────────
    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private StockReservationRepository reservationRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private EstimateRepository estimateRepository;
    @Mock private InvoiceService invoiceService;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private GenericTaxEngine taxEngine;
    @Mock private CommentService commentService;
    @Mock private DeliveryChallanRepository challanRepository;

    // ── DeliveryChallanService extra mocks ────────────────────────
    @Mock private StockBatchRepository batchRepository;
    @Mock private InventoryService inventoryService;

    private SalesOrderService salesOrderService;
    private DeliveryChallanService deliveryChallanService;

    // ── Shared test fixtures ──────────────────────────────────────
    private UUID orgId;
    private UUID contactId;
    private UUID itemId;
    private UUID warehouseId;
    private Item trackedItem;
    private Warehouse defaultWarehouse;
    private Contact customer;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        contactId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();

        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        trackedItem = new Item();
        trackedItem.setId(itemId);
        trackedItem.setName("Widget A");
        trackedItem.setTrackInventory(true);

        defaultWarehouse = new Warehouse();
        defaultWarehouse.setId(warehouseId);
        defaultWarehouse.setName("Main Warehouse");

        customer = new Contact();
        customer.setId(contactId);
        customer.setCompanyName("ACME Corp");

        salesOrderService = new SalesOrderService(
                salesOrderRepository, reservationRepository, contactRepository,
                itemRepository, warehouseRepository, stockBalanceRepository,
                branchRepository, estimateRepository, invoiceService,
                invoiceRepository, sequenceRepository, defaultAccountService,
                taxEngine, commentService, challanRepository);

        deliveryChallanService = new DeliveryChallanService(
                challanRepository, salesOrderRepository, reservationRepository,
                contactRepository, itemRepository, warehouseRepository,
                batchRepository, branchRepository, sequenceRepository,
                inventoryService, salesOrderService, commentService);

        // Common lenient stubs
        lenient().when(itemRepository.findById(itemId)).thenReturn(Optional.of(trackedItem));
        lenient().when(contactRepository.findById(contactId)).thenReturn(Optional.of(customer));
        lenient().when(warehouseRepository.findById(warehouseId)).thenReturn(Optional.of(defaultWarehouse));
        lenient().when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(defaultWarehouse));
        lenient().when(salesOrderRepository.save(any(SalesOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(challanRepository.save(any(DeliveryChallan.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(reservationRepository.save(any(StockReservation.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(invoiceRepository.countBySalesOrderId(any())).thenReturn(0);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Part A: Full B2B cycle ────────────────────────────────────

    @Test
    void fullB2bCycle_confirmDispatchInvoice_stockDeductedOnceOnDispatch() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();
        UUID challanId = UUID.randomUUID();

        // Step 1: SO in DRAFT state with a tracked line
        SalesOrderLine soLine = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("10"))
                .rate(new BigDecimal("500"))
                .build();
        soLine.setId(soLineId);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.addLine(soLine);

        StockBalance balance = new StockBalance();
        balance.setQuantityOnHand(new BigDecimal("50"));

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(balance));
        when(reservationRepository.sumActiveReservations(itemId, warehouseId))
                .thenReturn(BigDecimal.ZERO);

        // Step 2: Confirm SO → stock reservation created
        SalesOrderResponse confirmResult = salesOrderService.confirm(soId);
        assertEquals("CONFIRMED", confirmResult.status());

        ArgumentCaptor<StockReservation> resCaptor = ArgumentCaptor.forClass(StockReservation.class);
        verify(reservationRepository).save(resCaptor.capture());
        StockReservation reservation = resCaptor.getValue();
        assertEquals("ACTIVE", reservation.getStatus());
        assertEquals(0, new BigDecimal("10").compareTo(reservation.getQuantityReserved()));

        // Step 3: Dispatch challan → stock deducted (PGI), reservation fulfilled
        so.setStatus("CONFIRMED");  // as would be set after confirm + save

        DeliveryChallanLine dcLine = DeliveryChallanLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .salesOrderLineId(soLineId)
                .quantity(new BigDecimal("10"))
                .build();
        dcLine.setId(UUID.randomUUID());

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId)
                .contactId(contactId)
                .warehouseId(warehouseId)
                .challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.addLine(dcLine);

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(salesOrderRepository.findById(soId))
                .thenReturn(Optional.of(so));
        when(reservationRepository.findBySourceTypeAndSourceLineId("SALES_ORDER", soLineId))
                .thenReturn(Optional.of(reservation));

        DeliveryChallanResponse dispatchResult = deliveryChallanService.dispatch(challanId);

        assertEquals("DISPATCHED", dispatchResult.status());

        // Stock deducted exactly once with negative quantity
        ArgumentCaptor<StockMovementRequest> moveCaptor =
                ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService, times(1)).recordMovement(moveCaptor.capture());
        StockMovementRequest movement = moveCaptor.getValue();
        assertEquals(itemId, movement.itemId());
        assertTrue(movement.quantity().compareTo(BigDecimal.ZERO) < 0,
                "Stock movement quantity must be negative (deduction)");
        assertEquals(0, new BigDecimal("-10").compareTo(movement.quantity()));

        // Reservation fulfilled
        assertEquals("FULFILLED", reservation.getStatus());

        // SO shipped tracking updated
        assertEquals(0, new BigDecimal("10").compareTo(soLine.getQuantityShipped()));
        assertEquals("FULLY_SHIPPED", so.getShippedStatus());

        // Step 4: Convert SO to invoice — invoiceService.sendInvoice is called with skipStockMovement=true
        UUID invoiceId = UUID.randomUUID();
        Invoice mockInvoice = new Invoice();
        mockInvoice.setId(invoiceId);
        mockInvoice.setSalesOrderId(soId);

        InvoiceResponse mockInvoiceResponse = buildMockInvoiceResponse(invoiceId);

        soLine.setQuantityShipped(new BigDecimal("10")); // already set by dispatch
        soLine.setQuantityInvoiced(BigDecimal.ZERO);
        so.setStatus("SHIPPED");

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE))
                .thenReturn("4010");
        when(invoiceService.createInvoice(any())).thenReturn(mockInvoiceResponse);
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(mockInvoice));
        when(invoiceService.sendInvoice(eq(invoiceId), eq(true))).thenReturn(mockInvoiceResponse);
        when(invoiceService.getInvoiceResponse(invoiceId)).thenReturn(mockInvoiceResponse);
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> inv.getArgument(0));

        var convertRequest = new ConvertToInvoiceRequest(
                List.of(new ConvertToInvoiceRequest.InvoiceLineItem(soLineId, new BigDecimal("10"))));

        InvoiceResponse invoiceResult = salesOrderService.convertToInvoice(soId, convertRequest);

        assertNotNull(invoiceResult);

        // Critical: sendInvoice must be called with skipStockMovement=true
        verify(invoiceService).sendInvoice(invoiceId, true);

        // InventoryService.deductStockForInvoice NOT called (stock moved on dispatch)
        verify(inventoryService, never()).deductStockForInvoice(any());
    }

    // ── Part B: Edge cases ────────────────────────────────────────

    @Test
    void edgeCase_cannotInvoiceMoreThanShipped() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();

        SalesOrderLine soLine = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("20"))
                .rate(new BigDecimal("500"))
                .build();
        soLine.setId(soLineId);
        soLine.setQuantityShipped(new BigDecimal("8")); // only 8 shipped
        soLine.setQuantityInvoiced(BigDecimal.ZERO);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("PARTIALLY_SHIPPED");
        so.addLine(soLine);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE))
                .thenReturn("4010");

        var request = new ConvertToInvoiceRequest(
                List.of(new ConvertToInvoiceRequest.InvoiceLineItem(soLineId, new BigDecimal("15"))));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.convertToInvoice(soId, request));

        assertEquals("SO_INVOICE_EXCEEDS_SHIPPED", ex.getErrorCode());
        verify(invoiceService, never()).createInvoice(any());
    }

    @Test
    void edgeCase_cancelConfirmedSoReleasesReservations() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");

        StockReservation res1 = StockReservation.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .sourceType("SALES_ORDER").sourceId(soId).sourceLineId(soLineId)
                .quantityReserved(new BigDecimal("10"))
                .build();
        res1.setStatus("ACTIVE");

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(reservationRepository.findBySourceTypeAndSourceId("SALES_ORDER", soId))
                .thenReturn(List.of(res1));

        salesOrderService.cancel(soId);

        assertEquals("CANCELLED", so.getStatus());
        assertEquals("CANCELLED", res1.getStatus());
        assertNotNull(res1.getCancelledAt());
    }

    @Test
    void edgeCase_cannotCancelDispatchedChallan() {
        UUID challanId = UUID.randomUUID();
        UUID soId = UUID.randomUUID();

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId).contactId(contactId)
                .challanNumber("DC-001").challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.setStatus("DISPATCHED");

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> deliveryChallanService.cancel(challanId));

        assertEquals("DC_CANNOT_CANCEL", ex.getErrorCode());
    }

    @Test
    void edgeCase_partialShipThenPartialInvoice_updatesStatusesCorrectly() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();
        UUID challanId = UUID.randomUUID();

        SalesOrderLine soLine = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("20"))
                .rate(new BigDecimal("500"))
                .build();
        soLine.setId(soLineId);
        soLine.setQuantityShipped(BigDecimal.ZERO);
        soLine.setQuantityInvoiced(BigDecimal.ZERO);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");
        so.addLine(soLine);

        // Ship 12 of 20
        DeliveryChallanLine dcLine = DeliveryChallanLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .salesOrderLineId(soLineId)
                .quantity(new BigDecimal("12"))
                .build();
        dcLine.setId(UUID.randomUUID());

        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(soId).contactId(contactId)
                .warehouseId(warehouseId).challanNumber("DC-001")
                .challanDate(LocalDate.now())
                .build();
        challan.setId(challanId);
        challan.setOrgId(orgId);
        challan.addLine(dcLine);

        StockReservation reservation = StockReservation.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .sourceType("SALES_ORDER").sourceId(soId).sourceLineId(soLineId)
                .quantityReserved(new BigDecimal("20"))
                .build();
        reservation.setStatus("ACTIVE");

        when(challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId))
                .thenReturn(Optional.of(challan));
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(salesOrderRepository.findById(soId)).thenReturn(Optional.of(so));
        when(reservationRepository.findBySourceTypeAndSourceLineId("SALES_ORDER", soLineId))
                .thenReturn(Optional.of(reservation));

        deliveryChallanService.dispatch(challanId);

        // SO is partially shipped (12/20)
        assertEquals("PARTIALLY_SHIPPED", so.getShippedStatus());
        assertEquals(0, new BigDecimal("12").compareTo(soLine.getQuantityShipped()));

        // Reservation still ACTIVE with reduced qty
        assertEquals("ACTIVE", reservation.getStatus());
        assertEquals(0, new BigDecimal("8").compareTo(reservation.getQuantityReserved()));

        // Now invoice 12 (the shipped amount)
        soLine.setQuantityShipped(new BigDecimal("12")); // already set; confirming
        UUID invoiceId = UUID.randomUUID();
        Invoice mockInvoice = new Invoice();
        mockInvoice.setId(invoiceId);
        mockInvoice.setSalesOrderId(soId);

        InvoiceResponse mockInvoiceResponse = buildMockInvoiceResponse(invoiceId);
        so.setStatus("PARTIALLY_SHIPPED");

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE))
                .thenReturn("4010");
        when(invoiceService.createInvoice(any())).thenReturn(mockInvoiceResponse);
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(mockInvoice));
        when(invoiceService.sendInvoice(eq(invoiceId), eq(true))).thenReturn(mockInvoiceResponse);
        when(invoiceService.getInvoiceResponse(invoiceId)).thenReturn(mockInvoiceResponse);
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> inv.getArgument(0));

        var request = new ConvertToInvoiceRequest(
                List.of(new ConvertToInvoiceRequest.InvoiceLineItem(soLineId, new BigDecimal("12"))));

        salesOrderService.convertToInvoice(soId, request);

        // quantityInvoiced updated to 12, still not fully invoiced
        assertEquals(0, new BigDecimal("12").compareTo(soLine.getQuantityInvoiced()));
        assertEquals("PARTIALLY_INVOICED", so.getInvoicedStatus());
    }

    @Test
    void edgeCase_reservationPreventsOverselling() {
        UUID soId = UUID.randomUUID();

        SalesOrderLine line = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Limited Stock Item")
                .quantity(new BigDecimal("8"))
                .rate(new BigDecimal("1000"))
                .build();
        line.setId(UUID.randomUUID());

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.addLine(line);

        // 10 on hand, 5 already reserved by another SO → only 5 available
        StockBalance balance = new StockBalance();
        balance.setQuantityOnHand(new BigDecimal("10"));

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(balance));
        when(reservationRepository.sumActiveReservations(itemId, warehouseId))
                .thenReturn(new BigDecimal("5")); // 5 already reserved

        // Requesting 8, available = 10 - 5 = 5 → should fail
        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.confirm(soId));

        assertEquals("SO_INSUFFICIENT_STOCK", ex.getErrorCode());
        verify(reservationRepository, never()).save(any());
    }

    @Test
    void edgeCase_soInvoiceDoesNotDeductStock_skipStockMovementPassedTrue() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();

        SalesOrderLine soLine = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("5"))
                .rate(new BigDecimal("500"))
                .build();
        soLine.setId(soLineId);
        soLine.setQuantityShipped(new BigDecimal("5"));
        soLine.setQuantityInvoiced(BigDecimal.ZERO);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("SHIPPED");
        so.addLine(soLine);

        Invoice mockInvoice = new Invoice();
        mockInvoice.setId(invoiceId);
        mockInvoice.setSalesOrderId(soId);

        InvoiceResponse mockInvoiceResponse = buildMockInvoiceResponse(invoiceId);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE))
                .thenReturn("4010");
        when(invoiceService.createInvoice(any())).thenReturn(mockInvoiceResponse);
        when(invoiceRepository.findById(invoiceId)).thenReturn(Optional.of(mockInvoice));
        when(invoiceService.sendInvoice(eq(invoiceId), eq(true))).thenReturn(mockInvoiceResponse);
        when(invoiceService.getInvoiceResponse(invoiceId)).thenReturn(mockInvoiceResponse);
        when(invoiceRepository.save(any(Invoice.class))).thenAnswer(inv -> inv.getArgument(0));

        var request = new ConvertToInvoiceRequest(
                List.of(new ConvertToInvoiceRequest.InvoiceLineItem(soLineId, new BigDecimal("5"))));

        salesOrderService.convertToInvoice(soId, request);

        // sendInvoice MUST be called with skipStockMovement=true (stock was deducted on dispatch)
        verify(invoiceService).sendInvoice(invoiceId, true);
        // deductStockForInvoice must NOT be called
        verify(inventoryService, never()).deductStockForInvoice(any());
    }

    @Test
    void edgeCase_updateDerivedStatus_fullyShippedAndFullyInvoiced_setsInvoiced() {
        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(UUID.randomUUID());
        so.setShippedStatus("FULLY_SHIPPED");
        so.setInvoicedStatus("FULLY_INVOICED");

        salesOrderService.updateDerivedStatus(so);

        assertEquals("INVOICED", so.getStatus());
    }

    @Test
    void edgeCase_updateDerivedStatus_partiallyShipped_setsPartiallyShipped() {
        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(UUID.randomUUID());
        so.setShippedStatus("PARTIALLY_SHIPPED");
        so.setInvoicedStatus("NOT_INVOICED");

        salesOrderService.updateDerivedStatus(so);

        assertEquals("PARTIALLY_SHIPPED", so.getStatus());
    }

    // ── Helpers ───────────────────────────────────────────────────

    private InvoiceResponse buildMockInvoiceResponse(UUID invoiceId) {
        return new InvoiceResponse(
                invoiceId,
                contactId,
                "ACME Corp",
                "INV-001",
                LocalDate.now(),
                LocalDate.now().plusDays(30),
                "DRAFT",
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                "INR",
                null,
                false,
                null,
                null,
                List.of(),
                List.of(),
                Instant.now());
    }
}
