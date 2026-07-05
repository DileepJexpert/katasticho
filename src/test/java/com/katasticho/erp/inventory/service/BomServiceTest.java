package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.BomComponentRequest;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link BomService} — the v2 F4 BOM CRUD guards.
 * Covers every service-layer rejection that keeps the invoice-send
 * explosion path trivially safe:
 *
 * <ol>
 *   <li>Parent must be COMPOSITE.</li>
 *   <li>Child cannot be another COMPOSITE (no nested BOMs in v1).</li>
 *   <li>Child cannot be batch-tracked (credit-note restore would
 *       have no batchId to thread).</li>
 *   <li>Parent ≠ child (self-reference).</li>
 *   <li>Positive quantity.</li>
 *   <li>Duplicate (parent, child) rejected with
 *       {@code BOM_DUPLICATE_CHILD}.</li>
 *   <li>Happy path — addComponent persists the row.</li>
 * </ol>
 */
@ExtendWith(MockitoExtension.class)
class BomServiceTest {

    @Mock private BomComponentRepository bomRepository;
    @Mock private ItemRepository itemRepository;

    private BomService service;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new BomService(bomRepository, itemRepository);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void addComponent_parentNotComposite_throws() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item plainGoods = item("WIDGET", ItemType.GOODS, false);
        plainGoods.setId(parentId);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(plainGoods));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addComponent(parentId,
                        new BomComponentRequest(childId, new BigDecimal("2"))));
        assertEquals("BOM_PARENT_NOT_COMPOSITE", ex.getErrorCode());
        verify(bomRepository, never()).save(any());
    }

    @Test
    void addComponent_selfReference_throws() {
        UUID parentId = UUID.randomUUID();

        Item composite = item("KIT", ItemType.COMPOSITE, false);
        composite.setId(parentId);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(composite));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addComponent(parentId,
                        new BomComponentRequest(parentId, new BigDecimal("1"))));
        assertEquals("BOM_SELF_REFERENCE", ex.getErrorCode());
    }

    @Test
    void addComponent_nestedCompositeChild_throws() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item parent = item("KIT", ItemType.COMPOSITE, false);
        parent.setId(parentId);
        Item compositeChild = item("SUBKIT", ItemType.COMPOSITE, false);
        compositeChild.setId(childId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(parent));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId))
                .thenReturn(Optional.of(compositeChild));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addComponent(parentId,
                        new BomComponentRequest(childId, new BigDecimal("1"))));
        assertEquals("BOM_NESTED_NOT_SUPPORTED", ex.getErrorCode());
    }

    @Test
    void addComponent_batchTrackedChild_throws() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item parent = item("KIT", ItemType.COMPOSITE, false);
        parent.setId(parentId);
        Item batchChild = item("CHOC", ItemType.GOODS, true);
        batchChild.setId(childId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(parent));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId))
                .thenReturn(Optional.of(batchChild));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addComponent(parentId,
                        new BomComponentRequest(childId, new BigDecimal("2"))));
        assertEquals("BOM_BATCH_CHILD_NOT_SUPPORTED", ex.getErrorCode());
    }

    @Test
    void addComponent_zeroQuantity_throws() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item parent = item("KIT", ItemType.COMPOSITE, false);
        parent.setId(parentId);
        Item child = item("WIDGET", ItemType.GOODS, false);
        child.setId(childId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(parent));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId))
                .thenReturn(Optional.of(child));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addComponent(parentId,
                        new BomComponentRequest(childId, BigDecimal.ZERO)));
        assertEquals("BOM_QUANTITY_INVALID", ex.getErrorCode());
    }

    @Test
    void addComponent_duplicateChild_throws() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item parent = item("KIT", ItemType.COMPOSITE, false);
        parent.setId(parentId);
        Item child = item("WIDGET", ItemType.GOODS, false);
        child.setId(childId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(parent));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId))
                .thenReturn(Optional.of(child));
        when(bomRepository.existsInCurrentBom(
                orgId, parentId, childId)).thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addComponent(parentId,
                        new BomComponentRequest(childId, new BigDecimal("1"))));
        assertEquals("BOM_DUPLICATE_CHILD", ex.getErrorCode());
        verify(bomRepository, never()).save(any());
    }

    @Test
    void addComponent_happyPath_persists() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item parent = item("KIT", ItemType.COMPOSITE, false);
        parent.setId(parentId);
        Item child = item("WIDGET", ItemType.GOODS, false);
        child.setId(childId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(parent));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId))
                .thenReturn(Optional.of(child));
        when(bomRepository.existsInCurrentBom(
                orgId, parentId, childId)).thenReturn(false);
        when(bomRepository.save(any(BomComponent.class)))
                .thenAnswer(inv -> {
                    BomComponent row = inv.getArgument(0);
                    row.setId(UUID.randomUUID());
                    return row;
                });

        BomComponent saved = service.addComponent(parentId,
                new BomComponentRequest(childId, new BigDecimal("3")));

        assertNotNull(saved.getId());
        assertEquals(parentId, saved.getParentItemId());
        assertEquals(childId, saved.getChildItemId());
        assertEquals(0, new BigDecimal("3").compareTo(saved.getQuantity()));
    }

    // ── Phantom BOMs ─────────────────────────────────────────────────────

    @Test
    void addComponent_phantomCompositeChild_allowed() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();

        Item parent = item("KIT", ItemType.COMPOSITE, false);
        parent.setId(parentId);
        Item phantomChild = item("PH-SUB", ItemType.COMPOSITE, false);
        phantomChild.setId(childId);
        phantomChild.setPhantom(true);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(parent));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId))
                .thenReturn(Optional.of(phantomChild));
        when(bomRepository.existsInCurrentBom(
                orgId, parentId, childId)).thenReturn(false);
        when(bomRepository.save(any(BomComponent.class)))
                .thenAnswer(inv -> {
                    BomComponent row = inv.getArgument(0);
                    row.setId(UUID.randomUUID());
                    return row;
                });

        BomComponent saved = service.addComponent(parentId,
                new BomComponentRequest(childId, new BigDecimal("2")));

        assertNotNull(saved.getId());
        assertEquals(childId, saved.getChildItemId());
    }

    @Test
    void explode_phantomChild_flattensThroughWithScaledQuantities() {
        UUID parentId  = UUID.randomUUID();
        UUID rm1Id     = UUID.randomUUID();
        UUID phantomId = UUID.randomUUID();
        UUID rm2Id     = UUID.randomUUID();

        Item rm1 = item("RM-1", ItemType.GOODS, false);
        rm1.setId(rm1Id);
        Item phantom = item("PH-SUB", ItemType.COMPOSITE, false);
        phantom.setId(phantomId);
        phantom.setPhantom(true);
        Item rm2 = item("RM-2", ItemType.GOODS, false);
        rm2.setId(rm2Id);

        BomComponent rowRm1 = component(parentId, rm1Id, new BigDecimal("2"));
        BomComponent rowPhantom = component(parentId, phantomId, new BigDecimal("3"));
        BomComponent rowRm2 = component(phantomId, rm2Id, new BigDecimal("4"));
        rowRm2.setScrapPercent(new BigDecimal("5"));

        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(rowRm1, rowPhantom));
        when(bomRepository.findCurrentBom(orgId, phantomId))
                .thenReturn(java.util.List.of(rowRm2));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(rm1Id, orgId))
                .thenReturn(Optional.of(rm1));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(phantomId, orgId))
                .thenReturn(Optional.of(phantom));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(rm2Id, orgId))
                .thenReturn(Optional.of(rm2));

        java.util.List<BomComponent> result = service.explode(orgId, parentId);

        assertEquals(2, result.size());
        // Direct (non-phantom) child returned untouched
        assertEquals(rm1Id, result.get(0).getChildItemId());
        assertEquals(0, new BigDecimal("2").compareTo(result.get(0).getQuantity()));
        // Phantom flattened: 3 phantom units × 4 rm2 each = 12, re-parented onto the root
        assertEquals(rm2Id, result.get(1).getChildItemId());
        assertEquals(parentId, result.get(1).getParentItemId());
        assertEquals(0, new BigDecimal("12").compareTo(result.get(1).getQuantity()));
        // Scrap percent of the flattened row carried through
        assertEquals(0, new BigDecimal("5").compareTo(result.get(1).getScrapPercent()));
        // The phantom itself never appears
        assertTrue(result.stream().noneMatch(r -> phantomId.equals(r.getChildItemId())));
    }

    @Test
    void explode_phantomCycle_throws() {
        UUID parentId   = UUID.randomUUID();
        UUID phantomAId = UUID.randomUUID();
        UUID phantomBId = UUID.randomUUID();

        Item phantomA = item("PH-A", ItemType.COMPOSITE, false);
        phantomA.setId(phantomAId);
        phantomA.setPhantom(true);
        Item phantomB = item("PH-B", ItemType.COMPOSITE, false);
        phantomB.setId(phantomBId);
        phantomB.setPhantom(true);

        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(component(parentId, phantomAId, BigDecimal.ONE)));
        when(bomRepository.findCurrentBom(orgId, phantomAId))
                .thenReturn(java.util.List.of(component(phantomAId, phantomBId, BigDecimal.ONE)));
        when(bomRepository.findCurrentBom(orgId, phantomBId))
                .thenReturn(java.util.List.of(component(phantomBId, phantomAId, BigDecimal.ONE)));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(phantomAId, orgId))
                .thenReturn(Optional.of(phantomA));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(phantomBId, orgId))
                .thenReturn(Optional.of(phantomB));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.explode(orgId, parentId));
        assertEquals("BOM_PHANTOM_CYCLE", ex.getErrorCode());
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private BomComponent component(UUID parentId, UUID childId, BigDecimal qty) {
        BomComponent row = BomComponent.builder()
                .parentItemId(parentId)
                .childItemId(childId)
                .quantity(qty)
                .build();
        row.setId(UUID.randomUUID());
        row.setOrgId(orgId);
        return row;
    }


    // ── tracker #42 — parameterized BOMs ───────────────────────────

    private BomComponent componentWithFilter(UUID parentId, UUID childId,
                                             BigDecimal qty,
                                             java.util.Map<String, String> filter) {
        BomComponent row = component(parentId, childId, qty);
        row.setVariantFilter(filter);
        return row;
    }

    @Test
    void resolveBomForVariant_nullFilter_appliesToAllVariants() {
        UUID parentId = UUID.randomUUID();
        UUID childId = UUID.randomUUID();
        BomComponent universal = component(parentId, childId, BigDecimal.ONE);
        // No filter → universal line.

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(item("PARENT", ItemType.COMPOSITE, false)));
        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(universal));

        java.util.List<BomComponent> result = service.resolveBomForVariant(parentId,
                java.util.Map.of("size", "M", "color", "Red"));

        assertEquals(1, result.size());
        assertEquals(childId, result.get(0).getChildItemId());
    }

    @Test
    void resolveBomForVariant_filterMatchesAllAttributes_includesLine() {
        UUID parentId = UUID.randomUUID();
        UUID redDyeId = UUID.randomUUID();
        BomComponent redOnly = componentWithFilter(parentId, redDyeId,
                BigDecimal.valueOf(20), java.util.Map.of("color", "Red"));

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(item("PARENT", ItemType.COMPOSITE, false)));
        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(redOnly));

        java.util.List<BomComponent> matched = service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Red", "size", "M"));
        assertEquals(1, matched.size(), "color=Red filter should match a Red variant");

        java.util.List<BomComponent> unmatched = service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Blue"));
        assertTrue(unmatched.isEmpty(), "color=Red filter must NOT match Blue variant");
    }

    @Test
    void resolveBomForVariant_multiKeyFilter_requiresAllKeysToMatch() {
        UUID parentId = UUID.randomUUID();
        UUID redMediumPart = UUID.randomUUID();
        BomComponent both = componentWithFilter(parentId, redMediumPart, BigDecimal.ONE,
                java.util.Map.of("color", "Red", "size", "M"));

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(item("PARENT", ItemType.COMPOSITE, false)));
        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(both));

        // Both axes match → included.
        assertEquals(1, service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Red", "size", "M")).size());

        // Only one axis matches → excluded (AND semantics).
        assertTrue(service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Red", "size", "L")).isEmpty());
        assertTrue(service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Blue", "size", "M")).isEmpty());
    }

    @Test
    void resolveBomForVariant_mixedFilters_filtersIndependently() {
        // Realistic case: universal cotton + red-only dye + size-M-only pattern.
        UUID parentId = UUID.randomUUID();
        UUID cotton = UUID.randomUUID();
        UUID redDye = UUID.randomUUID();
        UUID sizeMpattern = UUID.randomUUID();

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(item("PARENT", ItemType.COMPOSITE, false)));
        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(
                        component(parentId, cotton, BigDecimal.valueOf(1.5)),
                        componentWithFilter(parentId, redDye, BigDecimal.valueOf(20),
                                java.util.Map.of("color", "Red")),
                        componentWithFilter(parentId, sizeMpattern, BigDecimal.ONE,
                                java.util.Map.of("size", "M"))));

        // Red-M variant: gets all three lines.
        assertEquals(3, service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Red", "size", "M")).size());

        // Blue-M variant: gets cotton + size-M pattern (NO red dye).
        java.util.List<BomComponent> blueM = service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Blue", "size", "M"));
        assertEquals(2, blueM.size());
        assertTrue(blueM.stream().noneMatch(c -> c.getChildItemId().equals(redDye)));

        // Red-L variant: gets cotton + red dye (NO size-M pattern).
        java.util.List<BomComponent> redL = service.resolveBomForVariant(parentId,
                java.util.Map.of("color", "Red", "size", "L"));
        assertEquals(2, redL.size());
        assertTrue(redL.stream().noneMatch(c -> c.getChildItemId().equals(sizeMpattern)));
    }

    @Test
    void resolveBomForVariant_emptyAttributes_keepsOnlyUnfilteredLines() {
        UUID parentId = UUID.randomUUID();
        UUID universal = UUID.randomUUID();
        UUID variantOnly = UUID.randomUUID();

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentId, orgId))
                .thenReturn(Optional.of(item("PARENT", ItemType.COMPOSITE, false)));
        when(bomRepository.findCurrentBom(orgId, parentId))
                .thenReturn(java.util.List.of(
                        component(parentId, universal, BigDecimal.ONE),
                        componentWithFilter(parentId, variantOnly, BigDecimal.ONE,
                                java.util.Map.of("color", "Red"))));

        // No attributes supplied → variant-specific lines should drop out;
        // only the universal-line remains.
        java.util.List<BomComponent> result =
                service.resolveBomForVariant(parentId, java.util.Map.of());
        assertEquals(1, result.size());
        assertEquals(universal, result.get(0).getChildItemId());
    }

    private Item item(String sku, ItemType type, boolean batch) {
        Item item = Item.builder()
                .sku(sku)
                .name(sku)
                .itemType(type)
                .trackInventory(type == ItemType.GOODS)
                .trackBatches(batch)
                .purchasePrice(BigDecimal.TEN)
                .salePrice(BigDecimal.TEN)
                .gstRate(BigDecimal.ZERO)
                .build();
        item.setOrgId(orgId);
        return item;
    }
}
