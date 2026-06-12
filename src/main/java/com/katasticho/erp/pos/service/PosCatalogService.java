package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.entity.DrugMaster;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.ItemService;
import com.katasticho.erp.pos.dto.PosSearchResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Marg-style "sell from the catalog" at the POS counter: when a medicine
 * exists in the platform drug master but not yet in the org's item master,
 * one tap creates the item (name, HSN, GST, MRP, composition, manufacturer
 * prefilled) and returns it as a ready-to-bill {@link PosSearchResult}.
 *
 * Idempotent: if an item with the same name already exists for the org,
 * that item is returned instead of creating a duplicate (double-tap safe).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PosCatalogService {

    private final DrugMasterRepository drugMasterRepository;
    private final ItemRepository itemRepository;
    private final ItemService itemService;
    private final PosSearchService posSearchService;
    private final com.katasticho.erp.organisation.OrgSettingsService orgSettingsService;

    @Transactional
    public PosSearchResult createItemFromDrug(UUID drugId, UUID warehouseId,
                                              java.math.BigDecimal openingStock) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DrugMaster drug = drugMasterRepository.findById(drugId)
                .orElseThrow(() -> BusinessException.notFound("DrugMaster", drugId));

        String name = drug.getBrandName().trim();

        // Already in the org's item master? Return it instead of duplicating.
        var existing = itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, name);
        String sku;
        if (existing.isPresent()) {
            sku = existing.get().getSku();
        } else {
            sku = uniqueSku(orgId, name);
            boolean trackBatches = Boolean.parseBoolean(orgSettingsService.get(
                    orgId, "pos.catalog_quick_add_track_batches", "false"));
            itemService.createItem(buildRequest(sku, drug, openingStock, warehouseId, trackBatches));
            log.info("POS catalog quick-add: created item '{}' (sku {}) from drug {} for org {}",
                    name, sku, drugId, orgId);
        }

        // Exact-SKU search returns the fresh item shaped exactly like any
        // other POS result, so the cart flow needs no special handling.
        List<PosSearchResult> results = posSearchService.search(orgId, sku, warehouseId, 1);
        if (results.isEmpty()) {
            throw new BusinessException("Item was created but could not be loaded for billing",
                    "POS_CATALOG_ADD_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }
        return results.get(0);
    }

    private CreateItemRequest buildRequest(String sku, DrugMaster drug,
                                           java.math.BigDecimal openingStock, UUID warehouseId,
                                           boolean trackBatches) {
        return new CreateItemRequest(
                sku,
                drug.getBrandName().trim(),
                null,                                  // description
                ItemType.GOODS,
                "Medicine",                            // category
                drug.getManufacturer(),                // brand
                drug.getHsnCode(),
                "PCS",                                 // unitOfMeasure
                null,                                  // purchasePrice
                drug.getMrp(),                         // salePrice (MRP until purchase data exists)
                drug.getMrp(),                         // mrp
                drug.getGstRate(),
                true,                                  // trackInventory
                trackBatches,                          // org setting pos.catalog_quick_add_track_batches
                null, null,                            // reorderLevel, reorderQuantity
                null,                                  // barcode
                truncate(drug.getManufacturer(), 100), // manufacturer
                null, null,                            // preferredVendorId, rackLocationId
                null, null, null, null, null, null,    // weight..dimensionUnit
                drug.getDrugSchedule(),
                drug.getSaltComposition(),
                truncate(drug.getDosageForm(), 50),
                truncate(drug.getPackSize(), 50),
                null,                                  // storageCondition
                drug.isPrescriptionRequired(),
                false,                                 // weightBasedBilling
                null, null, null,                      // account codes
                openingStock,                          // openingStock (qty on shelf, billable now)
                warehouseId,                           // openingWarehouseId (null = org default)
                // Batch-tracked quick-adds need a batch for the opening qty
                trackBatches && openingStock != null ? "OPENING" : null,
                null, null,                            // opening mfg/expiry dates
                null, null, null,                      // purchase UoM fields
                null,                                  // secondaryUnits
                null,                                  // groupId
                null);                                 // variantAttributes
    }

    /** SKU from the brand name, e.g. "DOLO-650" + random suffix on collision. */
    private String uniqueSku(UUID orgId, String name) {
        String base = name.toUpperCase(Locale.ROOT)
                .replaceAll("[^A-Z0-9]+", "-")
                .replaceAll("(^-|-$)", "");
        if (base.length() > 40) base = base.substring(0, 40);
        if (base.isBlank()) base = "MED";
        String sku = base;
        while (itemRepository.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, sku)) {
            sku = base + "-" + ThreadLocalRandom.current().nextInt(1000, 9999);
        }
        return sku;
    }

    private static String truncate(String s, int max) {
        return s != null && s.length() > max ? s.substring(0, max) : s;
    }
}
