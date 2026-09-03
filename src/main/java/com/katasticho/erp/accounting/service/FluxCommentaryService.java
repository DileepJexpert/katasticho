package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.flux.AccountFluxLine;
import com.katasticho.erp.accounting.dto.flux.FinancialFluxReportResponse;
import com.katasticho.erp.accounting.dto.report.ProfitLossResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class FluxCommentaryService {

    private final FinancialReportService financialReportService;

    private static final BigDecimal DEFAULT_MIN_MATERIAL_AMOUNT = new BigDecimal("5000.00");
    private static final BigDecimal DEFAULT_MIN_MATERIAL_PERCENT = new BigDecimal("15.00");
    private static final DateTimeFormatter MONTH_YEAR_FMT = DateTimeFormatter.ofPattern("MMM yyyy");

    public FinancialFluxReportResponse analyzeFlux(
            String periodType,
            LocalDate baseStart,
            LocalDate baseEnd,
            LocalDate compStart,
            LocalDate compEnd,
            BigDecimal minMaterialAmount,
            BigDecimal minMaterialPercent) {

        final String pType = (periodType != null && !periodType.isBlank()) ? periodType.toUpperCase() : "MOM";
        final BigDecimal minAmount = (minMaterialAmount != null && minMaterialAmount.compareTo(BigDecimal.ZERO) > 0)
                ? minMaterialAmount : DEFAULT_MIN_MATERIAL_AMOUNT;
        final BigDecimal minPercent = (minMaterialPercent != null && minMaterialPercent.compareTo(BigDecimal.ZERO) > 0)
                ? minMaterialPercent : DEFAULT_MIN_MATERIAL_PERCENT;

        // Auto-resolve dates for standard periods if not provided
        LocalDate bStart = baseStart;
        LocalDate bEnd = baseEnd;
        LocalDate cStart = compStart;
        LocalDate cEnd = compEnd;

        LocalDate now = LocalDate.now();
        if (cStart == null || cEnd == null || bStart == null || bEnd == null) {
            if ("QOQ".equalsIgnoreCase(pType)) {
                int currentMonth = now.getMonthValue();
                int currentQuarter = (currentMonth - 1) / 3 + 1;
                cStart = LocalDate.of(now.getYear(), (currentQuarter - 1) * 3 + 1, 1);
                cEnd = cStart.plusMonths(3).minusDays(1);

                bStart = cStart.minusMonths(3);
                bEnd = cStart.minusDays(1);
            } else if ("YOY".equalsIgnoreCase(pType)) {
                cStart = LocalDate.of(now.getYear(), 1, 1);
                cEnd = now;
                bStart = LocalDate.of(now.getYear() - 1, 1, 1);
                bEnd = now.minusYears(1);
            } else {
                LocalDate currentMonthFirst = LocalDate.of(now.getYear(), now.getMonth(), 1);
                cStart = currentMonthFirst.minusMonths(1);
                cEnd = currentMonthFirst.minusDays(1);
                bStart = cStart.minusMonths(1);
                bEnd = cStart.minusDays(1);
            }
        }

        ProfitLossResponse basePl = financialReportService.generateProfitLoss(bStart, bEnd);
        ProfitLossResponse compPl = financialReportService.generateProfitLoss(cStart, cEnd);

        String baseLabel = bStart.format(MONTH_YEAR_FMT) + (bStart.getMonth() != bEnd.getMonth() ? " - " + bEnd.format(MONTH_YEAR_FMT) : "");
        String compLabel = cStart.format(MONTH_YEAR_FMT) + (cStart.getMonth() != cEnd.getMonth() ? " - " + cEnd.format(MONTH_YEAR_FMT) : "");

        // Map base lines
        Map<UUID, ProfitLossResponse.AccountLine> baseRevenueMap = basePl.revenueAccounts().stream()
                .collect(Collectors.toMap(ProfitLossResponse.AccountLine::accountId, l -> l, (a, b) -> a));
        Map<UUID, ProfitLossResponse.AccountLine> baseExpenseMap = basePl.expenseAccounts().stream()
                .collect(Collectors.toMap(ProfitLossResponse.AccountLine::accountId, l -> l, (a, b) -> a));

        // Map comp lines
        Map<UUID, ProfitLossResponse.AccountLine> compRevenueMap = compPl.revenueAccounts().stream()
                .collect(Collectors.toMap(ProfitLossResponse.AccountLine::accountId, l -> l, (a, b) -> a));
        Map<UUID, ProfitLossResponse.AccountLine> compExpenseMap = compPl.expenseAccounts().stream()
                .collect(Collectors.toMap(ProfitLossResponse.AccountLine::accountId, l -> l, (a, b) -> a));

        List<AccountFluxLine> allLines = new ArrayList<>();

        // Process Revenue Accounts
        Set<UUID> allRevenueIds = new HashSet<>();
        allRevenueIds.addAll(baseRevenueMap.keySet());
        allRevenueIds.addAll(compRevenueMap.keySet());

        for (UUID acctId : allRevenueIds) {
            ProfitLossResponse.AccountLine bLine = baseRevenueMap.get(acctId);
            ProfitLossResponse.AccountLine cLine = compRevenueMap.get(acctId);

            String code = cLine != null ? cLine.accountCode() : (bLine != null ? bLine.accountCode() : "--");
            String name = cLine != null ? cLine.accountName() : (bLine != null ? bLine.accountName() : "Revenue Account");
            BigDecimal bAmt = bLine != null ? bLine.amount() : BigDecimal.ZERO;
            BigDecimal cAmt = cLine != null ? cLine.amount() : BigDecimal.ZERO;

            allLines.add(buildFluxLine(acctId, code, name, "REVENUE", bAmt, cAmt, minAmount, minPercent));
        }

        // Process Expense Accounts
        Set<UUID> allExpenseIds = new HashSet<>();
        allExpenseIds.addAll(baseExpenseMap.keySet());
        allExpenseIds.addAll(compExpenseMap.keySet());

        for (UUID acctId : allExpenseIds) {
            ProfitLossResponse.AccountLine bLine = baseExpenseMap.get(acctId);
            ProfitLossResponse.AccountLine cLine = compExpenseMap.get(acctId);

            String code = cLine != null ? cLine.accountCode() : (bLine != null ? bLine.accountCode() : "--");
            String name = cLine != null ? cLine.accountName() : (bLine != null ? bLine.accountName() : "Expense Account");
            BigDecimal bAmt = bLine != null ? bLine.amount() : BigDecimal.ZERO;
            BigDecimal cAmt = cLine != null ? cLine.amount() : BigDecimal.ZERO;

            allLines.add(buildFluxLine(acctId, code, name, "EXPENSE", bAmt, cAmt, minAmount, minPercent));
        }

        // Calculate Totals Variances
        BigDecimal revVarAmount = compPl.totalRevenue().subtract(basePl.totalRevenue());
        BigDecimal revVarPct = computePercentChange(basePl.totalRevenue(), revVarAmount);

        BigDecimal expVarAmount = compPl.totalExpenses().subtract(basePl.totalExpenses());
        BigDecimal expVarPct = computePercentChange(basePl.totalExpenses(), expVarAmount);

        BigDecimal netVarAmount = compPl.netProfit().subtract(basePl.netProfit());
        BigDecimal netVarPct = computePercentChange(basePl.netProfit(), netVarAmount);

        // Sort lines: Material lines first, then by absolute variance descending
        allLines.sort(Comparator.comparing(AccountFluxLine::isMaterial).reversed()
                .thenComparing((AccountFluxLine l) -> l.getVarianceAmount().abs(), Comparator.reverseOrder()));

        List<AccountFluxLine> topDrivers = allLines.stream()
                .filter(AccountFluxLine::isMaterial)
                .limit(6)
                .collect(Collectors.toList());

        String executiveNarrative = generateExecutiveSummary(
                baseLabel, compLabel,
                basePl.totalRevenue(), compPl.totalRevenue(), revVarAmount, revVarPct,
                basePl.totalExpenses(), compPl.totalExpenses(), expVarAmount, expVarPct,
                basePl.netProfit(), compPl.netProfit(), netVarAmount, netVarPct,
                allLines);

        return FinancialFluxReportResponse.builder()
                .periodType(pType)
                .basePeriodLabel(baseLabel)
                .baseStartDate(bStart)
                .baseEndDate(bEnd)
                .comparisonPeriodLabel(compLabel)
                .comparisonStartDate(cStart)
                .comparisonEndDate(cEnd)
                .currency(compPl.currency() != null ? compPl.currency() : "INR")
                .totalRevenueBase(basePl.totalRevenue())
                .totalRevenueComp(compPl.totalRevenue())
                .revenueVarianceAmount(revVarAmount)
                .revenueVariancePercent(revVarPct)
                .totalExpenseBase(basePl.totalExpenses())
                .totalExpenseComp(compPl.totalExpenses())
                .expenseVarianceAmount(expVarAmount)
                .expenseVariancePercent(expVarPct)
                .netProfitBase(basePl.netProfit())
                .netProfitComp(compPl.netProfit())
                .netProfitVarianceAmount(netVarAmount)
                .netProfitVariancePercent(netVarPct)
                .topDrivers(topDrivers)
                .accountLines(allLines)
                .executiveSummary(executiveNarrative)
                .build();
    }

    private AccountFluxLine buildFluxLine(
            UUID id, String code, String name, String type,
            BigDecimal baseAmt, BigDecimal compAmt,
            BigDecimal minAmount, BigDecimal minPercent) {

        BigDecimal variance = compAmt.subtract(baseAmt);
        BigDecimal pctChange = computePercentChange(baseAmt, variance);

        String driver = "NORMAL_VARIANCE";
        boolean isMaterial = false;
        String commentary = "";

        if ("EXPENSE".equals(type)) {
            if (variance.compareTo(minAmount) >= 0 && pctChange.compareTo(minPercent) >= 0) {
                driver = "MATERIAL_EXPENSE_SPIKE";
                isMaterial = true;
                commentary = String.format("Cost surge of +%.1f%% (+INR %s) vs prior period.", pctChange, formatCurrency(variance));
            } else if (variance.negate().compareTo(minAmount) >= 0 && pctChange.negate().compareTo(minPercent) >= 0) {
                driver = "MATERIAL_EXPENSE_SAVING";
                isMaterial = true;
                commentary = String.format("Cost reduction of %.1f%% (-INR %s) achieved.", pctChange.abs(), formatCurrency(variance.abs()));
            } else {
                commentary = String.format("Variance within normal bounds (%.1f%%).", pctChange);
            }
        } else if ("REVENUE".equals(type)) {
            if (variance.compareTo(minAmount) >= 0 && pctChange.compareTo(new BigDecimal("10.0")) >= 0) {
                driver = "REVENUE_GROWTH";
                isMaterial = true;
                commentary = String.format("Revenue expansion of +%.1f%% (+INR %s).", pctChange, formatCurrency(variance));
            } else if (variance.negate().compareTo(minAmount) >= 0 && pctChange.negate().compareTo(new BigDecimal("10.0")) >= 0) {
                driver = "REVENUE_DECLINE";
                isMaterial = true;
                commentary = String.format("Revenue contraction of %.1f%% (-INR %s).", pctChange.abs(), formatCurrency(variance.abs()));
            } else {
                commentary = String.format("Stable turnover (%.1f%% delta).", pctChange);
            }
        }

        return AccountFluxLine.builder()
                .accountId(id)
                .accountCode(code)
                .accountName(name)
                .accountType(type)
                .basePeriodAmount(baseAmt)
                .comparisonPeriodAmount(compAmt)
                .varianceAmount(variance)
                .variancePercent(pctChange)
                .fluxDriver(driver)
                .material(isMaterial)
                .commentary(commentary)
                .build();
    }

    private BigDecimal computePercentChange(BigDecimal base, BigDecimal delta) {
        if (base == null || base.compareTo(BigDecimal.ZERO) == 0) {
            return (delta != null && delta.compareTo(BigDecimal.ZERO) > 0)
                    ? new BigDecimal("100.00")
                    : (delta != null && delta.compareTo(BigDecimal.ZERO) < 0 ? new BigDecimal("-100.00") : BigDecimal.ZERO);
        }
        return delta.divide(base.abs(), 4, RoundingMode.HALF_UP).multiply(new BigDecimal("100")).setScale(2, RoundingMode.HALF_UP);
    }

    private String generateExecutiveSummary(
            String baseLabel, String compLabel,
            BigDecimal revBase, BigDecimal revComp, BigDecimal revDelta, BigDecimal revPct,
            BigDecimal expBase, BigDecimal expComp, BigDecimal expDelta, BigDecimal expPct,
            BigDecimal netBase, BigDecimal netComp, BigDecimal netDelta, BigDecimal netPct,
            List<AccountFluxLine> lines) {

        StringBuilder sb = new StringBuilder();

        // 1. High-level financial performance
        String revDirection = revDelta.compareTo(BigDecimal.ZERO) >= 0 ? "increased" : "declined";
        String expDirection = expDelta.compareTo(BigDecimal.ZERO) >= 0 ? "increased" : "contracted";
        String netDirection = netDelta.compareTo(BigDecimal.ZERO) >= 0 ? "expanded" : "compressed";

        sb.append(String.format("During %s, total revenue %s by %.1f%% to INR %s (compared to INR %s in %s). ",
                compLabel, revDirection, revPct.abs(), formatCurrency(revComp), formatCurrency(revBase), baseLabel));

        sb.append(String.format("Operating expenses %s by %.1f%% to INR %s. Net profit %s by %.1f%% (INR %s vs INR %s prior).\n\n",
                expDirection, expPct.abs(), formatCurrency(expComp), netDirection, netPct.abs(), formatCurrency(netComp), formatCurrency(netBase)));

        // 2. Material Cost Drivers
        List<AccountFluxLine> spikes = lines.stream()
                .filter(l -> "MATERIAL_EXPENSE_SPIKE".equals(l.getFluxDriver()))
                .limit(3)
                .collect(Collectors.toList());

        if (!spikes.isEmpty()) {
            sb.append("Key Expense Inflation Drivers:\n");
            for (AccountFluxLine s : spikes) {
                sb.append(String.format(" • %s: surged +%.1f%% (+INR %s) to INR %s\n",
                        s.getAccountName(), s.getVariancePercent(), formatCurrency(s.getVarianceAmount()), formatCurrency(s.getComparisonPeriodAmount())));
            }
            sb.append("\n");
        }

        // 3. Operational Efficiencies
        List<AccountFluxLine> savings = lines.stream()
                .filter(l -> "MATERIAL_EXPENSE_SAVING".equals(l.getFluxDriver()))
                .limit(3)
                .collect(Collectors.toList());

        if (!savings.isEmpty()) {
            sb.append("Operational Savings & Efficiencies:\n");
            for (AccountFluxLine sav : savings) {
                sb.append(String.format(" • %s: reduced by %.1f%% (-INR %s) down to INR %s\n",
                        sav.getAccountName(), sav.getVariancePercent().abs(), formatCurrency(sav.getVarianceAmount().abs()), formatCurrency(sav.getComparisonPeriodAmount())));
            }
        }

        return sb.toString().trim();
    }

    private String formatCurrency(BigDecimal amount) {
        if (amount == null) return "0.00";
        return amount.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }
}