package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.StockBatch;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * API projection of a {@link StockBatch}, optionally enriched with the
 * warehouse-specific on-hand quantity so the invoice-line batch picker
 * can render "which batches have stock right now?" in one round-trip.
 *
 * <p>{@code quantityAvailable} is nullable — it's only populated by the
 * FEFO endpoint that already scoped the query to one warehouse.
 */
public record BatchResponse(
        UUID id,
        UUID itemId,
        String batchNumber,
        LocalDate expiryDate,
        LocalDate manufacturingDate,
        BigDecimal unitCost,
        UUID supplierId,
        boolean active,
        BigDecimal quantityAvailable
) {
    public static BatchResponse from(StockBatch b) {
        return new BatchResponse(
                b.getId(), b.getItemId(), b.getBatchNumber(),
                b.getExpiryDate(), b.getManufacturingDate(),
                b.getUnitCost(), b.getSupplierId(), b.isActive(),
                null);
    }

    public static BatchResponse from(StockBatch b, BigDecimal available) {
        return new BatchResponse(
                b.getId(), b.getItemId(), b.getBatchNumber(),
                b.getExpiryDate(), b.getManufacturingDate(),
                b.getUnitCost(), b.getSupplierId(), b.isActive(),
                available);
    }
}
