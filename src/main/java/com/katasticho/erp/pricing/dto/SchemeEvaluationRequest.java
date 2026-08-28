package com.katasticho.erp.pricing.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;

public record SchemeEvaluationRequest(
    @NotNull UUID itemId,
    @NotNull BigDecimal quantity,
    @NotNull BigDecimal unitPrice,
    UUID schemeId
) {}
