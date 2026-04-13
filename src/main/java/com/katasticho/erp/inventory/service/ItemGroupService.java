package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.dto.GenerateVariantsRequest;
import com.katasticho.erp.inventory.dto.GenerateVariantsResponse;
import com.katasticho.erp.inventory.dto.ItemGroupRequest;
import com.katasticho.erp.inventory.dto.ItemGroupResponse;
import com.katasticho.erp.inventory.dto.ItemResponse;
import com.katasticho.erp.inventory.entity.AttributeDefinition;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemGroup;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.ItemGroupRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

/**
 * Lifecycle for {@link ItemGroup} — variant template CRUD plus the
 * matrix bulk-create that mints child {@link Item} rows in one call.
 *
 * <p><b>Attribute validation</b> is the gatekeeper. Every variant
 * (whether created via single-item POST or via {@link #generateVariants})
 * must have a {@code variant_attributes} map whose keys are a subset
 * of the group's {@link AttributeDefinition} keys and whose values are
 * each in their key's allowed list. Without this rule the JSONB bag
 * degenerates into "size/Size/SIZE" and "color/colour" typos that
 * make the picker unusable.
 *
 * <p><b>One-shot inheritance</b> happens in {@link #applyDefaults},
 * called from {@link ItemService#createItem} when a {@code groupId} is
 * present. Missing fields (HSN, GST, UoM, purchase/sale price) inherit
 * from the group; explicit values on the request always win. Once
 * persisted the item is self-contained — later edits to the group do
 * NOT cascade back, because invoice and report reproducibility require
 * historical items to stay frozen.
 *
 * <p>This service is intentionally thin on side effects: no stock
 * movements, no audit log churn beyond create/update/delete on the
 * group itself. The matrix generator delegates each child create to
 * {@link ItemService#createItem} so the inheritance path, audit log,
 * and SKU dedupe checks all stay in one place.
 */
@Service
@Slf4j
public class ItemGroupService {

    private final ItemGroupRepository groupRepository;
    private final ItemRepository itemRepository;
    private final AuditService auditService;

    /**
     * {@link ItemService} depends on this service for the inheritance
     * helper and we depend on it for the matrix generator's per-child
     * create. The lazy proxy breaks the cycle without requiring a
     * setter or a separate "creator" component.
     *
     * <p>Constructor is written by hand (not via Lombok's
     * {@code @RequiredArgsConstructor}) because Lombok drops field-
     * level annotations when generating the constructor, so the
     * {@code @Lazy} must sit directly on the constructor parameter
     * for Spring to honour it.
     */
    private final ItemService itemService;

    public ItemGroupService(ItemGroupRepository groupRepository,
                            ItemRepository itemRepository,
                            AuditService auditService,
                            @Lazy ItemService itemService) {
        this.groupRepository = groupRepository;
        this.itemRepository = itemRepository;
        this.auditService = auditService;
        this.itemService = itemService;
    }

    // ────────────────────────────────────────────────────────────────────
    // CRUD
    // ────────────────────────────────────────────────────────────────────

    @Transactional
    public ItemGroupResponse createGroup(ItemGroupRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String name = request.name().trim();
        if (groupRepository.existsByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, name)) {
            throw new BusinessException(
                    "Item group with name '" + name + "' already exists",
                    "GROUP_DUPLICATE_NAME", HttpStatus.CONFLICT);
        }

        List<AttributeDefinition> defs = sanitiseDefinitions(request.attributeDefinitions());

        ItemGroup group = ItemGroup.builder()
                .name(name)
                .description(request.description())
                .skuPrefix(blankToNull(request.skuPrefix()))
                .hsnCode(blankToNull(request.hsnCode()))
                .gstRate(request.gstRate())
                .defaultUom(blankToNull(request.defaultUom()))
                .defaultPurchasePrice(request.defaultPurchasePrice())
                .defaultSalePrice(request.defaultSalePrice())
                .attributeDefinitions(defs)
                .build();

