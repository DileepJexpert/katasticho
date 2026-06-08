package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.BaseEntity;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.ProductionScrap;
import com.katasticho.erp.manufacturing.entity.ScrapReasonCode;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.entity.WorkOrderLine;
import com.katasticho.erp.manufacturing.repository.ProductionScrapRepository;
import com.katasticho.erp.manufacturing.repository.ScrapReasonCodeRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ScrapServiceTest {

    @Mock private ScrapReasonCodeRepository reasonCodeRepository;
    @Mock private ProductionScrapRepository scrapRepository;
    @Mock private WorkOrderRepository workOrderRepository;
    @Mock private InventoryService inventoryService;

    private ScrapService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID warehouseId = UUID.randomUUID();
    private final UUID fgItemId = UUID.randomUUID();
    private final UUID rmItemId = UUID.randomUUID();
    private final UUID reasonCodeId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ScrapService(
                reasonCodeRepository, scrapRepository, workOrderRepository, inventoryService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── createReasonCode ─────────────────────────────────────────

    @Test
    void createReasonCode_success() {
        when(reasonCodeRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });

        ScrapReasonCode result = service.createReasonCode("DEFECT", "Manufacturing defect");

        assertNotNull(result.getId());
        assertEquals("DEFECT", result.getCode());
        assertEquals("Manufacturing defect", result.getDescription());
        assertTrue(result.isActive());
        verify(reasonCodeRepository).save(any());
    }

    // ── recordScrap ──────────────────────────────────────────────

    @Test
    void recordScrap_inProgressOrder_createsMovementAndUpdatesWoTotals() {
        WorkOrder wo = buildWorkOrder("IN_PROGRESS");

        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(scrapRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });
        when(workOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ProductionScrap result = service.recordScrap(
                wo.getId(), rmItemId, BigDecimal.valueOf(5), reasonCodeId, null, "Defective batch");

        assertNotNull(result.getId());
        assertEquals(wo.getId(), result.getWorkOrderId());
        assertEquals(rmItemId, result.getItemId());
        assertEquals(0, BigDecimal.valueOf(5).compareTo(result.getScrapQty()));
        // unitCost=50 from the WO line, scrapCost = 50 * 5 = 250.00
        assertEquals(0, BigDecimal.valueOf(50).compareTo(result.getUnitCost()));
        assertEquals(0, BigDecimal.valueOf(250).setScale(2).compareTo(result.getScrapCost()));
        assertEquals(reasonCodeId, result.getReasonCodeId());
        assertEquals("Defective batch", result.getNotes());

        // WO totals updated
        assertEquals(0, BigDecimal.valueOf(5).compareTo(wo.getScrapQty()));
        assertEquals(0, BigDecimal.valueOf(250).setScale(2).compareTo(wo.getScrapCost()));

        verify(inventoryService).recordMovement(any());
        verify(workOrderRepository).save(wo);
    }

    @Test
    void recordScrap_notInProgress_throws() {
        WorkOrder wo = buildWorkOrder("DRAFT");

        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordScrap(wo.getId(), rmItemId, BigDecimal.valueOf(3),
                        reasonCodeId, null, null));
        assertEquals("MFG_SCRAP_NOT_IN_PROGRESS", ex.getErrorCode());
        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void recordScrap_zeroOrNegativeQty_throws() {
        WorkOrder wo = buildWorkOrder("IN_PROGRESS");

        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        // Zero qty
        BusinessException ex1 = assertThrows(BusinessException.class,
                () -> service.recordScrap(wo.getId(), rmItemId, BigDecimal.ZERO,
                        reasonCodeId, null, null));
        assertEquals("MFG_SCRAP_INVALID_QTY", ex1.getErrorCode());

        // Negative qty
        BusinessException ex2 = assertThrows(BusinessException.class,
                () -> service.recordScrap(wo.getId(), rmItemId, BigDecimal.valueOf(-2),
                        reasonCodeId, null, null));
        assertEquals("MFG_SCRAP_INVALID_QTY", ex2.getErrorCode());

        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void recordScrap_itemNotInBom_usesZeroCost() {
        WorkOrder wo = buildWorkOrder("IN_PROGRESS");
        UUID unknownItemId = UUID.randomUUID(); // not in WO lines

        when(workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(scrapRepository.save(any())).thenAnswer(inv -> {
            var e = inv.getArgument(0);
            if (((BaseEntity) e).getId() == null) ((BaseEntity) e).setId(UUID.randomUUID());
            return e;
        });
        when(workOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ProductionScrap result = service.recordScrap(
                wo.getId(), unknownItemId, BigDecimal.valueOf(10), reasonCodeId, null, null);

        assertEquals(0, BigDecimal.ZERO.compareTo(result.getUnitCost()));
        assertEquals(0, BigDecimal.ZERO.setScale(2).compareTo(result.getScrapCost()));

        // WO totals still updated (with zero cost)
        assertEquals(0, BigDecimal.valueOf(10).compareTo(wo.getScrapQty()));
        assertEquals(0, BigDecimal.ZERO.setScale(2).compareTo(wo.getScrapCost()));

        verify(inventoryService).recordMovement(any());
    }

    // ── helpers ──────────────────────────────────────────────────

    private WorkOrder buildWorkOrder(String status) {
        WorkOrderLine line = WorkOrderLine.builder()
                .itemId(rmItemId)
                .requiredQty(BigDecimal.valueOf(30))
                .issuedQty(BigDecimal.ZERO)
                .unitCost(BigDecimal.valueOf(50))
                .lineCost(BigDecimal.valueOf(1500))
                .status("PENDING")
                .build();

        WorkOrder wo = WorkOrder.builder()
                .workOrderNumber("WO-00001")
                .finishedGoodId(fgItemId)
                .warehouseId(warehouseId)
                .quantityToProduce(BigDecimal.TEN)
                .quantityProduced(BigDecimal.ZERO)
                .status(status)
                .rawMaterialCost(BigDecimal.valueOf(1500))
                .directLaborCost(BigDecimal.ZERO)
                .overheadCost(BigDecimal.ZERO)
                .totalCost(BigDecimal.valueOf(1500))
                .unitCost(BigDecimal.valueOf(150))
                .scrapQty(BigDecimal.ZERO)
                .scrapCost(BigDecimal.ZERO)
                .lines(new ArrayList<>(List.of(line)))
                .build();
        wo.setId(UUID.randomUUID());
        wo.setOrgId(orgId);
        line.setWorkOrder(wo);
        return wo;
    }
}
