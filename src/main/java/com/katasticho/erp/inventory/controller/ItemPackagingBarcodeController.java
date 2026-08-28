package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.service.ItemPackagingBarcodeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/packaging-barcodes")
@RequiredArgsConstructor
public class ItemPackagingBarcodeController {

    private final ItemPackagingBarcodeService packagingBarcodeService;

    @GetMapping("/items/{itemId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<ItemPackagingBarcodeService.PackagingBarcodeResponse>>> listBarcodes(
            @PathVariable UUID itemId) {
        return ResponseEntity.ok(ApiResponse.ok(packagingBarcodeService.listBarcodesForItem(itemId)));
    }

    @PostMapping("/items/{itemId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemPackagingBarcodeService.PackagingBarcodeResponse>> addBarcode(
            @PathVariable UUID itemId,
            @RequestBody ItemPackagingBarcodeService.PackagingBarcodeRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(packagingBarcodeService.addBarcode(itemId, req), "Packaging barcode added"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemPackagingBarcodeService.PackagingBarcodeResponse>> updateBarcode(
            @PathVariable UUID id,
            @RequestBody ItemPackagingBarcodeService.PackagingBarcodeRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(packagingBarcodeService.updateBarcode(id, req), "Packaging barcode updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Void>> deleteBarcode(@PathVariable UUID id) {
        packagingBarcodeService.deleteBarcode(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Packaging barcode deleted"));
    }

    @GetMapping("/resolve/{barcode}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ItemPackagingBarcodeService.ResolvedBarcodeResponse>> resolveBarcode(
            @PathVariable String barcode) {
        return ResponseEntity.ok(ApiResponse.ok(packagingBarcodeService.resolveBarcode(barcode)));
    }
}
