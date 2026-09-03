package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.runway.CashRunwayReportResponse;
import com.katasticho.erp.accounting.dto.runway.CashRunwaySimulationRequest;
import com.katasticho.erp.accounting.dto.runway.CashRunwayWeeklyBucket;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalLineRepository;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 13-Week Rolling Cash Flow Runway & Working Capital Simulator (CFO Intelligence).
 * Projects future weekly liquidity positions starting from live liquid balances,
 * synthesizing AR collection probabilities, AP payment milestones, payroll,
 * statutory tax commitments, and what-if scenario simulations.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CashRunwayService {

    private final AccountRepository accountRepository;
    private final JournalLineRepository journalLineRepository;
    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final PurchaseOrderRepository purchaseOrderRepository;
    private final PayrollRunRepository payrollRunRepository;
    private final OrganisationRepository organisationRepository;

    private static final BigDecimal DEFAULT_SAFETY_BUFFER = BigDecimal.ZERO;
    private static final int FORECAST_WEEKS = 13;

    @Transactional(readOnly = true)
    public CashRunwayReportResponse generate13WeekRunway(LocalDate asOfDate, CashRunwaySimulationRequest simulation) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        LocalDate baseDate = asOfDate != null ? asOfDate : LocalDate.now();
        BigDecimal currentCash = computeLiveLiquidCash(orgId, baseDate);
        BigDecimal safetyBuffer = DEFAULT_SAFETY_BUFFER;

        // Effective simulation parameters (with defaults)
        int arDelayDays = simulation != null && simulation.arDelayDays() != null ? simulation.arDelayDays() : 0;
        int apExtensionDays = simulation != null && simulation.apExtensionDays() != null ? simulation.apExtensionDays() : 0;
        double arEfficiency = simulation != null && simulation.arCollectionEfficiency() != null
                ? simulation.arCollectionEfficiency() : 1.0;
        Map<Integer, BigDecimal> capexMap = simulation != null && simulation.plannedCapexByWeek() != null
                ? simulation.plannedCapexByWeek() : Collections.emptyMap();

        // 1. Fetch source items
        List<Invoice> outstandingInvoices = invoiceRepository.findOutstandingInvoices(orgId);
        List<PurchaseBill> outstandingBills = purchaseBillRepository.findOutstandingBills(orgId);
        List<PurchaseOrder> openPOs = purchaseOrderRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)
                .stream().filter(po -> "APPROVED".equalsIgnoreCase(po.getStatus()) || "SENT".equalsIgnoreCase(po.getStatus())).toList();
        BigDecimal estimatedMonthlyPayroll = estimateMonthlyPayroll(orgId, baseDate);

        // 2. Build 13 consecutive weekly buckets
        List<CashRunwayWeeklyBucket> buckets = new ArrayList<>();
        BigDecimal runningBalance = currentCash;
        BigDecimal totalInflows = BigDecimal.ZERO;
        BigDecimal totalOutflows = BigDecimal.ZERO;
        BigDecimal minBalance = currentCash;
        int minBalanceWeek = 1;
        int deficitCount = 0;
        List<String> alerts = new ArrayList<>();

        LocalDate weekStart = baseDate;

        for (int w = 1; w <= FORECAST_WEEKS; w++) {
            LocalDate weekEnd = weekStart.plusDays(6);
            String label = "W" + w + " (" + weekStart.getDayOfMonth() + "/" + weekStart.getMonthValue() + ")";

            // Inflows calculation
            BigDecimal arInflow = computeArInflowsForWeek(outstandingInvoices, weekStart, weekEnd, arDelayDays, arEfficiency, baseDate);
            BigDecimal pipelineOrders = BigDecimal.ZERO;
            BigDecimal recurringRev = BigDecimal.ZERO;
            BigDecimal weeklyInflow = arInflow.add(pipelineOrders).add(recurringRev);

            // Outflows calculation
            BigDecimal apOutflow = computeApOutflowsForWeek(outstandingBills, weekStart, weekEnd, apExtensionDays, baseDate);
            BigDecimal poOutflow = computePoOutflowsForWeek(openPOs, weekStart, weekEnd);
            BigDecimal payrollOutflow = computePayrollForWeek(estimatedMonthlyPayroll, weekStart, weekEnd);
            BigDecimal taxOutflow = computeStatutoryTaxForWeek(weekStart, weekEnd);
            BigDecimal opexOutflow = BigDecimal.ZERO;
            BigDecimal capexOutflow = capexMap.getOrDefault(w, BigDecimal.ZERO);
            BigDecimal weeklyOutflow = apOutflow.add(poOutflow).add(payrollOutflow).add(taxOutflow).add(opexOutflow).add(capexOutflow);

            BigDecimal netFlow = weeklyInflow.subtract(weeklyOutflow);
            BigDecimal opening = runningBalance;
            BigDecimal closing = opening.add(netFlow);

            boolean isDeficit = closing.compareTo(safetyBuffer) < 0;
            BigDecimal deficitAmt = isDeficit ? safetyBuffer.subtract(closing).max(BigDecimal.ZERO) : BigDecimal.ZERO;

            if (isDeficit) {
                deficitCount++;
                if (closing.compareTo(BigDecimal.ZERO) < 0) {
                    alerts.add(label + ": Critical Cash Deficit! Projected shortfall of ₹" + closing.abs().setScale(0, RoundingMode.HALF_UP) + " below zero.");
                }
            }

            if (closing.compareTo(minBalance) < 0) {
                minBalance = closing;
                minBalanceWeek = w;
            }

            totalInflows = totalInflows.add(weeklyInflow);
            totalOutflows = totalOutflows.add(weeklyOutflow);

            buckets.add(new CashRunwayWeeklyBucket(
                    w, weekStart, weekEnd, label, opening,
                    arInflow, pipelineOrders, recurringRev, weeklyInflow,
                    apOutflow, poOutflow, payrollOutflow, taxOutflow, opexOutflow, capexOutflow, weeklyOutflow,
                    netFlow, closing, isDeficit, deficitAmt
            ));

            runningBalance = closing;
            weekStart = weekEnd.plusDays(1);
        }

        // 3. Compute Runway in Weeks
        BigDecimal avgWeeklyOutflow = totalOutflows.divide(BigDecimal.valueOf(FORECAST_WEEKS), 2, RoundingMode.HALF_UP);
        BigDecimal avgWeeklyInflow = totalInflows.divide(BigDecimal.valueOf(FORECAST_WEEKS), 2, RoundingMode.HALF_UP);
        BigDecimal netWeeklyBurn = avgWeeklyOutflow.subtract(avgWeeklyInflow);

        Double runwayWeeks = 52.0; // Cap at 1 year if positive cash flow
        if (netWeeklyBurn.compareTo(BigDecimal.ZERO) > 0) {
            runwayWeeks = currentCash.divide(netWeeklyBurn, 1, RoundingMode.HALF_UP).doubleValue();
            runwayWeeks = Math.max(0.0, Math.min(runwayWeeks, 52.0));
        }

        // 4. Working Capital Health Metrics
        BigDecimal projectedCurrentRatio = totalOutflows.compareTo(BigDecimal.ZERO) > 0
                ? totalInflows.add(currentCash).divide(totalOutflows, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        BigDecimal projectedQuickRatio = totalOutflows.compareTo(BigDecimal.ZERO) > 0
                ? currentCash.add(totalInflows.multiply(BigDecimal.valueOf(0.8))).divide(totalOutflows, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        String liquidityStatus = deficitCount == 0 ? "HEALTHY" : (deficitCount <= 2 ? "MODERATE_RISK" : "CRITICAL_DEFICIT");

        CashRunwayReportResponse.WorkingCapitalMetrics metrics = new CashRunwayReportResponse.WorkingCapitalMetrics(
                projectedCurrentRatio, projectedQuickRatio, 0, liquidityStatus
        );

        return new CashRunwayReportResponse(
                baseDate, org.getBaseCurrency(), currentCash, safetyBuffer,
                runwayWeeks, minBalance, minBalanceWeek,
                totalInflows, totalOutflows, totalInflows.subtract(totalOutflows),
                deficitCount, alerts, buckets, metrics
        );
    }

    /** Sum of all cash & bank account balances from event-sourced journal lines. */
    private BigDecimal computeLiveLiquidCash(UUID orgId, LocalDate asOfDate) {
        List<Account> cashBankAccounts = accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId).stream()
                .filter(a -> "BANK".equalsIgnoreCase(a.getType()) || "CASH".equalsIgnoreCase(a.getType())
                        || "1000".equals(a.getCode()) || "1010".equals(a.getCode()) || "1020".equals(a.getCode()))
                .toList();

        if (cashBankAccounts.isEmpty()) return BigDecimal.ZERO;

        Set<UUID> accountIds = cashBankAccounts.stream().map(Account::getId).collect(Collectors.toSet());
        List<Object[]> trialData = journalLineRepository.computeTrialBalanceData(orgId, asOfDate);

        BigDecimal totalLiquid = BigDecimal.ZERO;
        for (Object[] row : trialData) {
            UUID accId = (UUID) row[0];
            if (accountIds.contains(accId)) {
                BigDecimal debit = (BigDecimal) row[1];
                BigDecimal credit = (BigDecimal) row[2];
                totalLiquid = totalLiquid.add(debit.subtract(credit));
            }
        }
        return totalLiquid.max(BigDecimal.ZERO);
    }

    private BigDecimal computeArInflowsForWeek(List<Invoice> invoices, LocalDate start, LocalDate end, int delayDays, double efficiency, LocalDate baseDate) {
        BigDecimal sum = BigDecimal.ZERO;
        for (Invoice inv : invoices) {
            LocalDate effDueDate = (inv.getDueDate() != null ? inv.getDueDate() : inv.getInvoiceDate()).plusDays(delayDays);
            // If already overdue before forecast, map to Week 1
            if (effDueDate.isBefore(start) && start.isEqual(baseDate)) {
                BigDecimal recoverable = inv.getBalanceDue().multiply(BigDecimal.valueOf(efficiency));
                sum = sum.add(recoverable);
            } else if (!effDueDate.isBefore(start) && !effDueDate.isAfter(end)) {
                BigDecimal recoverable = inv.getBalanceDue().multiply(BigDecimal.valueOf(efficiency));
                sum = sum.add(recoverable);
            }
        }
        return sum.setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal computeApOutflowsForWeek(List<PurchaseBill> bills, LocalDate start, LocalDate end, int extDays, LocalDate baseDate) {
        BigDecimal sum = BigDecimal.ZERO;
        for (PurchaseBill bill : bills) {
            LocalDate effDueDate = (bill.getDueDate() != null ? bill.getDueDate() : bill.getBillDate()).plusDays(extDays);
            if (effDueDate.isBefore(start) && start.isEqual(baseDate)) {
                sum = sum.add(bill.getBalanceDue());
            } else if (!effDueDate.isBefore(start) && !effDueDate.isAfter(end)) {
                sum = sum.add(bill.getBalanceDue());
            }
        }
        return sum.setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal computePoOutflowsForWeek(List<PurchaseOrder> pos, LocalDate start, LocalDate end) {
        BigDecimal sum = BigDecimal.ZERO;
        for (PurchaseOrder po : pos) {
            LocalDate delivery = po.getExpectedDeliveryDate() != null ? po.getExpectedDeliveryDate()
                    : (po.getCreatedAt() != null ? po.getCreatedAt().atZone(ZoneId.systemDefault()).toLocalDate().plusDays(10) : start);
            if (!delivery.isBefore(start) && !delivery.isAfter(end)) {
                sum = sum.add(po.getTotalAmount());
            }
        }
        return sum.setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal estimateMonthlyPayroll(UUID orgId, LocalDate baseDate) {
        List<PayrollRun> pastRuns = payrollRunRepository.findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(
                orgId, "POSTED", baseDate.minusMonths(3), baseDate);
        if (!pastRuns.isEmpty()) {
            return pastRuns.get(pastRuns.size() - 1).getNetPayTotal();
        }
        return BigDecimal.ZERO;
    }

    private BigDecimal computePayrollForWeek(BigDecimal monthlyPayroll, LocalDate start, LocalDate end) {
        // Disburses around 1st to 5th of each calendar month
        for (LocalDate d = start; !d.isAfter(end); d = d.plusDays(1)) {
            if (d.getDayOfMonth() == 1 || d.getDayOfMonth() == 5) {
                return monthlyPayroll;
            }
        }
        return BigDecimal.ZERO;
    }

    private BigDecimal computeStatutoryTaxForWeek(LocalDate start, LocalDate end) {
        return BigDecimal.ZERO;
    }
}
