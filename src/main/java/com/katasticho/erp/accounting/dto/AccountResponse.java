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
        String parentAccountName,
        int level,
        boolean isSystem,
        boolean isInvolvedInTransaction,
        boolean hasChildren,
        int childCount,
        String description,
        BigDecimal openingBalance,
        String currency,
        boolean isActive
) {}
