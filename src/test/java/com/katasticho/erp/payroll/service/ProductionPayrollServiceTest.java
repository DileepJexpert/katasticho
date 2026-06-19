package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.repository.JobCardRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeSalaryStructure;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductionPayrollServiceTest {

    @Mock private JobCardRepository jobCardRepo;
    @Mock private EmployeeRepository employeeRepo;

    private ProductionPayrollService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID employeeId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ProductionPayrollService(jobCardRepo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private Employee buildEmployee(UUID linkedUserId) {
        Employee e = Employee.builder()
                .orgId(orgId)
                .userId(linkedUserId)
                .fullName("Floor Worker")
                .build();
        e.setId(employeeId);
        return e;
    }

    private EmployeeSalaryStructure structure(String payType, BigDecimal hourly, BigDecimal piece) {
        return EmployeeSalaryStructure.builder()
                .orgId(orgId)
                .employeeId(employeeId)
                .effectiveFrom(LocalDate.now().minusMonths(1))
                .payType(payType)
                .hourlyRate(hourly)
                .pieceRate(piece)
                .build();
    }

    private JobCard completedCard(int minutes, double qty) {
        return JobCard.builder()
                .workOrderId(UUID.randomUUID())
                .operationId(UUID.randomUUID())
                .sequenceNumber(1)
                .assignedTo(userId)
                .status("COMPLETED")
                .timeLoggedMinutes(minutes)
                .completedQty(BigDecimal.valueOf(qty))
                .actualEnd(Instant.now())
                .build();
    }

    @Test
    void salaryStructure_shortCircuits_returnsZero_doesNotQueryJobCards() {
        Employee emp = buildEmployee(userId);
        EmployeeSalaryStructure s = structure("SALARY", null, null);

        ProductionPayrollService.LaborPay pay = service.computeLaborPay(
                emp, s, LocalDate.now().minusDays(30), LocalDate.now());

        assertEquals(0, pay.amount().compareTo(BigDecimal.ZERO));
        assertEquals("SALARY", pay.payType());
        // Critical: SALARY workers don't even hit the manufacturing repo.
        verify(jobCardRepo, never()).findCompletedByAssigneeInWindow(any(), any(), any(), any());
    }

    @Test
    void hourly_sumsMinutesAcrossCards_andComputesHoursTimesRate() {
        Employee emp = buildEmployee(userId);
        EmployeeSalaryStructure s = structure("HOURLY", new BigDecimal("250.00"), null);
        // 3 cards: 120min + 90min + 30min = 240min = 4.0 hours.
        when(jobCardRepo.findCompletedByAssigneeInWindow(eq(orgId), eq(userId), any(), any()))
                .thenReturn(List.of(completedCard(120, 5), completedCard(90, 3), completedCard(30, 2)));

        ProductionPayrollService.LaborPay pay = service.computeLaborPay(
                emp, s, LocalDate.now().minusDays(30), LocalDate.now());

        assertEquals(0, pay.totalHours().compareTo(new BigDecimal("4.0000")));
        // 4 hours × ₹250 = ₹1000
        assertEquals(0, pay.amount().compareTo(new BigDecimal("1000.00")));
        assertEquals(3, pay.jobCardCount());
    }

    @Test
    void pieceRate_sumsCompletedQtyAcrossCards_andComputesPiecesTimesRate() {
        Employee emp = buildEmployee(userId);
        EmployeeSalaryStructure s = structure("PIECE_RATE", null, new BigDecimal("8.50"));
        when(jobCardRepo.findCompletedByAssigneeInWindow(eq(orgId), eq(userId), any(), any()))
                .thenReturn(List.of(completedCard(60, 25), completedCard(45, 15)));

        ProductionPayrollService.LaborPay pay = service.computeLaborPay(
                emp, s, LocalDate.now().minusDays(30), LocalDate.now());

        // 25 + 15 = 40 pieces × ₹8.50 = ₹340
        assertEquals(0, pay.totalPieces().compareTo(new BigDecimal("40")));
        assertEquals(0, pay.amount().compareTo(new BigDecimal("340.00")));
    }

    @Test
    void hourly_withNoLinkedAppUser_returnsZero_withoutQueryingJobCards() {
        Employee emp = buildEmployee(null);     // no user link
        EmployeeSalaryStructure s = structure("HOURLY", new BigDecimal("250.00"), null);

        ProductionPayrollService.LaborPay pay = service.computeLaborPay(
                emp, s, LocalDate.now().minusDays(30), LocalDate.now());

        assertEquals(0, pay.amount().compareTo(BigDecimal.ZERO));
        verify(jobCardRepo, never()).findCompletedByAssigneeInWindow(any(), any(), any(), any());
    }

    @Test
    void hourly_withNoRateSet_returnsZeroAmount_butKeepsHourCount() {
        Employee emp = buildEmployee(userId);
        EmployeeSalaryStructure s = structure("HOURLY", null, null);   // no rate
        when(jobCardRepo.findCompletedByAssigneeInWindow(eq(orgId), eq(userId), any(), any()))
                .thenReturn(List.of(completedCard(120, 5)));

        ProductionPayrollService.LaborPay pay = service.computeLaborPay(
                emp, s, LocalDate.now().minusDays(30), LocalDate.now());

        // Hours still recorded — useful for HR to spot mis-configured rates.
        assertEquals(0, pay.totalHours().compareTo(new BigDecimal("2.0000")));
        assertEquals(0, pay.amount().compareTo(BigDecimal.ZERO));
    }
}
