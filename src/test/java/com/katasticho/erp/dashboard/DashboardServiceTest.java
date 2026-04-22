package com.katasticho.erp.dashboard;

import com.katasticho.erp.ar.repository.InvoiceLineRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.dashboard.dto.BranchSalesRow;
import com.katasticho.erp.dashboard.dto.TodaySalesResponse;
import com.katasticho.erp.dashboard.dto.TopSellingItem;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.repository.SalesReceiptLineRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PaymentRepository paymentRepository;
    @Mock private InvoiceLineRepository invoiceLineRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private com.katasticho.erp.ap.repository.PurchaseBillRepository purchaseBillRepository;
    @Mock private com.katasticho.erp.contact.repository.ContactRepository contactRepository;
    @Mock private SalesReceiptRepository salesReceiptRepository;
    @Mock private SalesReceiptLineRepository salesReceiptLineRepository;

    private DashboardService dashboardService;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        dashboardService = new DashboardService(
                invoiceRepository, paymentRepository, invoiceLineRepository,
                itemRepository, branchRepository, organisationRepository,
                purchaseBillRepository, contactRepository,
                salesReceiptRepository, salesReceiptLineRepository);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── getTodaySales ─────────────────────────────────────────────────

    @Test
    void getTodaySales_allBranches_combinesPosAndInvoice() {
        LocalDate today = LocalDate.now();

        Organisation org = new Organisation();
        org.setId(orgId);
        org.setBaseCurrency("INR");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        UUID sec62 = UUID.randomUUID();
        UUID sec18 = UUID.randomUUID();
        Branch b62 = Branch.builder().code("SEC62").name("Sector 62 Store").build();
        b62.setId(sec62);
        Branch b18 = Branch.builder().code("SEC18").name("Sector 18 Store").build();
        b18.setId(sec18);

        when(branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId))
                .thenReturn(List.of(b62, b18));

        // POS receipts: 8200
        when(salesReceiptRepository.sumTotalByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("8200"));
        // Paid invoices: 1500
        when(invoiceRepository.sumPaidInvoicesByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("1500"));
        // Credit invoices: 2750
        when(invoiceRepository.sumCreditSalesByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("2750"));
        // Counts
        when(salesReceiptRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(18L);
        when(invoiceRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(5L);

        // Branch rollup
        when(invoiceRepository.sumRevenueByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(
                        invoiceBranchRow(sec62, new BigDecimal("3000")),
                        invoiceBranchRow(sec18, new BigDecimal("1250"))));
        when(salesReceiptRepository.sumTotalByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(
                        posBranchRow(sec62, new BigDecimal("5200")),
                        posBranchRow(sec18, new BigDecimal("3000"))));

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, null);

        // cashUpiTotal = 8200 + 1500 = 9700
        assertEquals(0, new BigDecimal("9700").compareTo(resp.cashUpiTotal()));
        // creditTotal = 2750
        assertEquals(0, new BigDecimal("2750").compareTo(resp.creditTotal()));
        // totalSales = 9700 + 2750 = 12450
        assertEquals(0, new BigDecimal("12450").compareTo(resp.totalSales()));
        assertEquals(23, resp.transactionCount());
        assertEquals("INR", resp.currency());
        assertNull(resp.branchFilter());

        assertEquals(2, resp.byBranch().size());
        // SEC62: invoice 3000 + POS 5200 = 8200
        BranchSalesRow first = resp.byBranch().get(0);
        assertEquals(sec62, first.branchId());
        assertEquals(0, new BigDecimal("8200").compareTo(first.revenue()));
        // 8200 / 12450 * 100 = 65.86
        assertEquals(0, new BigDecimal("65.86").compareTo(first.sharePercent()));

        // SEC18: invoice 1250 + POS 3000 = 4250
        BranchSalesRow second = resp.byBranch().get(1);
        assertEquals(sec18, second.branchId());
        assertEquals(0, new BigDecimal("4250").compareTo(second.revenue()));
        // 4250 / 12450 * 100 = 34.14
        assertEquals(0, new BigDecimal("34.14").compareTo(second.sharePercent()));
    }

    @Test
    void getTodaySales_branchFilter_callsBranchScopedAggregatesAndFiltersRollup() {
        LocalDate today = LocalDate.now();

        Organisation org = new Organisation();
        org.setId(orgId);
        org.setBaseCurrency("INR");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        UUID sec62 = UUID.randomUUID();
        UUID sec18 = UUID.randomUUID();
        Branch b62 = Branch.builder().code("SEC62").name("Sector 62 Store").build();
        b62.setId(sec62);
        Branch b18 = Branch.builder().code("SEC18").name("Sector 18 Store").build();
        b18.setId(sec18);

        when(branchRepository.findByIdAndOrgIdAndIsDeletedFalse(sec62, orgId))
                .thenReturn(Optional.of(b62));
        when(branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId))
                .thenReturn(List.of(b62, b18));

        when(salesReceiptRepository.sumTotalByOrgBranchAndDateRange(
                eq(orgId), eq(sec62), any(), any()))
                .thenReturn(new BigDecimal("5200"));
        when(invoiceRepository.sumPaidInvoicesByOrgBranchAndDateRange(
                eq(orgId), eq(sec62), any(), any()))
                .thenReturn(new BigDecimal("1000"));
        when(invoiceRepository.sumCreditSalesByOrgBranchAndDateRange(
                eq(orgId), eq(sec62), any(), any()))
                .thenReturn(new BigDecimal("1000"));

        when(salesReceiptRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(10L);
        when(invoiceRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(3L);

        when(invoiceRepository.sumRevenueByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(invoiceBranchRow(sec62, new BigDecimal("2000"))));
        when(salesReceiptRepository.sumTotalByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(posBranchRow(sec62, new BigDecimal("5200"))));

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, sec62);

        assertEquals(0, new BigDecimal("6200").compareTo(resp.cashUpiTotal()));
        assertEquals(0, new BigDecimal("1000").compareTo(resp.creditTotal()));
        assertEquals(0, new BigDecimal("7200").compareTo(resp.totalSales()));
        assertEquals(sec62, resp.branchFilter());
        assertEquals(1, resp.byBranch().size());
        assertEquals(sec62, resp.byBranch().get(0).branchId());

        // Org-wide methods must NOT be called when a branch filter is active
        verify(salesReceiptRepository, never())
                .sumTotalByOrgAndDateRange(any(), any(), any());
        verify(invoiceRepository, never())
                .sumPaidInvoicesByOrgAndDateRange(any(), any(), any());
    }

    @Test
    void getTodaySales_unknownBranch_throwsNotFound() {
        LocalDate today = LocalDate.now();
        UUID unknown = UUID.randomUUID();

        Organisation org = new Organisation();
        org.setId(orgId);
        org.setBaseCurrency("INR");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(branchRepository.findByIdAndOrgIdAndIsDeletedFalse(unknown, orgId))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> dashboardService.getTodaySales(today, today, unknown));
        assertEquals("ERR_BRANCH_NOT_FOUND", ex.getErrorCode());

        verifyNoInteractions(invoiceLineRepository);
        verify(salesReceiptRepository, never())
                .sumTotalByOrgAndDateRange(any(), any(), any());
    }

    @Test
    void getTodaySales_invalidRange_throwsBusinessException() {
        LocalDate from = LocalDate.of(2025, 3, 10);
        LocalDate to = LocalDate.of(2025, 3, 1);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> dashboardService.getTodaySales(from, to, null));
        assertEquals("DASHBOARD_INVALID_RANGE", ex.getErrorCode());
        verifyNoInteractions(invoiceRepository, paymentRepository, branchRepository);
    }

    @Test
    void getTodaySales_zeroBranches_returnsEmptyRollup() {
        LocalDate today = LocalDate.now();

        Organisation org = new Organisation();
        org.setId(orgId);
        org.setBaseCurrency("INR");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        when(branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId))
                .thenReturn(List.of());
        when(salesReceiptRepository.sumTotalByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(BigDecimal.ZERO);
        when(invoiceRepository.sumPaidInvoicesByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(BigDecimal.ZERO);
        when(invoiceRepository.sumCreditSalesByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(BigDecimal.ZERO);
        when(salesReceiptRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(0L);
        when(invoiceRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(0L);

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, null);

        assertTrue(resp.byBranch().isEmpty());
        assertEquals(0, resp.transactionCount());
        verify(invoiceRepository, never()).sumRevenueByBranch(any(), any(), any());
    }

    @Test
    void getTodaySales_zeroRevenueBranch_showsWithZeroSharePercent() {
        LocalDate today = LocalDate.now();

        Organisation org = new Organisation();
        org.setId(orgId);
        org.setBaseCurrency("INR");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        UUID sec62 = UUID.randomUUID();
        UUID sec18 = UUID.randomUUID();
        Branch b62 = Branch.builder().code("SEC62").name("Sector 62 Store").build();
        b62.setId(sec62);
        Branch b18 = Branch.builder().code("SEC18").name("Sector 18 Store").build();
        b18.setId(sec18);

        when(branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId))
                .thenReturn(List.of(b62, b18));
        when(salesReceiptRepository.sumTotalByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("5200"));
        when(invoiceRepository.sumPaidInvoicesByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("2000"));
        when(invoiceRepository.sumCreditSalesByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(BigDecimal.ZERO);
        when(salesReceiptRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(12L);
        when(invoiceRepository.countByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(3L);

        when(invoiceRepository.sumRevenueByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(invoiceBranchRow(sec62, new BigDecimal("2000"))));
        when(salesReceiptRepository.sumTotalByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(posBranchRow(sec62, new BigDecimal("5200"))));

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, null);

        assertEquals(2, resp.byBranch().size(),
                "Zero-revenue branches must still appear");

        BranchSalesRow top = resp.byBranch().get(0);
        BranchSalesRow zero = resp.byBranch().get(1);
        assertEquals(sec62, top.branchId());
        assertEquals(0, new BigDecimal("7200").compareTo(top.revenue()));
        assertEquals(sec18, zero.branchId());
        assertEquals(0, BigDecimal.ZERO.compareTo(zero.revenue()));
        assertEquals(0, new BigDecimal("0.00").compareTo(zero.sharePercent()));
    }

    // ── getTopSelling ─────────────────────────────────────────────────

    @Test
    void getTopSelling_mergesInvoiceAndPosLines() {
        LocalDate today = LocalDate.now();
        UUID paraId = UUID.randomUUID();
        UUID crocinId = UUID.randomUUID();
        UUID oilId = UUID.randomUUID();

        Item para = Item.builder()
                .sku("PARA-500").name("Paracetamol 500mg").unitOfMeasure("STRIP").build();
        para.setId(paraId);
        Item crocin = Item.builder()
                .sku("CROC-ADV").name("Crocin Advance").unitOfMeasure("STRIP").build();
        crocin.setId(crocinId);
        Item oil = Item.builder()
                .sku("OIL-500").name("Hair Oil 500ml").unitOfMeasure("BOTTLE").build();
        oil.setId(oilId);

        // Invoice: para 50 qty, crocin 30 qty
        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of(
                        invoiceTopRow(paraId, "Paracetamol 500mg",
                                new BigDecimal("50"), new BigDecimal("2500")),
                        invoiceTopRow(crocinId, "Crocin Advance",
                                new BigDecimal("30"), new BigDecimal("2250"))));

        // POS: para 37 qty (more), oil 25 qty (POS-only item)
        when(salesReceiptLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of(
                        posTopRow(paraId, "Paracetamol 500mg",
                                new BigDecimal("37"), new BigDecimal("1850")),
                        posTopRow(oilId, "Hair Oil 500ml",
                                new BigDecimal("25"), new BigDecimal("1250"))));

        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any(Collection.class)))
                .thenReturn(List.of(para, crocin, oil));

        List<TopSellingItem> results = dashboardService.getTopSelling(today, today, 10);

        assertEquals(3, results.size());
        // para: 50 + 37 = 87 (highest)
        assertEquals(1, results.get(0).rank());
        assertEquals(paraId, results.get(0).itemId());
        assertEquals(0, new BigDecimal("87").compareTo(results.get(0).quantity()));
        assertEquals(0, new BigDecimal("4350").compareTo(results.get(0).revenue()));
        // crocin: 30
        assertEquals(2, results.get(1).rank());
        assertEquals(crocinId, results.get(1).itemId());
        assertEquals(0, new BigDecimal("30").compareTo(results.get(1).quantity()));
        // oil: 25 (POS only)
        assertEquals(3, results.get(2).rank());
        assertEquals(oilId, results.get(2).itemId());
        assertEquals(0, new BigDecimal("25").compareTo(results.get(2).quantity()));
    }

    @Test
    void getTopSelling_limitClampedBetween1And20() {
        LocalDate today = LocalDate.now();
        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());
        when(salesReceiptLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());

        dashboardService.getTopSelling(today, today, 0);
        dashboardService.getTopSelling(today, today, 9999);

        org.mockito.ArgumentCaptor<Pageable> captor =
                org.mockito.ArgumentCaptor.forClass(Pageable.class);
        verify(invoiceLineRepository, times(2))
                .findTopSelling(eq(orgId), any(), any(), captor.capture());

        List<Pageable> pageables = captor.getAllValues();
        assertEquals(1, pageables.get(0).getPageSize(), "limit=0 must clamp to 1");
        assertEquals(20, pageables.get(1).getPageSize(), "limit=9999 must clamp to 20");
    }

    @Test
    void getTopSelling_empty_returnsEmpty() {
        LocalDate today = LocalDate.now();
        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());
        when(salesReceiptLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());

        assertTrue(dashboardService.getTopSelling(today, today, 5).isEmpty());
        verifyNoInteractions(itemRepository);
    }

    @Test
    void getTopSelling_missingItem_fallsBackToLineDescription() {
        LocalDate today = LocalDate.now();
        UUID orphanId = UUID.randomUUID();

        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of(
                        invoiceTopRow(orphanId, "Legacy item description",
                                new BigDecimal("3"), new BigDecimal("150"))));
        when(salesReceiptLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any(Collection.class)))
                .thenReturn(List.of());

        List<TopSellingItem> results = dashboardService.getTopSelling(today, today, 5);

        assertEquals(1, results.size());
        assertEquals(1, results.get(0).rank());
        assertEquals(orphanId, results.get(0).itemId());
        assertEquals("Legacy item description", results.get(0).name());
        assertNull(results.get(0).sku());
        assertNull(results.get(0).unit());
    }

    // ── helpers ──────────────────────────────────────────────────────

    private static InvoiceRepository.RevenueByBranchRow invoiceBranchRow(UUID branchId, BigDecimal total) {
        return new InvoiceRepository.RevenueByBranchRow() {
            @Override public UUID getBranchId() { return branchId; }
            @Override public BigDecimal getTotal() { return total; }
        };
    }

    private static SalesReceiptRepository.RevenueByBranchRow posBranchRow(UUID branchId, BigDecimal total) {
        return new SalesReceiptRepository.RevenueByBranchRow() {
            @Override public UUID getBranchId() { return branchId; }
            @Override public BigDecimal getTotal() { return total; }
        };
    }

    private static InvoiceLineRepository.TopSellingRow invoiceTopRow(
            UUID itemId, String description, BigDecimal qty, BigDecimal revenue) {
        return new InvoiceLineRepository.TopSellingRow() {
            @Override public UUID getItemId() { return itemId; }
            @Override public String getDescription() { return description; }
            @Override public BigDecimal getTotalQty() { return qty; }
            @Override public BigDecimal getTotalRevenue() { return revenue; }
        };
    }

    private static SalesReceiptLineRepository.TopSellingRow posTopRow(
            UUID itemId, String description, BigDecimal qty, BigDecimal revenue) {
        return new SalesReceiptLineRepository.TopSellingRow() {
            @Override public UUID getItemId() { return itemId; }
            @Override public String getDescription() { return description; }
            @Override public BigDecimal getTotalQty() { return qty; }
            @Override public BigDecimal getTotalRevenue() { return revenue; }
        };
    }
}
