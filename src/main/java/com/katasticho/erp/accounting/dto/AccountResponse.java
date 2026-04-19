package com.katasticho.erp.accounting.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record AccountResponse(
        UUID id,
        String code,
        String name,
        String type,
        String subType,
        UUID parentId,
        int level,
        boolean isSystem,
        String description,
        BigDecimal openingBalance,
        String currency,
        boolean isActive
) {}
