package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemPackagingBarcode;
import com.katasticho.erp.inventory.repository.ItemPackagingBarcodeRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ItemPackagingBarcodeService {

    private final ItemPackagingBarcodeRepository packagingBarcodeRepository;
    private final ItemRepository itemRepository;

    public record PackagingBarcodeRequest(
            String barcode,
            String packagingLevel,
            String packagingName,
            BigDecimal conversionFactor,
            String uomName,
            BigDecimal mrp,
            BigDecimal salePrice,
            BigDecimal purchasePrice,
            Boolean isPrimary,
            String notes
    ) {}

    public record PackagingBarcodeResponse(
            UUID id,
            UUID itemId,
            String itemName,
            String itemSku,
            String barcode,
            String packagingLevel,
            String packagingName,
            BigDecimal conversionFactor,
            String uomName,
            BigDecimal mrp,
            BigDecimal salePrice,
            BigDecimal purchasePrice,
            boolean isPrimary,
            String notes
    ) {}

    public record ResolvedBarcodeResponse(
            UUID itemId,
            String itemName,
            String sku,
            String itemBarcode,
            String scannedBarcode,
            String packagingLevel,
            String packagingName,
            BigDecimal conversionFactor,
            BigDecimal quantityMultiplier,
            BigDecimal unitPrice,
            String uomName,
            boolean isHierarchyMatch
    ) {}

    @Transactional
    public PackagingBarcodeResponse addBarcode(UUID itemId, PackagingBarcodeRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));

        if (req.barcode() == null || req.barcode().isBlank()) {
            throw new BusinessException("Barcode string cannot be empty", "INV_BARCODE_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        // Check if barcode already exists in hierarchy table for this org
        packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, req.barcode().trim())
                .ifPresent(existing -> {
                    throw new BusinessException("Barcode '" + req.barcode() + "' is already assigned to an item",
                            "INV_BARCODE_DUPLICATE", HttpStatus.CONFLICT);
                });

        BigDecimal factor = req.conversionFactor() != null && req.conversionFactor().compareTo(BigDecimal.ZERO) > 0
                ? req.conversionFactor()
                : BigDecimal.ONE;

        ItemPackagingBarcode entity = ItemPackagingBarcode.builder()
                .itemId(itemId)
                .barcode(req.barcode().trim())
                .packagingLevel(req.packagingLevel() != null ? req.packagingLevel() : "UNIT")
                .packagingName(req.packagingName())
                .conversionFactor(factor)
                .uomName(req.uomName() != null ? req.uomName() : item.getUnitOfMeasure())
                .mrp(req.mrp() != null ? req.mrp() : item.getMrp())
                .salePrice(req.salePrice() != null ? req.salePrice() : item.getSalePrice())
                .purchasePrice(req.purchasePrice() != null ? req.purchasePrice() : item.getPurchasePrice())
                .isPrimary(Boolean.TRUE.equals(req.isPrimary()))
                .notes(req.notes())
                .build();
        entity.setOrgId(orgId);

        entity = packagingBarcodeRepository.save(entity);
        return toResponse(entity, item);
    }

    @Transactional
    public PackagingBarcodeResponse updateBarcode(UUID id, PackagingBarcodeRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemPackagingBarcode entity = packagingBarcodeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemPackagingBarcode", id));

        UUID itemId = entity.getItemId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));

        if (req.barcode() != null && !req.barcode().isBlank()) {
            entity.setBarcode(req.barcode().trim());
        }
        if (req.packagingLevel() != null) {
            entity.setPackagingLevel(req.packagingLevel());
        }
        if (req.packagingName() != null) {
            entity.setPackagingName(req.packagingName());
        }
        if (req.conversionFactor() != null && req.conversionFactor().compareTo(BigDecimal.ZERO) > 0) {
            entity.setConversionFactor(req.conversionFactor());
        }
        if (req.uomName() != null) {
            entity.setUomName(req.uomName());
        }
        if (req.mrp() != null) {
            entity.setMrp(req.mrp());
        }
        if (req.salePrice() != null) {
            entity.setSalePrice(req.salePrice());
        }
        if (req.purchasePrice() != null) {
            entity.setPurchasePrice(req.purchasePrice());
        }
        if (req.isPrimary() != null) {
            entity.setPrimary(req.isPrimary());
        }
        if (req.notes() != null) {
            entity.setNotes(req.notes());
        }

        entity = packagingBarcodeRepository.save(entity);
        return toResponse(entity, item);
    }

    @Transactional
    public void deleteBarcode(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemPackagingBarcode entity = packagingBarcodeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ItemPackagingBarcode", id));
        entity.setDeleted(true);
        packagingBarcodeRepository.save(entity);
    }

    @Transactional(readOnly = true)
    public List<PackagingBarcodeResponse> listBarcodesForItem(UUID itemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));

        List<ItemPackagingBarcode> list = packagingBarcodeRepository
                .findByOrgIdAndItemIdAndIsDeletedFalseOrderByConversionFactorAsc(orgId, itemId);

        return list.stream().map(e -> toResponse(e, item)).toList();
    }

    @Transactional(readOnly = true)
    public ResolvedBarcodeResponse resolveBarcode(String barcode) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String trimmed = barcode != null ? barcode.trim() : "";
        if (trimmed.isEmpty()) {
            throw new BusinessException("Barcode cannot be empty", "INV_BARCODE_EMPTY", HttpStatus.BAD_REQUEST);
        }

        // 1. Try resolving via Packaging Hierarchy Barcode table
        var pkgOpt = packagingBarcodeRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, trimmed);
        if (pkgOpt.isPresent()) {
            ItemPackagingBarcode pkg = pkgOpt.get();
            UUID pkgItemId = pkg.getItemId();
            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(pkgItemId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", pkgItemId));

            BigDecimal price = pkg.getSalePrice() != null ? pkg.getSalePrice() : item.getSalePrice();
            return new ResolvedBarcodeResponse(
                    item.getId(),
                    item.getName(),
                    item.getSku(),
                    item.getBarcode(),
                    trimmed,
                    pkg.getPackagingLevel(),
                    pkg.getPackagingName() != null ? pkg.getPackagingName() : pkg.getPackagingLevel(),
                    pkg.getConversionFactor(),
                    pkg.getConversionFactor(), // Quantity multiplier to base UoM
                    price,
                    pkg.getUomName() != null ? pkg.getUomName() : item.getUnitOfMeasure(),
                    true
            );
        }

        // 2. Fall back to Base Item Barcode / SKU
        var itemOpt = itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, trimmed);
        if (itemOpt.isPresent()) {
            Item item = itemOpt.get();
            return new ResolvedBarcodeResponse(
                    item.getId(),
                    item.getName(),
                    item.getSku(),
                    item.getBarcode(),
                    trimmed,
                    "UNIT",
                    "Base Unit",
                    BigDecimal.ONE,
                    BigDecimal.ONE,
                    item.getSalePrice(),
                    item.getUnitOfMeasure(),
                    false
            );
        }

        throw new BusinessException("No item or packaging hierarchy found with barcode: " + trimmed,
                "INV_BARCODE_NOT_FOUND", HttpStatus.NOT_FOUND);
    }

    private PackagingBarcodeResponse toResponse(ItemPackagingBarcode entity, Item item) {
        return new PackagingBarcodeResponse(
                entity.getId(),
                entity.getItemId(),
                item.getName(),
                item.getSku(),
                entity.getBarcode(),
                entity.getPackagingLevel(),
                entity.getPackagingName(),
                entity.getConversionFactor(),
                entity.getUomName(),
                entity.getMrp(),
                entity.getSalePrice(),
                entity.getPurchasePrice(),
                entity.isPrimary(),
                entity.getNotes()
        );
    }
}
