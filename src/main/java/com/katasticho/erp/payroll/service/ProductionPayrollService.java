package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.repository.JobCardRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeSalaryStructure;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * Production→payroll bridge (tracker #57). Sums an HOURLY or PIECE_RATE
 * worker's COMPLETED job cards in a payroll period and computes their
 * production-driven pay. Read-only on the manufacturing side — this
 * service never edits job cards; it just aggregates them.
 *
 * <p>SALARY employees never reach this code: {@link #computeLaborPay}
 * is only called from {@code PayrollService.calculatePayslip} when
 * {@code structure.payType != SALARY}.
 *
 * <p>Job cards are matched on {@code assignedTo} = the app user id
 * the worker carries on {@code Employee.userId}. If an employee has no
 * linked app user, the bridge returns zero hours/pieces — they simply
 * fall through to whatever their structure components produce (which
 * is the right answer for someone who isn't on the floor that month).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductionPayrollService {

    private final JobCardRepository jobCardRepository;
    private final EmployeeRepository employeeRepository;

    /**
     * Production-driven labour pay for one employee over a period.
     *
     * @param totalHours      sum of {@code timeLoggedMinutes / 60} on
     *                        completed job cards in the window
     * @param totalPieces     sum of {@code completedQty} on completed job
     *                        cards in the window
     * @param jobCardCount    how many job cards backed the rollup
     * @param amount          ₹ pay for the period — hours × hourlyRate
     *                        when {@code HOURLY}, pieces × pieceRate when
     *                        {@code PIECE_RATE}, ZERO when SALARY or no
     *                        rate set
     * @param payType         the structure's {@code payType} at calc time
     *                        (echoed back so the payslip line can name it)
     */
    public record LaborPay(BigDecimal totalHours, BigDecimal totalPieces,
                           int jobCardCount, BigDecimal amount, String payType) {}

    public static LaborPay zero(String payType) {
        return new LaborPay(BigDecimal.ZERO, BigDecimal.ZERO, 0, BigDecimal.ZERO, payType);
    }

    @Transactional(readOnly = true)
    public LaborPay computeLaborPay(Employee employee, EmployeeSalaryStructure structure,
                                    LocalDate periodStart, LocalDate periodEnd) {
        String payType = structure.getPayType() != null ? structure.getPayType() : "SALARY";
        if ("SALARY".equals(payType)) return zero(payType);
        if (employee.getUserId() == null) {
            log.debug("Employee {} not linked to an app user — labour pay = 0",
                    employee.getId());
            return zero(payType);
        }

        Instant from = periodStart.atStartOfDay(ZoneOffset.UTC).toInstant();
        // periodEnd is inclusive in payroll terminology — go one day past
        // to half-open the window against the JPQL <
        Instant to = periodEnd.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        List<JobCard> cards = jobCardRepository.findCompletedByAssigneeInWindow(
                employee.getOrgId(), employee.getUserId(), from, to);

        BigDecimal totalMinutes = BigDecimal.ZERO;
        BigDecimal totalPieces = BigDecimal.ZERO;
        for (JobCard jc : cards) {
            totalMinutes = totalMinutes.add(BigDecimal.valueOf(jc.getTimeLoggedMinutes()));
            if (jc.getCompletedQty() != null) {
                totalPieces = totalPieces.add(jc.getCompletedQty());
            }
        }
        BigDecimal totalHours = totalMinutes
                .divide(BigDecimal.valueOf(60), 4, RoundingMode.HALF_UP);

        BigDecimal amount = BigDecimal.ZERO;
        switch (payType) {
            case "HOURLY" -> {
                BigDecimal rate = structure.getHourlyRate();
                if (rate != null) {
                    amount = totalHours.multiply(rate).setScale(2, RoundingMode.HALF_UP);
                }
            }
            case "PIECE_RATE" -> {
                BigDecimal rate = structure.getPieceRate();
                if (rate != null) {
                    amount = totalPieces.multiply(rate).setScale(2, RoundingMode.HALF_UP);
                }
            }
            default -> { /* falls through to zero */ }
        }

        return new LaborPay(totalHours, totalPieces, cards.size(), amount, payType);
    }

    /**
     * Convenience preview endpoint backing — looks up the employee by id
     * inside the current tenant.
     */
    @Transactional(readOnly = true)
    public LaborPay previewByEmployeeId(UUID employeeId, EmployeeSalaryStructure structure,
                                        LocalDate periodStart, LocalDate periodEnd) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Employee employee = employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId)
                .orElseThrow(() -> new com.katasticho.erp.common.exception.BusinessException(
                        "Employee not found",
                        "PAYROLL_EMPLOYEE_NOT_FOUND",
                        org.springframework.http.HttpStatus.NOT_FOUND));
        Objects.requireNonNull(structure, "structure required");
        return computeLaborPay(employee, structure, periodStart, periodEnd);
    }
}
