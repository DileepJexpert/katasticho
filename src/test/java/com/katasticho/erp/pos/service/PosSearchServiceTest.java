package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.module.ModuleAccessService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.RackLocation;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.RackLocationRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.dto.PosSearchResult;
import com.katasticho.erp.tax.TaxEngine;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PosSearchServiceTest {

    @Mock private ItemRepository itemRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private StockBatchRepository batchRepository;
    @Mock private RackLocationRepository rackLocationRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private TaxGroupRepository taxGroupRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private TaxEngine taxEngine;
    @Mock private ModuleAccessService moduleAccessService;

    private PosSearchService posSearchService;

    @BeforeEach
    void setUp() {
        posSearchService = new PosSearchService(
                itemRepository,
                stockBalanceRepository,
                batchRepository,
                rackLocationRepository,
                warehouseRepository,
                taxGroupRepository,
                organisationRepository,
                taxEngine,
                moduleAccessService);
    }

    @Test
    void search_itemWithRackLocation_returnsRackCodeForCounterStaff() {
        UUID orgId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID warehouseId = UUID.randomUUID();
        UUID rackId = UUID.randomUUID();

        Item item = Item.builder()
                .sku("MED002")
                .name("Amoxicillin 500mg Capsule")
                .salePrice(new BigDecimal("52.00"))
                .purchasePrice(new BigDecimal("38.00"))
                .gstRate(BigDecimal.ZERO)
                .trackInventory(true)
                .trackBatches(false)
                .build();
        item.setId(itemId);
        item.setOrgId(orgId);
        item.setRackLocationId(rackId);

        Warehouse warehouse = Warehouse.builder()
                .code("MAIN")
                .name("Main Warehouse")
                .isDefault(true)
                .build();
        warehouse.setId(warehouseId);
        warehouse.setOrgId(orgId);

        StockBalance balance = StockBalance.builder()
                .orgId(orgId)
                .itemId(itemId)
                .warehouseId(warehouseId)
                .quantityOnHand(new BigDecimal("100"))
                .build();

        RackLocation rack = new RackLocation();
        rack.setId(rackId);
        rack.setOrgId(orgId);
        rack.setWarehouseId(warehouseId);
        rack.setCode("A1-01");

        when(itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, "amox"))
                .thenReturn(Optional.empty());
        when(itemRepository.findByOrgIdAndSkuAndIsDeletedFalse(orgId, "amox"))
                .thenReturn(Optional.empty());
        when(itemRepository.search(eq(orgId), eq("amox"), any(PageRequest.class)))
                .thenReturn(new PageImpl<>(List.of(item)));
        when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(warehouse));
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(balance));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.empty());
        when(rackLocationRepository.findAllById(any())).thenReturn(List.of(rack));

        List<PosSearchResult> results = posSearchService.search(orgId, "amox", null, 20);

        assertEquals(1, results.size());
        PosSearchResult result = results.get(0);
        assertEquals(itemId, result.id());
        assertEquals(new BigDecimal("100"), result.currentStock());
        assertEquals("A1-01", result.rackLocationCode());
    }
}
