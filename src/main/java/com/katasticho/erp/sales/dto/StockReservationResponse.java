package com.katasticho.erp.sales.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record StockReservationResponse(
        UUID id,
        UUID itemId,
        String itemName,
        UUID warehouseId,
        String warehouseName,
        BigDecimal quantityReserved,
        String status,
        Instant reservedAt
) {}
