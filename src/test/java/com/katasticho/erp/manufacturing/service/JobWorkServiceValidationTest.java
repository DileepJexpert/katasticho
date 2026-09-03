package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.JobWorkOrder;
import com.katasticho.erp.manufacturing.entity.JobWorkOrderLine;
import com.katasticho.erp.manufacturing.repository.JobWorkOrderRepository;
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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JobWorkServiceValidationTest {

    @Mock private JobWorkOrderRepository orderRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private InventoryService inventoryService;

    private JobWorkService service;
    private final UUID orgId = UUID.randomUUID();
    private final UUID orderId = UUID.randomUUID();
    private final UUID warehouseId = UUID.randomUUID();
    private final UUID materialId = UUID.randomUUID();
    private final UUID outputId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new JobWorkService(orderRepository, itemRepository, inventoryService);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void receiveGoods_withoutLines_rejectsRequestBeforePostingStock() {
        JobWorkOrder order = sentOrder(false, false);
        when(orderRepository.findByIdAndOrgIdAndIsDeletedFalse(orderId, orgId)).thenReturn(Optional.of(order));

        BusinessException exception = assertThrows(BusinessException.class,
                () -> service.receiveGoods(orderId, List.of()));

        assertEquals("JW_NO_RECEIPT_LINES", exception.getErrorCode());
        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void cancelJobWorkOrder_afterOutputReceipt_requiresStockCorrection() {
        JobWorkOrder order = sentOrder(true, true);
        when(orderRepository.findByIdAndOrgIdAndIsDeletedFalse(orderId, orgId)).thenReturn(Optional.of(order));

        BusinessException exception = assertThrows(BusinessException.class,
                () -> service.cancelJobWorkOrder(orderId));

        assertEquals("JW_OUTPUT_RECEIVED_CANNOT_CANCEL", exception.getErrorCode());
        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void createJobWorkOrder_rejectsBlankOrZeroMaterialQuantity() {
        BusinessException exception = assertThrows(BusinessException.class,
                () -> service.createJobWorkOrder(UUID.randomUUID(), warehouseId,
                        List.of(new JobWorkService.JobWorkLineInput(materialId, BigDecimal.ZERO)),
                        BigDecimal.ZERO, null, null, null));

        assertEquals("JW_LINE_QTY_INVALID", exception.getErrorCode());
    }

    private JobWorkOrder sentOrder(boolean withOutput, boolean outputReceived) {
        JobWorkOrder order = JobWorkOrder.builder()
                .jobWorkNumber("JW-00001")
                .vendorId(UUID.randomUUID())
                .warehouseId(warehouseId)
                .status("PARTIALLY_RECEIVED")
                .processingCharges(BigDecimal.ZERO)
                .totalMaterialCost(BigDecimal.valueOf(100))
                .totalCost(BigDecimal.valueOf(100))
                .lines(new ArrayList<>())
                .build();
        order.setId(orderId);
        order.setOrgId(orgId);
        order.getLines().add(line(order, materialId, "MATERIAL", BigDecimal.TEN, BigDecimal.ZERO));
        if (withOutput) {
            order.getLines().add(line(order, outputId, "OUTPUT", BigDecimal.TEN,
                    outputReceived ? BigDecimal.ONE : BigDecimal.ZERO));
        }
        return order;
    }

    private JobWorkOrderLine line(JobWorkOrder order, UUID itemId, String lineType,
                                  BigDecimal sent, BigDecimal received) {
        return JobWorkOrderLine.builder()
                .jobWorkOrder(order)
                .itemId(itemId)
                .lineType(lineType)
                .sentQty(sent)
                .receivedQty(received)
                .wastageQty(BigDecimal.ZERO)
                .unitCost(BigDecimal.TEN)
                .lineCost(BigDecimal.TEN)
                .status("SENT")
                .build();
    }
}
