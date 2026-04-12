package com.katasticho.erp.inventory.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockAdjustmentRequest;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * THE SINGLE STOCK GATE.
 *
 * Mirrors {@link com.katasticho.erp.accounting.service.JournalService} for
 * the inventory ledger. Every stock change in the entire ERP — invoice send,
 * credit note return, manual adjustment, opening balance, transfer — flows
 * through {@link #recordMovement(StockMovementRequest)}.
 *
 * NO module writes to {@code stock_movement} or {@code stock_balance} directly.
 *
 * Append-only contract: posted movements are immutable. Corrections happen by
 * recording a new movement of opposite sign with {@code reversal=true}, and
 * the V8 trigger {@code prevent_stock_movement_mutation()} enforces this at
 * the database level even if application code has bugs.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class InventoryService {

    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final StockMovementRepository stockMovementRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final AuditService auditService;

    /**
     * THE MOST IMPORTANT METHOD IN THIS MODULE.
     *
     * Steps mirror JournalService.postJournal():
     *   1. Validate org / item / warehouse all belong to current tenant
     *   2. Skip silently for SERVICE items (trackInventory=false)
     *   3. Validate quantity sign matches movement type
     *   4. Compute total_cost = quantity * unit_cost
     *   5. Persist immutable stock_movement row
     *   6. Update stock_balance cache (synchronously, same transaction)
     *   7. Audit log
     */
    @Transactional
    public StockMovement recordMovement(StockMovementRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        // Step 1: validate item exists in this tenant
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(request.itemId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", request.itemId()));

        // Step 2: SERVICE items are not tracked — silent no-op
        if (!item.isTrackInventory() || item.getItemType() == ItemType.SERVICE) {
            log.debug("Skipping stock movement for non-tracked item {}", item.getSku());
            return null;
        }

        Warehouse warehouse = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.warehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.warehouseId()));

        // Step 3: validate quantity is non-zero and sign is consistent
        BigDecimal qty = request.quantity().setScale(4, RoundingMode.HALF_UP);
        if (qty.compareTo(BigDecimal.ZERO) == 0) {
            throw new BusinessException("Stock movement quantity must be non-zero",
                    "INV_ZERO_QUANTITY", HttpStatus.BAD_REQUEST);
        }
        validateSign(request.movementType(), qty);

        // Step 4: cost
        BigDecimal unitCost = request.unitCost() != null
                ? request.unitCost().setScale(4, RoundingMode.HALF_UP)
                : item.getPurchasePrice().setScale(4, RoundingMode.HALF_UP);
        BigDecimal totalCost = unitCost.multiply(qty.abs()).setScale(2, RoundingMode.HALF_UP);

        // Step 5: persist immutable ledger row
        StockMovement movement = StockMovement.builder()
                .orgId(orgId)
                .itemId(item.getId())
                .warehouseId(warehouse.getId())
                .movementDate(request.movementDate())
                .movementType(request.movementType())
                .quantity(qty)
                .unitCost(unitCost)
                .totalCost(totalCost)
                .referenceType(request.referenceType())
                .referenceId(request.referenceId())
                .referenceNumber(request.referenceNumber())
                .reversal(false)
                .reversed(false)
                .notes(request.notes())
                .createdBy(userId)
                .build();

        movement = stockMovementRepository.save(movement);

        // Step 6: update cache
        updateBalanceCache(orgId, item, warehouse.getId(), qty, unitCost);

        // Step 7: audit
        auditService.log("STOCK_MOVEMENT", movement.getId(), "CREATE", null,
                "{\"item\":\"" + item.getSku() + "\",\"qty\":\"" + qty + "\",\"type\":\"" + request.movementType() + "\"}");

        log.info("Stock movement {} {} qty={} for item {} @ warehouse {}",
                movement.getId(), request.movementType(), qty, item.getSku(), warehouse.getCode());
        return movement;
    }

    /**
     * Reverse a previously-recorded movement.
     *
     * Creates a new stock_movement row with quantity negated and
     * {@code isReversal=true}, then marks the original as {@code isReversed=true}
     * (the only update the trigger allows on a posted row).
     */
    @Transactional
    public StockMovement reverseMovement(UUID movementId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        StockMovement original = stockMovementRepository.findById(movementId)
                .orElseThrow(() -> BusinessException.notFound("StockMovement", movementId));

        if (!orgId.equals(original.getOrgId())) {
            throw BusinessException.accessDenied("Stock movement does not belong to this org");
        }
        if (original.isReversed()) {
            throw new BusinessException("Stock movement already reversed",
                    "INV_ALREADY_REVERSED", HttpStatus.CONFLICT);
        }

        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(original.getItemId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", original.getItemId()));

        BigDecimal reversedQty = original.getQuantity().negate();

        StockMovement reversal = StockMovement.builder()
                .orgId(orgId)
                .itemId(original.getItemId())
                .warehouseId(original.getWarehouseId())
                .movementDate(LocalDate.now())
                .movementType(MovementType.REVERSAL)
                .quantity(reversedQty)
                .unitCost(original.getUnitCost())
                .totalCost(original.getTotalCost())
                .referenceType(original.getReferenceType())
                .referenceId(original.getReferenceId())
                .referenceNumber(original.getReferenceNumber())
                .reversal(true)
                .reversalOfId(original.getId())
                .reversed(false)
                .notes("Reversal: " + (reason != null ? reason : ""))
                .createdBy(userId)
                .build();

        reversal = stockMovementRepository.save(reversal);

        // Mark original — the ONLY mutation the DB trigger permits.
        original.setReversed(true);
        stockMovementRepository.save(original);

        // Update cache
        updateBalanceCache(orgId, item, original.getWarehouseId(), reversedQty, original.getUnitCost());

        auditService.log("STOCK_MOVEMENT", reversal.getId(), "REVERSE", null,
                "{\"reversalOf\":\"" + original.getId() + "\",\"reason\":\"" + reason + "\"}");

        log.info("Stock movement {} reversed by {}", original.getId(), reversal.getId());
        return reversal;
    }

    /**
     * Manual stock adjustment from the UI (loss, damage, found stock).
     */
    @Transactional
    public StockMovement adjustStock(StockAdjustmentRequest request) {
        UUID warehouseId = request.warehouseId();
        if (warehouseId == null) {
            UUID orgId = TenantContext.getCurrentOrgId();
            Warehouse defaultWarehouse = warehouseRepository
                    .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .orElseThrow(() -> new BusinessException(
                            "No default warehouse configured for this organisation",
                            "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));
            warehouseId = defaultWarehouse.getId();
        }
        LocalDate adjustmentDate = request.adjustmentDate() != null
                ? request.adjustmentDate()
                : LocalDate.now();
        String reason = request.reason() != null && !request.reason().isBlank()
                ? request.reason()
                : "Manual stock adjustment";
        StockMovementRequest movement = new StockMovementRequest(
                request.itemId(),
                warehouseId,
                MovementType.ADJUSTMENT,
                request.quantity(),
                request.unitCost(),
                adjustmentDate,
                ReferenceType.STOCK_ADJUSTMENT,
                null,
                null,
                reason);
        return recordMovement(movement);
    }

    /**
     * Called by InvoiceService.sendInvoice() AFTER the journal has been posted.
     * Iterates the invoice lines and records a SALE (negative quantity) for
     * each line that carries an item_id. Free-text lines are silently skipped.
     *
     * Uses the org's default warehouse in v1 — multi-warehouse selection lands
     * in a later sprint.
     */
    @Transactional
    public void deductStockForInvoice(Invoice invoice) {
        UUID orgId = invoice.getOrgId();
        Warehouse defaultWarehouse = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException(
                        "No default warehouse configured for org " + orgId,
                        "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));

        for (InvoiceLine line : invoice.getLines()) {
            if (line.getItemId() == null) {
                continue; // free-text invoice line — no inventory impact
            }

            // Negative quantity = stock out
            BigDecimal outQty = line.getQuantity().negate();

            // Use the line's unit price as a fallback cost; in a richer cost
            // model this would come from the item's average_cost.
            BigDecimal unitCost = line.getUnitPrice();

            StockMovementRequest req = new StockMovementRequest(
                    line.getItemId(),
                    defaultWarehouse.getId(),
                    MovementType.SALE,
                    outQty,
                    unitCost,
                    invoice.getInvoiceDate(),
                    ReferenceType.INVOICE,
                    invoice.getId(),
                    invoice.getInvoiceNumber(),
                    "Sale via " + invoice.getInvoiceNumber());

            recordMovement(req);
        }
    }

    /**
     * Called when a credit note is issued — restores the stock that was
     * deducted by the original invoice.
     */
    @Transactional
    public void restoreStockForCreditNote(UUID orgId,
                                          UUID itemId,
                                          BigDecimal quantity,
                                          BigDecimal unitCost,
                                          UUID creditNoteId,
                                          String creditNoteNumber,
                                          LocalDate creditNoteDate) {
        Warehouse defaultWarehouse = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException(
                        "No default warehouse configured for org " + orgId,
                        "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));

        StockMovementRequest req = new StockMovementRequest(
                itemId,
                defaultWarehouse.getId(),
                MovementType.RETURN_IN,
                quantity.abs(), // positive — stock comes back in
                unitCost,
                creditNoteDate,
                ReferenceType.CREDIT_NOTE,
                creditNoteId,
                creditNoteNumber,
                "Return via " + creditNoteNumber);

        recordMovement(req);
    }

    /**
     * Authoritative read: re-derives on-hand from the ledger. Used by tests
     * and the nightly verification job; UI reads should hit stock_balance.
     */
    public BigDecimal getComputedBalance(UUID itemId, UUID warehouseId, LocalDate asOfDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal balance = stockMovementRepository.computeOnHand(orgId, itemId, warehouseId, asOfDate);
        return balance != null ? balance : BigDecimal.ZERO;
    }

    /**
     * Synchronously update the stock_balance cache row inside the same
     * transaction as the stock_movement insert.
     *
     * Weighted average cost is recomputed only on PURCHASE / OPENING /
     * RETURN_IN with positive quantity (stock coming in). Stock going out
     * does not affect the average.
     */
    private void updateBalanceCache(UUID orgId, Item item, UUID warehouseId,
                                    BigDecimal deltaQty, BigDecimal unitCost) {
        StockBalance balance = stockBalanceRepository
                .findByOrgIdAndItemIdAndWarehouseId(orgId, item.getId(), warehouseId)
                .orElseGet(() -> StockBalance.builder()
                        .orgId(orgId)
                        .itemId(item.getId())
                        .warehouseId(warehouseId)
                        .quantityOnHand(BigDecimal.ZERO)
                        .averageCost(BigDecimal.ZERO)
                        .build());

        BigDecimal oldQty = balance.getQuantityOnHand();
        BigDecimal newQty = oldQty.add(deltaQty).setScale(4, RoundingMode.HALF_UP);

        // Weighted average cost — only on incoming stock.
        if (deltaQty.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal oldValue = balance.getAverageCost().multiply(oldQty);
            BigDecimal incomingValue = unitCost.multiply(deltaQty);
            BigDecimal totalValue = oldValue.add(incomingValue);
            BigDecimal newAverage = newQty.compareTo(BigDecimal.ZERO) > 0
                    ? totalValue.divide(newQty, 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
            balance.setAverageCost(newAverage);
        }

        balance.setQuantityOnHand(newQty);
        balance.setLastMovementAt(Instant.now());
        stockBalanceRepository.save(balance);
    }

    /**
     * Sign convention check: PURCHASE / OPENING / RETURN_IN / TRANSFER_IN must
     * be positive; SALE / RETURN_OUT / TRANSFER_OUT must be negative.
     * ADJUSTMENT, STOCK_COUNT, and REVERSAL accept either sign.
     */
    private void validateSign(MovementType type, BigDecimal qty) {
        boolean positive = qty.signum() > 0;
        switch (type) {
            case PURCHASE, OPENING, RETURN_IN, TRANSFER_IN -> {
                if (!positive) {
                    throw new BusinessException(
                            type + " movement must have positive quantity, got " + qty,
                            "INV_INVALID_SIGN", HttpStatus.BAD_REQUEST);
                }
            }
            case SALE, RETURN_OUT, TRANSFER_OUT -> {
                if (positive) {
                    throw new BusinessException(
                            type + " movement must have negative quantity, got " + qty,
                            "INV_INVALID_SIGN", HttpStatus.BAD_REQUEST);
                }
            }
            case ADJUSTMENT, STOCK_COUNT, REVERSAL -> {
                // Either sign permitted.
            }
        }
    }
}
