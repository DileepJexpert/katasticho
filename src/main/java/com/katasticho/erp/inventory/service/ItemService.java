package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.dto.ItemResponse;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.dto.UpdateItemRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemGroup;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.ItemUnitPrice;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Uom;
import com.katasticho.erp.inventory.entity.UomConversion;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemGroupRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.ItemUnitPriceRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.UomConversionRepository;
import com.katasticho.erp.inventory.repository.UomRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
@Slf4j
public class ItemService {

    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final WarehouseRepository warehouseRepository;
    private final InventoryService inventoryService;
    private final AuditService auditService;
    private final UomService uomService;
    private final ItemGroupRepository itemGroupRepository;
    /**
     * Lazy because {@link ItemGroupService} also depends on this
     * service (its matrix bulk-create routes through
     * {@link #createItem}). The proxy breaks the cycle without
     * requiring a setter or extracting a separate "creator" component.
     *
     * <p>Constructor is written by hand (not via Lombok's
     * {@code @RequiredArgsConstructor}) because Lombok drops field-
     * level annotations when generating the constructor, so the
     * {@code @Lazy} must sit directly on the constructor parameter
     * for Spring to honour it.
     */
    private final ItemGroupService itemGroupService;
    private final ContactRepository contactRepository;
    private final UomConversionRepository uomConversionRepository;
    private final ItemUnitPriceRepository itemUnitPriceRepository;
    private final UomRepository uomRepository;

    public ItemService(ItemRepository itemRepository,
                       StockBalanceRepository stockBalanceRepository,
                       WarehouseRepository warehouseRepository,
                       InventoryService inventoryService,
                       AuditService auditService,
                       UomService uomService,
                       ItemGroupRepository itemGroupRepository,
                       @Lazy ItemGroupService itemGroupService,
                       ContactRepository contactRepository,
                       UomConversionRepository uomConversionRepository,
                       ItemUnitPriceRepository itemUnitPriceRepository,
                       UomRepository uomRepository) {
        this.itemRepository = itemRepository;
        this.stockBalanceRepository = stockBalanceRepository;
        this.warehouseRepository = warehouseRepository;
        this.inventoryService = inventoryService;
        this.auditService = auditService;
        this.uomService = uomService;
        this.itemGroupRepository = itemGroupRepository;
        this.itemGroupService = itemGroupService;
        this.contactRepository = contactRepository;
        this.uomConversionRepository = uomConversionRepository;
        this.itemUnitPriceRepository = itemUnitPriceRepository;
        this.uomRepository = uomRepository;
    }

    @Transactional
    public ItemResponse createItem(CreateItemRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // F5: if the request links to an item group, run the request
        // through one-shot inheritance BEFORE the dedupe check so the
        // group's defaults are visible in any error context. The
        // service.applyDefaults call returns a NEW record — never
        // mutates the input — and validateAttributes runs against the
        // group's closed list of allowed keys/values.
        ItemGroup group = null;
        if (request.groupId() != null) {
            group = itemGroupService.loadForCreate(request.groupId());
            if (request.itemType() != null && request.itemType() == ItemType.COMPOSITE) {
                // Composites have their own lifecycle (BOM, no stock,
                // GRN-locked) and don't fit cleanly into the variant
                // template. Block them at the front door — the rule is
                // easy to relax in v2 without a migration.
                throw new BusinessException(
                        "Composite items cannot belong to a variant group in this release",
                        "GROUP_COMPOSITE_NOT_ALLOWED", HttpStatus.BAD_REQUEST);
            }
            itemGroupService.validateAttributes(group, request.variantAttributes());
            request = itemGroupService.applyDefaults(group, request);
        } else if (request.variantAttributes() != null && !request.variantAttributes().isEmpty()) {
            // Attributes without a group make no sense — they would
            // never satisfy a definitions list. Reject loud rather
            // than silently dropping them, so the UI can correct.
            throw new BusinessException(
                    "Variant attributes can only be set on items that belong to a group",
                    "GROUP_REQUIRED_FOR_ATTRIBUTES", HttpStatus.BAD_REQUEST);
        }

        String sku = request.sku().trim();
        if (itemRepository.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, sku)) {
            throw new BusinessException("Item with SKU " + sku + " already exists",
                    "INV_DUPLICATE_SKU", HttpStatus.CONFLICT);
        }

