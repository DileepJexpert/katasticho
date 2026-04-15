package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record TopSellingItem(
        int rank,
        UUID itemId,
        String sku,
        String name,
        String unit,
        BigDecimal quantity,
        BigDecimal revenue
) {}
