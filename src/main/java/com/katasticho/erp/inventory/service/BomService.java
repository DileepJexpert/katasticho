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
        if (child.getItemType() == ItemType.COMPOSITE) {
            // v1: nested BOMs not supported. The explosion path assumes
            // one level and would need cycle detection + recursion to
            // safely traverse more.
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
     * Return every live BOM row for {@code parentItemId} in this tenant.
     * Called from {@link InventoryService#deductStockForInvoice} and the
     * credit-note restore path once per composite invoice line; the v1
     * single-level constraint means we return the rows as-is and the
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
        return bomRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);
    }
}