        ItemType itemType = request.itemType() != null ? request.itemType() : ItemType.GOODS;
        // COMPOSITE items never hold stock in their own right — the
        // parent is an abstraction over BOM children. Force trackInventory
        // OFF (the invoice-send explosion path short-circuits the parent
        // before touching the ledger) and reject batch-tracking and
        // opening stock at the DTO level, so the operator sees the
        // constraint up-front instead of a cryptic failure later.
        boolean isComposite = itemType == ItemType.COMPOSITE;
        if (isComposite && Boolean.TRUE.equals(request.trackBatches())) {
            throw new BusinessException(
                    "Composite items cannot be batch-tracked — tracking belongs on the BOM children",
                    "INV_COMPOSITE_BATCH_NOT_ALLOWED", HttpStatus.BAD_REQUEST);
        }
        if (isComposite && request.openingStock() != null
                && request.openingStock().compareTo(BigDecimal.ZERO) > 0) {
            throw new BusinessException(
                    "Composite items cannot carry opening stock — stock the BOM children instead",
                    "INV_COMPOSITE_OPENING_NOT_ALLOWED", HttpStatus.BAD_REQUEST);
        }
        boolean trackInventory = isComposite
                ? false
                : (request.trackInventory() != null
                        ? request.trackInventory()
                        : itemType == ItemType.GOODS);

        String uomAbbr = request.unitOfMeasure() != null ? request.unitOfMeasure() : "PCS";
        UUID baseUomId = uomService.resolveBaseUomIdOrPcs(uomAbbr);

        Item item = Item.builder()
                .sku(sku)
                .name(request.name().trim())
                .description(request.description())
                .itemType(itemType)
                .category(request.category())
                .brand(request.brand())
                .hsnCode(request.hsnCode())
                .unitOfMeasure(uomAbbr)
                .baseUomId(baseUomId)
                .purchasePrice(nz(request.purchasePrice()))
                .salePrice(nz(request.salePrice()))
                .mrp(request.mrp())
                .gstRate(nz(request.gstRate()))
                .trackInventory(trackInventory)
                .trackBatches(Boolean.TRUE.equals(request.trackBatches()))
                .reorderLevel(nz(request.reorderLevel()))
                .reorderQuantity(nz(request.reorderQuantity()))
                .barcode(request.barcode())
                .manufacturer(request.manufacturer())
                .preferredVendorId(request.preferredVendorId())
                .weight(request.weight())
                .weightUnit(request.weightUnit())
                .length(request.length())
                .width(request.width())
                .height(request.height())
                .dimensionUnit(request.dimensionUnit())
                .drugSchedule(request.drugSchedule())
                .composition(request.composition())
                .dosageForm(request.dosageForm())
                .packSize(request.packSize())
                .storageCondition(request.storageCondition())
                .prescriptionRequired(Boolean.TRUE.equals(request.prescriptionRequired()))
                .weightBasedBilling(Boolean.TRUE.equals(request.weightBasedBilling()))
                .revenueAccountCode(request.revenueAccountCode())
                .cogsAccountCode(request.cogsAccountCode())
                .inventoryAccountCode(request.inventoryAccountCode())
                .active(true)
                .groupId(request.groupId())
                .variantAttributes(request.variantAttributes() != null
                        ? new HashMap<>(request.variantAttributes())
                        : new HashMap<>())
                .build();

        // Purchase UoM handling — set fields before save
        if (request.purchaseUom() != null && !request.purchaseUom().isBlank()
                && request.purchaseUomConversion() != null) {
            UUID purchaseUomId = uomService.resolveBaseUomIdOrPcs(request.purchaseUom());
            item.setPurchaseUomId(purchaseUomId);
            item.setPurchaseUomConversion(request.purchaseUomConversion());
            item.setPurchasePricePerUom(request.purchasePricePerUom());
            // Store per-base-unit purchase price: purchasePricePerUom / conversionFactor
            if (request.purchasePricePerUom() != null
                    && request.purchaseUomConversion().compareTo(BigDecimal.ZERO) > 0) {
                item.setPurchasePrice(request.purchasePricePerUom()
                        .divide(request.purchaseUomConversion(), 2, RoundingMode.HALF_UP));
            }
        }

        item = itemRepository.save(item);

        // Create per-item UoM conversion record for purchase unit
        if (item.getPurchaseUomId() != null && item.getBaseUomId() != null
                && !item.getPurchaseUomId().equals(item.getBaseUomId())) {
            UomConversion conv = UomConversion.builder()
                    .itemId(item.getId())
                    .fromUomId(item.getPurchaseUomId())
                    .toUomId(item.getBaseUomId())
                    .factor(item.getPurchaseUomConversion())
                    .build();
            uomConversionRepository.save(conv);
        }

