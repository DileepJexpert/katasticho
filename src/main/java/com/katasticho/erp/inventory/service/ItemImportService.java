package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.ItemImportPreview;
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
 * Bulk item import from CSV. Supports a two-phase flow:
 *
 *   1. {@link #previewImport(MultipartFile)} — dry-run, parses + validates
 *      every row and returns a row-level verdict for the UI preview grid.
 *      Writes NOTHING to the database.
 *   2. {@link #importItems(MultipartFile)} — runs the exact same parse +
 *      validate pass, then persists valid rows and posts opening-stock
 *      movements for goods with positive starting inventory.
 *
 * Both methods share {@link #parseAndValidate(MultipartFile, UUID)} so the
 * preview grid and the committed import can never drift out of sync.
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
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ItemImportService {

    private static final String STATUS_OK = "OK";
    private static final String STATUS_ERROR = "ERROR";

    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final InventoryService inventoryService;
    private final AuditService auditService;

    /**
     * Dry-run validator — parse the CSV, validate every row, return a
     * per-row verdict so the UI can show a preview grid. NO database
     * writes, NO audit log entry.
     */
    public ItemImportPreview previewImport(MultipartFile file) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<ParsedRow> parsed = parseAndValidate(file, orgId);

        List<ItemImportPreview.RowPreview> previews = new ArrayList<>(parsed.size());
        int valid = 0;
        for (ParsedRow p : parsed) {
            previews.add(p.preview);
            if (STATUS_OK.equals(p.preview.status())) valid++;
        }
        int errors = parsed.size() - valid;
        log.info("Item import preview: {} total, {} valid, {} errors",
                parsed.size(), valid, errors);
        return new ItemImportPreview(parsed.size(), valid, errors, previews);
    }

    /**
     * Commit a bulk import. Valid rows are persisted; invalid rows are
     * skipped and reported in {@link ItemImportResult#errors()}.
     */
    @Transactional
    public ItemImportResult importItems(MultipartFile file) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Warehouse defaultWarehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException(
                        "No default warehouse configured for opening stock",
                        "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));

        List<ParsedRow> parsed = parseAndValidate(file, orgId);

        List<ItemImportResult.RowError> errors = new ArrayList<>();
        int created = 0;

        for (ParsedRow p : parsed) {
            if (!STATUS_OK.equals(p.preview.status())) {
                errors.add(new ItemImportResult.RowError(
                        p.preview.rowNumber(),
                        p.preview.sku(),
                        p.preview.error()));
                continue;
            }

            Item saved = itemRepository.save(p.itemTemplate);
            created++;

            // Opening stock goes through the single inventory gate so bulk
            // import behaves identically to the manual create flow.
            if (p.trackInventory && p.openingStock != null
                    && p.openingStock.compareTo(BigDecimal.ZERO) > 0) {
                inventoryService.recordMovement(new StockMovementRequest(
                        saved.getId(),
                        defaultWarehouse.getId(),
                        MovementType.OPENING,
                        p.openingStock,
                        p.itemTemplate.getPurchasePrice(),
                        LocalDate.now(),
                        ReferenceType.OPENING_BALANCE,
                        null,
                        null,
                        "Opening stock from bulk import for " + p.preview.sku()));
            }
        }

        int totalRows = parsed.size();
        auditService.log("ITEM_IMPORT", null, "BULK_IMPORT", null,
                "{\"total\":" + totalRows + ",\"created\":" + created + ",\"skipped\":" + (totalRows - created) + "}");

        log.info("Item bulk import done: {} total, {} created, {} skipped",
                totalRows, created, totalRows - created);

        return new ItemImportResult(totalRows, created, totalRows - created, errors);
    }

    // ── Shared parse + validate pipeline ─────────────────────────────

    /**
     * Parse the CSV once, validate every row, and return a list of
     * {@link ParsedRow} holding BOTH a UI-ready preview DTO and (for
     * valid rows) a fully-built but unsaved {@link Item} entity. Shared
     * by preview and commit so they stay aligned.
     */
    private List<ParsedRow> parseAndValidate(MultipartFile file, UUID orgId) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Upload file is required",
                    "IMPORT_EMPTY_FILE", HttpStatus.BAD_REQUEST);
        }

        List<Map<String, String>> rows;
        try (Reader reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8)) {
            rows = SimpleCsvParser.parse(reader);
        } catch (IOException e) {
            log.error("Failed to parse CSV file", e);
            throw new BusinessException("Failed to parse CSV: " + e.getMessage(),
                    "IMPORT_PARSE_FAILED", HttpStatus.BAD_REQUEST);
        }

        List<ParsedRow> out = new ArrayList<>(rows.size());
        Set<String> seenSkusInFile = new HashSet<>();

        for (int i = 0; i < rows.size(); i++) {
            Map<String, String> row = rows.get(i);
            int rowNumber = i + 2; // +1 for header, +1 because rows are 1-indexed for humans

            String sku = get(row, "sku");
            String name = get(row, "name");
            String itemTypeRaw = get(row, "item_type");
            String category = get(row, "category");
            String hsn = get(row, "hsn_code");
            String uom = orDefault(get(row, "unit_of_measure"), "PCS");

            // ── Required fields ──────────────────────────────────
            if (sku == null || sku.isBlank()) {
                out.add(ParsedRow.error(rowNumber, null, name, itemTypeRaw,
                        category, hsn, uom, "SKU is required"));
                continue;
            }
            if (name == null || name.isBlank()) {
                out.add(ParsedRow.error(rowNumber, sku, null, itemTypeRaw,
                        category, hsn, uom, "Name is required"));
                continue;
            }

            // ── Duplicate detection ──────────────────────────────
            if (!seenSkusInFile.add(sku)) {
                out.add(ParsedRow.error(rowNumber, sku, name, itemTypeRaw,
                        category, hsn, uom, "Duplicate SKU within file"));
                continue;
            }
            if (itemRepository.existsByOrgIdAndSkuAndIsDeletedFalse(orgId, sku)) {
                out.add(ParsedRow.error(rowNumber, sku, name, itemTypeRaw,
                        category, hsn, uom, "SKU already exists in this org"));
                continue;
            }

            // ── item_type ────────────────────────────────────────
            ItemType itemType;
            try {
                itemType = (itemTypeRaw == null || itemTypeRaw.isBlank())
                        ? ItemType.GOODS
                        : ItemType.valueOf(itemTypeRaw.trim().toUpperCase());
            } catch (IllegalArgumentException e) {
                out.add(ParsedRow.error(rowNumber, sku, name, itemTypeRaw,
                        category, hsn, uom, "item_type must be GOODS or SERVICE"));
                continue;
            }

            // ── Numeric fields ───────────────────────────────────
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
                out.add(ParsedRow.error(rowNumber, sku, name, itemTypeRaw,
                        category, hsn, uom, "Invalid number: " + e.getMessage()));
                continue;
            }

            boolean trackInventory = itemType == ItemType.GOODS;

            Item item = Item.builder()
                    .sku(sku.trim())
                    .name(name.trim())
                    .description(get(row, "description"))
                    .itemType(itemType)
                    .category(category)
                    .brand(get(row, "brand"))
                    .hsnCode(hsn)
                    .unitOfMeasure(uom)
                    .purchasePrice(purchasePrice)
                    .salePrice(salePrice)
                    .mrp(mrp)
                    .gstRate(gstRate)
                    .trackInventory(trackInventory)
                    .reorderLevel(reorderLevel)
                    .reorderQuantity(reorderQty)
                    .active(true)
                    .build();

            ItemImportPreview.RowPreview preview = new ItemImportPreview.RowPreview(
                    rowNumber,
                    sku,
                    name,
                    itemType.name(),
                    category,
                    hsn,
                    uom,
                    purchasePrice,
                    salePrice,
                    gstRate,
                    openingStock,
                    STATUS_OK,
                    null);

            out.add(new ParsedRow(preview, item, openingStock, trackInventory));
        }

        return out;
    }

    /**
     * Intermediate struct shared between preview and commit. For valid
     * rows, {@code itemTemplate} is a fully-built but UNSAVED entity;
     * for error rows it's null and {@code preview.status() == ERROR}.
     */
    private record ParsedRow(
            ItemImportPreview.RowPreview preview,
            Item itemTemplate,
            BigDecimal openingStock,
            boolean trackInventory
    ) {
        static ParsedRow error(int rowNumber, String sku, String name,
                               String itemType, String category, String hsn,
                               String uom, String message) {
            return new ParsedRow(
                    new ItemImportPreview.RowPreview(
                            rowNumber, sku, name, itemType, category, hsn, uom,
                            null, null, null, null,
                            STATUS_ERROR, message),
                    null,
                    null,
                    false);
        }
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
