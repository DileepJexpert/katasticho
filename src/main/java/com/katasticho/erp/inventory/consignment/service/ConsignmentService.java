package com.katasticho.erp.inventory.consignment.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.consignment.entity.ConsignmentSettlement;
import com.katasticho.erp.inventory.consignment.entity.ConsignmentStock;
import com.katasticho.erp.inventory.consignment.repository.ConsignmentSettlementRepository;
import com.katasticho.erp.inventory.consignment.repository.ConsignmentStockRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ConsignmentService {

    private final ConsignmentStockRepository consignmentStockRepo;
    private final ConsignmentSettlementRepository settlementRepo;

    // ── Consignment Stock ─────────────────────────────────────────────────────

    /**
     * Receive consignment stock from a supplier into a warehouse.
     * If a record already exists for the same (item, warehouse, supplier), quantities are merged.
     */
    @Transactional
    public ConsignmentStock receiveConsignment(UUID itemId, UUID warehouseId, UUID supplierId,
                                               BigDecimal qty, BigDecimal unitCost,
                                               LocalDate consignmentDate, String agreementRef) {
        if (qty == null || qty.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Quantity must be positive", "CONSIGNMENT_INVALID_QTY");
        }
        UUID orgId = TenantContext.getCurrentOrgId();

        ConsignmentStock stock = consignmentStockRepo
                .findByOrgIdAndItemIdAndWarehouseIdAndSupplierIdAndIsDeletedFalse(
                        orgId, itemId, warehouseId, supplierId)
                .orElseGet(() -> ConsignmentStock.builder()
                        .itemId(itemId)
                        .warehouseId(warehouseId)
                        .supplierId(supplierId)
                        .build());

        // Weighted-average unit cost on top-up
        BigDecimal existingQty  = stock.getQuantity();
        BigDecimal existingCost = stock.getUnitCost();
        BigDecimal newTotalQty  = existingQty.add(qty);
        BigDecimal blendedCost  = newTotalQty.compareTo(BigDecimal.ZERO) == 0
                ? unitCost
                : (existingQty.multiply(existingCost).add(qty.multiply(unitCost)))
                  .divide(newTotalQty, 4, RoundingMode.HALF_UP);

        stock.setQuantity(newTotalQty);
        stock.setUnitCost(blendedCost);
        if (consignmentDate != null) stock.setConsignmentDate(consignmentDate);
        if (agreementRef    != null) stock.setAgreementRef(agreementRef);

        return consignmentStockRepo.save(stock);
    }

    /**
     * Record a sale of consignment goods — reduces on-hand quantity and creates a DRAFT settlement.
     */
    @Transactional
    public ConsignmentSettlement recordSale(UUID consignmentStockId, BigDecimal qtySold) {
        if (qtySold == null || qtySold.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Quantity sold must be positive", "CONSIGNMENT_INVALID_QTY");
        }
        UUID orgId = TenantContext.getCurrentOrgId();

        ConsignmentStock stock = consignmentStockRepo.findById(consignmentStockId)
                .filter(s -> s.getOrgId().equals(orgId) && !s.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("ConsignmentStock", consignmentStockId));

        if (stock.getQuantity().compareTo(qtySold) < 0) {
            throw new BusinessException(
                    "Insufficient consignment stock: available " + stock.getQuantity() + ", requested " + qtySold,
                    "CONSIGNMENT_INSUFFICIENT_STOCK",
                    HttpStatus.CONFLICT);
        }

        // Deduct stock
        stock.setQuantity(stock.getQuantity().subtract(qtySold));
        consignmentStockRepo.save(stock);

        // Build settlement
        BigDecimal total = qtySold.multiply(stock.getUnitCost())
                                  .setScale(4, RoundingMode.HALF_UP);

        ConsignmentSettlement settlement = ConsignmentSettlement.builder()
                .consignmentStockId(consignmentStockId)
                .settlementNumber(generateSettlementNumber(orgId))
                .quantitySold(qtySold)
                .unitCost(stock.getUnitCost())
                .totalAmount(total)
                .settlementDate(LocalDate.now())
                .status("DRAFT")
                .build();

        return settlementRepo.save(settlement);
    }

    /**
     * Mark a settlement as SETTLED (i.e., payable to supplier has been created externally).
     */
    @Transactional
    public ConsignmentSettlement settleConsignment(UUID settlementId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ConsignmentSettlement settlement = settlementRepo.findById(settlementId)
                .filter(s -> s.getOrgId().equals(orgId) && !s.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("ConsignmentSettlement", settlementId));

        if ("SETTLED".equals(settlement.getStatus())) {
            throw new BusinessException("Settlement is already settled",
                    "CONSIGNMENT_ALREADY_SETTLED", HttpStatus.CONFLICT);
        }

        settlement.setStatus("SETTLED");
        return settlementRepo.save(settlement);
    }

    // ── Queries ───────────────────────────────────────────────────────────────

    public List<ConsignmentStock> getConsignmentStock() {
        return consignmentStockRepo.findByOrgIdAndIsDeletedFalse(TenantContext.getCurrentOrgId());
    }

    public List<ConsignmentSettlement> getUnsettledSales(UUID supplierId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<ConsignmentStock> supplierStocks = consignmentStockRepo
                .findByOrgIdAndSupplierIdAndIsDeletedFalse(orgId, supplierId);
        if (supplierStocks.isEmpty()) {
            return List.of();
        }
        List<UUID> stockIds = supplierStocks.stream()
                .map(com.katasticho.erp.common.entity.BaseEntity::getId)
                .collect(Collectors.toList());
        return settlementRepo.findByOrgIdAndConsignmentStockIdInAndStatusAndIsDeletedFalse(
                orgId, stockIds, "DRAFT");
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String generateSettlementNumber(UUID orgId) {
        // Per-org sequence (was a GLOBAL count() → cross-org collisions + a tenant
        // volume leak). The V41 partial unique index (org, settlement_number)
        // backstops the residual MAX+1 race.
        String prefix = "CS-" + java.time.LocalDate.now().getYear();
        int seq = settlementRepo.nextSequence(orgId, prefix);
        return String.format("%s-%06d", prefix, seq);
    }
}
