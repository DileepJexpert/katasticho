package com.katasticho.erp.ap.match;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.StockReceiptLineRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ThreeWayMatchServiceTest {

    @Mock private PurchaseBillRepository billRepository;
    @Mock private BillMatchResultLineRepository matchResultRepository;
    @Mock private PurchaseOrderLineRepository purchaseOrderLineRepository;
    @Mock private StockReceiptLineRepository stockReceiptLineRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private OrgSettingsService orgSettingsService;
    @Mock private AiSuggestionService aiSuggestionService;
    @Mock private AiSuggestionRepository aiSuggestionRepository;

    private ThreeWayMatchService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new ThreeWayMatchService(
                billRepository, matchResultRepository,
                purchaseOrderLineRepository, stockReceiptLineRepository,
                itemRepository, orgSettingsService,
                aiSuggestionService, aiSuggestionRepository);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Helpers ─────────────────────────────────────────────────

    private void stubDefaults() {
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.required"), eq("true")))
                .thenReturn("true");
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.qty_tolerance_pct"), eq("0")))
                .thenReturn("0");
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.price_tolerance_abs"), eq("1")))
                .thenReturn("1");
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.price_tolerance_pct"), eq("0.005")))
                .thenReturn("0.005");
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.bypass_threshold"), eq("0")))
                .thenReturn("0");
    }

    private void stubTolerances(String qtyPct, String priceAbs, String pricePct, String bypass) {
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.required"), eq("true")))
                .thenReturn("true");
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.qty_tolerance_pct"), eq("0")))
                .thenReturn(qtyPct);
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.price_tolerance_abs"), eq("1")))
                .thenReturn(priceAbs);
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.price_tolerance_pct"), eq("0.005")))
                .thenReturn(pricePct);
        when(orgSettingsService.get(eq(orgId), eq("ap.three_way_match.bypass_threshold"), eq("0")))
                .thenReturn(bypass);
    }

    private PurchaseBill bill(BigDecimal totalAmount, List<PurchaseBillLine> lines) {
        PurchaseBill b = PurchaseBill.builder()
                .orgId(orgId).billNumber("BILL-2026-00001").status("DRAFT")
                .totalAmount(totalAmount).build();
        b.setId(UUID.randomUUID());
        for (PurchaseBillLine l : lines) {
            if (l.getId() == null) l.setId(UUID.randomUUID());
            b.addLine(l);
        }
        return b;
    }

    private PurchaseBillLine billLine(BigDecimal qty, BigDecimal price, UUID itemId, UUID poLineId) {
        PurchaseBillLine l = PurchaseBillLine.builder()
                .lineNumber(1)
                .description("test")
                .quantity(qty)
                .unitPrice(price)
                .itemId(itemId)
                .accountId(UUID.randomUUID())
                .purchaseOrderLineId(poLineId)
                .taxableAmount(qty.multiply(price))
                .lineTotal(qty.multiply(price))
                .build();
        l.setId(UUID.randomUUID());
        return l;
    }

    private PurchaseOrderLine poLine(UUID id, BigDecimal qty, BigDecimal price) {
        PurchaseOrderLine p = PurchaseOrderLine.builder()
                .poId(UUID.randomUUID())
                .itemId(UUID.randomUUID())
                .quantity(qty).unitPrice(price)
                .lineTotal(qty.multiply(price))
                .build();
        p.setId(id);
        return p;
    }

    private Item goodsItem() {
        Item i = Item.builder().sku("ITEM").name("Item").itemType(ItemType.GOODS).build();
        i.setId(UUID.randomUUID());
        return i;
    }

    private Item serviceItem() {
        Item i = Item.builder().sku("SVC").name("Service").itemType(ItemType.SERVICE).build();
        i.setId(UUID.randomUUID());
        return i;
    }

    private void stubBillFor(PurchaseBill b) {
        when(billRepository.findByIdAndOrgIdAndIsDeletedFalse(b.getId(), orgId))
                .thenReturn(Optional.of(b));
        when(billRepository.save(any(PurchaseBill.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @SuppressWarnings("unchecked")
    private List<BillMatchResultLine> captureSavedResults() {
        ArgumentCaptor<List<BillMatchResultLine>> c = ArgumentCaptor.forClass(List.class);
        verify(matchResultRepository).saveAll(c.capture());
        return c.getValue();
    }

    // ── Tests ───────────────────────────────────────────────────

    @Test
    void match_exact_qty_and_price_returns_MATCHED_no_suggestion() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1000"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("10"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));

        String status = service.match(b.getId());

        assertEquals("MATCHED", status);
        assertEquals("MATCHED", captureSavedResults().get(0).getStatus());
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void match_qty_over_received_at_zero_tolerance_returns_QTY_OVER() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        // Bill 110 units, only 100 received → 10-unit over
        PurchaseBillLine line = billLine(new BigDecimal("110"), new BigDecimal("100"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("11000"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("120"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("100"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(false);

        String status = service.match(b.getId());

        assertEquals("EXCEPTION", status);
        assertEquals("QTY_OVER", captureSavedResults().get(0).getStatus());
        verify(aiSuggestionService).createSuggestion(any(AiSuggestion.class));
    }

    @Test
    void match_qty_within_one_pct_tolerance_returns_MATCHED() {
        stubTolerances("1", "1", "0.005", "0");
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        // 100.5 billed vs 100 received → 0.5% over, within 1% tolerance
        PurchaseBillLine line = billLine(new BigDecimal("100.5"), new BigDecimal("100"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("10050"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("120"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("100"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));

        String status = service.match(b.getId());
        assertEquals("MATCHED", status);
    }

    @Test
    void match_price_above_abs_tolerance_returns_PRICE_HIKE() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        // Bill price 102, PO price 100 → ₹2 hike, abs tol ₹1 exceeded
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("102"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1020"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("10"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(false);

        String status = service.match(b.getId());
        assertEquals("EXCEPTION", status);
        assertEquals("PRICE_HIKE", captureSavedResults().get(0).getStatus());
    }

    @Test
    void match_price_within_abs_tolerance_returns_MATCHED() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        // Bill 100.50 vs PO 100 → ₹0.50, within ₹1 abs tolerance
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100.50"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1005"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("10"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));

        String status = service.match(b.getId());
        assertEquals("MATCHED", status);
    }

    @Test
    void match_price_within_pct_tolerance_returns_MATCHED() {
        // 0.4% over price, 0.5% pct tolerance (abs tol 0 so the pct does the work)
        stubTolerances("0", "0", "0.005", "0");
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        // 100.40 vs 100 = +0.40% — within 0.5%
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100.40"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1004"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("10"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));

        String status = service.match(b.getId());
        assertEquals("MATCHED", status);
    }

    @Test
    void match_line_with_no_po_link_returns_NO_PO() {
        stubDefaults();
        Item item = goodsItem();
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100"),
                item.getId(), null);
        PurchaseBill b = bill(new BigDecimal("1000"), List.of(line));
        stubBillFor(b);
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(false);

        String status = service.match(b.getId());
        assertEquals("EXCEPTION", status);
        assertEquals("NO_PO", captureSavedResults().get(0).getStatus());
        // PO repo was never asked
        verify(purchaseOrderLineRepository, never()).findById(any());
    }

    @Test
    void match_po_linked_but_no_grn_returns_NO_GRN() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1000"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(BigDecimal.ZERO);
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(false);

        String status = service.match(b.getId());
        assertEquals("EXCEPTION", status);
        assertEquals("NO_GRN", captureSavedResults().get(0).getStatus());
    }

    @Test
    void match_bill_below_bypass_threshold_with_no_PO_returns_BYPASSED() {
        // bypass_threshold = 5000, bill total 1000 < threshold → BYPASSED
        stubTolerances("0", "1", "0.005", "5000");
        Item item = goodsItem();
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100"),
                item.getId(), null);
        PurchaseBill b = bill(new BigDecimal("1000"), List.of(line));
        stubBillFor(b);

        String status = service.match(b.getId());
        assertEquals("BYPASSED", status);
        assertEquals("BYPASSED", captureSavedResults().get(0).getStatus());
        // No exception → no suggestion
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void match_multi_line_one_price_hike_rest_matched_overall_EXCEPTION() {
        stubDefaults();
        UUID polId1 = UUID.randomUUID();
        UUID polId2 = UUID.randomUUID();
        Item item1 = goodsItem();
        Item item2 = goodsItem();
        PurchaseBillLine ok = billLine(new BigDecimal("10"), new BigDecimal("100"),
                item1.getId(), polId1);
        PurchaseBillLine hike = billLine(new BigDecimal("5"), new BigDecimal("120"),
                item2.getId(), polId2);
        PurchaseBill b = bill(new BigDecimal("1600"), List.of(ok, hike));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId1))
                .thenReturn(Optional.of(poLine(polId1, new BigDecimal("10"), new BigDecimal("100"))));
        when(purchaseOrderLineRepository.findById(polId2))
                .thenReturn(Optional.of(poLine(polId2, new BigDecimal("5"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId1))
                .thenReturn(new BigDecimal("10"));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId2))
                .thenReturn(new BigDecimal("5"));
        when(itemRepository.findById(item1.getId())).thenReturn(Optional.of(item1));
        when(itemRepository.findById(item2.getId())).thenReturn(Optional.of(item2));
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(false);

        String status = service.match(b.getId());
        assertEquals("EXCEPTION", status);
        List<BillMatchResultLine> saved = captureSavedResults();
        assertEquals(2, saved.size());
        assertEquals("MATCHED", saved.get(0).getStatus());
        assertEquals("PRICE_HIKE", saved.get(1).getStatus());
    }

    @Test
    void match_replace_style_deletes_prior_results_before_writing() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("100"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1000"), List.of(line));
        stubBillFor(b);
        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("10"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));

        service.match(b.getId());

        verify(matchResultRepository).deleteByOrgIdAndBillId(orgId, b.getId());
        verify(matchResultRepository).saveAll(anyList());
    }

    @Test
    void override_stamps_overridden_by_and_reason_and_blocks_repeat() {
        PurchaseBill b = bill(new BigDecimal("1000"), List.of());
        b.setThreeWayMatchStatus("EXCEPTION");
        stubBillFor(b);

        service.override(b.getId(), "vendor agreed verbal price");
        assertEquals("OVERRIDDEN", b.getThreeWayMatchStatus());
        assertEquals(userId, b.getThreeWayMatchOverriddenBy());
        assertEquals("vendor agreed verbal price", b.getThreeWayMatchOverrideReason());

        // Re-override is blocked
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.override(b.getId(), "again"));
        assertEquals("THREE_WAY_MATCH_ALREADY_OVERRIDDEN", ex.getErrorCode());
    }

    @Test
    void match_exception_does_not_create_duplicate_suggestion_when_one_already_open() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item item = goodsItem();
        PurchaseBillLine line = billLine(new BigDecimal("10"), new BigDecimal("102"),
                item.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("1020"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("10"), new BigDecimal("100"))));
        when(stockReceiptLineRepository.sumReceivedQuantityForPurchaseOrderLine(polId))
                .thenReturn(new BigDecimal("10"));
        when(itemRepository.findById(item.getId())).thenReturn(Optional.of(item));
        // Suggestion already exists → idempotent: no second one created
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(true);

        String status = service.match(b.getId());
        assertEquals("EXCEPTION", status);
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void match_service_item_skips_grn_check_compares_price_only() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item svc = serviceItem();
        // Bill price 102 vs PO 100 → still PRICE_HIKE (svc doesn't receive but price matters)
        PurchaseBillLine line = billLine(new BigDecimal("1"), new BigDecimal("102"),
                svc.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("102"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("1"), new BigDecimal("100"))));
        when(itemRepository.findById(svc.getId())).thenReturn(Optional.of(svc));
        when(aiSuggestionRepository.existsOpenSuggestion(
                any(UUID.class), anyString(), any(UUID.class), isNull(),
                anyString(), anyCollection())).thenReturn(false);

        String status = service.match(b.getId());
        assertEquals("EXCEPTION", status);
        assertEquals("PRICE_HIKE", captureSavedResults().get(0).getStatus());
        // GRN repo was NEVER asked — SERVICE items skip the receive check
        verify(stockReceiptLineRepository, never()).sumReceivedQuantityForPurchaseOrderLine(any());
    }

    @Test
    void match_service_item_with_matched_price_returns_MATCHED() {
        stubDefaults();
        UUID polId = UUID.randomUUID();
        Item svc = serviceItem();
        PurchaseBillLine line = billLine(new BigDecimal("1"), new BigDecimal("100"),
                svc.getId(), polId);
        PurchaseBill b = bill(new BigDecimal("100"), List.of(line));
        stubBillFor(b);

        when(purchaseOrderLineRepository.findById(polId))
                .thenReturn(Optional.of(poLine(polId, new BigDecimal("1"), new BigDecimal("100"))));
        when(itemRepository.findById(svc.getId())).thenReturn(Optional.of(svc));

        String status = service.match(b.getId());
        assertEquals("MATCHED", status);
        verify(stockReceiptLineRepository, never()).sumReceivedQuantityForPurchaseOrderLine(any());
    }
}
