package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.entity.WarehouseZone;
import com.katasticho.erp.inventory.service.WarehouseZoneService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/warehouse-zones")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class WarehouseZoneController {

    private final WarehouseZoneService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WarehouseZone>> createZone(@RequestBody Map<String, Object> body) {
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        String code = (String) body.get("code");
        String name = (String) body.get("name");
        String zoneType = (String) body.get("zoneType");
        BigDecimal capacity = body.get("capacity") != null
                ? new BigDecimal(body.get("capacity").toString()) : null;
        boolean tempControlled = Boolean.TRUE.equals(body.get("temperatureControlled"));
        String notes = (String) body.get("notes");

        return ResponseEntity.ok(ApiResponse.ok(
                service.createZone(warehouseId, code, name, zoneType, capacity, tempControlled, notes),
                "Warehouse zone created"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<WarehouseZone>> getZone(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getZone(id)));
    }

    @GetMapping("/by-warehouse/{warehouseId}")
    public ResponseEntity<ApiResponse<List<WarehouseZone>>> getByWarehouse(@PathVariable UUID warehouseId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getZonesByWarehouse(warehouseId)));
    }

    @GetMapping("/by-type/{zoneType}")
    public ResponseEntity<ApiResponse<List<WarehouseZone>>> getByType(@PathVariable String zoneType) {
        return ResponseEntity.ok(ApiResponse.ok(service.getZonesByType(zoneType)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WarehouseZone>> updateZone(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        String zoneType = (String) body.get("zoneType");
        BigDecimal capacity = body.get("capacity") != null
                ? new BigDecimal(body.get("capacity").toString()) : null;
        boolean tempControlled = Boolean.TRUE.equals(body.get("temperatureControlled"));
        String notes = (String) body.get("notes");

        return ResponseEntity.ok(ApiResponse.ok(
                service.updateZone(id, name, zoneType, capacity, tempControlled, notes)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteZone(@PathVariable UUID id) {
        service.deleteZone(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
