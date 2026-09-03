package com.katasticho.erp.kenya.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KenyaPayeCalculationRequest {

    @NotNull(message = "Gross salary is required")
    @DecimalMin(value = "0.00", message = "Gross salary cannot be negative")
    private BigDecimal grossSalary;

    @Builder.Default
    private BigDecimal nonCashBenefits = BigDecimal.ZERO;

    @Builder.Default
    private BigDecimal pensionContribution = BigDecimal.ZERO;
}