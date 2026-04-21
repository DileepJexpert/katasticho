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
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
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
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Bulk item import from CSV / XLSX. Supports a two-phase flow:
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
 *   sku              (required)
 *   name             (required)
 *   description      (optional)
 *   item_type        (optional, default GOODS — values: GOODS / SERVICE)
 *   category         (optional)
 *   brand            (optional)
 *   hsn_code         (optional)
 *   unit_of_measure  (optional, default PCS)
 *   purchase_price   (optional, default 0)
 *   sale_price       (optional, default 0)
 *   mrp              (optional)
 *   gst_rate         (optional, default 0)
 *   reorder_level    (optional, default 0)
 *   reorder_quantity (optional, default 0)
 *   opening_stock    (optional, default 0)
 *   barcode          (optional)
 *   manufacturer     (optional)
 *   batch_number     (optional — triggers batch creation when non-empty)
 *   mfg_date         (optional, ISO yyyy-MM-dd)
 *   expiry_date      (optional, ISO yyyy-MM-dd)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ItemImportService {

    private static final String STATUS_OK = "OK";
    private static final String STATUS_ERROR = "ERROR";

    private static final Set<String> XLSX_CONTENT_TYPES = Set.of(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-excel"
    );

    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final InventoryService inventoryService;
    private final StockBatchRepository stockBatchRepository;
    private final AuditService auditService;
    private final UomService uomService;

    public static final String TEMPLATE_HEADER =
            "sku,name,description,item_type,category,brand,hsn_code,"
            + "unit_of_measure,purchase_price,sale_price,mrp,gst_rate,"
            + "reorder_level,reorder_quantity,opening_stock,"
            + "barcode,manufacturer,batch_number,mfg_date,expiry_date";

    /**
     * Dry-run validator — parse the file, validate every row, return a
     * per-row verdict so the UI can show a preview grid.
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

            if (p.batchNumber != null && !p.batchNumber.isBlank()) {
                StockBatch batch = StockBatch.builder()
                        .itemId(saved.getId())
                        .batchNumber(p.batchNumber.trim())
                        .manufacturingDate(p.mfgDate)
                        .expiryDate(p.expiryDate)
                        .unitCost(p.itemTemplate.getPurchasePrice())
                        .build();
                stockBatchRepository.save(batch);

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
                            "Opening stock from bulk import for " + p.preview.sku(),
                            batch.getId()));
                }
            } else if (p.trackInventory && p.openingStock != null
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

    private List<ParsedRow> parseAndValidate(MultipartFile file, UUID orgId) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Upload file is required",
                    "IMPORT_EMPTY_FILE", HttpStatus.BAD_REQUEST);
        }

        List<Map<String, String>> rows = parseFile(file);

        List<ParsedRow> out = new ArrayList<>(rows.size());
        Set<String> seenSkusInFile = new HashSet<>();

        for (int i = 0; i < rows.size(); i++) {
            Map<String, String> row = rows.get(i);
            int rowNumber = i + 2;

            String sku = get(row, "sku");
            String name = get(row, "name");
            String itemTypeRaw = get(row, "item_type");
            String category = get(row, "category");
            String hsn = get(row, "hsn_code");
            String uom = orDefault(get(row, "unit_of_measure"), "PCS");

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

            String barcode = get(row, "barcode");
            String manufacturer = get(row, "manufacturer");
            String batchNumber = get(row, "batch_number");
            LocalDate mfgDate = null;
            LocalDate expiryDate = null;

            String mfgDateRaw = get(row, "mfg_date");
            String expiryDateRaw = get(row, "expiry_date");
            try {
                if (mfgDateRaw != null && !mfgDateRaw.isBlank()) {
                    mfgDate = LocalDate.parse(mfgDateRaw.trim());
                }
                if (expiryDateRaw != null && !expiryDateRaw.isBlank()) {
                    expiryDate = LocalDate.parse(expiryDateRaw.trim());
                }
            } catch (DateTimeParseException e) {
                out.add(ParsedRow.error(rowNumber, sku, name, itemTypeRaw,
                        category, hsn, uom, "Invalid date (use yyyy-MM-dd): " + e.getMessage()));
                continue;
            }

            boolean trackInventory = itemType == ItemType.GOODS;
            boolean hasBatch = batchNumber != null && !batchNumber.isBlank();

            UUID baseUomId = uomService.resolveBaseUomIdOrPcs(uom);

            Item item = Item.builder()
                    .sku(sku.trim())
                    .name(name.trim())
                    .description(get(row, "description"))
                    .itemType(itemType)
                    .category(category)
                    .brand(get(row, "brand"))
                    .hsnCode(hsn)
                    .barcode(barcode)
                    .manufacturer(manufacturer)
                    .unitOfMeasure(uom)
                    .baseUomId(baseUomId)
                    .purchasePrice(purchasePrice)
                    .salePrice(salePrice)
                    .mrp(mrp)
                    .gstRate(gstRate)
                    .trackInventory(trackInventory)
                    .trackBatches(hasBatch)
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

            out.add(new ParsedRow(preview, item, openingStock, trackInventory,
                    batchNumber, mfgDate, expiryDate));
        }

        return out;
    }

    private List<Map<String, String>> parseFile(MultipartFile file) {
        String filename = file.getOriginalFilename();
        String contentType = file.getContentType();

        boolean isExcel = (filename != null && filename.toLowerCase().endsWith(".xlsx"))
                || (contentType != null && XLSX_CONTENT_TYPES.contains(contentType));

        if (isExcel) {
            try {
                return ExcelParser.parse(file.getInputStream());
            } catch (IOException e) {
                log.error("Failed to parse Excel file", e);
                throw new BusinessException("Failed to parse Excel file: " + e.getMessage(),
                        "IMPORT_PARSE_FAILED", HttpStatus.BAD_REQUEST);
            }
        }

        try (Reader reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8)) {
            return SimpleCsvParser.parse(reader);
        } catch (IOException e) {
            log.error("Failed to parse CSV file", e);
            throw new BusinessException("Failed to parse CSV: " + e.getMessage(),
                    "IMPORT_PARSE_FAILED", HttpStatus.BAD_REQUEST);
        }
    }

    private record ParsedRow(
            ItemImportPreview.RowPreview preview,
            Item itemTemplate,
            BigDecimal openingStock,
            boolean trackInventory,
            String batchNumber,
            LocalDate mfgDate,
            LocalDate expiryDate
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
                    false,
                    null,
                    null,
                    null);
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
