package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.service.PurchaseOrderService;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.supplychain.entity.DemandForecast;
import com.katasticho.erp.supplychain.entity.ItemSupplier;
import com.katasticho.erp.supplychain.entity.ReorderPolicy;
import com.katasticho.erp.supplychain.repository.DemandForecastRepository;
import com.katasticho.erp.supplychain.repository.ItemSupplierRepository;
import com.katasticho.erp.supplychain.repository.ReorderPolicyRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class MrpService {

    private final MrpRunRepository mrpRunRepo;
    private final MrpDemandRepository mrpDemandRepo;
    private final MrpSupplyRepository mrpSupplyRepo;
    private final PlannedOrderRepository plannedOrderRepo;

    private final SalesOrderRepository salesOrderRepo;
    private final ItemRepository itemRepo;
    private final StockBalanceRepository stockBalanceRepo;
    private final BomComponentRepository bomComponentRepo;
    private final ItemSupplierRepository itemSupplierRepo;
    private final ReorderPolicyRepository reorderPolicyRepo;
    private final DemandForecastRepository forecastRepo;
    private final WorkOrderRepository workOrderRepo;

    private final ManufacturingService manufacturingService;
    private final PurchaseOrderService purchaseOrderService;

    // ── Run MRP ──────────────────────────────────────────────────────────────

    @Transactional
    public MrpRun runMrp(int horizonDays) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate horizon = today.plusDays(horizonDays);

        // 1. Create MRP Run record
        MrpRun run = MrpRun.builder()
                .runDate(today)
                .status("RUNNING")
                .horizonDays(horizonDays)
                .build();
        run = mrpRunRepo.save(run);

        try {
            // 2. Collect demand
            Map<UUID, BigDecimal> demandByItem = new HashMap<>();

            // 2a. Open sales orders (CONFIRMED, not fully shipped)
            List<SalesOrder> openSOs = salesOrderRepo.findPendingDispatch(orgId);
            for (SalesOrder so : openSOs) {
                if (so.getOrderDate() != null && so.getOrderDate().isAfter(horizon)) {
                    continue;
                }
                for (SalesOrderLine line : so.getLines()) {
                    if (line.getItemId() == null) continue;
                    BigDecimal pending = line.getQuantity().subtract(line.getQuantityShipped());
                    if (pending.compareTo(BigDecimal.ZERO) <= 0) continue;

                    MrpDemand demand = MrpDemand.builder()
                            .mrpRun(run)
                            .itemId(line.getItemId())
                            .sourceType("SALES_ORDER")
                            .sourceId(so.getId())
                            .requiredDate(so.getExpectedShipmentDate() != null
                                    ? so.getExpectedShipmentDate() : today.plusDays(7))
                            .requiredQty(pending)
                            .build();
                    mrpDemandRepo.save(demand);

                    demandByItem.merge(line.getItemId(), pending, BigDecimal::add);
                }
            }

            // 2b. Demand forecasts within horizon
            List<DemandForecast> forecasts = forecastRepo
                    .findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                            orgId, today.withDayOfMonth(1), horizon.withDayOfMonth(1));
            for (DemandForecast f : forecasts) {
                MrpDemand demand = MrpDemand.builder()
                        .mrpRun(run)
                        .itemId(f.getItemId())
                        .sourceType("FORECAST")
                        .sourceId(f.getId())
                        .requiredDate(f.getForecastMonth())
                        .requiredQty(f.getForecastQty())
                        .build();
                mrpDemandRepo.save(demand);

                demandByItem.merge(f.getItemId(), f.getForecastQty(), BigDecimal::add);
            }

            // 3. Collect supply
            Map<UUID, BigDecimal> supplyByItem = new HashMap<>();

            // 3a. On-hand stock
            List<StockBalance> balances = stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId);
            for (StockBalance sb : balances) {
                BigDecimal available = sb.getQuantityOnHand().subtract(sb.getReservedQty());
                if (available.compareTo(BigDecimal.ZERO) <= 0) continue;

                MrpSupply supply = MrpSupply.builder()
                        .mrpRun(run)
                        .itemId(sb.getItemId())
                        .warehouseId(sb.getWarehouseId())
                        .supplyType("ON_HAND")
                        .availableDate(today)
                        .availableQty(available)
                        .build();
                mrpSupplyRepo.save(supply);

                supplyByItem.merge(sb.getItemId(), available, BigDecimal::add);
            }

            // 3b. In-progress Work Orders (expected output)
            List<WorkOrder> activeWos = workOrderRepo
                    .findByOrgIdAndStatusInAndIsDeletedFalse(orgId, List.of("IN_PROGRESS", "DRAFT"));
            for (WorkOrder wo : activeWos) {
                BigDecimal remaining = wo.getQuantityToProduce()
                        .subtract(wo.getQuantityProduced() != null ? wo.getQuantityProduced() : BigDecimal.ZERO);
                if (remaining.compareTo(BigDecimal.ZERO) <= 0) continue;

                LocalDate availDate = wo.getPlannedEndDate() != null ? wo.getPlannedEndDate() : today.plusDays(7);

                MrpSupply supply = MrpSupply.builder()
                        .mrpRun(run)
                        .itemId(wo.getFinishedGoodId())
                        .warehouseId(wo.getWarehouseId())
                        .supplyType("WORK_ORDER")
                        .supplyId(wo.getId())
                        .availableDate(availDate)
                        .availableQty(remaining)
                        .build();
                mrpSupplyRepo.save(supply);

                supplyByItem.merge(wo.getFinishedGoodId(), remaining, BigDecimal::add);
            }

            // 4. For each demanded item, compute net requirement and create planned orders
            Set<UUID> processedItems = new HashSet<>();
            // Use a queue so BOM explosion can add children
            Deque<UUID> itemQueue = new ArrayDeque<>(demandByItem.keySet());

            while (!itemQueue.isEmpty()) {
                UUID itemId = itemQueue.poll();
                if (processedItems.contains(itemId)) continue;
                processedItems.add(itemId);

                BigDecimal totalDemand = demandByItem.getOrDefault(itemId, BigDecimal.ZERO);
                BigDecimal totalSupply = supplyByItem.getOrDefault(itemId, BigDecimal.ZERO);

                // Get safety stock from reorder policy
                BigDecimal safetyStock = BigDecimal.ZERO;
                Optional<ReorderPolicy> policyOpt = reorderPolicyRepo
                        .findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, itemId);
                if (policyOpt.isPresent()) {
                    safetyStock = policyOpt.get().getSafetyStock() != null
                            ? policyOpt.get().getSafetyStock() : BigDecimal.ZERO;
                }

                BigDecimal netRequirement = totalDemand.subtract(totalSupply).add(safetyStock);

                if (netRequirement.compareTo(BigDecimal.ZERO) <= 0) {
                    continue; // Supply exceeds demand
                }

                // Determine if item is composite (PRODUCTION) or purchased
                Optional<Item> itemOpt = itemRepo.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId);
                if (itemOpt.isEmpty()) continue;
                Item item = itemOpt.get();

                List<BomComponent> bom = bomComponentRepo
                        .findCurrentBom(orgId, itemId);

                boolean isComposite = item.getItemType() == ItemType.COMPOSITE && !bom.isEmpty();
                // Phantom sub-assemblies are never produced on their own:
                // no PRODUCTION planned order — their components become
                // demand directly via the explosion below.
                boolean isPhantom = isComposite && item.isPhantom();

                int leadTime = 7;
                UUID supplierId = null;

                if (isComposite) {
                    // Look for routing lead time (default 7 days)
                    leadTime = 7;
                } else {
                    // Look up preferred supplier lead time
                    Optional<ItemSupplier> supplierOpt = itemSupplierRepo
                            .findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, itemId);
                    if (supplierOpt.isPresent()) {
                        leadTime = supplierOpt.get().getLeadTimeDays();
                        supplierId = supplierOpt.get().getSupplierId();
                    } else if (policyOpt.isPresent() && policyOpt.get().getLeadTimeDays() > 0) {
                        leadTime = policyOpt.get().getLeadTimeDays();
                    }
                }

                LocalDate plannedEnd = today.plusDays(horizonDays / 2);
                LocalDate plannedStart = plannedEnd.minusDays(leadTime);

                if (!isPhantom) {
                    PlannedOrder po = PlannedOrder.builder()
                            .mrpRun(run)
                            .itemId(itemId)
                            .orderType(isComposite ? "PRODUCTION" : "PURCHASE")
                            .plannedQty(netRequirement.setScale(4, RoundingMode.HALF_UP))
                            .plannedStartDate(plannedStart)
                            .plannedEndDate(plannedEnd)
                            .leadTimeDays(leadTime)
                            .supplierId(supplierId)
                            .status("PLANNED")
                            .notes("Auto-generated by MRP run. Net requirement: " + netRequirement)
                            .build();
                    plannedOrderRepo.save(po);
                }

                // 5. BOM explosion: create component demand for PRODUCTION
                //    orders. Phantoms explode too (that's their entire
                //    purpose) — the queue + processedItems set guards
                //    against cycles, since a revisited item is never
                //    re-processed.
                if (isComposite) {
                    for (BomComponent comp : bom) {
                        BigDecimal componentQty = comp.getQuantity()
                                .multiply(netRequirement);
                        BigDecimal scrap = comp.getScrapPercent() != null
                                ? comp.getScrapPercent() : BigDecimal.ZERO;
                        if (scrap.signum() > 0) {
                            componentQty = componentQty.multiply(
                                    BigDecimal.ONE.add(scrap.divide(BigDecimal.valueOf(100), 6, RoundingMode.HALF_UP)));
                        }
                        componentQty = componentQty.setScale(4, RoundingMode.HALF_UP);

                        MrpDemand componentDemand = MrpDemand.builder()
                                .mrpRun(run)
                                .itemId(comp.getChildItemId())
                                .sourceType("MRP_EXPLOSION")
                                .sourceId(itemId)
                                .requiredDate(plannedStart)
                                .requiredQty(componentQty)
                                .build();
                        mrpDemandRepo.save(componentDemand);

                        // Add to demand map and queue for processing
                        demandByItem.merge(comp.getChildItemId(), componentQty, BigDecimal::add);
                        if (!processedItems.contains(comp.getChildItemId())) {
                            itemQueue.add(comp.getChildItemId());
                        }
                    }
                }
            }

            run.setStatus("COMPLETED");
            run = mrpRunRepo.save(run);

            log.info("MRP run {} completed for org {} — {} demands, {} planned orders",
                    run.getId(), orgId, demandByItem.size(), processedItems.size());

        } catch (Exception e) {
            run.setStatus("FAILED");
            run.setNotes("Error: " + e.getMessage());
            mrpRunRepo.save(run);
            log.error("MRP run {} failed for org {}: {}", run.getId(), orgId, e.getMessage(), e);
            throw e;
        }

        return run;
    }

    // ── Query ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public MrpRun getMrpRun(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return mrpRunRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("MrpRun", id));
    }

    @Transactional(readOnly = true)
    public List<MrpRun> listMrpRuns() {
        return mrpRunRepo.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(TenantContext.getCurrentOrgId());
    }

    // ── Convert Planned → PO ─────────────────────────────────────────────────

    @Transactional
    public PlannedOrder convertPlannedToPO(UUID plannedOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PlannedOrder planned = plannedOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(plannedOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PlannedOrder", plannedOrderId));

        if (!"PLANNED".equals(planned.getStatus())) {
            throw new BusinessException(
                    "Planned order already converted or cancelled",
                    "MRP_ALREADY_CONVERTED", HttpStatus.BAD_REQUEST);
        }

        if (!"PURCHASE".equals(planned.getOrderType())) {
            throw new BusinessException(
                    "Only PURCHASE planned orders can be converted to a Purchase Order",
                    "MRP_WRONG_TYPE", HttpStatus.BAD_REQUEST);
        }

        if (planned.getSupplierId() == null) {
            throw new BusinessException(
                    "No supplier assigned to this planned order. Set a preferred supplier first.",
                    "MRP_NO_SUPPLIER", HttpStatus.BAD_REQUEST);
        }

        // Build PurchaseOrderRequest from planned order
        LocalDate orderDate = LocalDate.now();
        LocalDate deliveryDate = planned.getPlannedEndDate() != null
                ? planned.getPlannedEndDate() : orderDate.plusDays(planned.getLeadTimeDays());

        // Look up item price from preferred supplier
        BigDecimal unitPrice = itemSupplierRepo
                .findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, planned.getItemId())
                .map(ItemSupplier::getUnitPrice)
                .orElse(BigDecimal.ZERO);

        PurchaseOrderRequest request = new PurchaseOrderRequest(
                planned.getSupplierId(),
                orderDate,
                deliveryDate,
                "Generated from MRP run. Planned order: " + plannedOrderId,
                planned.getWarehouseId(),
                List.of(new PurchaseOrderRequest.LineRequest(
                        planned.getItemId(),
                        null,
                        planned.getPlannedQty(),
                        unitPrice,
                        null
                ))
        );

        var poResponse = purchaseOrderService.create(request);

        planned.setStatus("CONVERTED");
        planned.setPurchaseOrderId(poResponse.id());
        planned = plannedOrderRepo.save(planned);

        log.info("Planned order {} converted to PO {} for org {}", plannedOrderId, poResponse.id(), orgId);
        return planned;
    }

    // ── Convert Planned → WO ─────────────────────────────────────────────────

    @Transactional
    public PlannedOrder convertPlannedToWO(UUID plannedOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PlannedOrder planned = plannedOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(plannedOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PlannedOrder", plannedOrderId));

        if (!"PLANNED".equals(planned.getStatus())) {
            throw new BusinessException(
                    "Planned order already converted or cancelled",
                    "MRP_ALREADY_CONVERTED", HttpStatus.BAD_REQUEST);
        }

        if (!"PRODUCTION".equals(planned.getOrderType())) {
            throw new BusinessException(
                    "Only PRODUCTION planned orders can be converted to a Work Order",
                    "MRP_WRONG_TYPE", HttpStatus.BAD_REQUEST);
        }

        WorkOrder wo = manufacturingService.createWorkOrder(
                planned.getItemId(),
                planned.getWarehouseId(),
                planned.getPlannedQty(),
                planned.getPlannedStartDate(),
                planned.getPlannedEndDate(),
                null, null,
                "Generated from MRP run. Planned order: " + plannedOrderId
        );

        planned.setStatus("CONVERTED");
        planned.setWorkOrderId(wo.getId());
        planned = plannedOrderRepo.save(planned);

        log.info("Planned order {} converted to WO {} for org {}", plannedOrderId, wo.getId(), orgId);
        return planned;
    }
}