        // Secondary units (additional selling/buying units with optional custom prices)
        if (request.secondaryUnits() != null) {
            for (CreateItemRequest.UnitPriceEntry entry : request.secondaryUnits()) {
                Optional<Uom> uom = uomService.findByAbbreviation(entry.uomAbbreviation());
                if (uom.isEmpty()) continue;
                UUID secUomId = uom.get().getId();

                ItemUnitPrice iup = ItemUnitPrice.builder()
                        .itemId(item.getId())
                        .uomId(secUomId)
                        .conversionFactor(entry.conversionFactor())
                        .customPrice(entry.customPrice())
                        .build();
                itemUnitPriceRepository.save(iup);

                // Also create a UoM conversion record for this secondary unit
                if (!secUomId.equals(item.getBaseUomId())) {
                    UomConversion secConv = UomConversion.builder()
                            .itemId(item.getId())
                            .fromUomId(item.getBaseUomId())
                            .toUomId(secUomId)
                            .factor(BigDecimal.ONE.divide(entry.conversionFactor(), 6, RoundingMode.HALF_UP))
                            .build();
                    uomConversionRepository.save(secConv);
                }
            }
        }

        // Optional opening stock — recorded as an OPENING movement so it shows
        // up in the ledger and audit log just like every other change.
        BigDecimal openingStock = request.openingStock();
        if (trackInventory && openingStock != null && openingStock.compareTo(BigDecimal.ZERO) > 0) {
            UUID warehouseId = request.openingWarehouseId();
            if (warehouseId == null) {
                Warehouse defaultWh = warehouseRepository
                        .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                        .orElseThrow(() -> new BusinessException(
                                "No default warehouse for opening stock",
                                "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));
                warehouseId = defaultWh.getId();
            }
            inventoryService.recordMovement(new StockMovementRequest(
                    item.getId(),
                    warehouseId,
                    MovementType.OPENING,
                    openingStock,
                    item.getPurchasePrice(),
                    LocalDate.now(),
                    ReferenceType.OPENING_BALANCE,
                    null,
                    null,
                    "Opening stock for " + item.getSku()));
        }

        auditService.log("ITEM", item.getId(), "CREATE", null,
                "{\"sku\":\"" + item.getSku() + "\",\"name\":\"" + item.getName() + "\"}");

        log.info("Item {} created: {}", item.getSku(), item.getName());
        return toResponse(item);
    }

    @Transactional
    public ItemResponse updateItem(UUID id, UpdateItemRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", id));

        String newSku = request.sku().trim();
        if (!newSku.equals(item.getSku())
                && itemRepository.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, newSku)) {
            throw new BusinessException("Item with SKU " + newSku + " already exists",
                    "INV_DUPLICATE_SKU", HttpStatus.CONFLICT);
        }

        item.setSku(newSku);
        item.setName(request.name().trim());
        item.setDescription(request.description());
        item.setItemType(request.itemType());
        item.setCategory(request.category());
        item.setBrand(request.brand());
        item.setHsnCode(request.hsnCode());
        if (request.unitOfMeasure() != null) {
            String newUomAbbr = request.unitOfMeasure();
            // Re-resolve the UoM FK only if the abbreviation actually changed.
            // This keeps the legacy string column as the canonical display
            // value while repopulating base_uom_id on every change.
            if (!newUomAbbr.equalsIgnoreCase(item.getUnitOfMeasure())
                    || item.getBaseUomId() == null) {
                item.setBaseUomId(uomService.resolveBaseUomIdOrPcs(newUomAbbr));
            }
            item.setUnitOfMeasure(newUomAbbr);
        } else if (item.getBaseUomId() == null) {
            // Pre-V13 row that was never touched — backfill to PCS now.
            item.setBaseUomId(uomService.resolveBaseUomIdOrPcs(item.getUnitOfMeasure()));
        }
        if (request.purchasePrice() != null) item.setPurchasePrice(request.purchasePrice());
        if (request.salePrice() != null) item.setSalePrice(request.salePrice());
        item.setMrp(request.mrp());
        if (request.gstRate() != null) item.setGstRate(request.gstRate());
        if (request.trackInventory() != null) item.setTrackInventory(request.trackInventory());
        if (request.trackBatches() != null) {
            // Forbid toggling batch tracking while the item still has
            // on-hand stock — existing movements would be orphaned from
            // the new mode. Operators must zero out stock first (or the
            // flip through a data-migration job in a future sprint).
            if (item.isTrackBatches() != request.trackBatches()) {
                BigDecimal onHand = totalOnHand(orgId, item.getId());
                if (onHand.compareTo(BigDecimal.ZERO) != 0) {
                    throw new BusinessException(
                            "Cannot toggle track_batches on " + item.getSku()
                                    + " while on-hand is " + onHand,
                            "INV_TRACK_BATCHES_LOCKED", HttpStatus.CONFLICT);
                }
            }
            item.setTrackBatches(request.trackBatches());
        }
        if (request.reorderLevel() != null) item.setReorderLevel(request.reorderLevel());
        if (request.reorderQuantity() != null) item.setReorderQuantity(request.reorderQuantity());
        item.setBarcode(request.barcode());
        item.setManufacturer(request.manufacturer());
        item.setPreferredVendorId(request.preferredVendorId());
        item.setWeight(request.weight());
        item.setWeightUnit(request.weightUnit());
        item.setLength(request.length());
        item.setWidth(request.width());
        item.setHeight(request.height());
        item.setDimensionUnit(request.dimensionUnit());
        item.setDrugSchedule(request.drugSchedule());
        item.setComposition(request.composition());
        item.setDosageForm(request.dosageForm());
        item.setPackSize(request.packSize());
        item.setStorageCondition(request.storageCondition());
        if (request.prescriptionRequired() != null) item.setPrescriptionRequired(request.prescriptionRequired());
        if (request.weightBasedBilling() != null) item.setWeightBasedBilling(request.weightBasedBilling());
        item.setRevenueAccountCode(request.revenueAccountCode());
        item.setCogsAccountCode(request.cogsAccountCode());
        item.setInventoryAccountCode(request.inventoryAccountCode());
        if (request.active() != null) item.setActive(request.active());

        // Purchase UoM update
        if (request.purchaseUom() != null && !request.purchaseUom().isBlank()
                && request.purchaseUomConversion() != null) {
            UUID purchaseUomId = uomService.resolveBaseUomIdOrPcs(request.purchaseUom());
            item.setPurchaseUomId(purchaseUomId);
            item.setPurchaseUomConversion(request.purchaseUomConversion());
            item.setPurchasePricePerUom(request.purchasePricePerUom());
            if (request.purchasePricePerUom() != null
                    && request.purchaseUomConversion().compareTo(BigDecimal.ZERO) > 0) {
                item.setPurchasePrice(request.purchasePricePerUom()
                        .divide(request.purchaseUomConversion(), 2, RoundingMode.HALF_UP));
            }
        } else if (request.purchaseUom() == null || request.purchaseUom().isBlank()) {
            item.setPurchaseUomId(null);
            item.setPurchaseUomConversion(null);
            item.setPurchasePricePerUom(null);
        }

        item = itemRepository.save(item);

        // Rebuild per-item purchase UoM conversion
        List<UomConversion> existingConversions =
                uomConversionRepository.findByOrgIdAndItemIdAndIsDeletedFalse(orgId, item.getId());
        for (UomConversion c : existingConversions) {
            c.setDeleted(true);
            uomConversionRepository.save(c);
        }
        if (item.getPurchaseUomId() != null && item.getBaseUomId() != null
                && !item.getPurchaseUomId().equals(item.getBaseUomId())) {
            UomConversion conv = UomConversion.builder()
                    .itemId(item.getId())
                    .fromUomId(item.getPurchaseUomId())
                    .toUomId(item.getBaseUomId())
                    .factor(item.getPurchaseUomConversion())
                    .build();
            uomConversionRepository.save(conv);
        }

        // Rebuild secondary units
        List<ItemUnitPrice> existingPrices =
                itemUnitPriceRepository.findByOrgIdAndItemIdAndIsDeletedFalse(orgId, item.getId());
        for (ItemUnitPrice p : existingPrices) {
            p.setDeleted(true);
            itemUnitPriceRepository.save(p);
        }
        if (request.secondaryUnits() != null) {
            for (CreateItemRequest.UnitPriceEntry entry : request.secondaryUnits()) {
                Optional<Uom> uom = uomService.findByAbbreviation(entry.uomAbbreviation());
                if (uom.isEmpty()) continue;
                UUID secUomId = uom.get().getId();
                ItemUnitPrice iup = ItemUnitPrice.builder()
                        .itemId(item.getId())
                        .uomId(secUomId)
                        .conversionFactor(entry.conversionFactor())
                        .customPrice(entry.customPrice())
                        .build();
                itemUnitPriceRepository.save(iup);
                if (!secUomId.equals(item.getBaseUomId())) {
                    UomConversion secConv = UomConversion.builder()
                            .itemId(item.getId())
                            .fromUomId(item.getBaseUomId())
                            .toUomId(secUomId)
                            .factor(BigDecimal.ONE.divide(entry.conversionFactor(), 6, RoundingMode.HALF_UP))
                            .build();
                    uomConversionRepository.save(secConv);
                }
            }
        }

        auditService.log("ITEM", item.getId(), "UPDATE", null, null);
        return toResponse(item);
    }

