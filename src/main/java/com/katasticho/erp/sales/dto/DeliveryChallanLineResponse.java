package com.katasticho.erp.sales.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record DeliveryChallanLineResponse(
        UUID id,
        UUID salesOrderLineId,
        int lineNumber,
        UUID itemId,
        String itemName,
        String description,
        BigDecimal quantity,
        String unit,
        UUID batchId,
        String batchNumber
) {}
