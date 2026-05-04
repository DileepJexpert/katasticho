package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockAdjustmentRequest;
import com.katasticho.erp.inventory.dto.StockBalanceResponse;
import com.katasticho.erp.inventory.dto.StockMovementResponse;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stock")
@RequiredArgsConstructor
public class StockController {

    private final InventoryService inventoryService;
    private final StockMovementRepository stockMovementRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;

    /**
     * Manual stock adjustment (loss, damage, found stock).
     */
    @PostMapping("/adjust")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<StockMovementResponse>> adjust(
            @Valid @RequestBody StockAdjustmentRequest request) {
        StockMovement movement = inventoryService.adjustStock(request);
        return ResponseEntity.ok(ApiResponse.ok(toMovementResponse(movement), "Stock adjusted"));
    }

    /**
     * Reverse a previously-recorded movement.
     */
    @PostMapping("/movements/{id}/reverse")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<StockMovementResponse>> reverse(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        StockMovement reversal = inventoryService.reverseMovement(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(toMovementResponse(reversal), "Stock movement reversed"));
    }

    /**
     * Movement history for an item — newest first.
     */
    @GetMapping("/items/{itemId}/movements")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<StockMovementResponse>>> itemMovements(
            @PathVariable UUID itemId,
            Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<StockMovement> page = stockMovementRepository
                .findByOrgIdAndItemIdOrderByMovementDateDescCreatedAtDesc(orgId, itemId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(page.map(this::toMovementResponse).getContent()));
    }

    /**
     * Current on-hand balances for an item across all warehouses.
     */
    @GetMapping("/items/{itemId}/balances")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<StockBalanceResponse>>> itemBalances(@PathVariable UUID itemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<StockBalance> balances = stockBalanceRepository.findByOrgIdAndItemId(orgId, itemId);
        return ResponseEntity.ok(ApiResponse.ok(balances.stream().map(this::toBalanceResponse).toList()));
    }

    /**
     * Low-stock items for the dashboard widget.
     * Includes items with no StockBalance record (treated as qty=0).
     */
    @GetMapping("/low-stock")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<StockBalanceResponse>>> lowStock() {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Items that track inventory, are active, and have a reorder level > 0
        List<Item> trackableItems = itemRepository
                .findByOrgIdAndIsDeletedFalseAndTrackInventoryTrue(orgId)
                .stream()
                .filter(Item::isActive)
                .filter(i -> i.getReorderLevel().compareTo(BigDecimal.ZERO) > 0)
                .toList();

        Warehouse defaultWh = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElse(null);

        List<StockBalanceResponse> result = trackableItems.stream()
                .map(item -> {
                    List<StockBalance> balances = stockBalanceRepository
                            .findByOrgIdAndItemId(orgId, item.getId());
                    BigDecimal totalQty = balances.stream()
                            .map(StockBalance::getQuantityOnHand)
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    if (totalQty.compareTo(item.getReorderLevel()) > 0) return null;

                    UUID whId = balances.isEmpty()
                            ? (defaultWh != null ? defaultWh.getId() : null)
                            : balances.get(0).getWarehouseId();
                    String whName = balances.isEmpty()
                            ? (defaultWh != null ? defaultWh.getName() : "Default")
                            : null;
                    if (whName == null && whId != null) {
                        whName = warehouseRepository.findById(whId)
                                .map(Warehouse::getName).orElse("Unknown");
                    }

                    return new StockBalanceResponse(
                            item.getId(),
                            item.getSku(),
                            item.getName(),
                            whId,
                            whName,
                            totalQty,
                            balances.isEmpty() ? BigDecimal.ZERO
                                    : balances.get(0).getAverageCost(),
                            item.getReorderLevel(),
                            true,
                            balances.isEmpty() ? null
                                    : balances.get(0).getLastMovementAt());
                })
                .filter(java.util.Objects::nonNull)
                .sorted(java.util.Comparator.comparing(StockBalanceResponse::quantityOnHand))
                .toList();

        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    private StockMovementResponse toMovementResponse(StockMovement m) {
        if (m == null) return null;
        Item item = itemRepository.findById(m.getItemId()).orElse(null);
        Warehouse wh = warehouseRepository.findById(m.getWarehouseId()).orElse(null);
        return new StockMovementResponse(
                m.getId(),
                m.getItemId(),
                item != null ? item.getName() : null,
                item != null ? item.getSku() : null,
                m.getWarehouseId(),
                wh != null ? wh.getName() : null,
                m.getMovementDate(),
                m.getCreatedAt(),
                m.getMovementType(),
                m.getQuantity(),
                m.getUnitCost(),
                m.getTotalCost(),
                m.getReferenceType(),
                m.getReferenceId(),
                m.getReferenceNumber(),
                m.isReversal(),
                m.getReversalOfId(),
                m.isReversed(),
                m.getNotes());
    }

    private StockBalanceResponse toBalanceResponse(StockBalance b) {
        Item item = itemRepository.findById(b.getItemId())
                .orElseThrow(() -> BusinessException.notFound("Item", b.getItemId()));
        Warehouse wh = warehouseRepository.findById(b.getWarehouseId())
                .orElseThrow(() -> BusinessException.notFound("Warehouse", b.getWarehouseId()));
        boolean lowStock = b.getQuantityOnHand().compareTo(item.getReorderLevel()) <= 0
                && item.isTrackInventory();
        return new StockBalanceResponse(
                b.getItemId(),
                item.getSku(),
                item.getName(),
                b.getWarehouseId(),
                wh.getName(),
                b.getQuantityOnHand(),
                b.getAverageCost(),
                item.getReorderLevel(),
                lowStock,
                b.getLastMovementAt());
    }
}
