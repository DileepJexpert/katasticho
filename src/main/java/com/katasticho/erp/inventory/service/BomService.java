package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.BomComponentRequest;
import com.katasticho.erp.inventory.dto.BomComponentResponse;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Bill of Materials lifecycle for composite items. CRUD over {@code
 * bom_component} plus the {@link #explode} read used by the
 * invoice/credit-note hot paths in {@link InventoryService}.
 *
 * <p><b>v1 constraints enforced here:</b>
 * <ul>
 *   <li>Parent must have {@code itemType = COMPOSITE}. You can't attach
 *       children to a plain GOODS item — the explosion path would never
 *       see them anyway, so we fail loud at save time.</li>
 *   <li>Child must NOT be another COMPOSITE. v1 supports only one
 *       level of assembly; allowing nesting would force the explosion
 *       path to recurse (and guard against cycles), which is not in
 *       scope for this sprint.</li>
 *   <li>Child must NOT be batch-tracked. Credit-note restore of a
 *       composite has no per-child {@code batchId} to thread through
 *       the inventory gate, and auto-picking on restore would
 *       silently corrupt FEFO history. v1 keeps composites simple;
 *       batch-tracked kits land in v2.</li>
 *   <li>Parent ≠ child. A DB check constraint backs this up but the
 *       service catches it first for a better error message.</li>
 *   <li>Quantity must be strictly positive.</li>
 * </ul>
 *
 * <p>Soft-delete is idempotent: the {@link #deleteComponent} path
 * tolerates concurrent removals without blowing up.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BomService {

    private final BomComponentRepository bomRepository;
    private final ItemRepository itemRepository;

    // ────────────────────────────────────────────────────────────────────
    // CRUD
    // ────────────────────────────────────────────────────────────────────

    @Transactional
    public BomComponent addComponent(UUID parentItemId, BomComponentRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item parent = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", parentItemId));
        if (parent.getItemType() != ItemType.COMPOSITE) {
            throw new BusinessException(
                    "Item " + parent.getSku() + " is not a COMPOSITE — cannot add BOM components",
                    "BOM_PARENT_NOT_COMPOSITE", HttpStatus.BAD_REQUEST);
        }

        if (request.childItemId().equals(parentItemId)) {
            throw new BusinessException(
                    "A composite item cannot list itself as a child",
                    "BOM_SELF_REFERENCE", HttpStatus.BAD_REQUEST);
        }

        Item child = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(request.childItemId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", request.childItemId()));
        if (child.getItemType() == ItemType.COMPOSITE && !child.isPhantom()) {
            // Nested STOCKED composites are still not supported — the
            // explosion path only recurses through PHANTOM composites
            // (which are flattened with cycle detection in explode()).
            throw new BusinessException(
                    "Child " + child.getSku() + " is itself a composite — nested BOMs are not supported in this release",
                    "BOM_NESTED_NOT_SUPPORTED", HttpStatus.BAD_REQUEST);
        }
        if (child.isTrackBatches()) {
            // v1: batch-tracked children aren't supported in a BOM.
            // Credit-note restore of a composite would need to know
            // which batch the returned child came from, and there's
            // no per-child batch column on a composite invoice line.
            // See the class javadoc for the full rationale.
            throw new BusinessException(
                    "Child " + child.getSku() + " is batch-tracked — batch-tracked children are not supported in a BOM in this release",
                    "BOM_BATCH_CHILD_NOT_SUPPORTED", HttpStatus.BAD_REQUEST);
        }

        BigDecimal qty = request.quantity();
        if (qty == null || qty.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(
                    "BOM component quantity must be positive",
                    "BOM_QUANTITY_INVALID", HttpStatus.BAD_REQUEST);
        }

        BigDecimal scrapPercent = request.scrapPercent() != null
                ? request.scrapPercent() : BigDecimal.ZERO;
        if (scrapPercent.compareTo(BigDecimal.ZERO) < 0
                || scrapPercent.compareTo(BigDecimal.valueOf(100)) >= 0) {
            throw new BusinessException(
                    "BOM scrap percent must be between 0 and 99.99",
                    "BOM_SCRAP_PERCENT_INVALID", HttpStatus.BAD_REQUEST);
        }

        if (bomRepository.existsByOrgIdAndParentItemIdAndChildItemIdAndIsDeletedFalse(
                orgId, parentItemId, request.childItemId())) {
            throw new BusinessException(
                    "Child " + child.getSku() + " is already part of this BOM — edit its quantity instead",
                    "BOM_DUPLICATE_CHILD", HttpStatus.CONFLICT);
        }

        BomComponent row = BomComponent.builder()
                .parentItemId(parentItemId)
                .childItemId(request.childItemId())
                .quantity(qty)
                .scrapPercent(scrapPercent)
                .build();

        BomComponent saved = bomRepository.save(row);
        log.info("BOM: added child {} ×{} to parent {}", child.getSku(), qty, parent.getSku());
        return saved;
    }

    @Transactional(readOnly = true)
    public List<BomComponent> listComponents(UUID parentItemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // Tenant + existence check — raises 404 if the parent doesn't
        // belong to this org.
        itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", parentItemId));
        return bomRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);
    }

    /**
     * Same as {@link #listComponents} but batches a second lookup
     * against {@code item} so the response carries each child's SKU +
     * name — the Flutter item-detail screen needs it to render "2 ×
     * WIDGET-BLUE" without an N+1 fetch.
     */
    @Transactional(readOnly = true)
    public List<BomComponentResponse> listComponentsEnriched(UUID parentItemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", parentItemId));

        List<BomComponent> rows = bomRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);
        if (rows.isEmpty()) {
            return List.of();
        }

        Set<UUID> childIds = rows.stream()
                .map(BomComponent::getChildItemId)
                .collect(Collectors.toSet());
        Map<UUID, Item> byId = itemRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, childIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, i -> i));

        return rows.stream()
                .map(row -> {
                    Item child = byId.get(row.getChildItemId());
                    String sku = child != null ? child.getSku() : null;
                    String name = child != null ? child.getName() : null;
                    return BomComponentResponse.from(row, sku, name);
                })
                .toList();
    }

    @Transactional
    public void deleteComponent(UUID componentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BomComponent row = bomRepository.findByIdAndOrgIdAndIsDeletedFalse(componentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("BomComponent", componentId));
        row.setDeleted(true);
        bomRepository.save(row);
    }

    // ────────────────────────────────────────────────────────────────────
    // Explosion — the invoice/credit-note hot path
    // ────────────────────────────────────────────────────────────────────

    /**
     * Return every live BOM row for {@code parentItemId} in this tenant,
     * with PHANTOM composite children flattened through: a child that is
     * COMPOSITE + {@code isPhantom} is replaced by its own components,
     * each scaled by the phantom line's quantity (recursively, with
     * cycle detection). Non-phantom BOMs return the repository rows
     * untouched — the original v1 hot path.
     *
     * <p>Called from {@link InventoryService#deductStockForInvoice} and
     * the credit-note restore path once per composite invoice line; the
     * caller multiplies each row's {@code quantity} by the invoice-line
     * quantity to get the absolute number of child units to move.
     *
     * <p>Read-only and joins the caller's transaction. Returns an empty
     * list if the parent has no children — the caller decides whether
     * that's a data-quality warning or an error (invoice send treats
     * "empty BOM" as "nothing to deduct" and logs loud).
     */
    @Transactional(readOnly = true)
    public List<BomComponent> explode(UUID orgId, UUID parentItemId) {
        List<BomComponent> out = new java.util.ArrayList<>();
        Set<UUID> visiting = new java.util.HashSet<>();
        visiting.add(parentItemId);
        flatten(orgId, parentItemId, parentItemId, BigDecimal.ONE, visiting, out);
        return out;
    }

    /**
     * Depth-first flattening. {@code multiplier} carries the product of
     * phantom line quantities from the root down to this level; rows at
     * multiplier 1 (the common no-phantom case) are returned as-is so
     * the behaviour for existing BOMs is byte-for-byte unchanged.
     * Flattened rows are TRANSIENT copies re-parented onto the root so
     * callers see a single-level list, exactly like v1.
     */
    private void flatten(UUID orgId, UUID rootParentId, UUID parentItemId,
                         BigDecimal multiplier, Set<UUID> visiting, List<BomComponent> out) {
        List<BomComponent> rows = bomRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);
        for (BomComponent row : rows) {
            Item child = itemRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(row.getChildItemId(), orgId)
                    .orElse(null);
            if (child != null && child.getItemType() == ItemType.COMPOSITE && child.isPhantom()) {
                if (!visiting.add(child.getId())) {
                    throw new BusinessException(
                            "Phantom BOM cycle detected at item " + child.getSku(),
                            "BOM_PHANTOM_CYCLE", HttpStatus.CONFLICT);
                }
                flatten(orgId, rootParentId, child.getId(),
                        multiplier.multiply(row.getQuantity()), visiting, out);
                visiting.remove(child.getId());
            } else if (BigDecimal.ONE.compareTo(multiplier) == 0) {
                out.add(row);
            } else {
                BomComponent flat = BomComponent.builder()
                        .parentItemId(rootParentId)
                        .childItemId(row.getChildItemId())
                        .quantity(row.getQuantity().multiply(multiplier)
                                .setScale(4, java.math.RoundingMode.HALF_UP))
                        .scrapPercent(row.getScrapPercent())
                        .build();
                flat.setId(row.getId());
                flat.setOrgId(orgId);
                out.add(flat);
            }
        }
    }
}
