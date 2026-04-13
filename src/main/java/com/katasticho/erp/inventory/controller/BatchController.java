package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.BatchResponse;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Read endpoints over the batch master — creates come from GRN receive,
 * not from here, so there's no POST. The invoice-line batch picker
 * hits {@link #listFefo(UUID, UUID)} to get an expiry-ordered list with
 * current warehouse on-hand embedded.
 */
@RestController
@RequestMapping("/api/v1/batches")
@RequiredArgsConstructor
public class BatchController {

    private final BatchService batchService;
    private final StockBatchRepository batchRepository;
    private final WarehouseRepository warehouseRepository;

    /**
     * All batches for an item across all warehouses. Used by the item
     * detail page to show batch history.
     */
    @GetMapping("/item/{itemId}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<BatchResponse>>> listByItem(@PathVariable UUID itemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<BatchResponse> result = batchRepository
                .findByOrgIdAndItemIdAndIsDeletedFalseOrderByExpiryDateAsc(orgId, itemId)
                .stream()
                .map(BatchResponse::from)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    /**
     * FEFO-ordered list of batches that have stock in a given warehouse.
     * Each response element carries {@code quantityAvailable} so the
     * picker doesn't need a second call. Empty list means "no batch
     * stock at this warehouse" — caller falls back to its own
     * insufficient-stock UX.
     *
     * <p>{@code warehouseId} is optional — if the caller (typically the
     * Flutter invoice-line batch picker) doesn't track warehouses, we
     * fall back to the org's default. Keeping the parameter optional
     * lets the "power user" supply it explicitly for multi-warehouse
     * scenarios without breaking the simple path.
     */
    @GetMapping("/item/{itemId}/available")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<BatchResponse>>> listFefo(
            @PathVariable UUID itemId,
            @RequestParam(required = false) UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID effectiveWarehouseId = warehouseId;
        if (effectiveWarehouseId == null) {
            Warehouse defaultWh = warehouseRepository
                    .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .orElseThrow(() -> new BusinessException(
                            "No default warehouse configured for this organisation",
                            "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));
            effectiveWarehouseId = defaultWh.getId();
        }
        List<StockBatch> batches = batchService.findFefoBatches(itemId, effectiveWarehouseId);
        List<BatchResponse> result = new ArrayList<>(batches.size());
        for (StockBatch b : batches) {
            BigDecimal available = batchService.getBatchBalance(b.getId(), effectiveWarehouseId);
            result.add(BatchResponse.from(b, available));
        }
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<BatchResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(BatchResponse.from(batchService.getBatch(id))));
    }
}