        group = groupRepository.save(group);
        auditService.log("ITEM_GROUP", group.getId(), "CREATE", null,
                "{\"name\":\"" + group.getName() + "\"}");
        log.info("Item group {} created", group.getName());
        return ItemGroupResponse.from(group, 0);
    }

    @Transactional
    public ItemGroupResponse updateGroup(UUID id, ItemGroupRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemGroup group = groupRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemGroup", id));

        String newName = request.name().trim();
        if (!newName.equalsIgnoreCase(group.getName())
                && groupRepository.existsByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, newName)) {
            throw new BusinessException(
                    "Item group with name '" + newName + "' already exists",
                    "GROUP_DUPLICATE_NAME", HttpStatus.CONFLICT);
        }

        // Detect attribute-definition changes that would orphan
        // existing variants. If a key is dropped or a value is removed
        // and any live variant uses it, refuse the update — the operator
        // would otherwise get into a state where existing variants no
        // longer match their own group's schema and the picker shows
        // them in a "broken" state.
        List<AttributeDefinition> newDefs = sanitiseDefinitions(request.attributeDefinitions());
        validateDefinitionsAgainstExistingVariants(orgId, group, newDefs);

        group.setName(newName);
        group.setDescription(request.description());
        group.setSkuPrefix(blankToNull(request.skuPrefix()));
        group.setHsnCode(blankToNull(request.hsnCode()));
        group.setGstRate(request.gstRate());
        group.setDefaultUom(blankToNull(request.defaultUom()));
        group.setDefaultPurchasePrice(request.defaultPurchasePrice());
        group.setDefaultSalePrice(request.defaultSalePrice());
        group.setAttributeDefinitions(newDefs);

        group = groupRepository.save(group);
        auditService.log("ITEM_GROUP", group.getId(), "UPDATE", null, null);

        int variantCount = itemRepository
                .findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, group.getId())
                .size();
        return ItemGroupResponse.from(group, variantCount);
    }

    @Transactional
    public void deleteGroup(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemGroup group = groupRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemGroup", id));

        if (itemRepository.existsByOrgIdAndGroupIdAndIsDeletedFalse(orgId, id)) {
            throw new BusinessException(
                    "Cannot delete group '" + group.getName() + "' — it still has live variants. Delete them first.",
                    "GROUP_HAS_CHILDREN", HttpStatus.CONFLICT);
        }

        group.setDeleted(true);
        groupRepository.save(group);
        auditService.log("ITEM_GROUP", id, "DELETE", null, null);
    }

    @Transactional(readOnly = true)
    public ItemGroupResponse getGroup(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemGroup group = groupRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemGroup", id));
        int count = itemRepository
                .findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, id)
                .size();
        return ItemGroupResponse.from(group, count);
    }

    @Transactional(readOnly = true)
    public Page<ItemGroupResponse> listGroups(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return groupRepository
                .findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId, pageable)
                .map(g -> ItemGroupResponse.from(
                        g,
                        itemRepository.findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, g.getId()).size()));
    }

    @Transactional(readOnly = true)
    public List<ItemResponse> listVariants(UUID groupId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // Tenant + existence check
        groupRepository.findByIdAndOrgIdAndIsDeletedFalse(groupId, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemGroup", groupId));
        return itemRepository
                .findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, groupId)
                .stream()
                .map(itemService::toResponse)
                .toList();
    }

    // ────────────────────────────────────────────────────────────────────
    // Attribute validation — used by ItemService at create time too
    // ────────────────────────────────────────────────────────────────────

    /**
     * Verify {@code attributes} satisfies the group's
     * {@link AttributeDefinition} list. Throws a {@link BusinessException}
     * with the appropriate errorCode on the first mismatch — the UI
     * surfaces these as friendly snackbars.
     *
     * <p>Empty maps are rejected here as well as at the DB CHECK level
     * so the service-layer error (with field context) wins the race
     * against the bare constraint violation from Postgres.
     */
    public void validateAttributes(ItemGroup group, Map<String, String> attributes) {
        if (attributes == null || attributes.isEmpty()) {
            throw new BusinessException(
                    "Variant attributes cannot be empty for an item in group '" + group.getName() + "'",
                    "GROUP_EMPTY_ATTRIBUTES", HttpStatus.BAD_REQUEST);
        }

        List<AttributeDefinition> defs = group.getAttributeDefinitions();
        if (defs == null || defs.isEmpty()) {
            throw new BusinessException(
                    "Group '" + group.getName() + "' has no attribute definitions yet — add at least one before creating variants",
                    "GROUP_NO_ATTRIBUTES_DEFINED", HttpStatus.BAD_REQUEST);
        }

        // Every key in the variant must exist in the group, and every
        // value must be in that key's allowed list. Keys missing from
        // the variant are tolerated — operators can ship "size only"
        // variants of a "size + color" group if they choose. The
        // partial unique index treats missing keys as distinct from
        // present-with-different-value, which is the natural reading.
        Map<String, Set<String>> byKey = new LinkedHashMap<>();
        for (AttributeDefinition def : defs) {
            byKey.put(def.key(), def.values() == null ? Set.of() : new HashSet<>(def.values()));
        }

        for (Map.Entry<String, String> e : attributes.entrySet()) {
            String key = e.getKey();
            String value = e.getValue();
            if (!byKey.containsKey(key)) {
                throw new BusinessException(
                        "Attribute '" + key + "' is not defined on group '" + group.getName() + "'",
                        "GROUP_INVALID_ATTRIBUTE", HttpStatus.BAD_REQUEST);
            }
            if (value == null || value.isBlank()) {
                throw new BusinessException(
                        "Attribute '" + key + "' has no value",
                        "GROUP_INVALID_VALUE", HttpStatus.BAD_REQUEST);
            }
            Set<String> allowed = byKey.get(key);
            if (!allowed.isEmpty() && !allowed.contains(value)) {
                throw new BusinessException(
                        "Attribute '" + key + "' value '" + value
                                + "' is not in the allowed list for group '" + group.getName() + "'",
                        "GROUP_INVALID_VALUE", HttpStatus.BAD_REQUEST);
            }
        }
    }

    /**
     * One-shot inheritance helper called from
     * {@link ItemService#createItem}. For every group default field,
     * if the request did not supply a value, copy the group's value
     * onto a fresh {@link CreateItemRequest}. Non-default fields
     * (name, sku, itemType, accounts, …) pass through untouched.
     *
     * <p>Returns a *new* request record; never mutates the input.
     */
    public CreateItemRequest applyDefaults(ItemGroup group, CreateItemRequest req) {
        return new CreateItemRequest(
                req.sku(),
                req.name(),
                req.description(),
                req.itemType(),
                req.category(),
                req.brand(),
                req.hsnCode() != null ? req.hsnCode() : group.getHsnCode(),
                req.unitOfMeasure() != null ? req.unitOfMeasure() : group.getDefaultUom(),
                req.purchasePrice() != null ? req.purchasePrice() : group.getDefaultPurchasePrice(),
                req.salePrice() != null ? req.salePrice() : group.getDefaultSalePrice(),
                req.mrp(),
                req.gstRate() != null ? req.gstRate() : group.getGstRate(),
                req.trackInventory(),
                req.trackBatches(),
                req.reorderLevel(),
                req.reorderQuantity(),
                req.revenueAccountCode(),
                req.cogsAccountCode(),
                req.inventoryAccountCode(),
                req.openingStock(),
                req.openingWarehouseId(),
                req.groupId(),
                req.variantAttributes()
        );
    }

    /**
     * Tenant-scoped lookup used by {@link ItemService} when it sees a
     * {@code groupId} on an item create request. Throws 404 if the
     * group doesn't exist or belongs to another tenant.
     */
    @Transactional(readOnly = true)
    public ItemGroup loadForCreate(UUID groupId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return groupRepository.findByIdAndOrgIdAndIsDeletedFalse(groupId, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemGroup", groupId));
    }

    // ────────────────────────────────────────────────────────────────────
    // Matrix bulk-create
    // ────────────────────────────────────────────────────────────────────

    /**
     * Mint up to N variant items in one call. Each combination becomes
     * a single child item via {@link ItemService#createItem} so the
     * audit log, SKU dedupe, and inheritance path are all reused.
     *
     * <p>The endpoint is idempotent: combinations that already exist
     * as live variants are skipped (and reported in
     * {@link GenerateVariantsResponse#skippedReasons}). This lets the
     * operator re-run after a partial failure without having to
     * deselect already-created cells in the UI.
     */
    @Transactional
    public GenerateVariantsResponse generateVariants(UUID groupId, GenerateVariantsRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemGroup group = groupRepository.findByIdAndOrgIdAndIsDeletedFalse(groupId, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemGroup", groupId));

        if (group.getAttributeDefinitions() == null || group.getAttributeDefinitions().isEmpty()) {
            throw new BusinessException(
                    "Group '" + group.getName() + "' has no attribute definitions — add at least one before generating variants",
                    "GROUP_NO_ATTRIBUTES_DEFINED", HttpStatus.BAD_REQUEST);
        }
        if (group.getSkuPrefix() == null || group.getSkuPrefix().isBlank()) {
            // The matrix path mints SKUs automatically; without a
            // prefix there is no sane way to do that. Single-variant
            // create still works because the operator types the SKU.
            throw new BusinessException(
                    "Group '" + group.getName() + "' needs a SKU prefix before bulk variant generation",
                    "GROUP_NO_SKU_PREFIX", HttpStatus.BAD_REQUEST);
        }

        List<Item> existing = itemRepository
                .findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, group.getId());
        // Index existing variants by their attribute map so we can
        // detect duplicates before paying the cost of a per-row save.
        Set<Map<String, String>> existingCombos = new HashSet<>();
        Set<String> existingSkus = new HashSet<>();
        for (Item v : existing) {
            existingCombos.add(v.getVariantAttributes());
            existingSkus.add(v.getSku());
        }

        List<ItemResponse> created = new ArrayList<>();
        List<String> skipped = new ArrayList<>();

        for (Map<String, String> combo : request.combinations()) {
            // Validate the combo against the group definitions BEFORE
            // touching the DB — we want the whole batch to fail-fast on
            // the first bad input rather than half-create and bail.
            try {
                validateAttributes(group, combo);
            } catch (BusinessException ex) {
                throw new BusinessException(
                        "Combination " + combo + ": " + ex.getMessage(),
                        ex.getErrorCode(), HttpStatus.BAD_REQUEST);
            }

            if (existingCombos.contains(combo)) {
                skipped.add(combo + " — already exists");
                continue;
            }

            String childSku = mintSku(group, combo);
            // De-dupe against existing siblings AND against earlier
            // iterations of this same loop (a duplicate combo in the
            // request would otherwise mint the same SKU twice).
            if (existingSkus.contains(childSku)) {
                skipped.add(combo + " — SKU " + childSku + " already in use");
                continue;
            }
            existingSkus.add(childSku);

            String childName = group.getName() + " — " + joinValues(group, combo);
            CreateItemRequest req = new CreateItemRequest(
                    childSku,
                    childName,
                    null,                       // description
                    ItemType.GOODS,             // matrix path mints physical variants only
                    null, null,                 // category, brand
                    null,                       // hsnCode → inherited
                    null,                       // unitOfMeasure → inherited
                    null, null,                 // purchase, sale → inherited
                    null,                       // mrp
                    null,                       // gstRate → inherited
                    null,                       // trackInventory (default for GOODS = true)
                    null,                       // trackBatches
                    null, null,                 // reorder level / qty
                    null, null, null,           // accounts
                    null, null,                 // opening stock + warehouse
                    group.getId(),
                    combo
            );
            ItemResponse response = itemService.createItem(req);
            created.add(response);
        }

        log.info("Generated {} variants for group {} (skipped {})",
                created.size(), group.getName(), skipped.size());
        return new GenerateVariantsResponse(created, skipped);
    }

    // ────────────────────────────────────────────────────────────────────
    // Helpers
    // ────────────────────────────────────────────────────────────────────

    /**
     * Strip null/blank entries and reject duplicate keys in the input
     * definitions list. Keeps the rest of the service simple by
     * guaranteeing the group always carries a clean list.
     */
    private List<AttributeDefinition> sanitiseDefinitions(List<AttributeDefinition> input) {
        if (input == null || input.isEmpty()) {
            return new ArrayList<>();
        }
        Set<String> seenKeys = new HashSet<>();
        List<AttributeDefinition> out = new ArrayList<>(input.size());
        for (AttributeDefinition def : input) {
            if (def == null || def.key() == null || def.key().isBlank()) {
                continue;
            }
            String key = def.key().trim();
            if (!seenKeys.add(key.toLowerCase())) {
                throw new BusinessException(
                        "Duplicate attribute key '" + key + "' in definitions",
                        "GROUP_DUPLICATE_ATTRIBUTE_KEY", HttpStatus.BAD_REQUEST);
            }
            List<String> values = def.values() == null
                    ? List.of()
                    : def.values().stream()
                        .filter(Objects::nonNull)
                        .map(String::trim)
                        .filter(s -> !s.isBlank())
                        .distinct()
                        .toList();
            out.add(new AttributeDefinition(key, values));
        }
        return out;
    }

    /**
     * Refuse a definition update that would orphan an existing variant
     * (drop a key the variant uses, or remove a value it carries).
     * Returns silently on success.
     */
    private void validateDefinitionsAgainstExistingVariants(
            UUID orgId, ItemGroup group, List<AttributeDefinition> newDefs) {
        List<Item> variants = itemRepository
                .findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, group.getId());
        if (variants.isEmpty()) {
            return; // nothing to orphan
        }
        Map<String, Set<String>> newByKey = new LinkedHashMap<>();
        for (AttributeDefinition d : newDefs) {
            newByKey.put(d.key(), d.values() == null ? Set.of() : new HashSet<>(d.values()));
        }
        for (Item v : variants) {
            for (Map.Entry<String, String> e : v.getVariantAttributes().entrySet()) {
                if (!newByKey.containsKey(e.getKey())) {
                    throw new BusinessException(
                            "Cannot drop attribute '" + e.getKey()
                                    + "' — variant " + v.getSku() + " uses it",
                            "GROUP_ATTRIBUTE_IN_USE", HttpStatus.CONFLICT);
                }
                Set<String> allowed = newByKey.get(e.getKey());
                if (!allowed.isEmpty() && !allowed.contains(e.getValue())) {
                    throw new BusinessException(
                            "Cannot remove value '" + e.getValue() + "' from attribute '" + e.getKey()
                                    + "' — variant " + v.getSku() + " uses it",
                            "GROUP_ATTRIBUTE_VALUE_IN_USE", HttpStatus.CONFLICT);
                }
            }
        }
    }

    /**
     * Mint a child SKU as {@code <prefix>-<value1>-<value2>-...}.
     * Iteration order follows {@link AttributeDefinition} order on the
     * group so the same combination always yields the same SKU
     * regardless of how the operator's UI ordered the keys in the
     * request map.
     */
    private String mintSku(ItemGroup group, Map<String, String> combo) {
        StringBuilder sb = new StringBuilder(group.getSkuPrefix());
        for (AttributeDefinition def : group.getAttributeDefinitions()) {
            String value = combo.get(def.key());
            if (value != null && !value.isBlank()) {
                sb.append('-').append(value.toUpperCase().replaceAll("\\s+", ""));
            }
        }
        return sb.toString();
    }

    /**
     * Human-readable variant suffix for the auto-generated name.
     * Walks the group's {@link AttributeDefinition} order so the suffix
     * is deterministic for the same combo regardless of map iteration.
     */
    private String joinValues(ItemGroup group, Map<String, String> combo) {
        List<String> parts = new ArrayList<>();
        for (AttributeDefinition def : group.getAttributeDefinitions()) {
            String v = combo.get(def.key());
            if (v != null && !v.isBlank()) {
                parts.add(v);
            }
        }
        return String.join(" / ", parts);
    }

    private static String blankToNull(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }
}
