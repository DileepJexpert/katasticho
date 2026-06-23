package com.katasticho.erp.inventory.atp;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderLineRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Available-to-Promise computation for the SO capture screen.
 *
 * <p>Read-only — no writes, no movements, no journal posting. The numbers come
 * from {@code stock_balance} (cached), the open SO/PO/WO ledgers, and the item
 * + warehouse masters. ATP is a snapshot — if a second order taker is also
 * looking, the same number may already be promised somewhere else. Real
 * commitment happens when the SO is saved + confirmed.
 */
@Service
@RequiredArgsConstructor
public class AtpService {

    private static final List<String> OPEN_SO_STATUSES =
            List.of("CONFIRMED", "BACKORDER", "PARTIALLY_SHIPPED");

    /** PO statuses that still imply incoming stock. */
    private static final List<String> OPEN_PO_STATUSES = List.of("SENT");

    /** WO statuses that still imply incoming FG. */
    private static final List<String> OPEN_WO_STATUSES = List.of("IN_PROGRESS");

    private final StockBalanceRepository stockBalanceRepository;
    private final SalesOrderLineRepository salesOrderLineRepository;
    private final SalesOrderRepository salesOrderRepository;
    private final PurchaseOrderLineRepository purchaseOrderLineRepository;
    private final PurchaseOrderRepository purchaseOrderRepository;
    private final WorkOrderRepository workOrderRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;

