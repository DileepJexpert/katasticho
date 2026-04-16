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

/**
 * Unit tests for the owner-dashboard aggregation service. These tests pin
 * down the invariants the mobile client depends on when rendering the
 * Sharma Medical mock (revenue/cash split, branch rollup math, top-selling
 * rank assignment):
 *
 *   - branch-filtered and org-wide paths call the correct repo methods
 *   - share-percent math uses HALF_UP rounding against the total
 *   - branches with zero revenue still appear in the "all branches" view
 *   - top-selling ranks are assigned in returned order
 *   - free-text lines (missing item) fall back to the line description
 *
 * The repos and entity mocks are pure Mockito — no Spring context.
 */
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

    private DashboardService dashboardService;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        dashboardService = new DashboardService(
                invoiceRepository, paymentRepository, invoiceLineRepository,
                itemRepository, branchRepository, organisationRepository,
                purchaseBillRepository, contactRepository);
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
    void getTodaySales_allBranches_returnsRollupWithSharePercent() {
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

        when(invoiceRepository.sumRevenueByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("12450"));
        when(paymentRepository.sumCollectedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("8200"));

        when(invoiceRepository.sumRevenueByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(
                        branchRow(sec62, new BigDecimal("7200")),
                        branchRow(sec18, new BigDecimal("5250"))));

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, null);

        assertEquals(0, new BigDecimal("12450").compareTo(resp.revenue()));
        assertEquals(0, new BigDecimal("8200").compareTo(resp.cashCollected()));
        assertEquals("INR", resp.currency());
        assertNull(resp.branchFilter());
        assertEquals(2, resp.byBranch().size());

        // Descending by revenue — SEC62 first
        BranchSalesRow first = resp.byBranch().get(0);
        BranchSalesRow second = resp.byBranch().get(1);
        assertEquals(sec62, first.branchId());
        assertEquals(0, new BigDecimal("7200").compareTo(first.revenue()));
        // 7200 / 12450 * 100 = 57.83 (HALF_UP)
        assertEquals(0, new BigDecimal("57.83").compareTo(first.sharePercent()),
                "SEC62 share must be 57.83% (HALF_UP)");

        assertEquals(sec18, second.branchId());
        assertEquals(0, new BigDecimal("5250").compareTo(second.revenue()));
        // 5250 / 12450 * 100 = 42.17
        assertEquals(0, new BigDecimal("42.17").compareTo(second.sharePercent()));

        verify(invoiceRepository).sumRevenueByOrgAndDateRange(eq(orgId), any(), any());
        verify(invoiceRepository, never())
                .sumRevenueByOrgBranchAndDateRange(any(), any(), any(), any());
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

        when(invoiceRepository.sumRevenueByOrgBranchAndDateRange(
                eq(orgId), eq(sec62), any(), any()))
                .thenReturn(new BigDecimal("7200"));
        when(paymentRepository.sumCollectedByOrgBranchAndDateRange(
                eq(orgId), eq(sec62), any(), any()))
                .thenReturn(new BigDecimal("4500"));
        when(invoiceRepository.sumRevenueByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(
                        branchRow(sec62, new BigDecimal("7200")),
                        branchRow(sec18, new BigDecimal("5250"))));

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, sec62);

        assertEquals(0, new BigDecimal("7200").compareTo(resp.revenue()));
        assertEquals(0, new BigDecimal("4500").compareTo(resp.cashCollected()));
        assertEquals(sec62, resp.branchFilter());
        // byBranch collapses to the single filtered branch.
        assertEquals(1, resp.byBranch().size());
        assertEquals(sec62, resp.byBranch().get(0).branchId());
        // With denominator == row revenue the share is 100% exactly.
        assertEquals(0, new BigDecimal("100.00").compareTo(resp.byBranch().get(0).sharePercent()));

        // Org-wide sum methods must NOT be called when a branch filter is active.
        verify(invoiceRepository, never())
                .sumRevenueByOrgAndDateRange(any(), any(), any());
        verify(paymentRepository, never())
                .sumCollectedByOrgAndDateRange(any(), any(), any());
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

        // Should NOT have called any aggregation repos — validation happens first.
        verifyNoInteractions(invoiceLineRepository);
        verify(invoiceRepository, never())
                .sumRevenueByOrgBranchAndDateRange(any(), any(), any(), any());
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
        when(invoiceRepository.sumRevenueByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(BigDecimal.ZERO);
        when(paymentRepository.sumCollectedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(BigDecimal.ZERO);

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, null);

        assertTrue(resp.byBranch().isEmpty());
        // sumRevenueByBranch should be short-circuited when there are no branches.
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
        when(invoiceRepository.sumRevenueByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("7200"));
        when(paymentRepository.sumCollectedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(new BigDecimal("4500"));
        when(invoiceRepository.sumRevenueByBranch(eq(orgId), any(), any()))
                .thenReturn(List.of(branchRow(sec62, new BigDecimal("7200"))));

        TodaySalesResponse resp = dashboardService.getTodaySales(today, today, null);

        assertEquals(2, resp.byBranch().size(),
                "Zero-revenue branches must still appear in the All-Branches view");

        BranchSalesRow top = resp.byBranch().get(0);
        BranchSalesRow zero = resp.byBranch().get(1);
        assertEquals(sec62, top.branchId());
        assertEquals(0, new BigDecimal("100.00").compareTo(top.sharePercent()));
        assertEquals(sec18, zero.branchId());
        assertEquals(0, BigDecimal.ZERO.compareTo(zero.revenue()));
        assertEquals(0, new BigDecimal("0.00").compareTo(zero.sharePercent()));
    }

    // ── getTopSelling ─────────────────────────────────────────────────

    @Test
    void getTopSelling_ranksInReturnedOrderAndEnrichesFromItem() {
        LocalDate today = LocalDate.now();
        UUID paraId = UUID.randomUUID();
        UUID crocinId = UUID.randomUUID();
        UUID d3Id = UUID.randomUUID();

        Item para = Item.builder()
                .sku("PARA-500").name("Paracetamol 500mg").unitOfMeasure("STRIP").build();
        para.setId(paraId);
        Item crocin = Item.builder()
                .sku("CROC-ADV").name("Crocin Advance").unitOfMeasure("STRIP").build();
        crocin.setId(crocinId);
        Item d3 = Item.builder()
                .sku("VITD3").name("Vitamin D3").unitOfMeasure("BOTTLE").build();
        d3.setId(d3Id);

        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of(
                        topSellingRow(paraId, "Paracetamol 500mg",
                                new BigDecimal("87"), new BigDecimal("4350")),
                        topSellingRow(crocinId, "Crocin Advance",
                                new BigDecimal("43"), new BigDecimal("3225")),
                        topSellingRow(d3Id, "Vitamin D3",
                                new BigDecimal("12"), new BigDecimal("4800"))));

        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any(Collection.class)))
                .thenReturn(List.of(para, crocin, d3));

        List<TopSellingItem> results = dashboardService.getTopSelling(today, today, 10);

        assertEquals(3, results.size());
        assertEquals(1, results.get(0).rank());
        assertEquals(2, results.get(1).rank());
        assertEquals(3, results.get(2).rank());

        assertEquals(paraId, results.get(0).itemId());
        assertEquals("Paracetamol 500mg", results.get(0).name());
        assertEquals("PARA-500", results.get(0).sku());
        assertEquals("STRIP", results.get(0).unit());
        assertEquals(0, new BigDecimal("87").compareTo(results.get(0).quantity()));
        assertEquals(0, new BigDecimal("4350").compareTo(results.get(0).revenue()));

        assertEquals("Crocin Advance", results.get(1).name());
        assertEquals("Vitamin D3", results.get(2).name());
    }

    @Test
    void getTopSelling_limitClampedBetween1And20() {
        LocalDate today = LocalDate.now();
        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());

        // Too low -> 1, too high -> 20
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

        assertTrue(dashboardService.getTopSelling(today, today, 5).isEmpty());
        // Must not waste a round-trip enriching zero rows.
        verifyNoInteractions(itemRepository);
    }

    @Test
    void getTopSelling_missingItem_fallsBackToLineDescription() {
        LocalDate today = LocalDate.now();
        UUID orphanId = UUID.randomUUID();

        when(invoiceLineRepository.findTopSelling(eq(orgId), any(), any(), any(Pageable.class)))
                .thenReturn(List.of(
                        topSellingRow(orphanId, "Legacy item description",
                                new BigDecimal("3"), new BigDecimal("150"))));
        // Item was deleted or belongs to another org — not returned by the batch load.
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any(Collection.class)))
                .thenReturn(List.of());

        List<TopSellingItem> results = dashboardService.getTopSelling(today, today, 5);

        assertEquals(1, results.size());
        assertEquals(1, results.get(0).rank());
        assertEquals(orphanId, results.get(0).itemId());
        assertEquals("Legacy item description", results.get(0).name(),
                "When no Item row is found, fall back to the line description");
        assertNull(results.get(0).sku());
        assertNull(results.get(0).unit());
    }

    // ── helpers ──────────────────────────────────────────────────────

    private static InvoiceRepository.RevenueByBranchRow branchRow(UUID branchId, BigDecimal total) {
        return new InvoiceRepository.RevenueByBranchRow() {
            @Override public UUID getBranchId() { return branchId; }
            @Override public BigDecimal getTotal() { return total; }
        };
    }

    private static InvoiceLineRepository.TopSellingRow topSellingRow(
            UUID itemId, String description, BigDecimal qty, BigDecimal revenue) {
        return new InvoiceLineRepository.TopSellingRow() {
            @Override public UUID getItemId() { return itemId; }
            @Override public String getDescription() { return description; }
            @Override public BigDecimal getTotalQty() { return qty; }
            @Override public BigDecimal getTotalRevenue() { return revenue; }
        };
    }
}
