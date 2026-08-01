package com.katasticho.erp.inventory.cost.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.cost.dto.InventoryCostEventResponse;
import com.katasticho.erp.inventory.cost.entity.InventoryCostAllocation;
import com.katasticho.erp.inventory.cost.service.InventoryCostLedgerService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory/cost-events")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class InventoryCostController {

    private final InventoryCostLedgerService ledgerService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<InventoryCostEventResponse>>> recent() {
        return ResponseEntity.ok(ApiResponse.ok(ledgerService.listRecent().stream()
                .map(InventoryCostEventResponse::from).toList()));
    }

    @GetMapping("/source/{sourceType}/{sourceId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<InventoryCostEventResponse>>> bySource(
            @PathVariable String sourceType, @PathVariable UUID sourceId) {
        return ResponseEntity.ok(ApiResponse.ok(ledgerService.findBySource(sourceType, sourceId).stream()
                .map(InventoryCostEventResponse::from).toList()));
    }

    @GetMapping("/movement/{movementId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<InventoryCostEventResponse.Allocation>>> byMovement(
            @PathVariable UUID movementId) {
        return ResponseEntity.ok(ApiResponse.ok(ledgerService.findByMovement(movementId).stream()
                .map(a -> new InventoryCostEventResponse.Allocation(a.getId(), a.getStockMovementId(),
                        a.getItemId(), a.getBatchId(), a.getQuantity(), a.getAllocatedAmount(),
                        a.getUnitCostAddition())).toList()));
    }

    @GetMapping("/batch/{batchId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<InventoryCostEventResponse.Allocation>>> byBatch(
            @PathVariable UUID batchId) {
        List<InventoryCostAllocation> rows = ledgerService.findByBatch(batchId);
        return ResponseEntity.ok(ApiResponse.ok(rows.stream()
                .map(a -> new InventoryCostEventResponse.Allocation(a.getId(), a.getStockMovementId(),
                        a.getItemId(), a.getBatchId(), a.getQuantity(), a.getAllocatedAmount(),
                        a.getUnitCostAddition())).toList()));
    }
}
