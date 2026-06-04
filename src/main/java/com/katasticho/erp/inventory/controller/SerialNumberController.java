package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.entity.SerialNumber;
import com.katasticho.erp.inventory.service.SerialNumberService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/serial-numbers")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class SerialNumberController {

    private final SerialNumberService serialNumberService;

    @PostMapping("/receive")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<SerialNumber>>> receive(@RequestBody Map<String, Object> body) {
        UUID itemId = UUID.fromString((String) body.get("itemId"));
        UUID warehouseId = body.get("warehouseId") != null ? UUID.fromString((String) body.get("warehouseId")) : null;
        UUID batchId = body.get("batchId") != null ? UUID.fromString((String) body.get("batchId")) : null;
        UUID receiptLineId = body.get("receiptLineId") != null ? UUID.fromString((String) body.get("receiptLineId")) : null;
        @SuppressWarnings("unchecked")
        List<String> serials = (List<String>) body.get("serials");

        List<SerialNumber> result = serialNumberService.receiveSerials(itemId, warehouseId, batchId, receiptLineId, serials);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(result));
    }

    @PostMapping("/assign-sale")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<SerialNumber>>> assignToSale(@RequestBody Map<String, Object> body) {
        UUID itemId = UUID.fromString((String) body.get("itemId"));
        UUID warehouseId = body.get("warehouseId") != null ? UUID.fromString((String) body.get("warehouseId")) : null;
        UUID invoiceLineId = body.get("invoiceLineId") != null ? UUID.fromString((String) body.get("invoiceLineId")) : null;
        @SuppressWarnings("unchecked")
        List<String> serials = (List<String>) body.get("serials");

        List<SerialNumber> result = serialNumberService.assignToSale(itemId, warehouseId, invoiceLineId, serials);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @PostMapping("/{id}/damage")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SerialNumber>> markDamaged(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String notes = body != null ? body.get("notes") : null;
        return ResponseEntity.ok(ApiResponse.ok(serialNumberService.markDamaged(id, notes)));
    }

    @PostMapping("/{id}/return")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<SerialNumber>> markReturned(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(serialNumberService.markReturned(id)));
    }

    @GetMapping("/available")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<SerialNumber>>> listAvailable(
            @RequestParam UUID itemId,
            @RequestParam(required = false) UUID warehouseId) {
        return ResponseEntity.ok(ApiResponse.ok(serialNumberService.listAvailable(itemId, warehouseId)));
    }

    @GetMapping("/by-item/{itemId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<Page<SerialNumber>>> listByItem(
            @PathVariable UUID itemId, Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(serialNumberService.listByItem(itemId, pageable)));
    }
}
