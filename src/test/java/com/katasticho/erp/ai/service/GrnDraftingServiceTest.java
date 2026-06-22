package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.dto.GrnDraftFromScanRequest;
import com.katasticho.erp.ai.dto.GrnDraftResult;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.StockReceiptLineRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.service.StockReceiptService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class GrnDraftingServiceTest {

    private final StockReceiptService stockReceiptService = mock(StockReceiptService.class);
    private final PurchaseOrderRepository purchaseOrderRepository = mock(PurchaseOrderRepository.class);
    private final PurchaseOrderLineRepository purchaseOrderLineRepository =
            mock(PurchaseOrderLineRepository.class);
    private final ItemRepository itemRepository = mock(ItemRepository.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);
    private final AiSuggestionRepository aiSuggestionRepository = mock(AiSuggestionRepository.class);

    private final GrnDraftingService service = new GrnDraftingService(
            stockReceiptService, purchaseOrderRepository, purchaseOrderLineRepository,
            itemRepository, aiSuggestionService, aiSuggestionRepository);

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID suggestionId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        when(aiSuggestionService.createSuggestion(any(AiSuggestion.class))).thenAnswer(inv -> {
            AiSuggestion s = inv.getArgument(0);
            s.setId(suggestionId);
            return s;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void draftWithPoMatchesLinesByItemNameAndStampsFks() {
        UUID poId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();
        UUID warehouseId = UUID.randomUUID();
        UUID itemAId = UUID.randomUUID();
        UUID itemBId = UUID.randomUUID();
        UUID polAId = UUID.randomUUID();
        UUID polBId = UUID.randomUUID();
        UUID grnId = UUID.randomUUID();

        PurchaseOrder po = po(poId, supplierId, warehouseId, "PO-2026-0001");
        when(purchaseOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(poId, orgId))
                .thenReturn(Optional.of(po));

        PurchaseOrderLine polA = poLine(polAId, poId, itemAId, "10", "95");
        PurchaseOrderLine polB = poLine(polBId, poId, itemBId, "20", "40");
        when(purchaseOrderLineRepository.findByPoId(poId)).thenReturn(List.of(polA, polB));

        Item itemA = item(itemAId, "Crocin 500mg", "3004", "10");
        Item itemB = item(itemBId, "Brufen 400mg", "3004", "10");
        when(itemRepository.findAllById(any())).thenReturn(List.of(itemA, itemB));

        when(stockReceiptService.createDraft(any(CreateStockReceiptRequest.class)))
                .thenReturn(draftGrn(grnId, supplierId, "GRN-2026-0001"));

        GrnDraftFromScanRequest req = new GrnDraftFromScanRequest(
                poId, null, "ABC Pharma", null, "INV-44",
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 2), null, 0.91,
                List.of(
                        new GrnDraftFromScanRequest.ScanLine(
                                "Crocin 500mg", "3004", new BigDecimal("8"), new BigDecimal("95"),
                                new BigDecimal("100"), "B123", LocalDate.of(2027, 12, 31),
                                new BigDecimal("12")),
                        new GrnDraftFromScanRequest.ScanLine(
                                "Brufen 400mg", "3004", new BigDecimal("15"), new BigDecimal("40"),
                                new BigDecimal("50"), "B456", LocalDate.of(2028, 6, 30),
                                new BigDecimal("12"))));

        GrnDraftResult result = service.draftFromScan(req);

        assertThat(result.grnId()).isEqualTo(grnId);
        assertThat(result.suggestionId()).isEqualTo(suggestionId);
        assertThat(result.purchaseOrderId()).isEqualTo(poId);
        assertThat(result.lineCount()).isEqualTo(2);
        assertThat(result.unmatchedCount()).isZero();
        assertThat(result.status()).isEqualTo("DRAFT");

        ArgumentCaptor<CreateStockReceiptRequest> captor =
                ArgumentCaptor.forClass(CreateStockReceiptRequest.class);
        verify(stockReceiptService).createDraft(captor.capture());
        CreateStockReceiptRequest sent = captor.getValue();
        assertThat(sent.supplierId()).isEqualTo(supplierId);
        assertThat(sent.warehouseId()).isEqualTo(warehouseId);
        assertThat(sent.purchaseOrderId()).isEqualTo(poId);
        assertThat(sent.lines()).hasSize(2);
        // Crocin line bound to polA + itemA; Brufen line bound to polB + itemB.
        StockReceiptLineRequest l0 = sent.lines().get(0);
        StockReceiptLineRequest l1 = sent.lines().get(1);
        assertThat(l0.itemId()).isEqualTo(itemAId);
        assertThat(l0.purchaseOrderLineId()).isEqualTo(polAId);
        assertThat(l0.batchNumber()).isEqualTo("B123");
        assertThat(l1.itemId()).isEqualTo(itemBId);
        assertThat(l1.purchaseOrderLineId()).isEqualTo(polBId);
        // Suggestion priority MEDIUM when nothing is unmatched.
        verify(aiSuggestionService).createSuggestion(argThat((AiSuggestion s) ->
                "MEDIUM".equals(s.getPriority()) && "DRAFT_GRN".equals(s.getSuggestionType())));
    }

    @Test
    void draftWithPoFlagsUnmatchedLinesAsHighPriority() {
        UUID poId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();
        UUID warehouseId = UUID.randomUUID();
        UUID itemAId = UUID.randomUUID();
        UUID polAId = UUID.randomUUID();
        UUID grnId = UUID.randomUUID();

        PurchaseOrder po = po(poId, supplierId, warehouseId, "PO-2026-0002");
        when(purchaseOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(poId, orgId))
                .thenReturn(Optional.of(po));
        PurchaseOrderLine polA = poLine(polAId, poId, itemAId, "10", "95");
        when(purchaseOrderLineRepository.findByPoId(poId)).thenReturn(List.of(polA));

        Item itemA = item(itemAId, "Crocin 500mg", "3004", "10");
        when(itemRepository.findAllById(any())).thenReturn(List.of(itemA));

        when(stockReceiptService.createDraft(any(CreateStockReceiptRequest.class)))
                .thenReturn(draftGrn(grnId, supplierId, "GRN-2026-0002"));

        GrnDraftFromScanRequest req = new GrnDraftFromScanRequest(
                poId, null, "ABC Pharma", null, "INV-45",
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 2), null, 0.7,
                List.of(
                        new GrnDraftFromScanRequest.ScanLine(
                                "Crocin 500mg", "3004", new BigDecimal("8"), new BigDecimal("95"),
                                new BigDecimal("100"), "B123", LocalDate.of(2027, 12, 31),
                                new BigDecimal("12")),
                        new GrnDraftFromScanRequest.ScanLine(
                                "Unknown widget", null, new BigDecimal("2"), new BigDecimal("50"),
                                null, null, null, null)));

        GrnDraftResult result = service.draftFromScan(req);

        // Matched line is in; the unmatched line is dropped from the draft + counted.
        assertThat(result.lineCount()).isEqualTo(1);
        assertThat(result.unmatchedCount()).isEqualTo(1);
        assertThat(result.warnings()).anyMatch(w -> w.contains("could not be matched"));
        verify(aiSuggestionService).createSuggestion(argThat((AiSuggestion s) ->
                "HIGH".equals(s.getPriority())));
    }

    @Test
    void draftWithoutPoUsesSuppliedWarehouseAndItemLookup() {
        UUID supplierId = UUID.randomUUID();
        UUID warehouseId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID grnId = UUID.randomUUID();

        Item item = item(itemId, "Crocin 500mg", "3004", "10");
        when(itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Crocin 500mg"))
                .thenReturn(Optional.of(item));

        when(stockReceiptService.createDraft(any(CreateStockReceiptRequest.class)))
                .thenReturn(draftGrn(grnId, supplierId, "GRN-2026-0003"));

        GrnDraftFromScanRequest req = new GrnDraftFromScanRequest(
                null, warehouseId, "Walk-in supplier", supplierId, "INV-9",
                null, null, null, 0.6,
                List.of(new GrnDraftFromScanRequest.ScanLine(
                        "Crocin 500mg", "3004", new BigDecimal("5"), new BigDecimal("90"),
                        new BigDecimal("100"), "B999", null, new BigDecimal("12"))));

        GrnDraftResult result = service.draftFromScan(req);

        assertThat(result.purchaseOrderId()).isNull();
        assertThat(result.lineCount()).isEqualTo(1);

        ArgumentCaptor<CreateStockReceiptRequest> captor =
                ArgumentCaptor.forClass(CreateStockReceiptRequest.class);
        verify(stockReceiptService).createDraft(captor.capture());
        CreateStockReceiptRequest sent = captor.getValue();
        assertThat(sent.warehouseId()).isEqualTo(warehouseId);
        assertThat(sent.supplierId()).isEqualTo(supplierId);
        assertThat(sent.purchaseOrderId()).isNull();
        assertThat(sent.lines().get(0).itemId()).isEqualTo(itemId);
        assertThat(sent.lines().get(0).purchaseOrderLineId()).isNull();
        // No PO → priority is HIGH regardless of matching.
        verify(aiSuggestionService).createSuggestion(argThat((AiSuggestion s) ->
                "HIGH".equals(s.getPriority())));
        verify(purchaseOrderRepository, never()).findByIdAndOrgIdAndIsDeletedFalse(any(), any());
    }

    @Test
    void draftWithoutPoAndWithoutWarehouseThrows() {
        UUID supplierId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        Item item = item(itemId, "Crocin 500mg", "3004", "10");
        when(itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.of(item));

        GrnDraftFromScanRequest req = new GrnDraftFromScanRequest(
                null, null, "Walk-in supplier", supplierId, "INV-9",
                null, null, null, 0.6,
                List.of(new GrnDraftFromScanRequest.ScanLine(
                        "Crocin 500mg", "3004", new BigDecimal("5"), new BigDecimal("90"),
                        new BigDecimal("100"), null, null, null)));

        assertThatThrownBy(() -> service.draftFromScan(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Warehouse is required");
        verify(stockReceiptService, never()).createDraft(any());
    }

    @Test
    void twoScanLinesForSamePoLineOnlyFirstWinsSecondIsUnmatched() {
        UUID poId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();
        UUID warehouseId = UUID.randomUUID();
        UUID itemAId = UUID.randomUUID();
        UUID polAId = UUID.randomUUID();
        UUID grnId = UUID.randomUUID();

        PurchaseOrder po = po(poId, supplierId, warehouseId, "PO-2026-0003");
        when(purchaseOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(poId, orgId))
                .thenReturn(Optional.of(po));
        PurchaseOrderLine polA = poLine(polAId, poId, itemAId, "10", "95");
        when(purchaseOrderLineRepository.findByPoId(poId)).thenReturn(List.of(polA));
        Item itemA = item(itemAId, "Crocin 500mg", "3004", "10");
        when(itemRepository.findAllById(any())).thenReturn(List.of(itemA));

        when(stockReceiptService.createDraft(any(CreateStockReceiptRequest.class)))
                .thenReturn(draftGrn(grnId, supplierId, "GRN-2026-0004"));

        // Two scan lines both naming the same PO product.
        GrnDraftFromScanRequest req = new GrnDraftFromScanRequest(
                poId, null, "ABC Pharma", null, "INV-50",
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 2), null, 0.7,
                List.of(
                        new GrnDraftFromScanRequest.ScanLine(
                                "Crocin 500mg", "3004", new BigDecimal("5"), new BigDecimal("95"),
                                null, "B1", null, null),
                        new GrnDraftFromScanRequest.ScanLine(
                                "Crocin 500mg", "3004", new BigDecimal("3"), new BigDecimal("95"),
                                null, "B2", null, null)));

        GrnDraftResult result = service.draftFromScan(req);

        assertThat(result.lineCount()).isEqualTo(1);
        assertThat(result.unmatchedCount()).isEqualTo(1);
        ArgumentCaptor<CreateStockReceiptRequest> captor =
                ArgumentCaptor.forClass(CreateStockReceiptRequest.class);
        verify(stockReceiptService).createDraft(captor.capture());
        // Only the first scan line binds to polA.
        assertThat(captor.getValue().lines().get(0).purchaseOrderLineId()).isEqualTo(polAId);
    }

    @Test
    void approveReceivesGrnAndMarksAccepted() {
        UUID grnId = UUID.randomUUID();
        UUID supplierId = UUID.randomUUID();

        AiSuggestion suggestion = AiSuggestion.builder()
                .id(suggestionId).orgId(orgId)
                .entityType("STOCK_RECEIPT").entityId(grnId)
                .suggestionType("DRAFT_GRN").status("PENDING")
                .confidence(new BigDecimal("0.900"))
                .build();
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(suggestion));

        StockReceiptResponse received = receivedGrn(grnId, supplierId, "GRN-2026-0001");
        when(stockReceiptService.receive(grnId)).thenReturn(received);

        GrnDraftResult result = service.approve(suggestionId);

        assertThat(result.grnId()).isEqualTo(grnId);
        assertThat(result.status()).isEqualTo("RECEIVED");

        verify(stockReceiptService).receive(grnId);
        verify(aiSuggestionService).review(eq(suggestionId),
                argThat((AiSuggestionReviewRequest r) -> "ACCEPT".equals(r.action())));
    }

    @Test
    void rejectCancelsDraftAndMarksRejected() {
        UUID grnId = UUID.randomUUID();
        AiSuggestion suggestion = AiSuggestion.builder()
                .id(suggestionId).orgId(orgId)
                .entityType("STOCK_RECEIPT").entityId(grnId)
                .suggestionType("DRAFT_GRN").status("PENDING")
                .build();
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(suggestion));

        service.reject(suggestionId, "Wrong supplier");

        verify(stockReceiptService).cancel(eq(grnId), argThat(s -> s.contains("Wrong supplier")));
        verify(aiSuggestionService).review(eq(suggestionId),
                argThat((AiSuggestionReviewRequest r) -> "REJECT".equals(r.action())));
    }

    @Test
    void approveRejectsNonDraftGrnSuggestion() {
        AiSuggestion suggestion = AiSuggestion.builder()
                .id(suggestionId).orgId(orgId)
                .entityType("PURCHASE_BILL").entityId(UUID.randomUUID())
                .suggestionType("DRAFT_BILL").status("PENDING")
                .build();
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(suggestion));

        assertThatThrownBy(() -> service.approve(suggestionId))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("not a drafted GRN");
        verify(stockReceiptService, never()).receive(any());
    }

    // ── fixtures ─────────────────────────────────────────────────────────

    private PurchaseOrder po(UUID id, UUID supplierId, UUID warehouseId, String number) {
        PurchaseOrder p = PurchaseOrder.builder()
                .id(id)
                .orgId(orgId)
                .supplierId(supplierId)
                .warehouseId(warehouseId)
                .poNumber(number)
                .status("SENT")
                .orderDate(LocalDate.of(2026, 5, 30))
                .build();
        return p;
    }

    private PurchaseOrderLine poLine(UUID id, UUID poId, UUID itemId, String qty, String price) {
        return PurchaseOrderLine.builder()
                .id(id)
                .poId(poId)
                .itemId(itemId)
                .quantity(new BigDecimal(qty))
                .unitPrice(new BigDecimal(price))
                .receivedQuantity(BigDecimal.ZERO)
                .build();
    }

    private Item item(UUID id, String name, String hsn, String gst) {
        Item it = new Item();
        it.setId(id);
        it.setOrgId(orgId);
        it.setName(name);
        it.setHsnCode(hsn);
        it.setGstRate(new BigDecimal(gst));
        it.setUnitOfMeasure("PCS");
        return it;
    }

    private StockReceiptResponse draftGrn(UUID id, UUID supplierId, String number) {
        return new StockReceiptResponse(
                id, number, LocalDate.of(2026, 6, 2),
                UUID.randomUUID(), "Main Warehouse",
                supplierId, "ABC Pharma", "27AABCT1234A1Z5",
                "INV-44", LocalDate.of(2026, 6, 1),
                "DRAFT",
                new BigDecimal("760"), new BigDecimal("91.20"), new BigDecimal("851.20"),
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                "INR", null, null,
                List.of(), null, null, null, Instant.now());
    }

    private StockReceiptResponse receivedGrn(UUID id, UUID supplierId, String number) {
        return new StockReceiptResponse(
                id, number, LocalDate.of(2026, 6, 2),
                UUID.randomUUID(), "Main Warehouse",
                supplierId, "ABC Pharma", "27AABCT1234A1Z5",
                "INV-44", LocalDate.of(2026, 6, 1),
                "RECEIVED",
                new BigDecimal("760"), new BigDecimal("91.20"), new BigDecimal("851.20"),
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                "INR", null, null,
                List.of(), Instant.now(), null, null, Instant.now());
    }
}
