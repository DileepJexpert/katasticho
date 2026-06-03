package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import com.katasticho.erp.sales.entity.DeliveryChallan;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OperationalReportServiceTest {

    @Mock private OrganisationRepository organisationRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private SalesReceiptRepository salesReceiptRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private JournalEntryRepository journalEntryRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private StockMovementRepository stockMovementRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private StockBatchRepository stockBatchRepository;
    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private DeliveryChallanRepository deliveryChallanRepository;

    private OperationalReportService service;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        service = new OperationalReportService(
                organisationRepository,
                invoiceRepository,
                salesReceiptRepository,
                purchaseBillRepository,
                journalEntryRepository,
                stockBalanceRepository,
                stockMovementRepository,
                contactRepository,
                itemRepository,
                warehouseRepository,
                stockBatchRepository,
                salesOrderRepository,
                deliveryChallanRepository);

        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);

        Organisation org = Organisation.builder().name("Distributor").baseCurrency("INR").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void pendingDispatch_returnsConfirmedAndBackorderSalesOrders() {
        UUID customerId = UUID.randomUUID();
        SalesOrder confirmed = salesOrder(
                customerId,
                "SO-001",
                "CONFIRMED",
                "NOT_SHIPPED",
                "NOT_INVOICED",
                LocalDate.of(2026, 6, 1),
                LocalDate.of(2026, 6, 3),
                new BigDecimal("1200"));
        SalesOrder backorder = salesOrder(
                customerId,
                "SO-002",
                "BACKORDER",
                "PARTIALLY_SHIPPED",
                "NOT_INVOICED",
                LocalDate.of(2026, 6, 2),
                null,
                new BigDecimal("800"));
        Contact customer = new Contact();
        customer.setId(customerId);
        customer.setDisplayName("Life Pharmacy");

        when(salesOrderRepository.findPendingDispatch(orgId))
                .thenReturn(List.of(confirmed, backorder));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyCollection()))
                .thenReturn(List.of(customer));

        var report = service.pendingDispatch();

        assertEquals("pending-dispatch", report.reportKey());
        assertEquals(2, report.rows().size());
        assertEquals(new BigDecimal("2000"), report.metrics().stream()
                .filter(m -> "value".equals(m.key()))
                .findFirst()
                .orElseThrow()
                .value());
        assertEquals("Life Pharmacy", report.rows().get(0).get("customer"));
        assertEquals("SO-001", report.rows().get(0).get("orderNumber"));
    }

    @Test
    void challanNotInvoiced_returnsDispatchedChallansLinkedToOpenSalesOrders() {
        UUID customerId = UUID.randomUUID();
        SalesOrder salesOrder = salesOrder(
                customerId,
                "SO-010",
                "CONFIRMED",
                "SHIPPED",
                "PARTIALLY_INVOICED",
                LocalDate.of(2026, 6, 1),
                LocalDate.of(2026, 6, 2),
                new BigDecimal("3000"));
        DeliveryChallan challan = DeliveryChallan.builder()
                .salesOrderId(salesOrder.getId())
                .contactId(customerId)
                .challanNumber("DC-010")
                .challanDate(LocalDate.of(2026, 6, 3))
                .dispatchDate(LocalDate.of(2026, 6, 4))
                .status("DISPATCHED")
                .build();
        challan.setId(UUID.randomUUID());
        challan.setOrgId(orgId);

        Contact customer = new Contact();
        customer.setId(customerId);
        customer.setDisplayName("City Medical");

        when(deliveryChallanRepository.findDispatchedNotFullyInvoiced(orgId))
                .thenReturn(List.of(challan));
        when(salesOrderRepository.findAllById(List.of(salesOrder.getId())))
                .thenReturn(List.of(salesOrder));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyCollection()))
                .thenReturn(List.of(customer));

        var report = service.challanNotInvoiced();

        assertEquals("challan-not-invoiced", report.reportKey());
        assertEquals(1, report.rows().size());
        assertEquals("DC-010", report.rows().get(0).get("challanNumber"));
        assertEquals("SO-010", report.rows().get(0).get("salesOrder"));
        assertEquals("PARTIALLY_INVOICED", report.rows().get(0).get("invoiceStatus"));
        assertEquals(new BigDecimal("3000"), report.metrics().stream()
                .filter(m -> "value".equals(m.key()))
                .findFirst()
                .orElseThrow()
                .value());
    }

    private SalesOrder salesOrder(
            UUID customerId,
            String number,
            String status,
            String shippedStatus,
            String invoicedStatus,
            LocalDate orderDate,
            LocalDate expectedShipmentDate,
            BigDecimal total) {
        SalesOrder salesOrder = SalesOrder.builder()
                .contactId(customerId)
                .salesorderNumber(number)
                .status(status)
                .shippedStatus(shippedStatus)
                .invoicedStatus(invoicedStatus)
                .orderDate(orderDate)
                .expectedShipmentDate(expectedShipmentDate)
                .total(total)
                .build();
        salesOrder.setId(UUID.randomUUID());
        salesOrder.setOrgId(orgId);
        return salesOrder;
    }
}
