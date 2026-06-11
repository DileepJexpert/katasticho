package com.katasticho.erp.supplychain.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.supplychain.entity.*;
import com.katasticho.erp.supplychain.repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SupplyChainService {

    private final ItemSupplierRepository itemSupplierRepo;
    private final SupplierPerformanceRepository supplierPerfRepo;
    private final DemandForecastRepository forecastRepo;
    private final PurchaseRequisitionRepository requisitionRepo;
    private final ReturnOrderRepository returnOrderRepo;
    private final ReorderPolicyRepository reorderPolicyRepo;
    private final SupplyChainAlertRepository alertRepo;
    private final StockBalanceRepository stockBalanceRepo;
    private final ItemRepository itemRepo;
    private final EntityManager em;

    // ──────────────────────────────────────────────
    // Item-Supplier mapping
    // ──────────────────────────────────────────────

    @Transactional
    public ItemSupplier addItemSupplier(UUID itemId, UUID supplierId, int leadTimeDays,
                                        BigDecimal minOrderQty, BigDecimal unitPrice,
                                        boolean preferred, String supplierSku) {
        UUID orgId = TenantContext.getCurrentOrgId();
        itemSupplierRepo.findByOrgIdAndItemIdAndSupplierIdAndIsDeletedFalse(orgId, itemId, supplierId)
                .ifPresent(existing -> {
                    throw new BusinessException("This supplier is already mapped to this item",
                            "SC_DUPLICATE_ITEM_SUPPLIER", HttpStatus.CONFLICT);
                });

        if (preferred) {
            clearPreferred(orgId, itemId);
        }

        ItemSupplier is = ItemSupplier.builder()
                .itemId(itemId)
                .supplierId(supplierId)
                .leadTimeDays(leadTimeDays)
                .minOrderQty(minOrderQty)
                .unitPrice(unitPrice)
                .preferred(preferred)
                .supplierSku(supplierSku)
                .build();
        return itemSupplierRepo.save(is);
    }

    public List<ItemSupplier> getItemSuppliers(UUID itemId) {
        return itemSupplierRepo.findByOrgIdAndItemIdAndIsDeletedFalse(
                TenantContext.getCurrentOrgId(), itemId);
    }

    public List<ItemSupplier> getSupplierItems(UUID supplierId) {
        return itemSupplierRepo.findByOrgIdAndSupplierIdAndIsDeletedFalse(
                TenantContext.getCurrentOrgId(), supplierId);
    }

    @Transactional
    public ItemSupplier setPreferredSupplier(UUID itemId, UUID supplierId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        clearPreferred(orgId, itemId);
        ItemSupplier is = itemSupplierRepo.findByOrgIdAndItemIdAndSupplierIdAndIsDeletedFalse(orgId, itemId, supplierId)
                .orElseThrow(() -> BusinessException.notFound("ItemSupplier", itemId));
        is.setPreferred(true);
        return itemSupplierRepo.save(is);
    }

    @Transactional
    public void removeItemSupplier(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ItemSupplier is = itemSupplierRepo.findById(id)
                .filter(i -> i.getOrgId().equals(orgId) && !i.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("ItemSupplier", id));
        is.setDeleted(true);
        itemSupplierRepo.save(is);
    }

    private void clearPreferred(UUID orgId, UUID itemId) {
        itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, itemId)
                .ifPresent(existing -> {
                    existing.setPreferred(false);
                    itemSupplierRepo.save(existing);
                });
    }

    // ──────────────────────────────────────────────
    // Demand Forecasting
    // ──────────────────────────────────────────────

    @Transactional
    @SuppressWarnings("unchecked")
    public List<DemandForecast> generateForecast(int monthsAhead, int historyMonths) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate historyStart = today.minusMonths(historyMonths).withDayOfMonth(1);

        List<Object[]> salesData = em.createNativeQuery("""
                SELECT sm.item_id, DATE_TRUNC('month', sm.movement_date)::date AS month,
                       ABS(SUM(sm.quantity)) AS qty
                FROM stock_movement sm
                WHERE sm.org_id = :orgId
                  AND sm.movement_type = 'SALE'
                  AND sm.is_reversal = false AND sm.is_reversed = false
                  AND sm.movement_date >= :start
                GROUP BY sm.item_id, DATE_TRUNC('month', sm.movement_date)
                ORDER BY sm.item_id, month
                """)
                .setParameter("orgId", orgId)
                .setParameter("start", historyStart)
                .getResultList();

        Map<UUID, List<BigDecimal>> itemHistory = new LinkedHashMap<>();
        for (Object[] row : salesData) {
            UUID itemId = (UUID) row[0];
            BigDecimal qty = (BigDecimal) row[2];
            itemHistory.computeIfAbsent(itemId, k -> new ArrayList<>()).add(qty);
        }

        List<DemandForecast> forecasts = new ArrayList<>();
        for (Map.Entry<UUID, List<BigDecimal>> entry : itemHistory.entrySet()) {
            UUID itemId = entry.getKey();
            List<BigDecimal> history = entry.getValue();
            BigDecimal avg = movingAverage(history);

            for (int m = 1; m <= monthsAhead; m++) {
                LocalDate month = today.plusMonths(m).withDayOfMonth(1);
                DemandForecast f = DemandForecast.builder()
                        .itemId(itemId)
                        .forecastMonth(month)
                        .forecastQty(avg)
                        .method("MOVING_AVG")
                        .confidence(computeConfidence(history))
                        .build();
                forecasts.add(forecastRepo.save(f));
            }
        }
        return forecasts;
    }

    public List<DemandForecast> getForecasts(UUID itemId) {
        return forecastRepo.findByOrgIdAndItemIdAndIsDeletedFalseOrderByForecastMonthDesc(
                TenantContext.getCurrentOrgId(), itemId);
    }

    public List<DemandForecast> getForecastsInRange(LocalDate from, LocalDate to) {
        return forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                TenantContext.getCurrentOrgId(), from, to);
    }

    private BigDecimal movingAverage(List<BigDecimal> values) {
        if (values.isEmpty()) return BigDecimal.ZERO;
        BigDecimal sum = values.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        return sum.divide(BigDecimal.valueOf(values.size()), 4, RoundingMode.HALF_UP);
    }

    private BigDecimal computeConfidence(List<BigDecimal> history) {
        if (history.size() < 3) return new BigDecimal("50.00");
        BigDecimal avg = movingAverage(history);
        if (avg.compareTo(BigDecimal.ZERO) == 0) return new BigDecimal("50.00");
        BigDecimal variance = history.stream()
                .map(v -> v.subtract(avg).pow(2))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(history.size()), 4, RoundingMode.HALF_UP);
        BigDecimal stdDev = variance.sqrt(new MathContext(10));
        BigDecimal cv = stdDev.divide(avg, 4, RoundingMode.HALF_UP);
        BigDecimal confidence = BigDecimal.ONE.subtract(cv).multiply(new BigDecimal("100"))
                .max(BigDecimal.TEN).min(new BigDecimal("99"));
        return confidence.setScale(2, RoundingMode.HALF_UP);
    }

    // ──────────────────────────────────────────────
    // ABC Classification
    // ──────────────────────────────────────────────

    @Transactional
    @SuppressWarnings("unchecked")
    public List<ReorderPolicy> runAbcClassification() {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<Object[]> consumptionData = em.createNativeQuery("""
                SELECT sm.item_id, ABS(SUM(sm.total_cost)) AS total_value
                FROM stock_movement sm
                WHERE sm.org_id = :orgId
                  AND sm.movement_type = 'SALE'
                  AND sm.is_reversal = false AND sm.is_reversed = false
                  AND sm.movement_date >= :cutoff
                GROUP BY sm.item_id
                ORDER BY total_value DESC
                """)
                .setParameter("orgId", orgId)
                .setParameter("cutoff", LocalDate.now().minusMonths(12))
                .getResultList();

        BigDecimal grandTotal = consumptionData.stream()
                .map(r -> (BigDecimal) r[1])
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (grandTotal.compareTo(BigDecimal.ZERO) == 0) return List.of();

        BigDecimal cumulative = BigDecimal.ZERO;
        List<ReorderPolicy> results = new ArrayList<>();

        for (Object[] row : consumptionData) {
            UUID itemId = (UUID) row[0];
            BigDecimal value = (BigDecimal) row[1];
            cumulative = cumulative.add(value);
            BigDecimal pct = cumulative.divide(grandTotal, 4, RoundingMode.HALF_UP)
                    .multiply(new BigDecimal("100"));

            String abcClass;
            if (pct.compareTo(new BigDecimal("80")) <= 0) {
                abcClass = "A";
            } else if (pct.compareTo(new BigDecimal("95")) <= 0) {
                abcClass = "B";
            } else {
                abcClass = "C";
            }

            ReorderPolicy policy = reorderPolicyRepo
                    .findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, itemId)
                    .orElseGet(() -> {
                        ReorderPolicy rp = ReorderPolicy.builder().itemId(itemId).build();
                        rp.setOrgId(orgId);
                        return rp;
                    });
            policy.setAbcClass(abcClass);
            policy.setLastCalculated(Instant.now());
            results.add(reorderPolicyRepo.save(policy));
        }
        return results;
    }

    public List<ReorderPolicy> getReorderPolicies() {
        return reorderPolicyRepo.findByOrgIdAndIsDeletedFalseOrderByAbcClassAsc(
                TenantContext.getCurrentOrgId());
    }

    public List<ReorderPolicy> getByAbcClass(String abcClass) {
        return reorderPolicyRepo.findByOrgIdAndAbcClassAndIsDeletedFalse(
                TenantContext.getCurrentOrgId(), abcClass);
    }

    // ──────────────────────────────────────────────
    // Safety Stock & EOQ Calculation
    // ──────────────────────────────────────────────

    @Transactional
    @SuppressWarnings("unchecked")
    public ReorderPolicy calculateReorderParams(UUID itemId, UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<Object[]> dailySales = em.createNativeQuery("""
                SELECT sm.movement_date, ABS(SUM(sm.quantity)) AS daily_qty
                FROM stock_movement sm
                WHERE sm.org_id = :orgId AND sm.item_id = :itemId
                  AND sm.movement_type = 'SALE'
                  AND sm.is_reversal = false AND sm.is_reversed = false
                  AND sm.movement_date >= :cutoff
                GROUP BY sm.movement_date
                ORDER BY sm.movement_date
                """)
                .setParameter("orgId", orgId)
                .setParameter("itemId", itemId)
                .setParameter("cutoff", LocalDate.now().minusMonths(6))
                .getResultList();

        if (dailySales.isEmpty()) return getOrCreatePolicy(orgId, itemId, warehouseId);

        List<BigDecimal> quantities = dailySales.stream()
                .map(r -> (BigDecimal) r[1])
                .collect(Collectors.toList());

        BigDecimal avgDemand = movingAverage(quantities);
        BigDecimal variance = quantities.stream()
                .map(v -> v.subtract(avgDemand).pow(2))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(quantities.size()), 4, RoundingMode.HALF_UP);
        BigDecimal stdDev = variance.sqrt(new MathContext(10));

        ReorderPolicy policy = getOrCreatePolicy(orgId, itemId, warehouseId);
        int leadTime = policy.getLeadTimeDays();

        // Safety stock = Z * σ * √L  (Z=1.65 for 95% service level)
        BigDecimal z = new BigDecimal("1.65");
        BigDecimal sqrtLead = BigDecimal.valueOf(Math.sqrt(leadTime));
        BigDecimal safetyStock = z.multiply(stdDev).multiply(sqrtLead)
                .setScale(4, RoundingMode.HALF_UP);

        // Reorder point = avgDemand * L + safetyStock
        BigDecimal reorderPoint = avgDemand.multiply(BigDecimal.valueOf(leadTime))
                .add(safetyStock).setScale(4, RoundingMode.HALF_UP);

        // EOQ = √(2DS/H) where D=annual demand, S=ordering cost (est 500), H=holding cost (est 20% of price)
        BigDecimal annualDemand = avgDemand.multiply(new BigDecimal("365"));
        BigDecimal orderingCost = new BigDecimal("500");
        BigDecimal itemPrice = itemRepo.findById(itemId)
                .map(i -> i.getPurchasePrice().max(BigDecimal.ONE))
                .orElse(BigDecimal.ONE);
        BigDecimal holdingCost = itemPrice.multiply(new BigDecimal("0.20"));
        BigDecimal eoqInner = annualDemand.multiply(orderingCost).multiply(new BigDecimal("2"))
                .divide(holdingCost.max(BigDecimal.ONE), 4, RoundingMode.HALF_UP);
        BigDecimal eoq = eoqInner.sqrt(new MathContext(10)).setScale(4, RoundingMode.HALF_UP);

        policy.setSafetyStock(safetyStock);
        policy.setReorderPoint(reorderPoint);
        policy.setReorderQty(eoq);
        policy.setEoq(eoq);
        policy.setLastCalculated(Instant.now());
        return reorderPolicyRepo.save(policy);
    }

    private ReorderPolicy getOrCreatePolicy(UUID orgId, UUID itemId, UUID warehouseId) {
        if (warehouseId != null) {
            return reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdAndIsDeletedFalse(orgId, itemId, warehouseId)
                    .orElseGet(() -> {
                        ReorderPolicy rp = ReorderPolicy.builder().itemId(itemId).warehouseId(warehouseId).build();
                        rp.setOrgId(orgId);
                        return rp;
                    });
        }
        return reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, itemId)
                .orElseGet(() -> {
                    ReorderPolicy rp = ReorderPolicy.builder().itemId(itemId).build();
                    rp.setOrgId(orgId);
                    return rp;
                });
    }

    // ──────────────────────────────────────────────
    // Purchase Requisition
    // ──────────────────────────────────────────────

    @Transactional
    public PurchaseRequisition createRequisition(UUID supplierId, UUID warehouseId,
                                                  LocalDate requiredByDate, String notes,
                                                  List<RequisitionLineRequest> lineRequests) {
        UUID orgId = TenantContext.getCurrentOrgId();
        int seq = requisitionRepo.findMaxRequisitionSequence(orgId) + 1;
        String number = String.format("PR-%05d", seq);

        PurchaseRequisition pr = PurchaseRequisition.builder()
                .requisitionNumber(number)
                .requestedBy(TenantContext.getCurrentUserId())
                .supplierId(supplierId)
                .warehouseId(warehouseId)
                .requiredByDate(requiredByDate)
                .notes(notes)
                .source("MANUAL")
                .build();

        BigDecimal total = BigDecimal.ZERO;
        for (RequisitionLineRequest lr : lineRequests) {
            BigDecimal lineTotal = lr.estimatedUnitPrice().multiply(lr.requiredQty());
            PurchaseRequisitionLine line = PurchaseRequisitionLine.builder()
                    .requisition(pr)
                    .itemId(lr.itemId())
                    .requiredQty(lr.requiredQty())
                    .estimatedUnitPrice(lr.estimatedUnitPrice())
                    .estimatedLineTotal(lineTotal)
                    .build();
            pr.getLines().add(line);
            total = total.add(lineTotal);
        }
        pr.setTotalAmount(total);
        return requisitionRepo.save(pr);
    }

    @Transactional
    public PurchaseRequisition autoCreateRequisition() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<StockBalance> lowStock = stockBalanceRepo.findLowStock(orgId);
        if (lowStock.isEmpty()) return null;

        List<RequisitionLineRequest> lines = new ArrayList<>();
        for (StockBalance sb : lowStock) {
            itemRepo.findById(sb.getItemId()).ifPresent(item -> {
                if (!item.isDeleted() && item.isTrackInventory()) {
                    BigDecimal reorderQty = item.getReorderQuantity().compareTo(BigDecimal.ZERO) > 0
                            ? item.getReorderQuantity()
                            : item.getReorderLevel().subtract(sb.getQuantityOnHand()).max(BigDecimal.ONE);
                    lines.add(new RequisitionLineRequest(
                            item.getId(), reorderQty, item.getPurchasePrice()));
                }
            });
        }

        if (lines.isEmpty()) return null;
        return createRequisition(null, null, LocalDate.now().plusDays(7),
                "Auto-generated from low stock alert", lines);
    }

    @Transactional
    public PurchaseRequisition approveRequisition(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PurchaseRequisition pr = requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseRequisition", id));
        if (!"DRAFT".equals(pr.getStatus()) && !"SUBMITTED".equals(pr.getStatus())) {
            throw new BusinessException("Only DRAFT/SUBMITTED requisitions can be approved",
                    "SC_INVALID_PR_STATUS", HttpStatus.BAD_REQUEST);
        }
        pr.setStatus("APPROVED");
        pr.setApprovedBy(TenantContext.getCurrentUserId());
        pr.setApprovedAt(Instant.now());
        return requisitionRepo.save(pr);
    }

    @Transactional
    public PurchaseRequisition submitRequisition(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PurchaseRequisition pr = requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseRequisition", id));
        if (!"DRAFT".equals(pr.getStatus())) {
            throw new BusinessException("Only DRAFT requisitions can be submitted",
                    "SC_INVALID_PR_STATUS", HttpStatus.BAD_REQUEST);
        }
        pr.setStatus("SUBMITTED");
        return requisitionRepo.save(pr);
    }

    @Transactional
    public PurchaseRequisition rejectRequisition(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PurchaseRequisition pr = requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseRequisition", id));
        pr.setStatus("REJECTED");
        return requisitionRepo.save(pr);
    }

    public Page<PurchaseRequisition> listRequisitions(String status, int page, int size) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PageRequest pr = PageRequest.of(page, size);
        if (status != null && !status.isEmpty()) {
            return requisitionRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pr);
        }
        return requisitionRepo.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pr);
    }

    public PurchaseRequisition getRequisition(UUID id) {
        return requisitionRepo.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("PurchaseRequisition", id));
    }

    // ──────────────────────────────────────────────
    // Return Orders
    // ──────────────────────────────────────────────

    @Transactional
    public ReturnOrder createReturnOrder(String returnType, UUID contactId,
                                          UUID warehouseId, String reasonCode,
                                          String reasonNotes,
                                          List<ReturnLineRequest> lineRequests) {
        UUID orgId = TenantContext.getCurrentOrgId();
        int seq = returnOrderRepo.findMaxReturnSequence(orgId) + 1;
        String number = String.format("RET-%05d", seq);

        ReturnOrder ro = ReturnOrder.builder()
                .returnNumber(number)
                .returnType(returnType)
                .contactId(contactId)
                .warehouseId(warehouseId)
                .reasonCode(reasonCode)
                .reasonNotes(reasonNotes)
                .build();

        BigDecimal total = BigDecimal.ZERO;
        for (ReturnLineRequest lr : lineRequests) {
            BigDecimal lineTotal = lr.unitPrice().multiply(lr.quantity());
            ReturnOrderLine line = ReturnOrderLine.builder()
                    .returnOrder(ro)
                    .itemId(lr.itemId())
                    .batchId(lr.batchId())
                    .quantity(lr.quantity())
                    .unitPrice(lr.unitPrice())
                    .lineTotal(lineTotal)
                    .condition(lr.condition() != null ? lr.condition() : "GOOD")
                    .restock(lr.restock())
                    .build();
            ro.getLines().add(line);
            total = total.add(lineTotal);
        }
        ro.setTotalAmount(total);
        ro.setNetRefund(total);
        return returnOrderRepo.save(ro);
    }

    @Transactional
    public ReturnOrder approveReturn(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ReturnOrder ro = returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ReturnOrder", id));
        if (!"DRAFT".equals(ro.getStatus())) {
            throw new BusinessException("Only DRAFT return orders can be approved",
                    "SC_INVALID_RETURN_STATUS", HttpStatus.BAD_REQUEST);
        }
        ro.setStatus("APPROVED");
        ro.setApprovedBy(TenantContext.getCurrentUserId());
        ro.setApprovedAt(Instant.now());
        return returnOrderRepo.save(ro);
    }

    @Transactional
    public ReturnOrder processReturn(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ReturnOrder ro = returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ReturnOrder", id));
        if (!"APPROVED".equals(ro.getStatus())) {
            throw new BusinessException("Only APPROVED return orders can be processed",
                    "SC_INVALID_RETURN_STATUS", HttpStatus.BAD_REQUEST);
        }
        ro.setStatus("PROCESSED");
        return returnOrderRepo.save(ro);
    }

    @Transactional
    public ReturnOrder cancelReturn(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ReturnOrder ro = returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("ReturnOrder", id));
        if ("PROCESSED".equals(ro.getStatus())) {
            throw new BusinessException("Processed return orders cannot be cancelled",
                    "SC_RETURN_ALREADY_PROCESSED", HttpStatus.BAD_REQUEST);
        }
        ro.setStatus("CANCELLED");
        return returnOrderRepo.save(ro);
    }

    public Page<ReturnOrder> listReturnOrders(String status, String returnType, int page, int size) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PageRequest pr = PageRequest.of(page, size);
        if (status != null && !status.isEmpty()) {
            return returnOrderRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pr);
        }
        if (returnType != null && !returnType.isEmpty()) {
            return returnOrderRepo.findByOrgIdAndReturnTypeAndIsDeletedFalseOrderByCreatedAtDesc(orgId, returnType, pr);
        }
        return returnOrderRepo.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pr);
    }

    public ReturnOrder getReturnOrder(UUID id) {
        return returnOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("ReturnOrder", id));
    }

    // ──────────────────────────────────────────────
    // Supply Chain Alerts
    // ──────────────────────────────────────────────

    @Transactional
    public SupplyChainAlert createAlert(String alertType, String severity, String title,
                                         String description, UUID itemId, UUID supplierId,
                                         UUID warehouseId) {
        SupplyChainAlert alert = SupplyChainAlert.builder()
                .alertType(alertType)
                .severity(severity)
                .title(title)
                .description(description)
                .itemId(itemId)
                .supplierId(supplierId)
                .warehouseId(warehouseId)
                .build();
        return alertRepo.save(alert);
    }

    @Transactional
    public SupplyChainAlert resolveAlert(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SupplyChainAlert alert = alertRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("SupplyChainAlert", id));
        alert.setStatus("RESOLVED");
        alert.setResolvedAt(Instant.now());
        alert.setResolvedBy(TenantContext.getCurrentUserId());
        return alertRepo.save(alert);
    }

    public Page<SupplyChainAlert> listAlerts(String status, int page, int size) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PageRequest pr = PageRequest.of(page, size);
        if (status != null && !status.isEmpty()) {
            return alertRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pr);
        }
        return alertRepo.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pr);
    }

    @Transactional
    @SuppressWarnings("unchecked")
    public List<SupplyChainAlert> runAlertScan() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<SupplyChainAlert> alerts = new ArrayList<>();

        // 1. Stockout risk: items below safety stock
        List<ReorderPolicy> policies = reorderPolicyRepo.findByOrgIdAndIsDeletedFalseOrderByAbcClassAsc(orgId);
        for (ReorderPolicy policy : policies) {
            stockBalanceRepo.findByOrgIdAndItemId(orgId, policy.getItemId()).stream()
                    .filter(sb -> sb.getQuantityOnHand().compareTo(policy.getSafetyStock()) < 0)
                    .forEach(sb -> {
                        boolean exists = !alertRepo.findByOrgIdAndAlertTypeAndStatusAndIsDeletedFalse(
                                orgId, "STOCKOUT_RISK", "OPEN").isEmpty();
                        if (!exists) {
                            alerts.add(createAlert("STOCKOUT_RISK", "HIGH",
                                    "Stock below safety level",
                                    "Item stock " + sb.getQuantityOnHand() + " is below safety stock " + policy.getSafetyStock(),
                                    policy.getItemId(), null, sb.getWarehouseId()));
                        }
                    });
        }

        // 2. Low stock alerts from reorder point
        List<StockBalance> lowStock = stockBalanceRepo.findLowStock(orgId);
        for (StockBalance sb : lowStock) {
            boolean alreadyAlerted = !alertRepo.findByOrgIdAndAlertTypeAndStatusAndIsDeletedFalse(
                    orgId, "LOW_STOCK", "OPEN").isEmpty();
            if (!alreadyAlerted) {
                alerts.add(createAlert("LOW_STOCK", "MEDIUM",
                        "Stock below reorder level",
                        "Current qty: " + sb.getQuantityOnHand(),
                        sb.getItemId(), null, sb.getWarehouseId()));
            }
        }

        return alerts;
    }

    // ──────────────────────────────────────────────
    // Inventory Analytics
    // ──────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    public List<Map<String, Object>> getInventoryTurnover(int months) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate cutoff = LocalDate.now().minusMonths(months);

        List<Object[]> data = em.createNativeQuery("""
                SELECT sm.item_id,
                       ABS(SUM(CASE WHEN sm.movement_type = 'SALE' THEN sm.total_cost ELSE 0 END)) AS cogs,
                       i.name AS item_name
                FROM stock_movement sm
                JOIN item i ON i.id = sm.item_id
                WHERE sm.org_id = :orgId
                  AND sm.is_reversal = false AND sm.is_reversed = false
                  AND sm.movement_date >= :cutoff
                GROUP BY sm.item_id, i.name
                ORDER BY cogs DESC
                """)
                .setParameter("orgId", orgId)
                .setParameter("cutoff", cutoff)
                .getResultList();

        List<Map<String, Object>> results = new ArrayList<>();
        for (Object[] row : data) {
            UUID itemId = (UUID) row[0];
            BigDecimal cogs = (BigDecimal) row[1];
            String name = (String) row[2];

            BigDecimal avgInventory = stockBalanceRepo.findByOrgIdAndItemId(orgId, itemId).stream()
                    .map(sb -> sb.getQuantityOnHand().multiply(sb.getAverageCost()))
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            BigDecimal turnover = avgInventory.compareTo(BigDecimal.ZERO) > 0
                    ? cogs.divide(avgInventory, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            BigDecimal daysOnHand = turnover.compareTo(BigDecimal.ZERO) > 0
                    ? new BigDecimal("365").divide(turnover, 0, RoundingMode.HALF_UP)
                    : new BigDecimal("999");

            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("itemId", itemId);
            entry.put("itemName", name);
            entry.put("cogs", cogs);
            entry.put("avgInventoryValue", avgInventory);
            entry.put("turnoverRatio", turnover);
            entry.put("daysOnHand", daysOnHand);
            results.add(entry);
        }
        return results;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getSupplyChainDashboard() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> dashboard = new LinkedHashMap<>();

        long openAlerts = alertRepo.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "OPEN");
        dashboard.put("openAlerts", openAlerts);

        List<StockBalance> lowStock = stockBalanceRepo.findLowStock(orgId);
        dashboard.put("lowStockCount", lowStock.size());

        List<ReorderPolicy> policies = reorderPolicyRepo.findByOrgIdAndIsDeletedFalseOrderByAbcClassAsc(orgId);
        long classA = policies.stream().filter(p -> "A".equals(p.getAbcClass())).count();
        long classB = policies.stream().filter(p -> "B".equals(p.getAbcClass())).count();
        long classC = policies.stream().filter(p -> "C".equals(p.getAbcClass())).count();
        dashboard.put("abcClassification", Map.of("A", classA, "B", classB, "C", classC));

        BigDecimal totalInventoryValue = stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId).stream()
                .map(sb -> sb.getQuantityOnHand().multiply(sb.getAverageCost()))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        dashboard.put("totalInventoryValue", totalInventoryValue);

        List<ReorderPolicy> autoReorder = reorderPolicyRepo.findByOrgIdAndAutoReorderTrueAndIsDeletedFalse(orgId);
        dashboard.put("autoReorderItems", autoReorder.size());

        return dashboard;
    }

    // ──────────────────────────────────────────────
    // Supplier Performance
    // ──────────────────────────────────────────────

    public List<SupplierPerformance> getSupplierScorecard(UUID supplierId) {
        return supplierPerfRepo.findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByPeriodStartDesc(
                TenantContext.getCurrentOrgId(), supplierId);
    }

    public List<SupplierPerformance> getSupplierRankings() {
        return supplierPerfRepo.findByOrgIdAndIsDeletedFalseOrderByOverallScoreDesc(
                TenantContext.getCurrentOrgId());
    }

    @Transactional
    @SuppressWarnings("unchecked")
    public SupplierPerformance calculateSupplierPerformance(UUID supplierId, LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<Object[]> poData = em.createNativeQuery("""
                SELECT COUNT(DISTINCT po.id) AS total_orders,
                       COALESCE(SUM(pol.quantity), 0) AS total_qty
                FROM purchase_orders po
                JOIN purchase_order_line pol ON pol.purchase_order_id = po.id
                WHERE po.org_id = :orgId AND po.supplier_id = :supplierId
                  AND po.order_date BETWEEN :from AND :to
                  AND po.is_deleted = false
                """)
                .setParameter("orgId", orgId)
                .setParameter("supplierId", supplierId)
                .setParameter("from", from)
                .setParameter("to", to)
                .getResultList();

        List<Object[]> grnData = em.createNativeQuery("""
                SELECT COALESCE(SUM(srl.received_qty), 0) AS received,
                       COALESCE(SUM(srl.quantity - srl.received_qty), 0) AS rejected,
                       COALESCE(SUM(srl.received_qty * srl.unit_cost), 0) AS amount
                FROM stock_receipt sr
                JOIN stock_receipt_line srl ON srl.stock_receipt_id = sr.id
                WHERE sr.org_id = :orgId AND sr.supplier_id = :supplierId
                  AND sr.receipt_date BETWEEN :from AND :to
                  AND sr.is_deleted = false
                """)
                .setParameter("orgId", orgId)
                .setParameter("supplierId", supplierId)
                .setParameter("from", from)
                .setParameter("to", to)
                .getResultList();

        int totalOrders = poData.isEmpty() ? 0 : ((Number) poData.get(0)[0]).intValue();
        BigDecimal totalQtyOrdered = poData.isEmpty() ? BigDecimal.ZERO : (BigDecimal) poData.get(0)[1];
        BigDecimal totalQtyReceived = grnData.isEmpty() ? BigDecimal.ZERO : (BigDecimal) grnData.get(0)[0];
        BigDecimal totalQtyRejected = grnData.isEmpty() ? BigDecimal.ZERO : (BigDecimal) grnData.get(0)[1];
        BigDecimal totalAmount = grnData.isEmpty() ? BigDecimal.ZERO : (BigDecimal) grnData.get(0)[2];

        BigDecimal qualityRate = totalQtyReceived.add(totalQtyRejected).compareTo(BigDecimal.ZERO) > 0
                ? totalQtyReceived.divide(totalQtyReceived.add(totalQtyRejected), 4, RoundingMode.HALF_UP)
                        .multiply(new BigDecimal("100"))
                : new BigDecimal("100");

        BigDecimal overallScore = qualityRate;

        SupplierPerformance perf = supplierPerfRepo
                .findByOrgIdAndSupplierIdAndPeriodStartAndPeriodEndAndIsDeletedFalse(orgId, supplierId, from, to)
                .orElseGet(() -> {
                    SupplierPerformance sp = SupplierPerformance.builder()
                            .supplierId(supplierId)
                            .periodStart(from)
                            .periodEnd(to)
                            .build();
                    sp.setOrgId(orgId);
                    return sp;
                });

        perf.setTotalOrders(totalOrders);
        perf.setTotalQtyOrdered(totalQtyOrdered);
        perf.setTotalQtyReceived(totalQtyReceived);
        perf.setTotalQtyRejected(totalQtyRejected);
        perf.setTotalAmount(totalAmount);
        perf.setQualityRate(qualityRate);
        perf.setOverallScore(overallScore);

        return supplierPerfRepo.save(perf);
    }

    // ──────────────────────────────────────────────
    // DTOs
    // ──────────────────────────────────────────────

    public record RequisitionLineRequest(UUID itemId, BigDecimal requiredQty, BigDecimal estimatedUnitPrice) {}
    public record ReturnLineRequest(UUID itemId, UUID batchId, BigDecimal quantity,
                                     BigDecimal unitPrice, String condition, boolean restock) {}
}
