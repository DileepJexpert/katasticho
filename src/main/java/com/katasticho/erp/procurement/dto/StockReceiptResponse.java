package com.katasticho.erp.procurement.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record StockReceiptResponse(
        UUID id,
        String receiptNumber,
        LocalDate receiptDate,
        UUID warehouseId,
        String warehouseName,
        UUID supplierId,
        String supplierName,
        String supplierGstin,
        String supplierInvoiceNo,
        LocalDate supplierInvoiceDate,
        String status,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        String currency,
        String notes,
        List<LineResponse> lines,
        Instant receivedAt,
        Instant cancelledAt,
        String cancelReason,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            Integer lineNumber,
            UUID itemId,
            String itemSku,
            String description,
            String hsnCode,
            BigDecimal quantity,
            String unitOfMeasure,
            BigDecimal unitPrice,
            BigDecimal discountPercent,
            BigDecimal taxableAmount,
            BigDecimal gstRate,
            BigDecimal taxAmount,
            BigDecimal lineTotal,
            String batchNumber,
            LocalDate expiryDate,
            LocalDate manufacturingDate,
            UUID stockMovementId
    ) {}
}
