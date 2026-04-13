package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.inventory.dto.BomComponentRequest;
import com.katasticho.erp.inventory.dto.BomComponentResponse;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.dto.ItemImportPreview;
import com.katasticho.erp.inventory.dto.ItemImportResult;
import com.katasticho.erp.inventory.dto.ItemResponse;
import com.katasticho.erp.inventory.dto.UpdateItemRequest;
import com.katasticho.erp.inventory.service.BomService;
import com.katasticho.erp.inventory.service.ItemImportService;
import com.katasticho.erp.inventory.service.ItemService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/items")
@RequiredArgsConstructor
public class ItemController {

    private final ItemService itemService;
    private final ItemImportService itemImportService;
    private final BomService bomService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemResponse>> createItem(@Valid @RequestBody CreateItemRequest request) {
        ItemResponse item = itemService.createItem(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(item));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ItemResponse>> getItem(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(itemService.getItem(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<ItemResponse>>> listItems(
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "false") boolean activeOnly,
            Pageable pageable) {
        Page<ItemResponse> page = itemService.listItems(search, activeOnly, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemResponse>> updateItem(
            @PathVariable UUID id, @Valid @RequestBody UpdateItemRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(itemService.updateItem(id, request), "Item updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteItem(@PathVariable UUID id) {
        itemService.deleteItem(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Item deleted"));
    }

    /**
     * Bulk import items from a CSV upload — COMMIT phase.
     * Form field name: {@code file}. Headers must include {@code sku} and
     * {@code name}; everything else is optional. Rows that fail validation
     * are skipped and reported in the response, but the rest of the file
     * still imports.
     */
    @PostMapping(value = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemImportResult>> importItems(
            @RequestParam("file") MultipartFile file) {
        ItemImportResult result = itemImportService.importItems(file);
        String message = result.created() + " items imported, " + result.skipped() + " skipped";
        return ResponseEntity.ok(ApiResponse.ok(result, message));
    }

    /**
     * Bulk import items — DRY-RUN / PREVIEW phase. Parses + validates every
     * row and returns a per-row verdict (OK / ERROR) so the UI can show a
     * preview grid before the user commits. Writes nothing to the database.
     */
    @PostMapping(value = "/import/preview", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemImportPreview>> previewImport(
            @RequestParam("file") MultipartFile file) {
        ItemImportPreview preview = itemImportService.previewImport(file);
        String message = preview.validRows() + " valid, " + preview.errorRows() + " with errors";
        return ResponseEntity.ok(ApiResponse.ok(preview, message));
    }

    // ── Composite items / BOM (Feature 4) ───────────────────────────────
    //
    // Endpoints live under the parent item so the URL mirrors the
    // conceptual relationship — "/items/{id}/bom" reads as "the BOM of
    // this item". The invoice-send explosion is an internal path and
    // never called over HTTP.

    @PostMapping("/{id}/bom")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<BomComponentResponse>> addBomComponent(
            @PathVariable UUID id,
            @Valid @RequestBody BomComponentRequest request) {
        BomComponentResponse response = BomComponentResponse.from(
                bomService.addComponent(id, request));
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @GetMapping("/{id}/bom")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<BomComponentResponse>>> listBomComponents(
            @PathVariable UUID id) {
        // Enriched variant joins each row with the child's SKU + name
        // so the Flutter item-detail screen can render "2 × WIDGET-BLUE"
        // without an N+1 fetch.
        List<BomComponentResponse> result = bomService.listComponentsEnriched(id);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @DeleteMapping("/bom/{componentId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Void>> deleteBomComponent(
            @PathVariable UUID componentId) {
        bomService.deleteComponent(componentId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
