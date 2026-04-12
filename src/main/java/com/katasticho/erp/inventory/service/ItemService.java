package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.dto.ItemResponse;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.dto.UpdateItemRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ItemService {

    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final WarehouseRepository warehouseRepository;
    private final InventoryService inventoryService;
    private final AuditService auditService;

    @Transactional
    public ItemResponse createItem(CreateItemRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String sku = request.sku().trim();
        if (itemRepository.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, sku)) {
            throw new BusinessException("Item with SKU " + sku + " already exists",
                    "INV_DUPLICATE_SKU", HttpStatus.CONFLICT);
        }

        ItemType itemType = request.itemType() != null ? request.itemType() : ItemType.GOODS;
        boolean trackInventory = request.trackInventory() != null
                ? request.trackInventory()
                : itemType == ItemType.GOODS;

        Item item = Item.builder()
                .sku(sku)
                .name(request.name().trim())
                .description(request.description())
                .itemType(itemType)
                .category(request.category())
                .brand(request.brand())
                .hsnCode(request.hsnCode())
                .unitOfMeasure(request.unitOfMeasure() != null ? request.unitOfMeasure() : "PCS")
                .purchasePrice(nz(request.purchasePrice()))
                .salePrice(nz(request.salePrice()))
                .mrp(request.mrp())
                .gstRate(nz(request.gstRate()))
                .trackInventory(trackInventory)
                .reorderLevel(nz(request.reorderLevel()))
                .reorderQuantity(nz(request.reorderQuantity()))
                .revenueAccountCode(request.revenueAccountCode())
                .cogsAccountCode(request.cogsAccountCode())
                .inventoryAccountCode(request.inventoryAccountCode())
                .active(true)
                .build();

        item = itemRepository.save(item);

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
        if (request.unitOfMeasure() != null) item.setUnitOfMeasure(request.unitOfMeasure());
        if (request.purchasePrice() != null) item.setPurchasePrice(request.purchasePrice());
        if (request.salePrice() != null) item.setSalePrice(request.salePrice());
        item.setMrp(request.mrp());
        if (request.gstRate() != null) item.setGstRate(request.gstRate());
        if (request.trackInventory() != null) item.setTrackInventory(request.trackInventory());
        if (request.reorderLevel() != null) item.setReorderLevel(request.reorderLevel());
        if (request.reorderQuantity() != null) item.setReorderQuantity(request.reorderQuantity());
        item.setRevenueAccountCode(request.revenueAccountCode());
        item.setCogsAccountCode(request.cogsAccountCode());
        item.setInventoryAccountCode(request.inventoryAccountCode());
        if (request.active() != null) item.setActive(request.active());

        item = itemRepository.save(item);
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
        return new ItemResponse(
                i.getId(), i.getSku(), i.getName(), i.getDescription(), i.getItemType(),
                i.getCategory(), i.getBrand(), i.getHsnCode(), i.getUnitOfMeasure(),
                i.getPurchasePrice(), i.getSalePrice(), i.getMrp(), i.getGstRate(),
                i.isTrackInventory(), i.getReorderLevel(), i.getReorderQuantity(),
                i.getRevenueAccountCode(), i.getCogsAccountCode(), i.getInventoryAccountCode(),
                i.isActive(), totalOnHand, i.getCreatedAt());
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
