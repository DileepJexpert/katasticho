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
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import com.katasticho.erp.procurement.service.PurchaseOrderService;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.supplychain.entity.ItemSupplier;
import com.katasticho.erp.supplychain.entity.PurchaseRequisition;
import com.katasticho.erp.supplychain.repository.ItemSupplierRepository;
import com.katasticho.erp.supplychain.repository.PurchaseRequisitionRepository;
import com.katasticho.erp.supplychain.service.SupplyChainService;
import com.katasticho.erp.supplychain.service.SupplyChainService.RequisitionLineRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Advisory agentic replenishment: when stock dips below reorder level for a
 * non-composite item, draft a Purchase Requisition (or Purchase Order on the
 * approver's choice) as an AI Inbox suggestion. The human is the only path
 * to posting a real document — nothing here ever bypasses approval.
 *
 * <p>Composites belong to the existing manufacturing auto-WO sweep
 * ({@code ManufacturingService.autoCreateWorkOrdersFromReorder}); this
 * service only scans non-composite items, so the two sweeps complement
 * without overlap.
 *
 * <p>Idempotency: one open {@code AGENTIC_REPLENISHMENT} suggestion per item.
 * Items that already have an open WO / PO / PR for the same item are skipped
 * so the inbox doesn't pile up suggestions on top of in-flight procurement.
 *
 * <p>Opt-in: gated by org setting {@code replenishment.agent.enabled}
 * (default {@code false}). A new org must consciously turn this on.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AgenticReplenishmentService {

    public static final String ENTITY_TYPE = "ITEM";
    public static final String SUGGESTION_TYPE = "AGENTIC_REPLENISHMENT";
    public static final String AGENT_NAME = "replenishment_agent";
    public static final String DOC_TYPE_PR = "PURCHASE_REQUISITION";
    public static final String DOC_TYPE_PO = "PURCHASE_ORDER";

    static final String SETTING_ENABLED = "replenishment.agent.enabled";

    private static final List<String> OPEN_SUGGESTION_STATUSES = List.of("PENDING", "DEFERRED");
    private static final List<String> OPEN_WO_STATUSES = List.of("DRAFT", "PENDING_APPROVAL", "IN_PROGRESS");
    private static final List<String> OPEN_PR_STATUSES = List.of("DRAFT", "SUBMITTED", "APPROVED");
    private static final List<String> OPEN_PO_STATUSES = List.of("DRAFT", "SENT");

    private final StockBalanceRepository stockBalanceRepository;
    private final ItemRepository itemRepository;
    private final ItemSupplierRepository itemSupplierRepository;
    private final SupplierRepository supplierRepository;
    private final WorkOrderRepository workOrderRepository;
    private final PurchaseOrderRepository purchaseOrderRepository;
    private final PurchaseRequisitionRepository purchaseRequisitionRepository;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final OrgSettingsService orgSettingsService;
    @Lazy private final SupplyChainService supplyChainService;
    @Lazy private final PurchaseOrderService purchaseOrderService;

    /**
     * Scan low-stock non-composite items and draft AI Inbox suggestions for
     * the ones that don't already have open replenishment in flight.
     * Returns the count of NEW suggestions created.
     */
    @Transactional
    public int runForOrg() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (!isEnabled(orgId)) {
            log.debug("Agentic replenishment skipped for org {} (disabled)", orgId);
            return 0;
        }

        List<StockBalance> lowStock = stockBalanceRepository.findLowStock(orgId);
        if (lowStock.isEmpty()) return 0;

        // Aggregate deficit per item across warehouses — a multi-warehouse
        // shortfall is one replenishment decision, not N.
        Map<UUID, BigDecimal> deficitByItem = new LinkedHashMap<>();
        Map<UUID, BigDecimal> onHandByItem = new HashMap<>();
        for (StockBalance sb : lowStock) {
            deficitByItem.merge(sb.getItemId(), BigDecimal.ZERO, BigDecimal::add);
            onHandByItem.merge(sb.getItemId(), nullSafe(sb.getQuantityOnHand()), BigDecimal::add);
        }

        int created = 0;
        for (UUID itemId : deficitByItem.keySet()) {
            try {
                if (drafSuggestion(orgId, itemId, onHandByItem.get(itemId))) {
                    created++;
                }
            } catch (Exception ex) {
                // One bad item must not kill the sweep.
                log.warn("Replenishment suggestion failed for item {}: {}", itemId, ex.getMessage());
            }
        }
        log.info("Agentic replenishment for org {}: {} new suggestions", orgId, created);
        return created;
    }

    private boolean drafSuggestion(UUID orgId, UUID itemId, BigDecimal onHandTotal) {
        Optional<Item> opt = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId);
        if (opt.isEmpty()) return false;
        Item item = opt.get();
        if (!item.isTrackInventory() || !item.isActive()) return false;

        // Composites are handled by the manufacturing auto-WO sweep; never
        // draft a requisition for one.
        if (item.getItemType() == ItemType.COMPOSITE) return false;

        // Dedupe: open AGENTIC_REPLENISHMENT suggestion for the same item.
        if (aiSuggestionRepository.existsOpenSuggestion(
                orgId, ENTITY_TYPE, itemId, null, SUGGESTION_TYPE, OPEN_SUGGESTION_STATUSES)) {
            return false;
        }
        // Skip if a real replenishment is already in flight — WO / PO / PR.
        if (workOrderRepository.existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse(
                orgId, itemId, OPEN_WO_STATUSES)) {
            return false;
        }
        if (purchaseRequisitionRepository.existsOpenForItem(orgId, itemId, OPEN_PR_STATUSES)) {
            return false;
        }
        if (purchaseOrderRepository.existsOpenForItem(orgId, itemId, OPEN_PO_STATUSES)) {
            return false;
        }

        BigDecimal reorderLevel = nullSafe(item.getReorderLevel());
        BigDecimal reorderQty = nullSafe(item.getReorderQuantity());
        BigDecimal suggestedQty = reorderQty.signum() > 0
                ? reorderQty.add(reorderLevel.subtract(onHandTotal).max(BigDecimal.ZERO))
                : reorderLevel.subtract(onHandTotal).max(BigDecimal.ONE);

        // Severity: shortfall > 50% of reorder level → HIGH priority.
        BigDecimal shortfall = reorderLevel.subtract(onHandTotal).max(BigDecimal.ZERO);
        boolean high = reorderLevel.signum() > 0
                && shortfall.multiply(new BigDecimal("2")).compareTo(reorderLevel) > 0;

        ItemSupplier preferred = itemSupplierRepository
                .findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, itemId)
                .orElse(null);
        UUID preferredSupplierId = preferred != null ? preferred.getSupplierId() : null;
        String preferredSupplierName = null;
        if (preferredSupplierId != null) {
            preferredSupplierName = supplierRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(preferredSupplierId, orgId)
                    .map(Supplier::getName)
                    .orElse(null);
        }

        Map<String, Object> value = new LinkedHashMap<>();
        value.put("itemId", itemId);
        value.put("itemName", item.getName());
        value.put("itemSku", item.getSku());
        value.put("onHand", onHandTotal);
        value.put("reorderLevel", reorderLevel);
        value.put("suggestedQty", suggestedQty);
        value.put("preferredSupplierId", preferredSupplierId);
        value.put("preferredSupplierName", preferredSupplierName);
        value.put("suggestedDocType", DOC_TYPE_PR);

        String reasoning = "Stock " + onHandTotal + " "
                + (item.getUnitOfMeasure() == null ? "" : item.getUnitOfMeasure())
                + " is at/below the reorder level " + reorderLevel + ". "
                + "Suggested replenishment qty: " + suggestedQty
                + (preferredSupplierName != null
                    ? " (preferred supplier: " + preferredSupplierName + ")."
                    : " (no preferred supplier — choose at approval).");

        aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(orgId)
                .entityType(ENTITY_TYPE)
                .entityId(itemId)
                .suggestionType(SUGGESTION_TYPE)
                .suggestedAction("REVIEW_AND_POST_PURCHASE_REQUISITION")
                .suggestedValue(value)
                .reasoning(reasoning)
                .agentName(AGENT_NAME)
                .modelName("rule_based")
                .modelVersion("1")
                .priority(high ? "HIGH" : "MEDIUM")
                .priorityScore(high ? new BigDecimal("75") : new BigDecimal("45"))
                .status("PENDING")
                .build());
        return true;
    }

    // ── Approve / reject ────────────────────────────────────────────────

    /**
     * Approve a drafted replenishment — drafts a real {@link PurchaseRequisition}
     * (default) or a DRAFT {@link com.katasticho.erp.procurement.entity.PurchaseOrder}
     * when the caller picks PO. The drafted document still moves through the
     * existing approval flow; this method does not bypass it.
     */
    @Transactional
    public ApproveResult approve(UUID suggestionId, String requestedDocType) {
        UUID orgId = TenantContext.getCurrentOrgId();
        AiSuggestion suggestion = aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("AiSuggestion", suggestionId));
        if (!SUGGESTION_TYPE.equals(suggestion.getSuggestionType())) {
            throw new BusinessException(
                    "Suggestion is not an agentic replenishment draft",
                    "AI_NOT_AGENTIC_REPLENISHMENT", HttpStatus.BAD_REQUEST);
        }
        if (!"PENDING".equals(suggestion.getStatus()) && !"DEFERRED".equals(suggestion.getStatus())) {
            throw new BusinessException(
                    "Suggestion already reviewed", "AI_SUGGESTION_NOT_OPEN", HttpStatus.BAD_REQUEST);
        }
        Map<String, Object> v = suggestion.getSuggestedValue();
        UUID itemId = parseUuid(v.get("itemId"));
        BigDecimal qty = parseBigDecimal(v.get("suggestedQty"));
        UUID supplierId = parseUuid(v.get("preferredSupplierId"));

        String docType = requestedDocType == null || requestedDocType.isBlank()
                ? DOC_TYPE_PR
                : requestedDocType.trim().toUpperCase();

        Map<String, Object> reviewed = new LinkedHashMap<>(v);
        reviewed.put("docType", docType);

        UUID createdDocId;
        String createdDocNumber;
        if (DOC_TYPE_PO.equals(docType)) {
            if (supplierId == null) {
                throw new BusinessException(
                        "Cannot draft PO without a preferred supplier; create a PR instead",
                        "AGENTIC_PO_NO_SUPPLIER", HttpStatus.BAD_REQUEST);
            }
            PurchaseOrderResponse po = purchaseOrderService.create(buildPoRequest(itemId, qty, supplierId, v));
            createdDocId = po.id();
            createdDocNumber = po.poNumber();
            reviewed.put("purchaseOrderId", createdDocId);
            reviewed.put("purchaseOrderNumber", createdDocNumber);
        } else {
            PurchaseRequisition pr = supplyChainService.createRequisition(
                    supplierId,
                    null,
                    LocalDate.now().plusDays(7),
                    "Drafted by replenishment agent — review supplier + qty before submitting",
                    List.of(new RequisitionLineRequest(itemId, qty, getUnitPrice(orgId, itemId))));
            createdDocId = pr.getId();
            createdDocNumber = pr.getRequisitionNumber();
            reviewed.put("requisitionId", createdDocId);
            reviewed.put("requisitionNumber", createdDocNumber);
        }

        suggestion.setStatus("ACCEPTED");
        suggestion.setReviewAction("ACCEPT");
        suggestion.setReviewedValue(reviewed);
        suggestion.setReviewedBy(TenantContext.getCurrentUserId());
        suggestion.setReviewedAt(java.time.Instant.now());
        aiSuggestionRepository.save(suggestion);

        return new ApproveResult(suggestionId, docType, createdDocId, createdDocNumber);
    }

    /** Reject a drafted replenishment — no document created. */
    @Transactional
    public void reject(UUID suggestionId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        AiSuggestion suggestion = aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("AiSuggestion", suggestionId));
        if (!SUGGESTION_TYPE.equals(suggestion.getSuggestionType())) {
            throw new BusinessException(
                    "Suggestion is not an agentic replenishment draft",
                    "AI_NOT_AGENTIC_REPLENISHMENT", HttpStatus.BAD_REQUEST);
        }
        suggestion.setStatus("REJECTED");
        suggestion.setReviewAction("REJECT");
        suggestion.setCorrectionReason(reason);
        suggestion.setReviewedBy(TenantContext.getCurrentUserId());
        suggestion.setReviewedAt(java.time.Instant.now());
        aiSuggestionRepository.save(suggestion);
    }

    // ── helpers ───────────────────────────────────────────────────────────

    boolean isEnabled(UUID orgId) {
        return "true".equalsIgnoreCase(orgSettingsService.get(orgId, SETTING_ENABLED, "false"));
    }

    private PurchaseOrderRequest buildPoRequest(UUID itemId, BigDecimal qty, UUID supplierId,
                                                Map<String, Object> v) {
        BigDecimal unitPrice = parseBigDecimal(v.get("unitPrice"));
        if (unitPrice == null || unitPrice.signum() <= 0) {
            unitPrice = getUnitPrice(TenantContext.getCurrentOrgId(), itemId);
        }
        var line = new PurchaseOrderRequest.LineRequest(
                itemId, null, qty, unitPrice, null);
        return new PurchaseOrderRequest(
                supplierId,
                LocalDate.now(),
                LocalDate.now().plusDays(7),
                "Drafted by replenishment agent — review before sending",
                null,
                List.of(line));
    }

    private BigDecimal getUnitPrice(UUID orgId, UUID itemId) {
        return itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .map(Item::getPurchasePrice)
                .filter(p -> p.signum() > 0)
                .orElse(BigDecimal.ONE);
    }

    private static BigDecimal nullSafe(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static UUID parseUuid(Object v) {
        if (v == null) return null;
        if (v instanceof UUID u) return u;
        try {
            return UUID.fromString(v.toString());
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private static BigDecimal parseBigDecimal(Object v) {
        if (v == null) return null;
        if (v instanceof BigDecimal b) return b;
        if (v instanceof Number n) return new BigDecimal(n.toString());
        try {
            return new BigDecimal(v.toString());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    public record ApproveResult(
            UUID suggestionId, String docType, UUID createdDocId, String createdDocNumber) {}
}
