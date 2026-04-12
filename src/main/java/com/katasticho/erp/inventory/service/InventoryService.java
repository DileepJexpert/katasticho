package com.katasticho.erp.inventory.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockAdjustmentRequest;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
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
import java.util.List;
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
    private final BomComponentRepository bomComponentRepository;
    private final BatchService batchService;
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

        // Step 3b: batch-tracking invariant. Items with track_batches=true
        // MUST carry a batchId on every movement so the per-batch balance
        // stays consistent. Items without the flag MUST NOT carry one —
        // that would strand the movement against a batch the aggregate
        // path can't see. This is the single place we enforce it.
        if (item.isTrackBatches() && request.batchId() == null) {
            throw new BusinessException(
                    "Item " + item.getSku() + " has track_batches=true — batchId is required",
                    "INV_BATCH_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (!item.isTrackBatches() && request.batchId() != null) {
            throw new BusinessException(
                    "Item " + item.getSku() + " is not batch-tracked — batchId must be null",
                    "INV_BATCH_NOT_ALLOWED", HttpStatus.BAD_REQUEST);
        }

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
                .batchId(request.batchId())
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

        // Step 6a: update the aggregate item×warehouse cache (every item,
        // batch-tracked or not, is represented here so totals stay correct).
        updateBalanceCache(orgId, item, warehouse.getId(), qty, unitCost);

        // Step 6b: for batch-tracked items, also fan out the delta to the
        // per-batch per-warehouse grain so FEFO picks see an up-to-date
        // view. Same transaction — either both balance rows update or
        // the whole movement rolls back.
        if (request.batchId() != null) {
            batchService.applyDelta(request.batchId(), warehouse.getId(), qty);
        }

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
                .batchId(original.getBatchId())
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

        // Update aggregate cache
        updateBalanceCache(orgId, item, original.getWarehouseId(), reversedQty, original.getUnitCost());

        // Fan out to the per-batch balance if the original was batch-tracked.
        if (original.getBatchId() != null) {
            batchService.applyDelta(original.getBatchId(), original.getWarehouseId(), reversedQty);
        }

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
     * Records a SALE (negative quantity) against the item's stock. Free-text
     * invoice lines (item_id = NULL) are silently skipped.
     *
     * <p>Three branches depending on the item's batch-tracking flag:
     * <ol>
     *   <li><b>Non-batch item</b> — single movement with {@code batchId=null},
     *       identical to v1 behaviour.</li>
     *   <li><b>Batch-tracked with explicit pick</b> ({@code line.batchId} set) —
     *       one movement against that specific batch. The single stock gate
     *       (via {@link BatchService#applyDelta}) fails loud if the chosen
     *       batch can't cover the quantity.</li>
     *   <li><b>Batch-tracked with FEFO auto-pick</b> ({@code line.batchId} null) —
     *       walks batches in expiry order and posts one movement per batch
     *       consumed until the line quantity is satisfied. A single invoice
     *       line can therefore produce multiple {@code stock_movement} rows,
     *       each tagged with a different {@code batch_id}. If the total
     *       available across all batches is short, the whole post fails with
     *       {@code INV_INSUFFICIENT_BATCH_STOCK} and the outer transaction
     *       rolls back — no partial deductions.</li>
     * </ol>
     *
     * <p>Uses the org's default warehouse in v1 — multi-warehouse selection
     * lands in a later sprint.
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

            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(line.getItemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", line.getItemId()));

            // COMPOSITE items never move their own stock — they aren't
            // received, aren't counted, and aren't physically held. The
            // parent is an abstraction over its children. Explode the
            // BOM and post one SALE movement per child, multiplying the
            // child's per-parent quantity by the line quantity.
            //
            // Checked BEFORE the trackInventory/SERVICE early-return
            // below, because composite items always have
            // trackInventory=false (enforced in ItemService) and the
            // explosion must still fire — we just want the ledger
            // impact on the children, not the parent.
            //
            // BomService enforces at save time that children are simple
            // non-batch GOODS or SERVICE, so there's no FEFO or batch
            // path to worry about here. An empty BOM is logged loud but
            // does NOT fail the send — the operator may have configured
            // the item this way on purpose (e.g. a pure labour charge
            // that carries its own revenue account).
            if (item.getItemType() == ItemType.COMPOSITE) {
                List<BomComponent> components = bomComponentRepository
                        .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(
                                orgId, item.getId());
                if (components.isEmpty()) {
                    log.warn("Composite item {} sold on invoice {} has no BOM — no stock deducted",
                            item.getSku(), invoice.getInvoiceNumber());
                    continue;
                }
                BigDecimal parentQty = line.getQuantity();
                for (BomComponent comp : components) {
                    BigDecimal childTotalQty = comp.getQuantity().multiply(parentQty);
                    Item child = itemRepository
                            .findByIdAndOrgIdAndIsDeletedFalse(comp.getChildItemId(), orgId)
                            .orElseThrow(() -> BusinessException.notFound("Item", comp.getChildItemId()));
                    // Children are guaranteed non-batch GOODS/SERVICE
                    // by BomService. recordMovement() will silently
                    // no-op SERVICE children and post a plain SALE for
                    // non-batch GOODS.
                    if (!child.isTrackInventory() || child.getItemType() == ItemType.SERVICE) {
                        continue;
                    }
                    // Build the request against the CHILD's itemId, not
                    // the parent's — recordMovement validates the item
                    // belongs to this tenant and updates balance for
                    // that id. Unit cost is left null so the gate falls
                    // back to the child's purchase_price (the parent's
                    // sale price has no relationship to child cost).
                    StockMovementRequest childMove = new StockMovementRequest(
                            child.getId(),
                            defaultWarehouse.getId(),
                            MovementType.SALE,
                            childTotalQty.negate(),
                            null, // use child.purchasePrice
                            invoice.getInvoiceDate(),
                            ReferenceType.INVOICE,
                            invoice.getId(),
                            invoice.getInvoiceNumber(),
                            "Sale via " + invoice.getInvoiceNumber()
                                    + " (BOM child of " + item.getSku() + ")",
                            null);
                    recordMovement(childMove);
                }
                continue;
            }

            // SERVICE items and non-tracked items have nothing to deduct.
            // recordMovement() would no-op these anyway, but short-circuiting
            // here keeps the FEFO branch clean of that special case.
            if (!item.isTrackInventory() || item.getItemType() == ItemType.SERVICE) {
                continue;
            }

            if (!item.isTrackBatches()) {
                // Non-batch path: single aggregate SALE movement.
                recordMovement(buildInvoiceSaleRequest(
                        invoice, line, defaultWarehouse.getId(),
                        line.getQuantity().negate(), null));
                continue;
            }

            // From here on the item is batch-tracked.

            if (line.getBatchId() != null) {
                // Explicit pick — honour it as-is. The gate's applyDelta
                // call will fail loud with BATCH_NEGATIVE_BALANCE if the
                // chosen batch doesn't have enough stock.
                recordMovement(buildInvoiceSaleRequest(
                        invoice, line, defaultWarehouse.getId(),
                        line.getQuantity().negate(), line.getBatchId()));
                continue;
            }

            // FEFO auto-pick. Walk batches in expiry-ascending order and
            // consume greedily. A single line can split across multiple
            // stock_movement rows if no single batch covers the quantity.
            BigDecimal remaining = line.getQuantity().setScale(4, RoundingMode.HALF_UP);
            List<StockBatch> batches = batchService.findFefoBatches(item.getId(), defaultWarehouse.getId());
            for (StockBatch batch : batches) {
                if (remaining.compareTo(BigDecimal.ZERO) <= 0) {
                    break;
                }
                BigDecimal available = batchService
                        .getBatchBalance(batch.getId(), defaultWarehouse.getId());
                if (available.compareTo(BigDecimal.ZERO) <= 0) {
                    continue;
                }
                BigDecimal consume = available.min(remaining);
                recordMovement(buildInvoiceSaleRequest(
                        invoice, line, defaultWarehouse.getId(),
                        consume.negate(), batch.getId()));
                remaining = remaining.subtract(consume);
            }

            if (remaining.compareTo(BigDecimal.ZERO) > 0) {
                throw new BusinessException(
                        "Insufficient batch-tracked stock for " + item.getSku()
                                + ": short by " + remaining
                                + ". Either receive more stock or pick a"
                                + " specific batch that has enough.",
                        "INV_INSUFFICIENT_BATCH_STOCK", HttpStatus.CONFLICT);
            }
        }
    }

    /** Shared request builder so the three deduction branches stay symmetrical. */
    private StockMovementRequest buildInvoiceSaleRequest(Invoice invoice, InvoiceLine line,
                                                         UUID warehouseId, BigDecimal signedQty,
                                                         UUID batchId) {
        return new StockMovementRequest(
                line.getItemId(),
                warehouseId,
                MovementType.SALE,
                signedQty,
                line.getUnitPrice(),
                invoice.getInvoiceDate(),
                ReferenceType.INVOICE,
                invoice.getId(),
                invoice.getInvoiceNumber(),
                "Sale via " + invoice.getInvoiceNumber(),
                batchId);
    }

    /**
     * Called when a credit note is issued — restores the stock that was
     * deducted by the original invoice.
     *
     * <p>For batch-tracked items the caller MUST supply a {@code batchId}:
     * returned goods come back with a specific batch printed on them, so
     * auto-picking on restore would silently corrupt the master data. The
     * method fails loud with {@code CN_BATCH_REQUIRED} otherwise. Non-batch
     * items continue to restore via a plain aggregate movement.
     */
    @Transactional
    public void restoreStockForCreditNote(UUID orgId,
                                          UUID itemId,
                                          BigDecimal quantity,
                                          BigDecimal unitCost,
                                          UUID creditNoteId,
                                          String creditNoteNumber,
                                          LocalDate creditNoteDate,
                                          UUID batchId) {
        Warehouse defaultWarehouse = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException(
                        "No default warehouse configured for org " + orgId,
                        "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));

        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));

        // COMPOSITE parent: mirror the invoice-send explosion. Walk the
        // BOM and restore each child at (childQty × lineQty). The
        // parent itself never held stock, so no movement against its
        // own id. BomService guarantees children are non-batch and
        // non-composite, so there's no batch/FEFO path here.
        if (item.getItemType() == ItemType.COMPOSITE) {
            List<BomComponent> components = bomComponentRepository
                    .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, itemId);
            if (components.isEmpty()) {
                log.warn("Credit note {} returns composite {} with no BOM — no stock restored",
                        creditNoteNumber, item.getSku());
                return;
            }
            BigDecimal parentQty = quantity.abs();
            for (BomComponent comp : components) {
                BigDecimal childTotalQty = comp.getQuantity().multiply(parentQty);
                Item child = itemRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(comp.getChildItemId(), orgId)
                        .orElseThrow(() -> BusinessException.notFound("Item", comp.getChildItemId()));
                if (!child.isTrackInventory() || child.getItemType() == ItemType.SERVICE) {
                    continue;
                }
                StockMovementRequest childReq = new StockMovementRequest(
                        child.getId(),
                        defaultWarehouse.getId(),
                        MovementType.RETURN_IN,
                        childTotalQty,
                        null, // use child.purchasePrice
                        creditNoteDate,
                        ReferenceType.CREDIT_NOTE,
                        creditNoteId,
                        creditNoteNumber,
                        "Return via " + creditNoteNumber + " (BOM child of " + item.getSku() + ")",
                        null);
                recordMovement(childReq);
            }
            return;
        }

        // Guard batch-tracked items early so the operator sees an
        // actionable error ("pick a batch") instead of the gate's raw
        // INV_BATCH_REQUIRED which fires in a different context.
        if (item.isTrackBatches() && batchId == null) {
            throw new BusinessException(
                    "Credit note line for batch-tracked item " + item.getSku()
                            + " must specify which batch to restore to",
                    "CN_BATCH_REQUIRED", HttpStatus.BAD_REQUEST);
        }

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
                "Return via " + creditNoteNumber,
                batchId);

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
