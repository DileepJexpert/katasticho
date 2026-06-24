package com.katasticho.erp.supplychain.agent;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import com.katasticho.erp.procurement.service.PurchaseOrderService;
import com.katasticho.erp.supplychain.entity.ItemSupplier;
import com.katasticho.erp.supplychain.entity.PurchaseRequisition;
import com.katasticho.erp.supplychain.repository.ItemSupplierRepository;
import com.katasticho.erp.supplychain.repository.PurchaseRequisitionRepository;
import com.katasticho.erp.supplychain.service.SupplyChainService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AgenticReplenishmentServiceTest {

    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private ItemSupplierRepository itemSupplierRepository;
    @Mock private SupplierRepository supplierRepository;
    @Mock private WorkOrderRepository workOrderRepository;
    @Mock private PurchaseOrderRepository purchaseOrderRepository;
    @Mock private PurchaseRequisitionRepository purchaseRequisitionRepository;
    @Mock private AiSuggestionService aiSuggestionService;
    @Mock private AiSuggestionRepository aiSuggestionRepository;
    @Mock private OrgSettingsService orgSettingsService;
    @Mock private SupplyChainService supplyChainService;
    @Mock private PurchaseOrderService purchaseOrderService;

    private AgenticReplenishmentService service;
    private UUID orgId;
    private UUID itemId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        service = new AgenticReplenishmentService(
                stockBalanceRepository, itemRepository, itemSupplierRepository,
                supplierRepository, workOrderRepository, purchaseOrderRepository,
                purchaseRequisitionRepository, aiSuggestionService, aiSuggestionRepository,
                orgSettingsService, supplyChainService, purchaseOrderService);

        // Default: agent enabled.
        when(orgSettingsService.get(orgId, AgenticReplenishmentService.SETTING_ENABLED, "false"))
                .thenReturn("true");
        // Default: no other replenishment in flight, no open suggestion.
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);
        when(workOrderRepository
                .existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse(any(), any(), anyList()))
                .thenReturn(false);
        when(purchaseRequisitionRepository.existsOpenForItem(any(), any(), any())).thenReturn(false);
        when(purchaseOrderRepository.existsOpenForItem(any(), any(), any())).thenReturn(false);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void happyPath_withPreferredSupplier_createsSuggestionWithMediumPriority() {
        // onHand 80 vs reorderLevel 100 → shortfall 20 (≤50% of reorderLevel)
        // → MEDIUM priority.
        Item item = goodsItem(new BigDecimal("100"), new BigDecimal("50"));
        UUID supplierId = stubItemSupplier();
        Supplier sup = new Supplier();
        sup.setName("Acme Pharma");
        when(supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(supplierId, orgId))
                .thenReturn(Optional.of(sup));
        stubLowStock(new BigDecimal("80"));
        stubItem(item);

        int created = service.runForOrg();

        assertEquals(1, created);
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(cap.capture());
        AiSuggestion s = cap.getValue();
        assertEquals(AgenticReplenishmentService.SUGGESTION_TYPE, s.getSuggestionType());
        assertEquals(AgenticReplenishmentService.ENTITY_TYPE, s.getEntityType());
        assertEquals(itemId, s.getEntityId());
        assertEquals("MEDIUM", s.getPriority());
        Map<String, Object> v = s.getSuggestedValue();
        assertEquals(itemId, v.get("itemId"));
        assertEquals("Acme Pharma", v.get("preferredSupplierName"));
        // suggestedQty = reorderQty + shortfall = 50 + (100 − 80) = 70
        assertEquals(0, new BigDecimal(v.get("suggestedQty").toString()).compareTo(new BigDecimal("70")));
    }

    @Test
    void severeShortage_overHalfReorderLevel_marksHighPriority() {
        // onHand 5, reorderLevel 100 → shortfall 95 → > 50% of reorder level → HIGH
        Item item = goodsItem(new BigDecimal("100"), new BigDecimal("50"));
        when(itemSupplierRepository
                .findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, itemId))
                .thenReturn(Optional.empty());
        stubLowStock(new BigDecimal("5"));
        stubItem(item);

        service.runForOrg();

        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(cap.capture());
        assertEquals("HIGH", cap.getValue().getPriority());
    }

    @Test
    void alreadyOpenSuggestion_skipsItem() {
        stubLowStock(new BigDecimal("20"));
        stubItem(goodsItem(new BigDecimal("100"), new BigDecimal("50")));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), eq(AgenticReplenishmentService.ENTITY_TYPE), eq(itemId),
                isNull(), eq(AgenticReplenishmentService.SUGGESTION_TYPE), any()))
                .thenReturn(true);

        int created = service.runForOrg();

        assertEquals(0, created);
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void itemWithOpenWo_skipped() {
        stubLowStock(new BigDecimal("20"));
        stubItem(goodsItem(new BigDecimal("100"), new BigDecimal("50")));
        when(workOrderRepository.existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse(
                eq(orgId), eq(itemId), anyList())).thenReturn(true);

        int created = service.runForOrg();

        assertEquals(0, created);
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void itemWithOpenPo_skipped() {
        stubLowStock(new BigDecimal("20"));
        stubItem(goodsItem(new BigDecimal("100"), new BigDecimal("50")));
        when(purchaseOrderRepository.existsOpenForItem(eq(orgId), eq(itemId), any()))
                .thenReturn(true);

        int created = service.runForOrg();

        assertEquals(0, created);
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void compositeItem_neverReachesReplenishmentPath() {
        stubLowStock(new BigDecimal("5"));
        Item composite = goodsItem(new BigDecimal("100"), new BigDecimal("50"));
        composite.setItemType(ItemType.COMPOSITE);
        stubItem(composite);

        int created = service.runForOrg();

        assertEquals(0, created);
        verify(aiSuggestionService, never()).createSuggestion(any());
        // Composite items belong to the manufacturing auto-WO sweep — the
        // dedupe checks should never even fire for them.
        verify(workOrderRepository, never())
                .existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse(any(), any(), anyList());
    }

    @Test
    void approve_defaultsToRequisition_drafsPrViaSupplyChainService() {
        UUID suggestionId = UUID.randomUUID();
        AiSuggestion sug = openSuggestion(suggestionId, /*supplierId=*/null);
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(sug));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(goodsItem(new BigDecimal("100"), new BigDecimal("50"))));
        PurchaseRequisition pr = PurchaseRequisition.builder().build();
        pr.setId(UUID.randomUUID());
        pr.setRequisitionNumber("PR-00007");
        when(supplyChainService.createRequisition(any(), any(), any(), anyString(), anyList()))
                .thenReturn(pr);

        AgenticReplenishmentService.ApproveResult r = service.approve(suggestionId, null);

        assertEquals(AgenticReplenishmentService.DOC_TYPE_PR, r.docType());
        assertEquals(pr.getId(), r.createdDocId());
        assertEquals("PR-00007", r.createdDocNumber());

        ArgumentCaptor<List> linesCap = ArgumentCaptor.forClass(List.class);
        verify(supplyChainService).createRequisition(isNull(), isNull(), any(), anyString(), linesCap.capture());
        @SuppressWarnings("unchecked")
        List<SupplyChainService.RequisitionLineRequest> lines = linesCap.getValue();
        assertEquals(1, lines.size());
        assertEquals(itemId, lines.get(0).itemId());
        assertEquals(0, lines.get(0).requiredQty().compareTo(new BigDecimal("120")));

        // Suggestion marked ACCEPTED with the requisition id stored.
        ArgumentCaptor<AiSuggestion> savedCap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(savedCap.capture());
        assertEquals("ACCEPTED", savedCap.getValue().getStatus());
    }

    @Test
    void approve_purchaseOrder_drafsPoWhenSupplierPresent() {
        UUID supplierId = UUID.randomUUID();
        UUID suggestionId = UUID.randomUUID();
        AiSuggestion sug = openSuggestion(suggestionId, supplierId);
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(sug));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(goodsItem(new BigDecimal("100"), new BigDecimal("50"))));
        PurchaseOrderResponse poResp = mock(PurchaseOrderResponse.class);
        UUID poId = UUID.randomUUID();
        when(poResp.id()).thenReturn(poId);
        when(poResp.poNumber()).thenReturn("PO-0042");
        when(purchaseOrderService.create(any(PurchaseOrderRequest.class))).thenReturn(poResp);

        AgenticReplenishmentService.ApproveResult r = service.approve(suggestionId, "PURCHASE_ORDER");

        assertEquals(AgenticReplenishmentService.DOC_TYPE_PO, r.docType());
        assertEquals(poId, r.createdDocId());

        ArgumentCaptor<PurchaseOrderRequest> reqCap = ArgumentCaptor.forClass(PurchaseOrderRequest.class);
        verify(purchaseOrderService).create(reqCap.capture());
        assertEquals(supplierId, reqCap.getValue().supplierId());
        assertEquals(1, reqCap.getValue().lines().size());
        assertEquals(itemId, reqCap.getValue().lines().get(0).itemId());
    }

    @Test
    void approve_purchaseOrder_withoutSupplier_throws() {
        UUID suggestionId = UUID.randomUUID();
        AiSuggestion sug = openSuggestion(suggestionId, /*supplierId=*/null);
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(sug));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approve(suggestionId, "PURCHASE_ORDER"));
        assertEquals("AGENTIC_PO_NO_SUPPLIER", ex.getErrorCode());
        verify(purchaseOrderService, never()).create(any());
    }

    @Test
    void reject_marksSuggestionRejected_noDocCreated() {
        UUID suggestionId = UUID.randomUUID();
        AiSuggestion sug = openSuggestion(suggestionId, null);
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(sug));

        service.reject(suggestionId, "Not needed this month");

        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionRepository).save(cap.capture());
        assertEquals("REJECTED", cap.getValue().getStatus());
        assertEquals("Not needed this month", cap.getValue().getCorrectionReason());
        verifyNoInteractions(supplyChainService);
        verifyNoInteractions(purchaseOrderService);
    }

    @Test
    void disabled_setting_runsZeroAndDoesNotScan() {
        when(orgSettingsService.get(orgId, AgenticReplenishmentService.SETTING_ENABLED, "false"))
                .thenReturn("false");

        int created = service.runForOrg();

        assertEquals(0, created);
        // The agent must short-circuit without ever scanning stock_balance.
        verify(stockBalanceRepository, never()).findLowStock(any());
    }

    // ── helpers ───────────────────────────────────────────────────────

    private Item goodsItem(BigDecimal reorderLevel, BigDecimal reorderQty) {
        Item item = Item.builder().build();
        item.setId(itemId);
        item.setOrgId(orgId);
        item.setName("Paracetamol 500mg");
        item.setSku("PARA-500");
        item.setItemType(ItemType.GOODS);
        item.setTrackInventory(true);
        item.setActive(true);
        item.setReorderLevel(reorderLevel);
        item.setReorderQuantity(reorderQty);
        item.setPurchasePrice(new BigDecimal("12.50"));
        item.setUnitOfMeasure("STRIP");
        return item;
    }

    private void stubItem(Item item) {
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item));
    }

    private void stubLowStock(BigDecimal onHand) {
        StockBalance sb = StockBalance.builder()
                .orgId(orgId).itemId(itemId).warehouseId(UUID.randomUUID())
                .quantityOnHand(onHand).build();
        when(stockBalanceRepository.findLowStock(orgId)).thenReturn(List.of(sb));
        // The agent now re-fetches every balance for the low-flagged items and
        // sums across warehouses. For single-warehouse test fixtures the
        // aggregate equals the low-row's on-hand.
        when(stockBalanceRepository.findByOrgIdAndItemIdIn(eq(orgId), any()))
                .thenReturn(List.of(sb));
    }

    private UUID stubItemSupplier() {
        UUID supplierId = UUID.randomUUID();
        ItemSupplier is = ItemSupplier.builder()
                .itemId(itemId).supplierId(supplierId).preferred(true).build();
        when(itemSupplierRepository
                .findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, itemId))
                .thenReturn(Optional.of(is));
        return supplierId;
    }

    private AiSuggestion openSuggestion(UUID id, UUID supplierId) {
        java.util.LinkedHashMap<String, Object> value = new java.util.LinkedHashMap<>();
        value.put("itemId", itemId);
        value.put("itemName", "Paracetamol");
        value.put("suggestedQty", new BigDecimal("120"));
        value.put("preferredSupplierId", supplierId);
        AiSuggestion s = AiSuggestion.builder()
                .id(id)
                .orgId(orgId)
                .entityType(AgenticReplenishmentService.ENTITY_TYPE)
                .entityId(itemId)
                .suggestionType(AgenticReplenishmentService.SUGGESTION_TYPE)
                .suggestedValue(value)
                .status("PENDING")
                .priority("MEDIUM")
                .build();
        return s;
    }
}
