package com.katasticho.erp.inventory;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemPackagingBarcode;
import com.katasticho.erp.inventory.repository.ItemPackagingBarcodeRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.ItemPackagingBarcodeService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ItemPackagingBarcodeServiceTest {

    @Mock private ItemPackagingBarcodeRepository packagingBarcodeRepository;
    @Mock private ItemRepository itemRepository;

    private ItemPackagingBarcodeService service;
    private final UUID orgId = UUID.randomUUID();
    private final UUID itemId = UUID.randomUUID();
    private Item mockItem;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        service = new ItemPackagingBarcodeService(packagingBarcodeRepository, itemRepository);

        mockItem = Item.builder()
                .name("Crocin 650mg Tablet")
                .sku("MED-CROCIN-650")
                .barcode("8901234567001")
                .unitOfMeasure("STRIP")
                .salePrice(new BigDecimal("35.00"))
                .purchasePrice(new BigDecimal("28.00"))
                .mrp(new BigDecimal("40.00"))
                .build();
        mockItem.setId(itemId);
        mockItem.setOrgId(orgId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(itemId), eq(orgId)))
                .thenReturn(Optional.of(mockItem));
        when(itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("8901234567001")))
                .thenReturn(Optional.of(mockItem));

        when(packagingBarcodeRepository.save(any(ItemPackagingBarcode.class)))
                .thenAnswer(inv -> inv.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void testAddBarcode_AddsCartonPackagingTier() {
        var req = new ItemPackagingBarcodeService.PackagingBarcodeRequest(
                "8901234567010", "CARTON", "Outer Box 10 Strips",
                new BigDecimal("10.0"), "BOX", new BigDecimal("400.00"),
                new BigDecimal("350.00"), new BigDecimal("270.00"), false, "Wholesale Carton"
        );

        when(packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("8901234567010")))
                .thenReturn(Optional.empty());

        var resp = service.addBarcode(itemId, req);

        assertNotNull(resp);
        assertEquals(itemId, resp.itemId());
        assertEquals("8901234567010", resp.barcode());
        assertEquals("CARTON", resp.packagingLevel());
        assertEquals(new BigDecimal("10.0"), resp.conversionFactor());
        assertEquals("BOX", resp.uomName());
        assertEquals("Crocin 650mg Tablet", resp.itemName());
        verify(packagingBarcodeRepository).save(any(ItemPackagingBarcode.class));
    }

    @Test
    void testAddBarcode_DuplicateBarcodeThrowsConflict() {
        var req = new ItemPackagingBarcodeService.PackagingBarcodeRequest(
                "8901234567010", "CARTON", "Box 10",
                new BigDecimal("10.0"), "BOX", null, null, null, false, null
        );

        ItemPackagingBarcode existing = ItemPackagingBarcode.builder()
                .barcode("8901234567010")
                .itemId(UUID.randomUUID())
                .build();

        when(packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("8901234567010")))
                .thenReturn(Optional.of(existing));

        assertThrows(BusinessException.class, () -> service.addBarcode(itemId, req));
    }

    @Test
    void testResolveBarcode_ResolvesCartonWithMultiplier() {
        ItemPackagingBarcode cartonBarcode = ItemPackagingBarcode.builder()
                .itemId(itemId)
                .barcode("8901234567010")
                .packagingLevel("CARTON")
                .packagingName("Master Carton 24x")
                .conversionFactor(new BigDecimal("24.0"))
                .salePrice(new BigDecimal("800.00"))
                .uomName("CARTON")
                .build();
        cartonBarcode.setId(UUID.randomUUID());
        cartonBarcode.setOrgId(orgId);

        when(packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("8901234567010")))
                .thenReturn(Optional.of(cartonBarcode));

        var resolved = service.resolveBarcode("8901234567010");

        assertNotNull(resolved);
        assertEquals(itemId, resolved.itemId());
        assertEquals("Crocin 650mg Tablet", resolved.itemName());
        assertEquals("8901234567010", resolved.scannedBarcode());
        assertEquals("CARTON", resolved.packagingLevel());
        assertEquals(new BigDecimal("24.0"), resolved.quantityMultiplier());
        assertEquals(new BigDecimal("800.00"), resolved.unitPrice());
        assertTrue(resolved.isHierarchyMatch());
    }

    @Test
    void testResolveBarcode_FallsBackToBaseItemBarcode() {
        when(packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("8901234567001")))
                .thenReturn(Optional.empty());

        var resolved = service.resolveBarcode("8901234567001");

        assertNotNull(resolved);
        assertEquals(itemId, resolved.itemId());
        assertEquals("Crocin 650mg Tablet", resolved.itemName());
        assertEquals(BigDecimal.ONE, resolved.quantityMultiplier());
        assertEquals("UNIT", resolved.packagingLevel());
        assertEquals(new BigDecimal("35.00"), resolved.unitPrice());
        assertFalse(resolved.isHierarchyMatch());
    }

    @Test
    void testResolveBarcode_UnknownBarcodeThrowsNotFound() {
        when(packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("9999999999999")))
                .thenReturn(Optional.empty());
        when(itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(eq(orgId), eq("9999999999999")))
                .thenReturn(Optional.empty());

        assertThrows(BusinessException.class, () -> service.resolveBarcode("9999999999999"));
    }
}
