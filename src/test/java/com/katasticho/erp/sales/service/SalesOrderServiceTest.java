package com.katasticho.erp.sales.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.policy.CreditPolicy;
import com.katasticho.erp.common.policy.OverduePolicy;
import com.katasticho.erp.common.policy.PolicyResolverService;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
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
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import com.katasticho.erp.sales.dto.CreateSalesOrderRequest;
import com.katasticho.erp.sales.dto.SalesOrderLineRequest;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.entity.StockReservation;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderLineRepository;
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
    @Mock private SalesOrderLineRepository soLineRepository;
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
    @Mock private PolicyResolverService policyResolverService;
    @Mock private ApprovalWorkflowService approvalWorkflowService;
    @Mock private PriceListService priceListService;

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
                salesOrderRepository, soLineRepository, reservationRepository,
                contactRepository, itemRepository, warehouseRepository,
                stockBalanceRepository, branchRepository, estimateRepository,
                invoiceService, invoiceRepository, sequenceRepository,
                defaultAccountService, taxEngine, commentService, challanRepository,
                policyResolverService, approvalWorkflowService, priceListService);

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
        lenient().when(branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());
        lenient().when(itemRepository.findById(itemId)).thenReturn(Optional.of(trackedItem));
        lenient().when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        lenient().when(invoiceRepository.countBySalesOrderId(any())).thenReturn(0);
        lenient().when(sequenceRepository.findByOrgIdAndPrefixAndYear(eq(orgId), eq("SO"), anyInt()))
                .thenReturn(Optional.empty());
        lenient().when(sequenceRepository.save(any(InvoiceNumberSequence.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(salesOrderRepository.save(any(SalesOrder.class)))
                .thenAnswer(inv -> {
                    SalesOrder so = inv.getArgument(0);
                    if (so.getId() == null) {
                        so.setId(UUID.randomUUID());
                    }
                    return so;
                });
        lenient().when(reservationRepository.save(any(StockReservation.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(policyResolverService.creditPolicy(orgId)).thenReturn(CreditPolicy.WARN);
        lenient().when(policyResolverService.overduePolicy(orgId)).thenReturn(OverduePolicy.WARN);
        lenient().when(policyResolverService.overdueGraceDays(orgId)).thenReturn(0);
        lenient().when(invoiceRepository.findOutstandingByContact(orgId, contactId)).thenReturn(List.of());
        lenient().when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("SALES_ORDER"), anyMap()))
                .thenReturn(Optional.empty());
        lenient().when(priceListService.resolvePrice(any(), any(), any())).thenReturn(Optional.empty());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── create() credit policy ───────────────────────────────────────────────

    @Test
    void create_overCreditLimitWithWarnPolicy_createsOrderAndAddsWarningComment() {
        contact.setCreditLimit(new BigDecimal("1000"));
        contact.setOutstandingAr(new BigDecimal("900"));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        SalesOrderResponse result = salesOrderService.create(createRequest(new BigDecimal("200")));

        assertEquals(new BigDecimal("200"), result.totalAmount());
        verify(salesOrderRepository).save(any(SalesOrder.class));
        verify(commentService).addSystemComment(eq("SALES_ORDER"), any(), eq("Sales order created"));
        verify(commentService).addSystemComment(eq("SALES_ORDER"), any(),
                contains("Credit limit exceeded"));
    }

    @Test
    void create_overCreditLimitWithBlockPolicy_throwsBusinessException() {
        contact.setCreditLimit(new BigDecimal("1000"));
        contact.setOutstandingAr(new BigDecimal("900"));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(policyResolverService.creditPolicy(orgId)).thenReturn(CreditPolicy.BLOCK);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.create(createRequest(new BigDecimal("200"))));

        assertEquals("SO_CREDIT_LIMIT_EXCEEDED", ex.getErrorCode());
        verify(salesOrderRepository, never()).save(any(SalesOrder.class));
        verify(commentService, never()).addSystemComment(eq("SALES_ORDER"), any(), anyString());
    }

    @Test
    void create_overCreditLimitWithMatchingWorkflow_createsPendingApprovalOrder() {
        contact.setCreditLimit(new BigDecimal("1000"));
        contact.setOutstandingAr(new BigDecimal("900"));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("SALES_ORDER_CREDIT_APPROVAL")
                .name("Sales Order Credit Approval")
                .documentType("SALES_ORDER")
                .triggerCondition("{}")
                .active(true)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("SALES_ORDER"), anyMap()))
                .thenReturn(Optional.of(workflow));

        SalesOrderResponse result = salesOrderService.create(createRequest(new BigDecimal("200")));

        assertEquals("PENDING_APPROVAL", result.status());
        ArgumentCaptor<SalesOrder> captor = ArgumentCaptor.forClass(SalesOrder.class);
        verify(salesOrderRepository).save(captor.capture());
        assertEquals("PENDING_APPROVAL", captor.getValue().getStatus());
        verify(approvalWorkflowService).requestApproval(
                eq(orgId),
                eq(workflow),
                eq("SALES_ORDER"),
                any(),
                contains("Credit limit exceeded"),
                anyMap());
    }

    @Test
    void create_underCreditLimit_createsOrderWithoutWarningComment() {
        contact.setCreditLimit(new BigDecimal("1000"));
        contact.setOutstandingAr(new BigDecimal("700"));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        salesOrderService.create(createRequest(new BigDecimal("200")));

        verify(salesOrderRepository).save(any(SalesOrder.class));
        verify(commentService).addSystemComment(eq("SALES_ORDER"), any(), eq("Sales order created"));
        verify(commentService, never()).addSystemComment(eq("SALES_ORDER"), any(),
                contains("Credit limit exceeded"));
    }

    @Test
    void create_withoutCreditLimit_createsOrderWithoutWarningComment() {
        contact.setCreditLimit(BigDecimal.ZERO);
        contact.setOutstandingAr(new BigDecimal("5000"));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        salesOrderService.create(createRequest(new BigDecimal("200")));

        verify(salesOrderRepository).save(any(SalesOrder.class));
        verify(commentService, never()).addSystemComment(eq("SALES_ORDER"), any(),
                contains("Credit limit exceeded"));
    }

    // ── confirm() ────────────────────────────────────────────────

    @Test
    void create_inactiveContact_throwsBusinessExceptionBeforeOrderSave() {
        contact.setActive(false);
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.create(createRequest(new BigDecimal("200"))));

        assertEquals("SO_CONTACT_INACTIVE", ex.getErrorCode());
        verify(salesOrderRepository, never()).save(any(SalesOrder.class));
        verify(sequenceRepository, never()).save(any(InvoiceNumberSequence.class));
    }

    @Test
    void create_contactOnSalesHold_throwsBusinessExceptionBeforeOrderSave() {
        contact.setSalesHold(true);
        contact.setSalesHoldReason("Credit review pending");
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.create(createRequest(new BigDecimal("200"))));

        assertEquals("SO_CONTACT_SALES_HOLD", ex.getErrorCode());
        verify(salesOrderRepository, never()).save(any(SalesOrder.class));
        verify(sequenceRepository, never()).save(any(InvoiceNumberSequence.class));
    }

    @Test
    void create_contactWithExpiredSalesHold_createsOrder() {
        contact.setSalesHold(true);
        contact.setSalesHoldUntil(LocalDate.now().minusDays(1));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));

        SalesOrderResponse result = salesOrderService.create(createRequest(new BigDecimal("200")));

        assertEquals(new BigDecimal("200"), result.totalAmount());
        verify(salesOrderRepository).save(any(SalesOrder.class));
    }

    @Test
    void create_withOverdueInvoiceAndWarnPolicy_createsOrderAndAddsWarningComment() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(invoiceRepository.findOutstandingByContact(orgId, contactId))
                .thenReturn(List.of(overdueInvoice(new BigDecimal("800"), LocalDate.now().minusDays(5))));

        SalesOrderResponse result = salesOrderService.create(createRequest(new BigDecimal("200")));

        assertEquals(new BigDecimal("200"), result.totalAmount());
        verify(salesOrderRepository).save(any(SalesOrder.class));
        verify(commentService).addSystemComment(eq("SALES_ORDER"), any(),
                contains("overdue invoice"));
    }

    @Test
    void create_withOverdueInvoiceAndBlockPolicy_throwsBusinessException() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(invoiceRepository.findOutstandingByContact(orgId, contactId))
                .thenReturn(List.of(overdueInvoice(new BigDecimal("800"), LocalDate.now().minusDays(5))));
        when(policyResolverService.overduePolicy(orgId)).thenReturn(OverduePolicy.BLOCK);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> salesOrderService.create(createRequest(new BigDecimal("200"))));

        assertEquals("SO_OVERDUE_INVOICES", ex.getErrorCode());
        verify(salesOrderRepository, never()).save(any(SalesOrder.class));
    }

    @Test
    void create_withOverdueInvoiceAndMatchingWorkflow_createsPendingApprovalOrder() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(invoiceRepository.findOutstandingByContact(orgId, contactId))
                .thenReturn(List.of(overdueInvoice(new BigDecimal("800"), LocalDate.now().minusDays(5))));

        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("SALES_ORDER_OVERDUE_APPROVAL")
                .name("Sales Order Overdue Approval")
                .documentType("SALES_ORDER")
                .triggerCondition("{}")
                .active(true)
                .build();
        workflow.setId(UUID.randomUUID());
        workflow.setOrgId(orgId);
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("SALES_ORDER"), anyMap()))
                .thenReturn(Optional.of(workflow));

        SalesOrderResponse result = salesOrderService.create(createRequest(new BigDecimal("200")));

        assertEquals("PENDING_APPROVAL", result.status());
        verify(approvalWorkflowService).requestApproval(
                eq(orgId),
                eq(workflow),
                eq("SALES_ORDER"),
                any(),
                contains("overdue invoice"),
                anyMap());
    }

    @Test
    void create_itemLineUsesResolvedPriceListRate() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(priceListService.resolvePrice(contactId, itemId, BigDecimal.ONE))
                .thenReturn(Optional.of(new BigDecimal("175.50")));

        SalesOrderResponse result = salesOrderService.create(createRequest(new BigDecimal("200")));

        assertEquals(0, new BigDecimal("175.50").compareTo(result.totalAmount()));
        assertEquals(1, result.lines().size());
        assertEquals(0, new BigDecimal("175.50").compareTo(result.lines().get(0).rate()));
        ArgumentCaptor<SalesOrder> captor = ArgumentCaptor.forClass(SalesOrder.class);
        verify(salesOrderRepository).save(captor.capture());
        SalesOrder saved = captor.getValue();
        assertEquals(0, new BigDecimal("175.50").compareTo(saved.getTotal()));
        assertEquals(0, new BigDecimal("175.50").compareTo(saved.getLines().get(0).getRate()));
    }

    private CreateSalesOrderRequest createRequest(BigDecimal rate) {
        return new CreateSalesOrderRequest(
                contactId,
                List.of(new SalesOrderLineRequest(
                        itemId,
                        "Widget A",
                        BigDecimal.ONE,
                        rate,
                        "PCS",
                        BigDecimal.ZERO,
                        null,
                        null)),
                LocalDate.now(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                false);
    }

    private Invoice overdueInvoice(BigDecimal balanceDue, LocalDate dueDate) {
        Invoice invoice = new Invoice();
        invoice.setId(UUID.randomUUID());
        invoice.setOrgId(orgId);
        invoice.setContactId(contactId);
        invoice.setInvoiceNumber("INV-TEST");
        invoice.setInvoiceDate(dueDate.minusDays(10));
        invoice.setDueDate(dueDate);
        invoice.setStatus("SENT");
        invoice.setBalanceDue(balanceDue);
        return invoice;
    }

    // confirm()

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
