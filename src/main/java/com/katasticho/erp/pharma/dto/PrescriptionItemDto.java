package com.katasticho.erp.pharma.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record PrescriptionItemDto(
        UUID itemId,
        String itemName,
        BigDecimal quantity,
        String dosageInstructions
) {}
