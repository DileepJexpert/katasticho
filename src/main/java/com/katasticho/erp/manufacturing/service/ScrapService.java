package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.ProductionScrap;
import com.katasticho.erp.manufacturing.entity.ScrapReasonCode;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.ProductionScrapRepository;
import com.katasticho.erp.manufacturing.repository.ScrapReasonCodeRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ScrapService {

    private final ScrapReasonCodeRepository reasonCodeRepository;
    private final ProductionScrapRepository scrapRepository;
    private final WorkOrderRepository workOrderRepository;
    private final InventoryService inventoryService;

    // ── Reason Codes ──────────────────────────────────────────────

    @Transactional
    public ScrapReasonCode createReasonCode(String code, String description) {
        ScrapReasonCode rc = ScrapReasonCode.builder()
                .code(code)
                .description(description)
                .build();
        rc = reasonCodeRepository.save(rc);
        log.info("Created scrap reason code {} for org {}", code, TenantContext.getCurrentOrgId());
        return rc;
    }

    @Transactional(readOnly = true)
    public List<ScrapReasonCode> listReasonCodes() {
        return reasonCodeRepository.findByOrgIdAndIsActiveTrueAndIsDeletedFalseOrderByCodeAsc(
                TenantContext.getCurrentOrgId());
    }

    // ── Record Scrap ──────────────────────────────────────────────

    @Transactional
    public ProductionScrap recordScrap(UUID workOrderId, UUID itemId, BigDecimal scrapQty,
                                        UUID reasonCodeId, UUID jobCardId, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if (!"IN_PROGRESS".equals(wo.getStatus())) {
            throw new BusinessException("Scrap can only be recorded on IN_PROGRESS work orders",
                    "MFG_SCRAP_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        if (scrapQty == null || scrapQty.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Scrap quantity must be positive",
                    "MFG_SCRAP_INVALID_QTY", HttpStatus.BAD_REQUEST);
        }

        BigDecimal unitCost = wo.getLines().stream()
                .filter(l -> !l.isDeleted() && l.getItemId().equals(itemId))
                .findFirst()
                .map(l -> l.getUnitCost())
                .orElse(BigDecimal.ZERO);

        BigDecimal scrapCost = unitCost.multiply(scrapQty).setScale(2, RoundingMode.HALF_UP);

        // Only deduct warehouse stock in BACKFLUSH mode. In backflush the RM is still
        // in the warehouse (issueMaterials is deferred to FG receipt), so scrapping it
        // genuinely consumes warehouse stock. In the non-backflush path the RM already
        // left the warehouse at issueToProduction, so a second negative movement here
        // would double-deduct it. Either way the ProductionScrap row + WO scrap totals
        // are recorded (they drive scrap-rate reporting and the WIP scrap allocation).
        if (wo.isBackflushMode()) {
            inventoryService.recordMovement(new StockMovementRequest(
                    itemId,
                    wo.getWarehouseId(),
                    MovementType.PRODUCTION_SCRAP,
                    scrapQty.negate(),
                    unitCost,
                    LocalDate.now(),
                    ReferenceType.WORK_ORDER,
                    wo.getId(),
                    wo.getWorkOrderNumber(),
                    "Production scrap — " + wo.getWorkOrderNumber()
            ));
        }

        ProductionScrap scrap = ProductionScrap.builder()
                .workOrderId(workOrderId)
                .jobCardId(jobCardId)
                .itemId(itemId)
                .scrapQty(scrapQty)
                .unitCost(unitCost)
                .scrapCost(scrapCost)
                .reasonCodeId(reasonCodeId)
                .notes(notes)
                .build();
        scrap = scrapRepository.save(scrap);

        wo.setScrapQty(wo.getScrapQty().add(scrapQty));
        wo.setScrapCost(wo.getScrapCost().add(scrapCost));
        workOrderRepository.save(wo);

        log.info("Recorded scrap {} of item {} on WO {} (cost={}) for org {}",
                scrapQty, itemId, wo.getWorkOrderNumber(), scrapCost, orgId);
        return scrap;
    }

    @Transactional(readOnly = true)
    public List<ProductionScrap> getScrapForWorkOrder(UUID workOrderId) {
        return scrapRepository.findByWorkOrderIdAndOrgIdAndIsDeletedFalse(
                workOrderId, TenantContext.getCurrentOrgId());
    }

    @Transactional(readOnly = true)
    public Page<ProductionScrap> listScrap(Pageable pageable) {
        return scrapRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), pageable);
    }
}
