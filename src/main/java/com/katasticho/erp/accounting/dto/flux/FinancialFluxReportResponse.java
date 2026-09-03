package com.katasticho.erp.accounting.dto.flux;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FinancialFluxReportResponse {
    private String periodType; // MOM, QOQ, YOY, CUSTOM
    private String basePeriodLabel;
    private LocalDate baseStartDate;
    private LocalDate baseEndDate;

    private String comparisonPeriodLabel;
    private LocalDate comparisonStartDate;
    private LocalDate comparisonEndDate;

    private String currency;

    // Totals
    private BigDecimal totalRevenueBase;
    private BigDecimal totalRevenueComp;
    private BigDecimal revenueVarianceAmount;
    private BigDecimal revenueVariancePercent;

    private BigDecimal totalExpenseBase;
    private BigDecimal totalExpenseComp;
    private BigDecimal expenseVarianceAmount;
    private BigDecimal expenseVariancePercent;

    private BigDecimal netProfitBase;
    private BigDecimal netProfitComp;
    private BigDecimal netProfitVarianceAmount;
    private BigDecimal netProfitVariancePercent;

    // Top flux drivers sorted by materiality
    private List<AccountFluxLine> topDrivers;

    // Full detailed account lines
    private List<AccountFluxLine> accountLines;

    // AI / Rule-based synthesized executive narrative
    private String executiveSummary;
}