    @Transactional(readOnly = true)
    public AtpResponse compute(UUID itemId, UUID warehouseId, BigDecimal requestedQty) {
        if (itemId == null) {
            throw new BusinessException("Item id is required", "ATP_ITEM_REQUIRED");
        }
        if (warehouseId == null) {
            throw new BusinessException("Warehouse id is required", "ATP_WAREHOUSE_REQUIRED");
        }
        BigDecimal qty = requestedQty == null ? BigDecimal.ZERO : requestedQty;
        UUID orgId = TenantContext.getCurrentOrgId();

        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));
        Warehouse warehouse = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouseId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", warehouseId));

        BigDecimal onHand = stockBalanceRepository
                .findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId)
                .map(StockBalance::getQuantityOnHand)
                .orElse(BigDecimal.ZERO);
        // Bill-freely mode lets on-hand go negative — never quote a negative
        // promise to a customer.
        BigDecimal onHandClamped = onHand.max(BigDecimal.ZERO);

        BigDecimal committed = commitmentForItem(orgId, itemId);
        BigDecimal availableNow = onHandClamped.subtract(committed).max(BigDecimal.ZERO);

        OpenInflow purchase = openPurchaseInflow(orgId, itemId, warehouseId);
        OpenInflow production = openProductionInflow(orgId, itemId);

        LocalDate nextInflowDate = earlier(purchase.earliestDate(), production.earliestDate());

        String status;
        BigDecimal shortfall;
        if (qty.signum() <= 0) {
            status = AtpResponse.STATUS_OK;
            shortfall = BigDecimal.ZERO;
        } else if (availableNow.compareTo(qty) >= 0) {
            status = AtpResponse.STATUS_OK;
            shortfall = BigDecimal.ZERO;
        } else if (availableNow.signum() > 0) {
            status = AtpResponse.STATUS_PARTIAL;
            shortfall = qty.subtract(availableNow);
        } else {
            status = AtpResponse.STATUS_BACKORDER;
            shortfall = qty;
        }

        return new AtpResponse(
                itemId, item.getName(),
                warehouseId, warehouse.getName(),
                onHandClamped,
                committed,
                availableNow,
                purchase.qty(),
                production.qty(),
                nextInflowDate,
                qty,
                status,
                shortfall);
    }

    /**
     * Σ(quantity − quantityShipped) across every CONFIRMED / BACKORDER /
     * PARTIALLY_SHIPPED SO line for the item.
     *
     * <p>Two queries (line set then header set then in-memory join) instead of a
     * native sum because SO has no warehouse field and the SOL repository's
     * existing native sum methods only cover backorder. Item-scoped — typical
     * cardinality per item is small (open SO lines for one item, not all org SOs).
     */
    private BigDecimal commitmentForItem(UUID orgId, UUID itemId) {
        List<SalesOrderLine> lines = salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId);
        if (lines.isEmpty()) return BigDecimal.ZERO;
        Set<UUID> orderIds = lines.stream()
                .map(l -> l.getSalesOrder().getId())
                .collect(Collectors.toCollection(HashSet::new));
        Map<UUID, SalesOrder> orders = salesOrderRepository.findAllById(orderIds).stream()
                .filter(so -> orgId.equals(so.getOrgId()) && !so.isDeleted()
                        && OPEN_SO_STATUSES.contains(so.getStatus()))
                .collect(Collectors.toMap(SalesOrder::getId, so -> so));
        BigDecimal total = BigDecimal.ZERO;
        for (SalesOrderLine l : lines) {
            SalesOrder so = orders.get(l.getSalesOrder().getId());
            if (so == null) continue;
            BigDecimal open = nullSafe(l.getQuantity()).subtract(nullSafe(l.getQuantityShipped()));
            if (open.signum() > 0) total = total.add(open);
        }
        return total;
    }

    private OpenInflow openPurchaseInflow(UUID orgId, UUID itemId, UUID warehouseId) {
        List<PurchaseOrderLine> lines = purchaseOrderLineRepository.findOpenForItem(orgId, itemId);
        if (lines.isEmpty()) return OpenInflow.empty();
        Set<UUID> poIds = lines.stream().map(PurchaseOrderLine::getPoId)
                .collect(Collectors.toCollection(HashSet::new));
        Map<UUID, PurchaseOrder> pos = purchaseOrderRepository.findAllById(poIds).stream()
                .filter(po -> orgId.equals(po.getOrgId()) && !po.isDeleted()
                        && OPEN_PO_STATUSES.contains(po.getStatus())
                        && (warehouseId == null || warehouseId.equals(po.getWarehouseId())))
                .collect(Collectors.toMap(PurchaseOrder::getId, po -> po));
        BigDecimal qty = BigDecimal.ZERO;
        LocalDate earliest = null;
        for (PurchaseOrderLine l : lines) {
            PurchaseOrder po = pos.get(l.getPoId());
            if (po == null) continue;
            BigDecimal pending = nullSafe(l.getQuantity()).subtract(nullSafe(l.getReceivedQuantity()));
            if (pending.signum() > 0) {
                qty = qty.add(pending);
                LocalDate eta = po.getExpectedDeliveryDate();
                if (eta != null && (earliest == null || eta.isBefore(earliest))) earliest = eta;
            }
        }
        return new OpenInflow(qty, earliest);
    }

    private OpenInflow openProductionInflow(UUID orgId, UUID itemId) {
        // Only IN_PROGRESS WOs are guaranteed inflow — DRAFT WOs can still be
        // cancelled, so they don't earn an ATP promise.
        List<WorkOrder> wos = workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(
                orgId, OPEN_WO_STATUSES);
        if (wos.isEmpty()) return OpenInflow.empty();
        BigDecimal qty = BigDecimal.ZERO;
        LocalDate earliest = null;
        for (WorkOrder wo : wos) {
            if (!itemId.equals(wo.getFinishedGoodId())) continue;
            BigDecimal pending = nullSafe(wo.getQuantityToProduce())
                    .subtract(nullSafe(wo.getQuantityProduced()));
            if (pending.signum() > 0) {
                qty = qty.add(pending);
                LocalDate eta = wo.getPlannedEndDate();
                if (eta != null && (earliest == null || eta.isBefore(earliest))) earliest = eta;
            }
        }
        return new OpenInflow(qty, earliest);
    }

    private static BigDecimal nullSafe(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static LocalDate earlier(LocalDate a, LocalDate b) {
        if (a == null) return b;
        if (b == null) return a;
        return a.isBefore(b) ? a : b;
    }

    /** Internal accumulator for one inflow source (PO or WO). */
    private record OpenInflow(BigDecimal qty, LocalDate earliestDate) {
        static OpenInflow empty() {
            return new OpenInflow(BigDecimal.ZERO, null);
        }
    }
}
