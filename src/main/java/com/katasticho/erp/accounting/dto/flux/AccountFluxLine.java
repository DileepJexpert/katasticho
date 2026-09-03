package com.katasticho.erp.accounting.dto.flux;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AccountFluxLine {
    private UUID accountId;
    private String accountCode;
    private String accountName;
    private String accountType; // REVENUE or EXPENSE
    private BigDecimal basePeriodAmount;
    private BigDecimal comparisonPeriodAmount;
    private BigDecimal varianceAmount; // comparison - base
    private BigDecimal variancePercent; // (variance / base) * 100
    private String fluxDriver; // MATERIAL_EXPENSE_SPIKE, MATERIAL_EXPENSE_SAVING, REVENUE_GROWTH, REVENUE_DECLINE, NORMAL_VARIANCE
    private boolean material;
    private String commentary;
}