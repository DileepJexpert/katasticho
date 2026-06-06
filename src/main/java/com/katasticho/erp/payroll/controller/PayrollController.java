package com.katasticho.erp.payroll.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.payroll.dto.*;
import com.katasticho.erp.payroll.entity.*;
import com.katasticho.erp.payroll.service.PayrollService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/payroll")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.PAYROLL)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
public class PayrollController {

    private final PayrollService service;

    // ── Settings ──

    @GetMapping("/settings")
    public ResponseEntity<ApiResponse<PayrollSettings>> getSettings() {
        return ResponseEntity.ok(ApiResponse.ok(service.getOrCreateSettings()));
    }

    @PutMapping("/settings")
    public ResponseEntity<ApiResponse<PayrollSettings>> updateSettings(
            @Valid @RequestBody PayrollSettingsRequest request) {
        PayrollSettings settings = PayrollSettings.builder()
                .payrollStartMonth(request.payrollStartMonth())
                .payFrequency(request.payFrequency())
                .defaultSalaryExpenseAccountId(request.defaultSalaryExpenseAccountId())
                .defaultSalaryPayableAccountId(request.defaultSalaryPayableAccountId())
                .defaultPfPayableAccountId(request.defaultPfPayableAccountId())
                .defaultEsiPayableAccountId(request.defaultEsiPayableAccountId())
                .defaultPtPayableAccountId(request.defaultPtPayableAccountId())
                .defaultLwfPayableAccountId(request.defaultLwfPayableAccountId())
                .defaultTdsPayableAccountId(request.defaultTdsPayableAccountId())
                .pfEnabled(request.pfEnabled())
                .esiEnabled(request.esiEnabled())
                .ptEnabled(request.ptEnabled())
                .lwfEnabled(request.lwfEnabled())
                .tdsEnabled(request.tdsEnabled())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.updateSettings(settings), "Payroll settings saved"));
    }

    // ── Employees ──

    @GetMapping("/employees")
    public ResponseEntity<ApiResponse<Page<Employee>>> listEmployees(
            @RequestParam(defaultValue = "0") int pageNo,
            @RequestParam(defaultValue = "50") int pageSize) {
        Page<Employee> page = service.listEmployees(
                PageRequest.of(pageNo, pageSize, Sort.by("fullName")));
        return ResponseEntity.ok(ApiResponse.ok(page));
    }

    @PostMapping("/employees")
    public ResponseEntity<ApiResponse<Employee>> createEmployee(
            @Valid @RequestBody EmployeeRequest request) {
        Employee employee = Employee.builder()
                .employeeCode(request.employeeCode())
                .fullName(request.fullName())
                .phone(request.phone())
                .email(request.email())
                .designation(request.designation())
                .department(request.department())
                .dateOfJoining(request.dateOfJoining())
                .paymentMode(request.paymentMode())
                .bankAccountName(request.bankAccountName())
                .bankAccountNumber(request.bankAccountNumber())
                .bankIfsc(request.bankIfsc())
                .pan(request.pan())
                .aadhaarLast4(request.aadhaarLast4())
                .uan(request.uan())
                .esiNumber(request.esiNumber())
                .pfApplicable(request.isPfApplicable())
                .esiApplicable(request.isEsiApplicable())
                .ptApplicable(request.isPtApplicable())
                .lwfApplicable(request.isLwfApplicable())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.createEmployee(employee), "Employee created"));
    }

    @GetMapping("/employees/{id}")
    public ResponseEntity<ApiResponse<Employee>> getEmployee(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getEmployee(id)));
    }

    @PutMapping("/employees/{id}")
    public ResponseEntity<ApiResponse<Employee>> updateEmployee(
            @PathVariable UUID id,
            @Valid @RequestBody EmployeeRequest request) {
        Employee updates = Employee.builder()
                .employeeCode(request.employeeCode())
                .fullName(request.fullName())
                .phone(request.phone())
                .email(request.email())
                .designation(request.designation())
                .department(request.department())
                .dateOfJoining(request.dateOfJoining())
                .paymentMode(request.paymentMode())
                .bankAccountName(request.bankAccountName())
                .bankAccountNumber(request.bankAccountNumber())
                .bankIfsc(request.bankIfsc())
                .pan(request.pan())
                .aadhaarLast4(request.aadhaarLast4())
                .uan(request.uan())
                .esiNumber(request.esiNumber())
                .pfApplicable(request.isPfApplicable())
                .esiApplicable(request.isEsiApplicable())
                .ptApplicable(request.isPtApplicable())
                .lwfApplicable(request.isLwfApplicable())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.updateEmployee(id, updates), "Employee updated"));
    }

    @DeleteMapping("/employees/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteEmployee(@PathVariable UUID id) {
        service.deleteEmployee(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Employee deleted"));
    }

    // ── Salary Components ──

    @GetMapping("/salary-components")
    public ResponseEntity<ApiResponse<List<SalaryComponent>>> listComponents() {
        return ResponseEntity.ok(ApiResponse.ok(service.listComponents()));
    }

    @PostMapping("/salary-components")
    public ResponseEntity<ApiResponse<SalaryComponent>> createComponent(
            @Valid @RequestBody SalaryComponentRequest request) {
        SalaryComponent component = SalaryComponent.builder()
                .code(request.code())
                .name(request.name())
                .componentType(request.componentType())
                .taxability(request.taxability())
                .statutory(request.isStatutory())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.createComponent(component), "Component created"));
    }

    @PutMapping("/salary-components/{id}")
    public ResponseEntity<ApiResponse<SalaryComponent>> updateComponent(
            @PathVariable UUID id,
            @Valid @RequestBody SalaryComponentRequest request) {
        SalaryComponent updates = SalaryComponent.builder()
                .code(request.code())
                .name(request.name())
                .componentType(request.componentType())
                .taxability(request.taxability())
                .statutory(request.isStatutory())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(service.updateComponent(id, updates), "Component updated"));
    }

    // ── Salary Structure ──

    @GetMapping("/employees/{employeeId}/salary-structure")
    public ResponseEntity<ApiResponse<EmployeeSalaryStructure>> getStructure(
            @PathVariable UUID employeeId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getCurrentStructure(employeeId)));
    }

    @PostMapping("/employees/{employeeId}/salary-structure")
    public ResponseEntity<ApiResponse<EmployeeSalaryStructure>> createStructure(
            @PathVariable UUID employeeId,
            @Valid @RequestBody SalaryStructureRequest request) {
        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .effectiveFrom(request.effectiveFrom())
                .ctcMonthly(request.ctcMonthly())
                .grossMonthly(request.grossMonthly())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(
                service.createStructure(employeeId, structure), "Salary structure saved"));
    }

    // ── Payroll Runs ──

    @GetMapping("/runs")
    public ResponseEntity<ApiResponse<Page<PayrollRun>>> listRuns(
            @RequestParam(defaultValue = "0") int pageNo,
            @RequestParam(defaultValue = "20") int pageSize) {
        Page<PayrollRun> page = service.listRuns(PageRequest.of(pageNo, pageSize));
        return ResponseEntity.ok(ApiResponse.ok(page));
    }

    @PostMapping("/runs")
    public ResponseEntity<ApiResponse<PayrollRun>> createRun(
            @Valid @RequestBody CreatePayrollRunRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.createRun(request.periodStart(), request.periodEnd()), "Payroll run created"));
    }

    @GetMapping("/runs/{id}")
    public ResponseEntity<ApiResponse<PayrollRun>> getRun(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getRun(id)));
    }

    @PostMapping("/runs/{id}/calculate")
    public ResponseEntity<ApiResponse<PayrollRun>> calculateRun(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.calculateRun(id), "Payroll calculated"));
    }

    @PostMapping("/runs/{id}/approve")
    public ResponseEntity<ApiResponse<PayrollRun>> approveRun(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approveRun(id), "Payroll approved"));
    }

    @PostMapping("/runs/{id}/post")
    public ResponseEntity<ApiResponse<PayrollRun>> postRun(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.postRun(id), "Payroll posted"));
    }

    @PostMapping("/runs/{id}/cancel")
    public ResponseEntity<ApiResponse<PayrollRun>> cancelRun(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.cancelRun(id), "Payroll cancelled"));
    }

    // ── Payslips ──

    @GetMapping("/runs/{runId}/payslips")
    public ResponseEntity<ApiResponse<List<Payslip>>> listPayslips(@PathVariable UUID runId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listPayslips(runId)));
    }

    @GetMapping("/payslips/{id}")
    public ResponseEntity<ApiResponse<Payslip>> getPayslip(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getPayslip(id)));
    }

    // ── Payments ──

    @PostMapping("/runs/{runId}/payment")
    public ResponseEntity<ApiResponse<PayrollPayment>> recordPayment(
            @PathVariable UUID runId,
            @Valid @RequestBody PayrollPaymentRequest request) {
        PayrollPayment payment = PayrollPayment.builder()
                .paymentDate(request.paymentDate())
                .paymentAccountId(request.paymentAccountId())
                .amount(request.amount())
                .paymentMode(request.paymentMode())
                .referenceNumber(request.referenceNumber())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordPayment(runId, payment), "Payment recorded"));
    }

    @PostMapping("/statutory-payments")
    public ResponseEntity<ApiResponse<StatutoryPayment>> recordStatutoryPayment(
            @Valid @RequestBody StatutoryPaymentRequest request) {
        StatutoryPayment payment = StatutoryPayment.builder()
                .statutoryType(request.statutoryType())
                .periodLabel(request.periodLabel())
                .dueDate(request.dueDate())
                .paymentDate(request.paymentDate())
                .amount(request.amount())
                .paymentAccountId(request.paymentAccountId())
                .referenceNumber(request.referenceNumber())
                .build();
        return ResponseEntity.ok(ApiResponse.ok(
                service.recordStatutoryPayment(payment), "Statutory payment recorded"));
    }
}
