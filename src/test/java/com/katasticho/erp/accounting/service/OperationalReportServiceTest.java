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
import static org.mockito.ArgumentMatchers.any;
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
    @Mock private com.katasticho.erp.inventory.service.FifoCostingService fifoCostingService;
    @Mock private FinancialReportService financialReportService;
    @Mock private com.katasticho.erp.accounting.defaults.service.DefaultAccountService defaultAccountService;
    @Mock private com.katasticho.erp.accounting.repository.BudgetLineRepository budgetLineRepository;
    @Mock private com.katasticho.erp.accounting.repository.AccountRepository accountRepository;

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
                orgSettingsService,
                fifoCostingService,
                financialReportService,
                defaultAccountService,
                budgetLineRepository,
                accountRepository);

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

    @Test
    void stockAgeing_allocatesOnHandToNewestReceiptsFifo() {
        UUID itemId = UUID.randomUUID();
        var item = com.katasticho.erp.inventory.entity.Item.builder()
                .name("Crocin 500mg").sku("CROCIN").build();
        item.setId(itemId);

        var balance = new com.katasticho.erp.inventory.entity.StockBalance();
        balance.setItemId(itemId);
        balance.setWarehouseId(UUID.randomUUID());
        balance.setQuantityOnHand(new BigDecimal("100"));
        balance.setAverageCost(new BigDecimal("10"));

        // Receipts newest-first: 60 @ 10 days old, 80 @ 120 days old.
        var recent = com.katasticho.erp.inventory.entity.StockMovement.builder()
                .itemId(itemId).quantity(new BigDecimal("60"))
                .movementDate(LocalDate.now().minusDays(10)).build();
        var old = com.katasticho.erp.inventory.entity.StockMovement.builder()
                .itemId(itemId).quantity(new BigDecimal("80"))
                .movementDate(LocalDate.now().minusDays(120)).build();

        when(stockBalanceRepository.findByOrgIdOrderByLastMovementAtDesc(orgId))
                .thenReturn(List.of(balance));
        when(stockMovementRepository.findIncomingByOrgNewestFirst(orgId))
                .thenReturn(List.of(recent, old));
        when(itemRepository.findAllById(anyCollection())).thenReturn(List.of(item));

        var report = service.stockAgeing();

        assertEquals("stock-ageing", report.reportKey());
        var row = report.rows().get(0);
        // FIFO: 60 of 100 on hand are the 10-day receipt, remaining 40 from the 120-day one.
        assertEquals(0, new BigDecimal("60").compareTo((BigDecimal) row.get("d0_30")));
        assertEquals(0, new BigDecimal("40").compareTo((BigDecimal) row.get("d90_plus")));
        assertEquals(0, new BigDecimal("1000.00").compareTo((BigDecimal) row.get("value")));
        // Value 90+: 40 × avg cost 10 = 400.
        assertEquals(0, new BigDecimal("400.00").compareTo(
                (BigDecimal) report.metrics().get(1).value()));
    }

    @Test
    void ratioAnalysis_computesLiquidityAndMarginFromTbAndPl() {
        LocalDate from = LocalDate.of(2026, 4, 1);
        LocalDate to = LocalDate.of(2026, 4, 30);

        when(defaultAccountService.getCode(eq(orgId), any())).thenAnswer(inv ->
                switch (inv.getArgument(1, com.katasticho.erp.accounting.defaults.DefaultAccountPurpose.class)) {
                    case CASH -> "1010";
                    case BANK -> "1020";
                    case AR -> "1100";
                    case INVENTORY_ASSET -> "1200";
                    case AP -> "2010";
                    default -> "0000";
                });

        var tb = new com.katasticho.erp.accounting.dto.report.TrialBalanceResponse(
                to, "INR", BigDecimal.ZERO, BigDecimal.ZERO, true, List.of(
                tbLine("1010", new BigDecimal("50000")),
                tbLine("1020", new BigDecimal("150000")),
                tbLine("1100", new BigDecimal("100000")),
                tbLine("1200", new BigDecimal("200000")),
                tbLine("2010", new BigDecimal("-100000"))));   // AP credit-normal
        when(financialReportService.generateTrialBalance(to)).thenReturn(tb);
        when(financialReportService.generateProfitLoss(from, to)).thenReturn(
                new com.katasticho.erp.accounting.dto.report.ProfitLossResponse(
                        from, to, "INR",
                        new BigDecimal("300000"), new BigDecimal("240000"), new BigDecimal("60000"),
                        List.of(), List.of()));

        var report = service.ratioAnalysis(from, to);

        assertEquals("ratio-analysis", report.reportKey());
        java.util.Map<String, BigDecimal> values = report.rows().stream().collect(
                java.util.stream.Collectors.toMap(
                        r -> (String) r.get("ratio"), r -> (BigDecimal) r.get("value")));
        // (50k+150k+100k+200k) / 100k = 5.00 ; quick = 300k/100k = 3.00
        assertEquals(0, new BigDecimal("5.00").compareTo(values.get("Current ratio")));
        assertEquals(0, new BigDecimal("3.00").compareTo(values.get("Quick ratio")));
        // AR days = 100k / 300k × 30 = 10
        assertEquals(0, new BigDecimal("10").compareTo(values.get("Receivable days")));
        // margin = 60k/300k = 20%
        assertEquals(0, new BigDecimal("20.00").compareTo(values.get("Net profit margin %")));
        // Working capital = 500k − 100k = 400k
        assertEquals(0, new BigDecimal("400000.00").compareTo(values.get("Working capital")));
    }

    @Test
    void budgetVariance_proRatesAnnualBudgetOverWindow() {
        // Window: Apr 2026 (30 days) → FY 2026. Annual rent budget 365000 →
        // window budget 30/365 × 365000 = 30000. Actual 36000 → over by 6000.
        LocalDate from = LocalDate.of(2026, 4, 1);
        LocalDate to = LocalDate.of(2026, 4, 30);

        var rentBudget = com.katasticho.erp.accounting.entity.BudgetLine.builder()
                .fiscalYear(2026).accountCode("5200")
                .annualAmount(new BigDecimal("365000")).build();
        when(budgetLineRepository.findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByAccountCode(orgId, 2026))
                .thenReturn(List.of(rentBudget));

        when(financialReportService.generateProfitLoss(from, to)).thenReturn(
                new com.katasticho.erp.accounting.dto.report.ProfitLossResponse(
                        from, to, "INR", BigDecimal.ZERO, new BigDecimal("36000"),
                        new BigDecimal("-36000"), List.of(),
                        List.of(new com.katasticho.erp.accounting.dto.report.ProfitLossResponse.AccountLine(
                                UUID.randomUUID(), "5200", "Rent Expense", new BigDecimal("36000")))));

        var rent = com.katasticho.erp.accounting.entity.Account.builder()
                .code("5200").name("Rent Expense").type("EXPENSE").build();
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(rent));

        var report = service.budgetVariance(from, to);

        assertEquals("budget-variance", report.reportKey());
        var row = report.rows().get(0);
        assertEquals(0, new BigDecimal("30000.00").compareTo((BigDecimal) row.get("budget")));
        assertEquals(0, new BigDecimal("36000").compareTo((BigDecimal) row.get("actual")));
        assertEquals(0, new BigDecimal("6000.00").compareTo((BigDecimal) row.get("variance")));
        assertEquals(0, new BigDecimal("120.0").compareTo((BigDecimal) row.get("usagePct")));
        // 1 account over budget
        assertEquals(0, BigDecimal.ONE.compareTo((BigDecimal) report.metrics().get(2).value()));
    }

    private com.katasticho.erp.accounting.dto.report.TrialBalanceResponse.TrialBalanceLine tbLine(
            String code, BigDecimal balance) {
        return new com.katasticho.erp.accounting.dto.report.TrialBalanceResponse.TrialBalanceLine(
                UUID.randomUUID(), code, code, "ASSET",
                balance.signum() >= 0 ? balance : BigDecimal.ZERO,
                balance.signum() < 0 ? balance.negate() : BigDecimal.ZERO,
                balance);
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
