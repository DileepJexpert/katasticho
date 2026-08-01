package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.module.ModuleAccessService;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.entity.DrugMaster;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.ItemService;
import com.katasticho.erp.pos.dto.PosSearchResult;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PosCatalogServiceTest {

    @Mock private DrugMasterRepository drugMasterRepo;
    @Mock private ItemRepository itemRepo;
    @Mock private ItemService itemService;
    @Mock private PosSearchService posSearchService;
    @Mock private com.katasticho.erp.organisation.OrgSettingsService orgSettingsService;
    @Mock private ModuleAccessService moduleAccessService;

    private PosCatalogService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PosCatalogService(moduleAccessService, drugMasterRepo, itemRepo, itemService, posSearchService,
                orgSettingsService);
        lenient().doNothing().when(moduleAccessService).requireEnabled("PHARMA");
        lenient().when(orgSettingsService.get(eq(orgId),
                eq("pos.catalog_quick_add_track_batches"), eq("false"))).thenReturn("false");
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private DrugMaster drug() {
        DrugMaster d = new DrugMaster();
        d.setId(UUID.randomUUID());
        d.setBrandName("Dolo 650 Tablet");
        d.setSaltComposition("Paracetamol 650mg");
        d.setManufacturer("Micro Labs Ltd");
        d.setHsnCode("3004");
        d.setGstRate(new BigDecimal("5.00"));
        d.setDrugSchedule("GENERAL");
        d.setDosageForm("Tablet");
        d.setPackSize("strip of 15 tablets");
        d.setMrp(new BigDecimal("33.60"));
        d.setPrescriptionRequired(false);
        return d;
    }

    private PosSearchResult result(String name, String sku) {
        return new PosSearchResult(UUID.randomUUID(), name, sku, null,
                new BigDecimal("33.60"), new BigDecimal("33.60"), null,
                null, null, "3004", "PCS", BigDecimal.ZERO, false,
                null, null, false, null, null, false,
                "GENERAL", "Paracetamol 650mg", "Micro Labs Ltd", null);
    }

    @Test
    void createFromDrug_mapsCatalogFieldsOntoItem() {
        DrugMaster d = drug();
        when(drugMasterRepo.findById(d.getId())).thenReturn(Optional.of(d));
        when(itemRepo.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Dolo 650 Tablet"))
                .thenReturn(Optional.empty());
        when(itemRepo.existsByOrgIdAndSkuAndIsDeletedFalse(eq(orgId), anyString())).thenReturn(false);
        when(posSearchService.search(eq(orgId), anyString(), any(), anyInt()))
                .thenReturn(List.of(result("Dolo 650 Tablet", "DOLO-650-TABLET")));

        PosSearchResult res = service.createItemFromDrug(d.getId(), null, new BigDecimal("10"));

        ArgumentCaptor<CreateItemRequest> captor = ArgumentCaptor.forClass(CreateItemRequest.class);
        verify(itemService).createItem(captor.capture());
        CreateItemRequest req = captor.getValue();
        assertEquals("Dolo 650 Tablet", req.name());
        assertEquals("DOLO-650-TABLET", req.sku());
        assertEquals(ItemType.GOODS, req.itemType());
        assertEquals("3004", req.hsnCode());
        assertEquals(0, new BigDecimal("5.00").compareTo(req.gstRate()));
        assertEquals(0, new BigDecimal("33.60").compareTo(req.salePrice()));
        assertEquals(0, new BigDecimal("33.60").compareTo(req.mrp()));
        assertEquals("Paracetamol 650mg", req.composition());
        assertEquals("Micro Labs Ltd", req.manufacturer());
        assertEquals(Boolean.TRUE, req.trackInventory());
        assertEquals(Boolean.FALSE, req.trackBatches());
        assertNull(req.purchasePrice());
        assertEquals(0, new BigDecimal("10").compareTo(req.openingStock()));
        assertEquals("Dolo 650 Tablet", res.name());
        verify(moduleAccessService).requireEnabled("PHARMA");
    }

    @Test
    void createFromDrug_existingItemName_isIdempotent() {
        DrugMaster d = drug();
        when(drugMasterRepo.findById(d.getId())).thenReturn(Optional.of(d));
        Item existing = mock(Item.class);
        when(existing.getSku()).thenReturn("DOLO-650-TABLET");
        when(itemRepo.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Dolo 650 Tablet"))
                .thenReturn(Optional.of(existing));
        when(posSearchService.search(orgId, "DOLO-650-TABLET", null, 1))
                .thenReturn(List.of(result("Dolo 650 Tablet", "DOLO-650-TABLET")));

        PosSearchResult res = service.createItemFromDrug(d.getId(), null, new BigDecimal("10"));

        verify(itemService, never()).createItem(any());
        assertEquals("DOLO-650-TABLET", res.sku());
    }

    @Test
    void createFromDrug_batchTrackSetting_enablesBatchesWithOpeningBatch() {
        DrugMaster d = drug();
        when(drugMasterRepo.findById(d.getId())).thenReturn(Optional.of(d));
        when(itemRepo.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Dolo 650 Tablet"))
                .thenReturn(Optional.empty());
        when(itemRepo.existsByOrgIdAndSkuAndIsDeletedFalse(eq(orgId), anyString())).thenReturn(false);
        when(orgSettingsService.get(orgId, "pos.catalog_quick_add_track_batches", "false"))
                .thenReturn("true");
        when(posSearchService.search(eq(orgId), anyString(), any(), anyInt()))
                .thenReturn(List.of(result("Dolo 650 Tablet", "DOLO-650-TABLET")));

        service.createItemFromDrug(d.getId(), null, new BigDecimal("10"));

        ArgumentCaptor<CreateItemRequest> captor = ArgumentCaptor.forClass(CreateItemRequest.class);
        verify(itemService).createItem(captor.capture());
        assertEquals(Boolean.TRUE, captor.getValue().trackBatches());
        assertEquals("OPENING", captor.getValue().openingBatchNumber());
    }

    @Test
    void createFromDrug_skuCollision_appendsSuffix() {
        DrugMaster d = drug();
        when(drugMasterRepo.findById(d.getId())).thenReturn(Optional.of(d));
        when(itemRepo.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Dolo 650 Tablet"))
                .thenReturn(Optional.empty());
        when(itemRepo.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, "DOLO-650-TABLET"))
                .thenReturn(true);
        when(itemRepo.existsByOrgIdAndSkuAndIsDeletedFalse(eq(orgId),
                argThat(s -> s != null && s.startsWith("DOLO-650-TABLET-")))).thenReturn(false);
        when(posSearchService.search(eq(orgId), anyString(), any(), anyInt()))
                .thenReturn(List.of(result("Dolo 650 Tablet", "DOLO-650-TABLET-1234")));

        service.createItemFromDrug(d.getId(), null, new BigDecimal("10"));

        ArgumentCaptor<CreateItemRequest> captor = ArgumentCaptor.forClass(CreateItemRequest.class);
        verify(itemService).createItem(captor.capture());
        assertTrue(captor.getValue().sku().matches("DOLO-650-TABLET-\\d{4}"));
    }
}

