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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.quality.Strictness;
import org.mockito.junit.jupiter.MockitoSettings;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link ItemGroupService} — the v2 F5 variant template
 * lifecycle. Covers:
 *
 * <ol>
 *   <li>Duplicate group name rejected.</li>
 *   <li>Duplicate attribute key in definitions rejected.</li>
 *   <li>Attribute validation: empty map, unknown key, unknown value.</li>
 *   <li>Definition update that would orphan a live variant rejected.</li>
 *   <li>Delete group with children rejected.</li>
 *   <li>{@code applyDefaults} inherits missing fields, never overrides
 *       explicit ones.</li>
 *   <li>{@code generateVariants} requires a SKU prefix.</li>
 *   <li>{@code generateVariants} happy path mints variants with
 *       inheritance + skip duplicates.</li>
 * </ol>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ItemGroupServiceTest {

    @Mock private ItemGroupRepository groupRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private AuditService auditService;
    @Mock private ItemService itemService;

    private ItemGroupService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new ItemGroupService(groupRepository, itemRepository, auditService, itemService);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ────────────────────────────────────────────────────────────────────
    // Group CRUD
    // ────────────────────────────────────────────────────────────────────

    @Test
    void createGroup_duplicateName_throws() {
        when(groupRepository.existsByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Cotton Tee"))
                .thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createGroup(req("Cotton Tee", List.of())));
        assertEquals("GROUP_DUPLICATE_NAME", ex.getErrorCode());
        verify(groupRepository, never()).save(any());
    }

    @Test
    void createGroup_duplicateAttributeKey_throws() {
        when(groupRepository.existsByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(false);

        // sanitiseDefinitions rejects two definitions with the same key
        // (case-insensitive) so a UI bug can't create a "Color"+"color"
        // template that would later fail attribute validation in
        // confusing ways.
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createGroup(req("Tee", List.of(
                        new AttributeDefinition("color", List.of("Red")),
                        new AttributeDefinition("Color", List.of("Blue"))
                ))));
        assertEquals("GROUP_DUPLICATE_ATTRIBUTE_KEY", ex.getErrorCode());
    }

    @Test
    void deleteGroup_withChildren_throws() {
        UUID gid = UUID.randomUUID();
        ItemGroup group = group(gid, "Tee", List.of());
        when(groupRepository.findByIdAndOrgIdAndIsDeletedFalse(gid, orgId))
                .thenReturn(Optional.of(group));
        when(itemRepository.existsByOrgIdAndGroupIdAndIsDeletedFalse(orgId, gid))
                .thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.deleteGroup(gid));
        assertEquals("GROUP_HAS_CHILDREN", ex.getErrorCode());
        verify(groupRepository, never()).save(any());
    }

    @Test
    void updateGroup_droppingValueInUseByVariant_throws() {
        UUID gid = UUID.randomUUID();
        ItemGroup existing = group(gid, "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M", "L")),
                new AttributeDefinition("color", List.of("Red", "Blue"))
        ));
        when(groupRepository.findByIdAndOrgIdAndIsDeletedFalse(gid, orgId))
                .thenReturn(Optional.of(existing));
        // One live variant currently uses size=L
        Item variant = Item.builder()
                .sku("TEE-L-RED")
                .name("Tee L Red")
                .itemType(ItemType.GOODS)
                .groupId(gid)
                .variantAttributes(Map.of("size", "L", "color", "Red"))
                .build();
        variant.setId(UUID.randomUUID());
        variant.setOrgId(orgId);
        when(itemRepository.findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, gid))
                .thenReturn(List.of(variant));

        // Proposed new definitions drop "L" from size
        ItemGroupRequest update = new ItemGroupRequest(
                "Tee", null, "TEE", null, null, null, null, null,
                List.of(
                        new AttributeDefinition("size", List.of("S", "M")),
                        new AttributeDefinition("color", List.of("Red", "Blue"))
                ));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updateGroup(gid, update));
        assertEquals("GROUP_ATTRIBUTE_VALUE_IN_USE", ex.getErrorCode());
    }

    // ────────────────────────────────────────────────────────────────────
    // Attribute validation
    // ────────────────────────────────────────────────────────────────────

    @Test
    void validateAttributes_emptyMap_throws() {
        ItemGroup g = group(UUID.randomUUID(), "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M"))));
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.validateAttributes(g, Map.of()));
        assertEquals("GROUP_EMPTY_ATTRIBUTES", ex.getErrorCode());
    }

    @Test
    void validateAttributes_unknownKey_throws() {
        ItemGroup g = group(UUID.randomUUID(), "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M"))));
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.validateAttributes(g, Map.of("color", "Red")));
        assertEquals("GROUP_INVALID_ATTRIBUTE", ex.getErrorCode());
    }

    @Test
    void validateAttributes_valueNotInAllowedList_throws() {
        ItemGroup g = group(UUID.randomUUID(), "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M", "L"))));
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.validateAttributes(g, Map.of("size", "XXL")));
        assertEquals("GROUP_INVALID_VALUE", ex.getErrorCode());
    }

    @Test
    void validateAttributes_happyPath_passes() {
        ItemGroup g = group(UUID.randomUUID(), "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M", "L")),
                new AttributeDefinition("color", List.of("Red", "Blue"))));
        // Should not throw
        service.validateAttributes(g, Map.of("size", "M", "color", "Blue"));
    }

    // ────────────────────────────────────────────────────────────────────
    // Inheritance
    // ────────────────────────────────────────────────────────────────────

    @Test
    void applyDefaults_inheritsMissing_keepsExplicit() {
        ItemGroup g = ItemGroup.builder()
                .name("Tee")
                .hsnCode("6109")
                .gstRate(new BigDecimal("12"))
                .defaultUom("PCS")
                .defaultPurchasePrice(new BigDecimal("100"))
                .defaultSalePrice(new BigDecimal("199"))
                .attributeDefinitions(List.of())
                .build();

        // Request with most fields blank — should inherit
        CreateItemRequest req = new CreateItemRequest(
                "TEE-M-RED", "Tee M Red", null, ItemType.GOODS,
                null, null,
                null,           // hsnCode → inherit
                null,           // uom → inherit
                null,           // purchase → inherit
                new BigDecimal("249"), // sale price EXPLICIT → must NOT inherit
                null, null,     // mrp, gstRate (gst → inherit)
                null, null, null, null, // trackInventory, trackBatches, reorderLevel, reorderQuantity
                null, null, null,       // barcode, manufacturer, preferredVendorId
                null, null, null, null, null, null, // weight, weightUnit, length, width, height, dimensionUnit
                null, null, null, null, null, null, // drugSchedule, composition, dosageForm, packSize, storageCondition, prescriptionRequired
                null,                   // weightBasedBilling
                null, null, null,       // revenueAccountCode, cogsAccountCode, inventoryAccountCode
                null, null,             // openingStock, openingWarehouseId
                null, null, null, null, // purchaseUom, purchaseUomConversion, purchasePricePerUom, secondaryUnits
                UUID.randomUUID(),
                Map.of("size", "M", "color", "Red")
        );

        CreateItemRequest result = service.applyDefaults(g, req);
        assertEquals("6109", result.hsnCode());
        assertEquals("PCS", result.unitOfMeasure());
        assertEquals(0, new BigDecimal("100").compareTo(result.purchasePrice()));
        // Sale price was explicit — must be kept, not overwritten
        assertEquals(0, new BigDecimal("249").compareTo(result.salePrice()));
        assertEquals(0, new BigDecimal("12").compareTo(result.gstRate()));
        // Variant attributes pass through unchanged
        assertEquals(Map.of("size", "M", "color", "Red"), result.variantAttributes());
    }

    // ────────────────────────────────────────────────────────────────────
    // Matrix bulk-create
    // ────────────────────────────────────────────────────────────────────

    @Test
    void generateVariants_noSkuPrefix_throws() {
        UUID gid = UUID.randomUUID();
        ItemGroup g = group(gid, "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M"))));
        // No skuPrefix set
        when(groupRepository.findByIdAndOrgIdAndIsDeletedFalse(gid, orgId))
                .thenReturn(Optional.of(g));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.generateVariants(gid, new GenerateVariantsRequest(
                        List.of(Map.of("size", "S")))));
        assertEquals("GROUP_NO_SKU_PREFIX", ex.getErrorCode());
    }

    @Test
    void generateVariants_happyPath_mintsAndSkipsDuplicates() {
        UUID gid = UUID.randomUUID();
        ItemGroup g = group(gid, "Tee", List.of(
                new AttributeDefinition("size", List.of("S", "M", "L")),
                new AttributeDefinition("color", List.of("Red", "Blue"))));
        g.setSkuPrefix("TEE");
        g.setHsnCode("6109");
        g.setGstRate(new BigDecimal("12"));
        g.setDefaultUom("PCS");
        g.setDefaultPurchasePrice(new BigDecimal("100"));
        g.setDefaultSalePrice(new BigDecimal("199"));

        when(groupRepository.findByIdAndOrgIdAndIsDeletedFalse(gid, orgId))
                .thenReturn(Optional.of(g));

        // Pre-existing variant: size=M color=Red — should be skipped
        Item existing = Item.builder()
                .sku("TEE-M-RED")
                .name("Tee M Red")
                .itemType(ItemType.GOODS)
                .groupId(gid)
                .variantAttributes(Map.of("size", "M", "color", "Red"))
                .build();
        existing.setId(UUID.randomUUID());
        existing.setOrgId(orgId);
        when(itemRepository.findByOrgIdAndGroupIdAndIsDeletedFalseOrderBySkuAsc(orgId, gid))
                .thenReturn(List.of(existing));

        // ItemService.createItem is mocked — return a stub response
        when(itemService.createItem(any(CreateItemRequest.class)))
                .thenAnswer(inv -> {
                    CreateItemRequest r = inv.getArgument(0);
                    return stubItemResponse(r.sku(), r.name(), r.groupId(), r.variantAttributes());
                });

        GenerateVariantsResponse response = service.generateVariants(gid,
                new GenerateVariantsRequest(List.of(
                        Map.of("size", "S", "color", "Red"),  // new
                        Map.of("size", "M", "color", "Red"),  // duplicate — skipped
                        Map.of("size", "L", "color", "Blue")  // new
                )));

        assertEquals(2, response.created().size());
        assertEquals(1, response.skippedReasons().size());
        // Created SKUs come from the prefix + value join
        List<String> createdSkus = response.created().stream().map(ItemResponse::sku).toList();
        assertTrue(createdSkus.contains("TEE-S-RED"));
        assertTrue(createdSkus.contains("TEE-L-BLUE"));
        // ItemService was called twice (the duplicate combo never reached it)
        verify(itemService, times(2)).createItem(any(CreateItemRequest.class));
    }

    // ────────────────────────────────────────────────────────────────────
    // Helpers
    // ────────────────────────────────────────────────────────────────────

    private ItemGroupRequest req(String name, List<AttributeDefinition> defs) {
        return new ItemGroupRequest(name, null, null, null, null, null, null, null, defs);
    }

    private ItemGroup group(UUID id, String name, List<AttributeDefinition> defs) {
        ItemGroup g = ItemGroup.builder()
                .name(name)
                .attributeDefinitions(defs)
                .build();
        g.setId(id);
        g.setOrgId(orgId);
        return g;
    }

    private ItemResponse stubItemResponse(
            String sku, String name, UUID groupId, Map<String, String> attrs) {
        return new ItemResponse(
                UUID.randomUUID(), sku, null, name, null, ItemType.GOODS,
                null, null, null, "6109", "PCS",
                new BigDecimal("100"), new BigDecimal("199"), null, new BigDecimal("12"),
                null,
                true, false,
                BigDecimal.ZERO, BigDecimal.ZERO,
                null, null,
                null, null, null, null, null, null,
                null, null, null, null, null, false,
                false, // weightBasedBilling
                null, null, null,
                true, BigDecimal.ZERO, Instant.now(),
                groupId, attrs, "Tee",
                null, null, null, List.of());
    }
}
