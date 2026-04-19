package com.katasticho.erp.sales.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record SalesOrderLineResponse(
        UUID id,
        int lineNumber,
        UUID itemId,
        String itemName,
        String description,
        BigDecimal quantity,
        BigDecimal quantityShipped,
        BigDecimal quantityInvoiced,
        String unit,
        BigDecimal rate,
        BigDecimal discountPct,
        UUID taxGroupId,
        BigDecimal taxRate,
        String hsnCode,
        BigDecimal amount
) {}
