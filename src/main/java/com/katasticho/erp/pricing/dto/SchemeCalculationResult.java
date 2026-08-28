package com.katasticho.erp.pricing.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record SchemeCalculationResult(
    UUID schemeId,
    String schemeName,
    String schemeType,
    BigDecimal orderedQuantity,
    BigDecimal freeQuantity,
    BigDecimal discountPercent,
    BigDecimal discountAmount,
    BigDecimal baseUnitPrice,
    BigDecimal effectiveUnitPrice,
    BigDecimal totalLineAmount,
    BigDecimal companyFundedAmount,
    BigDecimal distributorFundedAmount,
    boolean isHalfSchemeApplied,
    String explanation
) {}
