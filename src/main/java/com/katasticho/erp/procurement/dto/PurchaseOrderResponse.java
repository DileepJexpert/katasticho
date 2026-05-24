package com.katasticho.erp.procurement.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PurchaseOrderResponse(
        UUID id,
        UUID orgId,
        UUID supplierId,
        String supplierName,
        String poNumber,
        String status,
        LocalDate orderDate,
        LocalDate expectedDeliveryDate,
        String notes,
        UUID warehouseId,
        BigDecimal totalAmount,
        List<LineResponse> lines,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            UUID poId,
            UUID itemId,
            String itemName,
            String description,
            BigDecimal quantity,
            BigDecimal receivedQuantity,
            BigDecimal unitPrice,
            UUID taxGroupId,
            BigDecimal lineTotal
    ) {}
}
