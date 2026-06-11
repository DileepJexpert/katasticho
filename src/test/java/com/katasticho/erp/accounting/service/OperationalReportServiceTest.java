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
    @Mock private com.katasticho.erp.organisation.OrgSettingsService orgSettingsService;

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
                deliveryChallanRepository,
                orgSettingsService);

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

    @Test
    void costCentres_groupsTaggedLinesAndBucketsUntagged() {
        var entry = com.katasticho.erp.accounting.entity.JournalEntry.builder()
                .orgId(orgId).entryNumber("JV-1").status("POSTED")
                .effectiveDate(LocalDate.of(2026, 6, 1)).build();
        entry.getLines().add(com.katasticho.erp.accounting.entity.JournalLine.builder()
                .accountId(UUID.randomUUID()).costCentre("Mumbai")
                .baseDebit(new BigDecimal("5000")).baseCredit(BigDecimal.ZERO).build());
        entry.getLines().add(com.katasticho.erp.accounting.entity.JournalLine.builder()
                .accountId(UUID.randomUUID()).costCentre("Pune")
                .baseDebit(BigDecimal.ZERO).baseCredit(new BigDecimal("3000")).build());
        entry.getLines().add(com.katasticho.erp.accounting.entity.JournalLine.builder()
                .accountId(UUID.randomUUID())   // untagged
                .baseDebit(BigDecimal.ZERO).baseCredit(new BigDecimal("2000")).build());

        when(journalEntryRepository.findPostedWithLinesInRange(
                eq(orgId), eq(LocalDate.of(2026, 6, 1)), eq(LocalDate.of(2026, 6, 30))))
                .thenReturn(List.of(entry));

        var report = service.costCentres(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30));

        assertEquals("cost-centres", report.reportKey());
        assertEquals(3, report.rows().size());
        // Alphabetical tagged centres first, untagged last.
        assertEquals("Mumbai", report.rows().get(0).get("centre"));
        assertEquals(new BigDecimal("5000"), report.rows().get(0).get("debit"));
        assertEquals("Pune", report.rows().get(1).get("centre"));
        assertEquals("(untagged)", report.rows().get(2).get("centre"));
        // 2 tagged centres; tagged Dr+Cr = 5000 + 3000.
        assertEquals(new BigDecimal("2"), report.metrics().get(0).value());
        assertEquals(new BigDecimal("8000"), report.metrics().get(1).value());
    }

    @Test
    void overdueInterest_computesSimpleInterestPerInvoice() {
        when(orgSettingsService.get(orgId, "ar.interest_rate_pa", "18")).thenReturn("18");

        UUID customerId = UUID.randomUUID();
        Contact customer = new Contact();
        customer.setId(customerId);
        customer.setDisplayName("Slow Payer & Co");

        com.katasticho.erp.ar.entity.Invoice inv = com.katasticho.erp.ar.entity.Invoice.builder()
                .contactId(customerId).invoiceNumber("INV-77")
                .invoiceDate(LocalDate.now().minusDays(130))
                .dueDate(LocalDate.now().minusDays(100))     // 100 days late
                .balanceDue(new BigDecimal("36500"))
                .status("OVERDUE").build();
        when(invoiceRepository.findOverdueInvoices(eq(orgId), eq(LocalDate.now())))
                .thenReturn(List.of(inv));
        when(contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyCollection()))
                .thenReturn(List.of(customer));

        var report = service.overdueInterest();

        assertEquals("overdue-interest", report.reportKey());
        assertEquals(1, report.rows().size());
        // 36500 × 18% × 100/365 days = 1800.00
        assertEquals(0, new BigDecimal("1800.00").compareTo(
                (BigDecimal) report.rows().get(0).get("interest")));
        assertEquals("Slow Payer & Co", report.rows().get(0).get("customer"));
        assertEquals(0, new BigDecimal("1800.00").compareTo(
                (BigDecimal) report.metrics().get(2).value()));
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
