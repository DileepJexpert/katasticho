package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.ItemImportResult;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Bulk item import from CSV. Reads a header-row CSV, creates items in
 * batch, and records OPENING movements for any item with a positive
 * opening_stock — all through the same gates as the normal item-create
 * flow, so audit trails and balance caches stay consistent.
 *
 * Expected columns (case-insensitive headers):
 *   sku            (required)
 *   name           (required)
 *   description    (optional)
 *   item_type      (optional, default GOODS — values: GOODS / SERVICE)
 *   category       (optional)
 *   brand          (optional)
 *   hsn_code       (optional)
 *   unit_of_measure (optional, default PCS)
 *   purchase_price (optional, default 0)
 *   sale_price     (optional, default 0)
 *   mrp            (optional)
 *   gst_rate       (optional, default 0)
 *   reorder_level  (optional, default 0)
 *   reorder_quantity (optional, default 0)
 *   opening_stock  (optional, default 0)
 *
 * Rows that fail validation are reported in {@link ItemImportResult#errors()}
 * and skipped — the rest of the import still proceeds.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ItemImportService {

    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final InventoryService inventoryService;
    private final AuditService auditService;

    @Transactional
    public ItemImportResult importItems(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Upload file is required",
                    "IMPORT_EMPTY_FILE", HttpStatus.BAD_REQUEST);
        }

        UUID orgId = TenantContext.getCurrentOrgId();
        Warehouse defaultWarehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException(
                        "No default warehouse configured for opening stock",
                        "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));

        List<ItemImportResult.RowError> errors = new ArrayList<>();
        Set<String> seenSkusInFile = new HashSet<>();
        int created = 0;
        int totalRows = 0;

        List<Map<String, String>> rows;
        try (Reader reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8)) {
            rows = SimpleCsvParser.parse(reader);
        } catch (IOException e) {
            log.error("Failed to parse CSV file", e);
            throw new BusinessException("Failed to parse CSV: " + e.getMessage(),
                    "IMPORT_PARSE_FAILED", HttpStatus.BAD_REQUEST);
        }

        for (int i = 0; i < rows.size(); i++) {
            Map<String, String> row = rows.get(i);
            totalRows++;
            int rowNumber = i + 2; // +1 for the header row, +1 because rows are 1-indexed for humans

            String sku = get(row, "sku");
            String name = get(row, "name");

            if (sku == null || sku.isBlank()) {
                errors.add(new ItemImportResult.RowError(rowNumber, null, "SKU is required"));
                continue;
            }
            if (name == null || name.isBlank()) {
                errors.add(new ItemImportResult.RowError(rowNumber, sku, "Name is required"));
                continue;
            }

            if (!seenSkusInFile.add(sku)) {
                errors.add(new ItemImportResult.RowError(rowNumber, sku, "Duplicate SKU within file"));
                continue;
            }

            if (itemRepository.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, sku)) {
                errors.add(new ItemImportResult.RowError(rowNumber, sku, "SKU already exists in this org"));
                continue;
            }

            ItemType itemType;
            try {
                String typeStr = get(row, "item_type");
                itemType = (typeStr == null || typeStr.isBlank())
                        ? ItemType.GOODS
                        : ItemType.valueOf(typeStr.trim().toUpperCase());
            } catch (IllegalArgumentException e) {
                errors.add(new ItemImportResult.RowError(rowNumber, sku,
                        "item_type must be GOODS or SERVICE"));
                continue;
            }

            BigDecimal purchasePrice;
            BigDecimal salePrice;
            BigDecimal mrp;
            BigDecimal gstRate;
            BigDecimal reorderLevel;
            BigDecimal reorderQty;
            BigDecimal openingStock;
            try {
                purchasePrice = parseDecimal(row, "purchase_price", BigDecimal.ZERO);
                salePrice = parseDecimal(row, "sale_price", BigDecimal.ZERO);
                mrp = parseDecimal(row, "mrp", null);
                gstRate = parseDecimal(row, "gst_rate", BigDecimal.ZERO);
                reorderLevel = parseDecimal(row, "reorder_level", BigDecimal.ZERO);
                reorderQty = parseDecimal(row, "reorder_quantity", BigDecimal.ZERO);
                openingStock = parseDecimal(row, "opening_stock", BigDecimal.ZERO);
            } catch (NumberFormatException e) {
                errors.add(new ItemImportResult.RowError(rowNumber, sku,
                        "Invalid number: " + e.getMessage()));
                continue;
            }

            boolean trackInventory = itemType == ItemType.GOODS;

            Item item = Item.builder()
                    .sku(sku.trim())
                    .name(name.trim())
                    .description(get(row, "description"))
                    .itemType(itemType)
                    .category(get(row, "category"))
                    .brand(get(row, "brand"))
                    .hsnCode(get(row, "hsn_code"))
                    .unitOfMeasure(orDefault(get(row, "unit_of_measure"), "PCS"))
                    .purchasePrice(purchasePrice)
                    .salePrice(salePrice)
                    .mrp(mrp)
                    .gstRate(gstRate)
                    .trackInventory(trackInventory)
                    .reorderLevel(reorderLevel)
                    .reorderQuantity(reorderQty)
                    .active(true)
                    .build();

            item = itemRepository.save(item);
            created++;

            // Record opening stock through the single inventory gate so the
            // import behaves identically to the manual create flow.
            if (trackInventory && openingStock.compareTo(BigDecimal.ZERO) > 0) {
                inventoryService.recordMovement(new StockMovementRequest(
                        item.getId(),
                        defaultWarehouse.getId(),
                        MovementType.OPENING,
                        openingStock,
                        purchasePrice,
                        LocalDate.now(),
                        ReferenceType.OPENING_BALANCE,
                        null,
                        null,
                        "Opening stock from bulk import for " + sku));
            }
        }

        auditService.log("ITEM_IMPORT", null, "BULK_IMPORT", null,
                "{\"total\":" + totalRows + ",\"created\":" + created + ",\"skipped\":" + (totalRows - created) + "}");

        log.info("Item bulk import done: {} total, {} created, {} skipped",
                totalRows, created, totalRows - created);

        return new ItemImportResult(totalRows, created, totalRows - created, errors);
    }

    private static String get(Map<String, String> row, String key) {
        String value = row.get(key);
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static String orDefault(String value, String def) {
        return value == null || value.isBlank() ? def : value;
    }

    private static BigDecimal parseDecimal(Map<String, String> row, String key, BigDecimal def) {
        String raw = get(row, key);
        if (raw == null) return def;
        return new BigDecimal(raw);
    }
}
