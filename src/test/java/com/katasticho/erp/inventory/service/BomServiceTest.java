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
        when(bomRepository.existsByOrgIdAndParentItemIdAndChildItemIdAndIsDeletedFalse(
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
        when(bomRepository.existsByOrgIdAndParentItemIdAndChildItemIdAndIsDeletedFalse(
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

    // ── Helpers ──────────────────────────────────────────────────────────

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
