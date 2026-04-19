package com.katasticho.erp.sales.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.estimate.repository.EstimateRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.entity.StockReservation;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.sales.repository.StockReservationRepository;
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

@ExtendWith(MockitoExtension.class)
class SalesOrderServiceTest {

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

    private SalesOrderService salesOrderService;

    private UUID orgId;
    private UUID contactId;
    private UUID itemId;
    private UUID warehouseId;
    private Warehouse warehouse;
    private Item trackedItem;
    private Contact contact;

    @BeforeEach
    void setUp() {
        salesOrderService = new SalesOrderService(
                salesOrderRepository, reservationRepository, contactRepository,
                itemRepository, warehouseRepository, stockBalanceRepository,
                branchRepository, estimateRepository, invoiceService,
                invoiceRepository, sequenceRepository, defaultAccountService,
                taxEngine, commentService, challanRepository);

        orgId = UUID.randomUUID();
        contactId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();

        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        warehouse = new Warehouse();
        warehouse.setId(warehouseId);
        warehouse.setName("Main Warehouse");

        trackedItem = new Item();
        trackedItem.setId(itemId);
        trackedItem.setName("Widget A");
        trackedItem.setTrackInventory(true);

        contact = new Contact();
        contact.setId(contactId);
        contact.setCompanyName("ACME Corp");

        lenient().when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(warehouse));
        lenient().when(itemRepository.findById(itemId)).thenReturn(Optional.of(trackedItem));
        lenient().when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        lenient().when(invoiceRepository.countBySalesOrderId(any())).thenReturn(0);
        lenient().when(salesOrderRepository.save(any(SalesOrder.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(reservationRepository.save(any(StockReservation.class)))
                .thenAnswer(inv -> inv.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── confirm() ────────────────────────────────────────────────

    @Test
    void confirm_draftOrderWithAdequateStock_createsReservationAndSetsConfirmed() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();

        SalesOrderLine line = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("10"))
                .rate(new BigDecimal("500"))
                .build();
        line.setId(soLineId);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.addLine(line);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        StockBalance balance = new StockBalance();
        balance.setQuantityOnHand(new BigDecimal("50"));
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(balance));
        when(reservationRepository.sumActiveReservations(itemId, warehouseId))
                .thenReturn(BigDecimal.ZERO);

        SalesOrderResponse result = salesOrderService.confirm(soId);

        assertEquals("CONFIRMED", result.status());

        ArgumentCaptor<StockReservation> reservationCaptor =
                ArgumentCaptor.forClass(StockReservation.class);
        verify(reservationRepository).save(reservationCaptor.capture());

        StockReservation saved = reservationCaptor.getValue();
        assertEquals(orgId, saved.getOrgId());
        assertEquals(itemId, saved.getItemId());
        assertEquals(warehouseId, saved.getWarehouseId());
        assertEquals("SALES_ORDER", saved.getSourceType());
        assertEquals(soId, saved.getSourceId());
        assertEquals(soLineId, saved.getSourceLineId());
        assertEquals(0, new BigDecimal("10").compareTo(saved.getQuantityReserved()));
        assertEquals("ACTIVE", saved.getStatus());
    }

    @Test
    void confirm_insufficientAvailableStock_throwsBusinessException() {
        UUID soId = UUID.randomUUID();

        SalesOrderLine line = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("100"))
                .rate(new BigDecimal("500"))
                .build();
        line.setId(UUID.randomUUID());

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.addLine(line);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        StockBalance balance = new StockBalance();
        balance.setQuantityOnHand(new BigDecimal("30"));
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(balance));
        when(reservationRepository.sumActiveReservations(itemId, warehouseId))
                .thenReturn(new BigDecimal("10")); // 30 - 10 = 20 available, need 100

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.confirm(soId));

        assertEquals("SO_INSUFFICIENT_STOCK", ex.getErrorCode());
        verify(reservationRepository, never()).save(any());
    }

    @Test
    void confirm_alreadyConfirmedOrder_throwsBusinessException() {
        UUID soId = UUID.randomUUID();

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.confirm(soId));

        assertEquals("SO_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void confirm_noDefaultWarehouse_throwsBusinessException() {
        UUID soId = UUID.randomUUID();

        SalesOrderLine line = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("5"))
                .rate(new BigDecimal("100"))
                .build();
        line.setId(UUID.randomUUID());

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.addLine(line);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.confirm(soId));

        assertEquals("SO_NO_WAREHOUSE", ex.getErrorCode());
    }

    @Test
    void confirm_lineWithoutItemId_skipsReservationButConfirms() {
        UUID soId = UUID.randomUUID();

        SalesOrderLine textLine = SalesOrderLine.builder()
                .lineNumber(1)
                .description("Consulting Services")
                .quantity(new BigDecimal("3"))
                .rate(new BigDecimal("1000"))
                .build();
        textLine.setId(UUID.randomUUID());

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.addLine(textLine);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        SalesOrderResponse result = salesOrderService.confirm(soId);

        assertEquals("CONFIRMED", result.status());
        verify(reservationRepository, never()).save(any());
    }

    // ── cancel() ─────────────────────────────────────────────────

    @Test
    void cancel_confirmedOrder_releasesAllActiveReservations() {
        UUID soId = UUID.randomUUID();

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");

        StockReservation activeRes = StockReservation.builder()
                .orgId(orgId)
                .itemId(itemId)
                .warehouseId(warehouseId)
                .sourceType("SALES_ORDER")
                .sourceId(soId)
                .sourceLineId(UUID.randomUUID())
                .quantityReserved(new BigDecimal("10"))
                .build();
        activeRes.setStatus("ACTIVE");

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(reservationRepository.findBySourceTypeAndSourceId("SALES_ORDER", soId))
                .thenReturn(List.of(activeRes));

        SalesOrderResponse result = salesOrderService.cancel(soId);

        assertEquals("CANCELLED", result.status());
        assertEquals("CANCELLED", activeRes.getStatus());
        assertNotNull(activeRes.getCancelledAt());
        verify(reservationRepository, times(1)).save(activeRes);
    }

    @Test
    void cancel_draftOrder_setsStatusWithoutTouchingReservations() {
        UUID soId = UUID.randomUUID();

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        SalesOrderResponse result = salesOrderService.cancel(soId);

        assertEquals("CANCELLED", result.status());
        verify(reservationRepository, never()).findBySourceTypeAndSourceId(any(), any());
        verify(reservationRepository, never()).save(any());
    }

    @Test
    void cancel_alreadyCancelledOrder_throwsBusinessException() {
        UUID soId = UUID.randomUUID();

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("CANCELLED");

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.cancel(soId));

        assertEquals("SO_CANNOT_CANCEL", ex.getErrorCode());
    }

    // ── convertToInvoice() ───────────────────────────────────────

    @Test
    void convertToInvoice_requestExceedsShippedQuantity_throwsBusinessException() {
        UUID soId = UUID.randomUUID();
        UUID soLineId = UUID.randomUUID();

        SalesOrderLine line = SalesOrderLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .description("Widget A")
                .quantity(new BigDecimal("20"))
                .rate(new BigDecimal("500"))
                .build();
        line.setId(soLineId);
        line.setQuantityShipped(new BigDecimal("5")); // only 5 shipped
        line.setQuantityInvoiced(BigDecimal.ZERO);

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        so.setStatus("SHIPPED");
        so.addLine(line);

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE))
                .thenReturn("4010");

        var request = new com.katasticho.erp.sales.dto.ConvertToInvoiceRequest(
                List.of(new com.katasticho.erp.sales.dto.ConvertToInvoiceRequest.InvoiceLineItem(
                        soLineId, new BigDecimal("10")))); // requesting 10, only 5 shipped

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.convertToInvoice(soId, request));

        assertEquals("SO_INVOICE_EXCEEDS_SHIPPED", ex.getErrorCode());
    }

    @Test
    void convertToInvoice_draftSalesOrder_throwsBusinessException() {
        UUID soId = UUID.randomUUID();

        SalesOrder so = SalesOrder.builder()
                .contactId(contactId)
                .orderDate(LocalDate.now())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);
        // status = DRAFT (default)

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        var request = new com.katasticho.erp.sales.dto.ConvertToInvoiceRequest(List.of());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.convertToInvoice(soId, request));

        assertEquals("SO_CANNOT_INVOICE", ex.getErrorCode());
    }
}
