package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WhatsAppOrderServiceTest {

    @Mock private ItemRepository itemRepository;
    private WhatsAppOrderService service;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new WhatsAppOrderService(itemRepository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    // ── Segment splitting ────────────────────────────────────────

    @Test
    void splits_on_newlines_commas_and_and() {
        List<String> segs = service.splitSegments("200 amul, 5 dolo and 10 kg sugar\n12 atta");
        assertEquals(4, segs.size());
        assertEquals("200 amul", segs.get(0));
        assertEquals("5 dolo", segs.get(1));
        assertEquals("10 kg sugar", segs.get(2));
        assertEquals("12 atta", segs.get(3));
    }

    @Test
    void strips_bullets_and_blank_lines() {
        List<String> segs = service.splitSegments("- 200 amul\n\n• 5 dolo\n");
        assertEquals(2, segs.size());
        assertEquals("200 amul", segs.get(0));
        assertEquals("5 dolo", segs.get(1));
    }

    // ── Noise stripping ──────────────────────────────────────────

    @Test
    void strips_hindi_and_english_courtesy_verbs() {
        assertEquals("amul 1l", WhatsAppOrderService.stripNoise("amul 1L bhej do please"));
        assertEquals("dolo 500", WhatsAppOrderService.stripNoise("send dolo 500"));
        assertEquals("crocin", WhatsAppOrderService.stripNoise("kindly please crocin chahiye"));
    }

    // ── Parsing happy paths ──────────────────────────────────────

    @Test
    void parses_leading_qty_and_matches_item() {
        Item amul = item("Amul Taaza Milk 1L", "55");
        when(itemRepository.search(eq(orgId), any(), any(Pageable.class)))
                .thenReturn(page(List.of(amul)));

        var parsed = service.parse("200 amul 1L bhej do");
        assertEquals(1, parsed.lineCount());
        assertEquals(1, parsed.matchedCount());
        var line = parsed.lines().get(0);
        assertEquals(0, new BigDecimal("200").compareTo(line.quantity()));
        assertEquals(amul.getId(), line.itemId());
        assertEquals(0, new BigDecimal("11000").compareTo(parsed.estimatedTotal()),
                "200 × ₹55 = ₹11,000");
    }

    @Test
    void parses_trailing_qty_form() {
        Item dolo = item("Dolo 650 Tablet 15s", "30");
        when(itemRepository.search(eq(orgId), any(), any(Pageable.class)))
                .thenReturn(page(List.of(dolo)));

        var parsed = service.parse("dolo 650 5");
        var line = parsed.lines().get(0);
        assertEquals(0, new BigDecimal("5").compareTo(line.quantity()));
        assertEquals(dolo.getId(), line.itemId());
    }

    @Test
    void multi_line_message_parses_each_segment() {
        Item amul = item("Amul Milk", "55");
        Item dolo = item("Dolo 650", "30");
        // Return different items based on query token
        when(itemRepository.search(eq(orgId), any(String.class), any(Pageable.class)))
                .thenAnswer(inv -> {
                    String q = inv.getArgument(1);
                    if (q.contains("amul")) return page(List.of(amul));
                    if (q.contains("dolo")) return page(List.of(dolo));
                    return page(List.of());
                });

        var parsed = service.parse("200 amul\n5 dolo 650");
        assertEquals(2, parsed.lineCount());
        assertEquals(2, parsed.matchedCount());
    }

    // ── Failure / fallback paths ─────────────────────────────────

    @Test
    void unmatched_item_returns_warning_and_line_with_matched_false() {
        when(itemRepository.search(eq(orgId), any(), any(Pageable.class)))
                .thenReturn(page(List.of()));

        var parsed = service.parse("200 mystery item");
        assertEquals(1, parsed.lineCount());
        assertEquals(0, parsed.matchedCount());
        assertFalse(parsed.lines().get(0).matched());
        assertEquals(1, parsed.warnings().size());
        assertTrue(parsed.warnings().get(0).contains("mystery item"));
    }

    @Test
    void empty_or_null_message_returns_empty_parsed_order_no_throw() {
        var empty = service.parse("");
        assertEquals(0, empty.lineCount());
        assertTrue(empty.warnings().contains("Message was empty."));

        var nulled = service.parse(null);
        assertEquals(0, nulled.lineCount());
    }

    @Test
    void no_quantity_defaults_to_one_and_full_segment_as_name() {
        Item crocin = item("Crocin 500mg", "20");
        when(itemRepository.search(eq(orgId), eq("crocin"), any(Pageable.class)))
                .thenReturn(page(List.of(crocin)));

        var parsed = service.parse("crocin");
        var line = parsed.lines().get(0);
        assertEquals(0, BigDecimal.ONE.compareTo(line.quantity()));
        assertEquals(crocin.getId(), line.itemId());
    }

    @Test
    void supplies_alternates_for_disambiguation() {
        Item primary = item("Dolo 650 Tablet", "30");
        Item alt = item("Dolo 500 Tablet", "25");
        when(itemRepository.search(eq(orgId), any(), any(Pageable.class)))
                .thenReturn(page(List.of(primary, alt)));

        var parsed = service.parse("5 dolo");
        var line = parsed.lines().get(0);
        assertEquals(1, line.alternates().size());
        assertEquals(alt.getId(), line.alternates().get(0).itemId());
    }

    // ── Confidence ───────────────────────────────────────────────

    @Test
    void confidence_high_when_query_tokens_match_item_name() {
        assertEquals(1.0,
                WhatsAppOrderService.confidenceScore("amul milk", "Amul Taaza Milk 1L", 1),
                0.01);
    }

    @Test
    void confidence_penalised_when_many_candidates() {
        double single = WhatsAppOrderService.confidenceScore("dolo", "Dolo 650", 1);
        double many = WhatsAppOrderService.confidenceScore("dolo", "Dolo 650", 5);
        assertTrue(many < single, "5 candidates should reduce confidence vs 1");
    }

    // ── helpers ───────────────────────────────────────────────────

    private Item item(String name, String price) {
        Item i = new Item();
        i.setId(UUID.randomUUID());
        i.setOrgId(orgId);
        i.setName(name);
        i.setSalePrice(new BigDecimal(price));
        return i;
    }

    private Page<Item> page(List<Item> items) {
        return new PageImpl<>(items);
    }
}
