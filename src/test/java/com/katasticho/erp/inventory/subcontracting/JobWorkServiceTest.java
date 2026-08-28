package com.katasticho.erp.inventory.subcontracting;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.inventory.subcontracting.entity.JobWorkIssueLine;
import com.katasticho.erp.inventory.subcontracting.entity.JobWorkOrder;
import com.katasticho.erp.inventory.subcontracting.entity.JobWorkReceiptLine;
import com.katasticho.erp.inventory.subcontracting.repository.JobWorkIssueLineRepository;
import com.katasticho.erp.inventory.subcontracting.repository.JobWorkOrderRepository;
import com.katasticho.erp.inventory.subcontracting.repository.JobWorkReceiptLineRepository;
import com.katasticho.erp.inventory.subcontracting.service.JobWorkService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class JobWorkServiceTest {

    @Mock private JobWorkOrderRepository orderRepository;
    @Mock private JobWorkIssueLineRepository issueLineRepository;
    @Mock private JobWorkReceiptLineRepository receiptLineRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private InventoryService inventoryService;
    @Mock private WarehouseRepository warehouseRepository;

    private JobWorkService service;
    private final UUID orgId = UUID.randomUUID();
    private final UUID workerId = UUID.randomUUID();
    private final UUID rawItemId = UUID.randomUUID();
    private final UUID finItemId = UUID.randomUUID();
    private final UUID warehouseId = UUID.randomUUID();

    private Contact mockWorker;
    private Item mockRawItem;
    private Item mockFinItem;
    private Warehouse mockWarehouse;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        service = new JobWorkService(
                orderRepository, issueLineRepository, receiptLineRepository,
                contactRepository, itemRepository, inventoryService, warehouseRepository
        );

        mockWarehouse = Warehouse.builder().name("Main Central Warehouse").code("WH-MAIN").build();
        mockWarehouse.setId(warehouseId);
        mockWarehouse.setOrgId(orgId);
        when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(mockWarehouse));

        mockWorker = Contact.builder()
                .displayName("Precision Coating & Packaging Works")
                .gstin("27AABCP1234F1Z9")
                .build();
        mockWorker.setId(workerId);
        mockWorker.setOrgId(orgId);

        mockRawItem = Item.builder()
                .name("Uncoated Paracetamol Bulk Granules")
                .hsnCode("30049099")
                .unitOfMeasure("KG")
                .purchasePrice(new BigDecimal("250.00"))
                .gstRate(new BigDecimal("18.00"))
                .build();
        mockRawItem.setId(rawItemId);
        mockRawItem.setOrgId(orgId);

        mockFinItem = Item.builder()
                .name("Paracetamol Film Coated Granules")
                .hsnCode("30049099")
                .unitOfMeasure("KG")
                .salePrice(new BigDecimal("320.00"))
                .build();
        mockFinItem.setId(finItemId);
        mockFinItem.setOrgId(orgId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(workerId), eq(orgId)))
                .thenReturn(Optional.of(mockWorker));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(rawItemId), eq(orgId)))
                .thenReturn(Optional.of(mockRawItem));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(finItemId), eq(orgId)))
                .thenReturn(Optional.of(mockFinItem));

        when(orderRepository.save(any(JobWorkOrder.class))).thenAnswer(inv -> {
            JobWorkOrder o = inv.getArgument(0);
            if (o.getId() == null) o.setId(UUID.randomUUID());
            return o;
        });

        when(issueLineRepository.save(any(JobWorkIssueLine.class))).thenAnswer(inv -> {
            JobWorkIssueLine l = inv.getArgument(0);
            if (l.getId() == null) l.setId(UUID.randomUUID());
            return l;
        });

        when(receiptLineRepository.save(any(JobWorkReceiptLine.class))).thenAnswer(inv -> {
            JobWorkReceiptLine r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void testCreateOrder_CreatesChallan45IssueLinesAndCalculatesValue() {
        var issueLine = new JobWorkService.IssueLineRequest(
                "CH45-2026-001", LocalDate.now(), rawItemId,
                new BigDecimal("100.00"), new BigDecimal("250.00"),
                new BigDecimal("18.00"), "Film Coating & Quality Testing"
        );

        var req = new JobWorkService.CreateJobWorkOrderRequest(
                workerId, LocalDate.now(), LocalDate.now().plusDays(30),
                "Granule Coating Batch A-10", "Urgent batch for export",
                List.of(issueLine)
        );

        var resp = service.createOrder(req);

        assertNotNull(resp);
        assertEquals(workerId, resp.jobWorkerId());
        assertEquals("Precision Coating & Packaging Works", resp.jobWorkerName());
        assertEquals("ISSUED", resp.status());
        assertEquals(new BigDecimal("25000.0000"), resp.totalIssuedValue());
        assertEquals(1, resp.issueLines().size());
        assertEquals("Uncoated Paracetamol Bulk Granules", resp.issueLines().get(0).itemName());
        assertEquals(new BigDecimal("100.00"), resp.issueLines().get(0).issuedQuantity());
        verify(orderRepository, times(2)).save(any(JobWorkOrder.class));
    }

    @Test
    void testRecordReceipt_UpdatesConsumedRawItemsAndOrderStatus() {
        UUID orderId = UUID.randomUUID();
        JobWorkOrder order = JobWorkOrder.builder()
                .orderNumber("JWO-101")
                .jobWorkerId(workerId)
                .orderDate(LocalDate.now())
                .status("ISSUED")
                .totalIssuedValue(new BigDecimal("25000.00"))
                .build();
        order.setId(orderId);
        order.setOrgId(orgId);

        JobWorkIssueLine issue = JobWorkIssueLine.builder()
                .jobWorkOrderId(orderId)
                .challanNumber("CH45-101")
                .challanDate(LocalDate.now())
                .itemId(rawItemId)
                .issuedQuantity(new BigDecimal("100.00"))
                .returnedQuantity(BigDecimal.ZERO)
                .unitRate(new BigDecimal("250.00"))
                .build();
        issue.setId(UUID.randomUUID());
        issue.setOrgId(orgId);

        when(orderRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(orderId), eq(orgId)))
                .thenReturn(Optional.of(order));
        when(issueLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(eq(orgId), eq(orderId)))
                .thenReturn(List.of(issue));
        when(receiptLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(eq(orgId), eq(orderId)))
                .thenReturn(List.of());

        var req = new JobWorkService.ReceiveJobWorkRequest(
                "INW-CH-99", LocalDate.now(), finItemId,
                new BigDecimal("98.00"), rawItemId, new BigDecimal("100.00"),
                new BigDecimal("2.00"), new BigDecimal("3500.00"), "Batch coating completed"
        );

        var resp = service.recordReceipt(orderId, req);

        assertNotNull(resp);
        assertEquals("COMPLETED", resp.status());
        verify(receiptLineRepository).save(any(JobWorkReceiptLine.class));
        verify(issueLineRepository).save(any(JobWorkIssueLine.class));
    }

    @Test
    void testGetItc04Summary_AggregatesQuarterlyRegisters() {
        JobWorkIssueLine issue = JobWorkIssueLine.builder()
                .jobWorkOrderId(UUID.randomUUID())
                .challanNumber("CH45-201")
                .challanDate(LocalDate.of(2026, 1, 15))
                .itemId(rawItemId)
                .issuedQuantity(new BigDecimal("50.00"))
                .returnedQuantity(new BigDecimal("20.00"))
                .unitRate(new BigDecimal("250.00"))
                .taxableValue(new BigDecimal("12500.00"))
                .natureOfProcessing("Capsule Filling")
                .build();
        issue.setId(UUID.randomUUID());
        issue.setOrgId(orgId);

        when(issueLineRepository.findByOrgIdAndChallanDateBetweenAndIsDeletedFalse(
                eq(orgId), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(issue));
        when(receiptLineRepository.findByOrgIdAndReceiptDateBetweenAndIsDeletedFalse(
                eq(orgId), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        var report = service.getItc04Summary("Q1", 2026);

        assertNotNull(report);
        assertEquals("Q1", report.quarter());
        assertEquals(2026, report.year());
        assertEquals(0, new BigDecimal("12500.00").compareTo(report.totalIssuedValue()));
        assertEquals(0, new BigDecimal("5000.00").compareTo(report.totalReturnedValue()));
        assertEquals(0, new BigDecimal("7500.00").compareTo(report.pendingValue()));
        assertEquals(1, report.table4InputsSent().size());
    }
}
