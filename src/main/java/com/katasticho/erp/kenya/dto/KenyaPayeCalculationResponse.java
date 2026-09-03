package com.katasticho.erp.kenya.dto;

import lombok.Builder;

import java.math.BigDecimal;

@Builder
public record KenyaPayeCalculationResponse(
        BigDecimal grossSalary,
        BigDecimal nssfTier1,
        BigDecimal nssfTier2,
        BigDecimal totalNssf,
        BigDecimal taxablePay,
        BigDecimal grossPaye,
        BigDecimal personalRelief,
        BigDecimal insuranceRelief,
        BigDecimal netPaye,
        BigDecimal shifAmount,
        BigDecimal housingLevyAmount,
        BigDecimal totalDeductions,
        BigDecimal netPay
) {}