    @Transactional
    public void deleteItem(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", id));

        // Refuse to delete an item that still holds stock — that would
        // silently strand the inventory.
        BigDecimal totalOnHand = totalOnHand(orgId, item.getId());
        if (totalOnHand.compareTo(BigDecimal.ZERO) != 0) {
            throw new BusinessException(
                    "Cannot delete item " + item.getSku() + " — on-hand quantity is " + totalOnHand,
                    "INV_ITEM_HAS_STOCK", HttpStatus.CONFLICT);
        }

        item.setDeleted(true);
        item.setActive(false);
        itemRepository.save(item);
        auditService.log("ITEM", item.getId(), "DELETE", null, null);
    }

    @Transactional(readOnly = true)
    public ItemResponse getItem(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", id));
        return toResponse(item);
    }

    @Transactional(readOnly = true)
    public Page<ItemResponse> listItems(String search, boolean activeOnly, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<Item> page;
        if (search != null && !search.isBlank()) {
            page = itemRepository.search(orgId, search.trim(), pageable);
        } else if (activeOnly) {
            page = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, pageable);
        } else {
            page = itemRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
        }
        return page.map(this::toResponse);
    }

    public ItemResponse toResponse(Item i) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal totalOnHand = i.isTrackInventory() ? totalOnHand(orgId, i.getId()) : BigDecimal.ZERO;
        String groupName = null;
        if (i.getGroupId() != null) {
            groupName = itemGroupRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(i.getGroupId(), orgId)
                    .map(ItemGroup::getName)
                    .orElse(null);
        }
        Map<String, String> attrs = i.getVariantAttributes() != null
                ? i.getVariantAttributes()
                : new HashMap<>();
        String vendorName = null;
        if (i.getPreferredVendorId() != null) {
            vendorName = contactRepository.findById(i.getPreferredVendorId())
                    .map(Contact::getCompanyName).orElse(null);
        }

        // Purchase UoM abbreviation
        String purchaseUomAbbr = null;
        if (i.getPurchaseUomId() != null) {
            purchaseUomAbbr = uomRepository.findById(i.getPurchaseUomId())
                    .map(Uom::getAbbreviation).orElse(null);
        }

        // Secondary units
        List<ItemResponse.UnitPriceInfo> secondaryUnits = new ArrayList<>();
        if (i.getId() != null) {
            List<ItemUnitPrice> prices = itemUnitPriceRepository
                    .findByOrgIdAndItemIdAndIsDeletedFalse(orgId, i.getId());
            for (ItemUnitPrice p : prices) {
                Uom uom = uomRepository.findById(p.getUomId()).orElse(null);
                if (uom == null) continue;
                secondaryUnits.add(new ItemResponse.UnitPriceInfo(
                        uom.getId(), uom.getAbbreviation(), uom.getName(),
                        p.getConversionFactor(), p.getCustomPrice()));
            }
        }

        return new ItemResponse(
                i.getId(), i.getSku(), i.getBarcode(), i.getName(), i.getDescription(),
                i.getItemType(), i.getCategory(), i.getBrand(), i.getManufacturer(),
                i.getHsnCode(), i.getUnitOfMeasure(),
                i.getPurchasePrice(), i.getSalePrice(), i.getMrp(), i.getGstRate(),
                i.getDefaultTaxGroupId(),
                i.isTrackInventory(), i.isTrackBatches(),
                i.getReorderLevel(), i.getReorderQuantity(),
                i.getPreferredVendorId(), vendorName,
                i.getWeight(), i.getWeightUnit(),
                i.getLength(), i.getWidth(), i.getHeight(), i.getDimensionUnit(),
                i.getDrugSchedule(), i.getComposition(), i.getDosageForm(),
                i.getPackSize(), i.getStorageCondition(), i.isPrescriptionRequired(),
                i.isWeightBasedBilling(),
                i.getRevenueAccountCode(), i.getCogsAccountCode(), i.getInventoryAccountCode(),
                i.isActive(), totalOnHand, i.getCreatedAt(),
                i.getGroupId(), attrs, groupName,
                purchaseUomAbbr, i.getPurchaseUomConversion(), i.getPurchasePricePerUom(),
                secondaryUnits);
    }

    private BigDecimal totalOnHand(UUID orgId, UUID itemId) {
        List<StockBalance> balances = stockBalanceRepository.findByOrgIdAndItemId(orgId, itemId);
        return balances.stream()
                .map(StockBalance::getQuantityOnHand)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
