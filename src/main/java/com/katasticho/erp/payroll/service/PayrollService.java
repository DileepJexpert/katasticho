package com.katasticho.erp.payroll.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.*;
import com.katasticho.erp.payroll.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class PayrollService {

    private final PayrollSettingsRepository settingsRepository;
    private final EmployeeRepository employeeRepository;
    private final SalaryComponentRepository componentRepository;
    private final EmployeeSalaryStructureRepository structureRepository;
    private final PayrollRunRepository runRepository;
    private final PayslipRepository payslipRepository;
    private final PayrollPaymentRepository paymentRepository;
    private final StatutoryPaymentRepository statutoryPaymentRepository;
    private final JournalService journalService;
    private final AccountRepository accountRepository;
    private final com.katasticho.erp.attendance.LeaveRequestRepository leaveRequestRepository;
    private final ProductionPayrollService productionPayrollService;

    // ──────────────────────────────── Settings ────────────────────────────────

    public PayrollSettings getOrCreateSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return settingsRepository.findByOrgId(orgId)
                .orElseGet(() -> {
                    PayrollSettings defaults = PayrollSettings.builder()
                            .orgId(orgId)
                            .payFrequency("MONTHLY")
                            .pfEnabled(false)
                            .esiEnabled(false)
                            .ptEnabled(false)
                            .lwfEnabled(false)
                            .tdsEnabled(false)
                            .build();
                    return settingsRepository.save(defaults);
                });
    }

    @Transactional
    public PayrollSettings updateSettings(PayrollSettings settings) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PayrollSettings existing = settingsRepository.findByOrgId(orgId)
                .orElseThrow(() -> new BusinessException(
                        "Payroll settings not found. Call getOrCreateSettings first.",
                        "PAYROLL_SETTINGS_NOT_FOUND", HttpStatus.NOT_FOUND));

        existing.setPayrollStartMonth(settings.getPayrollStartMonth());
        existing.setPayFrequency(settings.getPayFrequency());
        existing.setDefaultSalaryExpenseAccountId(settings.getDefaultSalaryExpenseAccountId());
        existing.setDefaultSalaryPayableAccountId(settings.getDefaultSalaryPayableAccountId());
        existing.setDefaultPfPayableAccountId(settings.getDefaultPfPayableAccountId());
        existing.setDefaultEsiPayableAccountId(settings.getDefaultEsiPayableAccountId());
        existing.setDefaultPtPayableAccountId(settings.getDefaultPtPayableAccountId());
        existing.setDefaultLwfPayableAccountId(settings.getDefaultLwfPayableAccountId());
        existing.setDefaultTdsPayableAccountId(settings.getDefaultTdsPayableAccountId());
        existing.setPfEnabled(settings.isPfEnabled());
        existing.setEsiEnabled(settings.isEsiEnabled());
        existing.setPtEnabled(settings.isPtEnabled());
        existing.setLwfEnabled(settings.isLwfEnabled());
        existing.setTdsEnabled(settings.isTdsEnabled());

        existing = settingsRepository.save(existing);
        log.info("Payroll settings updated for org {}", orgId);
        return existing;
    }

    // ──────────────────────────────── Employees ───────────────────────────────

    public Page<Employee> listEmployees(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return employeeRepository.findByOrgIdAndIsDeletedFalseOrderByFullNameAsc(orgId, pageable);
    }

    public Employee getEmployee(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", id));
    }

    @Transactional
    public Employee createEmployee(Employee employee) {
        UUID orgId = TenantContext.getCurrentOrgId();
        employee.setOrgId(orgId);

        String empCode = employee.getEmployeeCode();
        if (empCode != null && !empCode.isBlank()) {
            employeeRepository.findByOrgIdAndEmployeeCodeAndIsDeletedFalse(orgId, empCode)
                    .ifPresent(existing -> {
                        throw new BusinessException(
                                "Employee code '" + empCode + "' already exists",
                                "PAYROLL_DUPLICATE_EMPLOYEE_CODE", HttpStatus.CONFLICT);
                    });
        }

        if (employee.getEmploymentStatus() == null) {
            employee.setEmploymentStatus("ACTIVE");
        }
        employee.setDeleted(false);

        employee = employeeRepository.save(employee);
        log.info("Employee {} created: {}", employee.getEmployeeCode(), employee.getFullName());
        return employee;
    }

    @Transactional
    public Employee updateEmployee(UUID id, Employee updates) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Employee existing = employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", id));

        // If employee code is changing, validate uniqueness
        if (updates.getEmployeeCode() != null
                && !updates.getEmployeeCode().equals(existing.getEmployeeCode())) {
            employeeRepository.findByOrgIdAndEmployeeCodeAndIsDeletedFalse(orgId, updates.getEmployeeCode())
                    .ifPresent(dup -> {
                        throw new BusinessException(
                                "Employee code '" + updates.getEmployeeCode() + "' already exists",
                                "PAYROLL_DUPLICATE_EMPLOYEE_CODE", HttpStatus.CONFLICT);
                    });
            existing.setEmployeeCode(updates.getEmployeeCode());
        }

        existing.setFullName(updates.getFullName());
        existing.setUserId(updates.getUserId());
        existing.setPhone(updates.getPhone());
        existing.setEmail(updates.getEmail());
        existing.setDesignation(updates.getDesignation());
        existing.setDepartment(updates.getDepartment());
        existing.setDateOfJoining(updates.getDateOfJoining());
        existing.setDateOfExit(updates.getDateOfExit());
        existing.setEmploymentStatus(updates.getEmploymentStatus());
        existing.setPaymentMode(updates.getPaymentMode());
        existing.setBankAccountName(updates.getBankAccountName());
        existing.setBankAccountNumber(updates.getBankAccountNumber());
        existing.setBankIfsc(updates.getBankIfsc());
        existing.setPan(updates.getPan());
        existing.setAadhaarLast4(updates.getAadhaarLast4());
        existing.setUan(updates.getUan());
        existing.setEsiNumber(updates.getEsiNumber());
        existing.setPfApplicable(updates.isPfApplicable());
        existing.setEsiApplicable(updates.isEsiApplicable());
        existing.setPtApplicable(updates.isPtApplicable());
        existing.setLwfApplicable(updates.isLwfApplicable());

        // V18 profile depth
        existing.setDateOfBirth(updates.getDateOfBirth());
        existing.setGender(updates.getGender());
        existing.setMaritalStatus(updates.getMaritalStatus());
        existing.setBloodGroup(updates.getBloodGroup());
        existing.setNationality(updates.getNationality());
        existing.setPersonalEmail(updates.getPersonalEmail());
        existing.setCurrentAddressLine1(updates.getCurrentAddressLine1());
        existing.setCurrentAddressLine2(updates.getCurrentAddressLine2());
        existing.setCurrentCity(updates.getCurrentCity());
        existing.setCurrentState(updates.getCurrentState());
        existing.setCurrentPincode(updates.getCurrentPincode());
        existing.setPermanentAddressLine1(updates.getPermanentAddressLine1());
        existing.setPermanentAddressLine2(updates.getPermanentAddressLine2());
        existing.setPermanentCity(updates.getPermanentCity());
        existing.setPermanentState(updates.getPermanentState());
        existing.setPermanentPincode(updates.getPermanentPincode());
        existing.setEmergencyContactName(updates.getEmergencyContactName());
        existing.setEmergencyContactRelationship(updates.getEmergencyContactRelationship());
        existing.setEmergencyContactPhone(updates.getEmergencyContactPhone());
        existing.setEmploymentType(updates.getEmploymentType());
        existing.setWorkLocation(updates.getWorkLocation());
        existing.setProbationEndDate(updates.getProbationEndDate());
        existing.setConfirmationDate(updates.getConfirmationDate());
        existing.setNoticePeriodDays(updates.getNoticePeriodDays());
        existing.setPhotoAttachmentId(updates.getPhotoAttachmentId());

        existing = employeeRepository.save(existing);
        log.info("Employee {} updated", existing.getEmployeeCode());
        return existing;
    }

    @Transactional
    public void deleteEmployee(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Employee employee = employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", id));

        employee.setDeleted(true);
        employeeRepository.save(employee);
        log.info("Employee {} soft-deleted", employee.getEmployeeCode());
    }

    // ──────────────────────────── Salary Components ───────────────────────────

    public List<SalaryComponent> listComponents() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return componentRepository.findByOrgIdAndActiveTrueOrderByCodeAsc(orgId);
    }

    @Transactional
    public SalaryComponent createComponent(SalaryComponent component) {
        UUID orgId = TenantContext.getCurrentOrgId();
        component.setOrgId(orgId);

        String compCode = component.getCode();
        componentRepository.findByOrgIdAndCode(orgId, compCode)
                .ifPresent(existing -> {
                    throw new BusinessException(
                            "Salary component code '" + compCode + "' already exists",
                            "PAYROLL_DUPLICATE_COMPONENT_CODE", HttpStatus.CONFLICT);
                });

        if (!component.isActive()) {
            component.setActive(true);
        }

        component = componentRepository.save(component);
        log.info("Salary component {} created", component.getCode());
        return component;
    }

    @Transactional
    public SalaryComponent updateComponent(UUID id, SalaryComponent updates) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalaryComponent existing = componentRepository.findById(id)
                .filter(c -> c.getOrgId().equals(orgId))
                .orElseThrow(() -> BusinessException.notFound("SalaryComponent", id));

        // If code is changing, validate uniqueness
        if (updates.getCode() != null && !updates.getCode().equals(existing.getCode())) {
            componentRepository.findByOrgIdAndCode(orgId, updates.getCode())
                    .ifPresent(dup -> {
                        throw new BusinessException(
                                "Salary component code '" + updates.getCode() + "' already exists",
                                "PAYROLL_DUPLICATE_COMPONENT_CODE", HttpStatus.CONFLICT);
                    });
            existing.setCode(updates.getCode());
        }

        existing.setName(updates.getName());
        existing.setComponentType(updates.getComponentType());
        existing.setTaxability(updates.getTaxability());
        existing.setStatutory(updates.isStatutory());
        existing.setActive(updates.isActive());

        existing = componentRepository.save(existing);
        log.info("Salary component {} updated", existing.getCode());
        return existing;
    }

    /**
     * Seeds default Indian salary components if not already present for the org.
     * Components: BASIC, HRA, DA, PF_EMPLOYEE, PF_EMPLOYER, ESI_EMPLOYEE,
     * ESI_EMPLOYER, PT, LWF, TDS.
     */
    @Transactional
    public void seedDefaultComponents() {
        UUID orgId = TenantContext.getCurrentOrgId();

        seedIfAbsent(orgId, "BASIC", "Basic Salary", "EARNING", false);
        seedIfAbsent(orgId, "HRA", "House Rent Allowance", "EARNING", false);
        seedIfAbsent(orgId, "DA", "Dearness Allowance", "EARNING", false);
        seedIfAbsent(orgId, "PF_EMPLOYEE", "Employee Provident Fund", "DEDUCTION", true);
        seedIfAbsent(orgId, "PF_EMPLOYER", "Employer Provident Fund", "EMPLOYER_CONTRIBUTION", true);
        seedIfAbsent(orgId, "ESI_EMPLOYEE", "Employee ESI", "DEDUCTION", true);
        seedIfAbsent(orgId, "ESI_EMPLOYER", "Employer ESI", "EMPLOYER_CONTRIBUTION", true);
        seedIfAbsent(orgId, "PT", "Professional Tax", "DEDUCTION", true);
        seedIfAbsent(orgId, "LWF", "Labour Welfare Fund", "DEDUCTION", true);
        seedIfAbsent(orgId, "TDS", "Tax Deducted at Source", "DEDUCTION", true);

        log.info("Default salary components seeded for org {}", orgId);
    }

    private void seedIfAbsent(UUID orgId, String code, String name, String componentType, boolean statutory) {
        if (componentRepository.findByOrgIdAndCode(orgId, code).isEmpty()) {
            SalaryComponent component = SalaryComponent.builder()
                    .orgId(orgId)
                    .code(code)
                    .name(name)
                    .componentType(componentType)
                    .statutory(statutory)
                    .active(true)
                    .build();
            componentRepository.save(component);
        }
    }

    // ──────────────────────────── Salary Structure ────────────────────────────

    public EmployeeSalaryStructure getCurrentStructure(UUID employeeId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // Verify employee exists
        employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", employeeId));

        return structureRepository.findCurrentActive(orgId, employeeId)
                .orElseThrow(() -> new BusinessException(
                        "No active salary structure found for employee " + employeeId,
                        "PAYROLL_NO_ACTIVE_STRUCTURE", HttpStatus.NOT_FOUND));
    }

    @Transactional
    public EmployeeSalaryStructure createStructure(UUID employeeId, EmployeeSalaryStructure structure) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Verify employee exists
        employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", employeeId));

        structure.setOrgId(orgId);
        structure.setEmployeeId(employeeId);

        if (structure.getStatus() == null) {
            structure.setStatus("ACTIVE");
        }

        // Deactivate any existing active structures that overlap with the new one
        List<EmployeeSalaryStructure> activeStructures =
                structureRepository.findByOrgIdAndEmployeeIdAndStatusOrderByEffectiveFromDesc(orgId, employeeId, "ACTIVE");
        for (EmployeeSalaryStructure active : activeStructures) {
            if (active.getEffectiveTo() == null || !active.getEffectiveTo().isBefore(structure.getEffectiveFrom())) {
                // Close the previous structure one day before the new one starts
                active.setEffectiveTo(structure.getEffectiveFrom().minusDays(1));
                if (active.getEffectiveTo().isBefore(active.getEffectiveFrom())) {
                    active.setStatus("SUPERSEDED");
                }
                structureRepository.save(active);
            }
        }

        structure = structureRepository.save(structure);
        log.info("Salary structure created for employee {} effective from {}", employeeId, structure.getEffectiveFrom());
        return structure;
    }

    // ──────────────────────────── Payroll Runs ────────────────────────────────

    public Page<PayrollRun> listRuns(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return runRepository.findByOrgIdOrderByPeriodStartDesc(orgId, pageable);
    }

    public PayrollRun getRun(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return runRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", id));
    }

    @Transactional
    public PayrollRun createRun(LocalDate periodStart, LocalDate periodEnd) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        if (periodEnd.isBefore(periodStart)) {
            throw new BusinessException("Period end must not be before period start",
                    "PAYROLL_INVALID_PERIOD", HttpStatus.BAD_REQUEST);
        }

        // Validate no overlapping non-cancelled run
        List<PayrollRun> overlapping = runRepository.findOverlapping(orgId, periodStart, periodEnd);
        if (!overlapping.isEmpty()) {
            throw new BusinessException(
                    "Payroll run overlaps with an existing run for period " +
                            overlapping.get(0).getPeriodStart() + " to " + overlapping.get(0).getPeriodEnd(),
                    "PAYROLL_PERIOD_OVERLAP", HttpStatus.CONFLICT);
        }

        PayrollRun run = PayrollRun.builder()
                .orgId(orgId)
                .periodStart(periodStart)
                .periodEnd(periodEnd)
                .status("DRAFT")
                .employeeCount(0)
                .grossTotal(BigDecimal.ZERO)
                .deductionTotal(BigDecimal.ZERO)
                .employerContributionTotal(BigDecimal.ZERO)
                .netPayTotal(BigDecimal.ZERO)
                .createdBy(userId)
                .build();

        run = runRepository.save(run);
        log.info("Payroll run created for period {} to {}", periodStart, periodEnd);
        return run;
    }

    /**
     * Calculate payslips for all active employees in the run.
     * Transitions run from DRAFT to CALCULATED.
     */
    @Transactional
    public PayrollRun calculateRun(UUID runId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PayrollRun run = runRepository.findByIdAndOrgId(runId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", runId));

        if (!"DRAFT".equals(run.getStatus())) {
            throw new BusinessException("Only DRAFT payroll runs can be calculated",
                    "PAYROLL_RUN_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        PayrollSettings settings = getOrCreateSettings();

        // Fetch all active employees
        List<Employee> activeEmployees = employeeRepository
                .findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE");

        if (activeEmployees.isEmpty()) {
            throw new BusinessException("No active employees found for payroll calculation",
                    "PAYROLL_NO_ACTIVE_EMPLOYEES", HttpStatus.BAD_REQUEST);
        }

        // Load active salary components indexed by code
        Map<String, SalaryComponent> componentsByCode = new HashMap<>();
        for (SalaryComponent sc : componentRepository.findByOrgIdAndActiveTrueOrderByCodeAsc(orgId)) {
            componentsByCode.put(sc.getCode(), sc);
        }

        // Remove any previously calculated payslips for this run (re-calculation support)
        List<Payslip> existingPayslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId);
        if (!existingPayslips.isEmpty()) {
            payslipRepository.deleteAll(existingPayslips);
        }

        BigDecimal runGross = BigDecimal.ZERO;
        BigDecimal runDeductions = BigDecimal.ZERO;
        BigDecimal runEmployerContributions = BigDecimal.ZERO;
        BigDecimal runNetPay = BigDecimal.ZERO;
        int employeeCount = 0;

        for (Employee employee : activeEmployees) {
            Optional<EmployeeSalaryStructure> structureOpt =
                    structureRepository.findCurrentActive(orgId, employee.getId());

            if (structureOpt.isEmpty()) {
                log.warn("Skipping employee {} — no active salary structure", employee.getEmployeeCode());
                continue;
            }

            EmployeeSalaryStructure structure = structureOpt.get();
            Payslip payslip = calculatePayslip(orgId, run, employee, structure, settings, componentsByCode);

            payslipRepository.save(payslip);

            runGross = runGross.add(payslip.getGrossPay());
            runDeductions = runDeductions.add(payslip.getTotalDeductions());
            runEmployerContributions = runEmployerContributions.add(payslip.getEmployerContributions());
            runNetPay = runNetPay.add(payslip.getNetPay());
            employeeCount++;
        }

        run.setEmployeeCount(employeeCount);
        run.setGrossTotal(runGross);
        run.setDeductionTotal(runDeductions);
        run.setEmployerContributionTotal(runEmployerContributions);
        run.setNetPayTotal(runNetPay);
        run.setStatus("CALCULATED");

        run = runRepository.save(run);
        log.info("Payroll run {} calculated: {} employees, gross={}, net={}",
                runId, employeeCount, runGross, runNetPay);
        return run;
    }

    /**
     * Approve a calculated payroll run.
     * Transitions CALCULATED to APPROVED.
     */
    @Transactional
    public PayrollRun approveRun(UUID runId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        PayrollRun run = runRepository.findByIdAndOrgId(runId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", runId));

        if (!"CALCULATED".equals(run.getStatus())) {
            throw new BusinessException("Only CALCULATED payroll runs can be approved",
                    "PAYROLL_RUN_NOT_CALCULATED", HttpStatus.BAD_REQUEST);
        }

        run.setStatus("APPROVED");
        run.setApprovedBy(userId);
        run.setApprovedAt(Instant.now());

        run = runRepository.save(run);
        log.info("Payroll run {} approved", runId);
        return run;
    }

    /**
     * Post an approved payroll run.
     * Creates a journal entry via JournalService with:
     *   DR Staff Salaries (expense) for gross total
     *   DR Employer PF/ESI if enabled
     *   CR Salary Payable for net pay
     *   CR PF/ESI/PT/LWF/TDS Payable for each enabled statutory deduction
     * Transitions APPROVED to POSTED.
     */
    @Transactional
    public PayrollRun postRun(UUID runId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PayrollRun run = runRepository.findByIdAndOrgId(runId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", runId));

        if (!"APPROVED".equals(run.getStatus())) {
            throw new BusinessException("Only APPROVED payroll runs can be posted",
                    "PAYROLL_RUN_NOT_APPROVED", HttpStatus.BAD_REQUEST);
        }

        PayrollSettings settings = settingsRepository.findByOrgId(orgId)
                .orElseThrow(() -> new BusinessException(
                        "Payroll settings not configured",
                        "PAYROLL_SETTINGS_NOT_FOUND", HttpStatus.BAD_REQUEST));

        // Build journal lines
        List<JournalLineRequest> lines = buildJournalLines(run, settings);

        String description = String.format("Payroll for %s to %s (%d employees)",
                run.getPeriodStart(), run.getPeriodEnd(), run.getEmployeeCount());

        JournalPostRequest journalRequest = new JournalPostRequest(
                run.getPeriodEnd(),   // effective date = period end
                description,
                "PAYROLL",            // source module
                run.getId(),          // source id
                lines,
                true                  // auto-post
        );

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

        run.setJournalEntryId(journalEntry.getId());
        run.setStatus("POSTED");
        run.setPostedAt(Instant.now());
        run = runRepository.save(run);

        // Update payslip statuses
        List<Payslip> payslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId);
        for (Payslip payslip : payslips) {
            payslip.setStatus("POSTED");
        }
        payslipRepository.saveAll(payslips);

        log.info("Payroll run {} posted with journal entry {}", runId, journalEntry.getEntryNumber());
        return run;
    }

    /**
     * Cancel a payroll run. Only DRAFT or CALCULATED runs can be cancelled.
     * POSTED runs cannot be cancelled.
     */
    @Transactional
    public PayrollRun cancelRun(UUID runId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PayrollRun run = runRepository.findByIdAndOrgId(runId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", runId));

        if ("POSTED".equals(run.getStatus())) {
            throw new BusinessException("Posted payroll runs cannot be cancelled. Create a reversal instead.",
                    "PAYROLL_RUN_POSTED_CANNOT_CANCEL", HttpStatus.BAD_REQUEST);
        }
        if ("CANCELLED".equals(run.getStatus())) {
            throw new BusinessException("Payroll run is already cancelled",
                    "PAYROLL_RUN_ALREADY_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        run.setStatus("CANCELLED");
        run = runRepository.save(run);

        // Cancel associated payslips
        List<Payslip> payslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId);
        for (Payslip payslip : payslips) {
            payslip.setStatus("CANCELLED");
        }
        payslipRepository.saveAll(payslips);

        log.info("Payroll run {} cancelled", runId);
        return run;
    }

    // ──────────────────────────────── Payslips ────────────────────────────────

    public List<Payslip> listPayslips(UUID runId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // Verify run exists
        runRepository.findByIdAndOrgId(runId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", runId));

        return payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId);
    }

    public Payslip getPayslip(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return payslipRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Payslip", id));
    }

    // ──────────────────────────────── Payments ────────────────────────────────

    @Transactional
    public PayrollPayment recordPayment(UUID runId, PayrollPayment payment) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PayrollRun run = runRepository.findByIdAndOrgId(runId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", runId));

        if (!"POSTED".equals(run.getStatus())) {
            throw new BusinessException("Payments can only be recorded for POSTED payroll runs",
                    "PAYROLL_RUN_NOT_POSTED", HttpStatus.BAD_REQUEST);
        }

        payment.setOrgId(orgId);
        payment.setPayrollRunId(runId);

        PayrollSettings settings = settingsRepository.findByOrgId(orgId)
                .orElseThrow(() -> new BusinessException(
                        "Payroll settings not configured",
                        "PAYROLL_SETTINGS_NOT_FOUND", HttpStatus.BAD_REQUEST));
        requireAccountCode(settings.getDefaultSalaryPayableAccountId(), "salary payable");

        String salaryPayableCode = resolveAccountCode(settings.getDefaultSalaryPayableAccountId());
        String paymentAccountCode = resolveAccountCode(payment.getPaymentAccountId());

        List<JournalLineRequest> lines = List.of(
                new JournalLineRequest(salaryPayableCode,
                        payment.getAmount(), BigDecimal.ZERO,
                        "Salary payment — payroll run settlement", null, null),
                new JournalLineRequest(paymentAccountCode,
                        BigDecimal.ZERO, payment.getAmount(),
                        "Salary payment — bank/cash", null, null)
        );

        JournalPostRequest journalRequest = new JournalPostRequest(
                payment.getPaymentDate(),
                String.format("Salary payment for payroll run %s", runId),
                "PAYROLL_PAYMENT",
                runId,
                lines,
                true
        );

        JournalEntry journalEntry = journalService.postJournal(journalRequest);
        payment.setJournalEntryId(journalEntry.getId());

        payment = paymentRepository.save(payment);
        log.info("Payroll payment recorded for run {}: amount={}, journal={}",
                runId, payment.getAmount(), journalEntry.getEntryNumber());
        return payment;
    }

    @Transactional
    public StatutoryPayment recordStatutoryPayment(StatutoryPayment payment) {
        UUID orgId = TenantContext.getCurrentOrgId();
        payment.setOrgId(orgId);

        if (payment.getStatus() == null) {
            payment.setStatus("PAID");
        }

        PayrollSettings settings = settingsRepository.findByOrgId(orgId)
                .orElseThrow(() -> new BusinessException(
                        "Payroll settings not configured",
                        "PAYROLL_SETTINGS_NOT_FOUND", HttpStatus.BAD_REQUEST));

        UUID payableAccountId = resolveStatutoryPayableAccount(settings, payment.getStatutoryType());
        requireAccountCode(payableAccountId, payment.getStatutoryType() + " payable");

        String payableCode = resolveAccountCode(payableAccountId);
        String paymentAccountCode = resolveAccountCode(payment.getPaymentAccountId());

        List<JournalLineRequest> lines = List.of(
                new JournalLineRequest(payableCode,
                        payment.getAmount(), BigDecimal.ZERO,
                        payment.getStatutoryType() + " settlement", null, null),
                new JournalLineRequest(paymentAccountCode,
                        BigDecimal.ZERO, payment.getAmount(),
                        payment.getStatutoryType() + " payment — bank/cash", null, null)
        );

        JournalPostRequest journalRequest = new JournalPostRequest(
                payment.getPaymentDate() != null ? payment.getPaymentDate() : LocalDate.now(),
                String.format("Statutory payment — %s for %s",
                        payment.getStatutoryType(), payment.getPeriodLabel()),
                "STATUTORY_PAYMENT",
                null,
                lines,
                true
        );

        JournalEntry journalEntry = journalService.postJournal(journalRequest);
        payment.setJournalEntryId(journalEntry.getId());

        payment = statutoryPaymentRepository.save(payment);
        log.info("Statutory payment recorded: type={}, amount={}, journal={}",
                payment.getStatutoryType(), payment.getAmount(), journalEntry.getEntryNumber());
        return payment;
    }

    private UUID resolveStatutoryPayableAccount(PayrollSettings settings, String statutoryType) {
        return switch (statutoryType) {
            case "PF" -> settings.getDefaultPfPayableAccountId();
            case "ESI" -> settings.getDefaultEsiPayableAccountId();
            case "PT" -> settings.getDefaultPtPayableAccountId();
            case "LWF" -> settings.getDefaultLwfPayableAccountId();
            case "TDS" -> settings.getDefaultTdsPayableAccountId();
            default -> throw new BusinessException(
                    "Unknown statutory type: " + statutoryType,
                    "PAYROLL_UNKNOWN_STATUTORY_TYPE", HttpStatus.BAD_REQUEST);
        };
    }

    // ──────────────────────────── Private Helpers ─────────────────────────────

    /**
     * Calculate a single payslip for an employee in a payroll run.
     * Applies statutory deductions based on settings and employee flags.
     */
    private Payslip calculatePayslip(UUID orgId, PayrollRun run, Employee employee,
                                     EmployeeSalaryStructure structure, PayrollSettings settings,
                                     Map<String, SalaryComponent> componentsByCode) {

        BigDecimal lopDays = lopDays(orgId, employee, run);
        // Earnings prorate by (period days - LOP days) / period days
        long periodDays = java.time.temporal.ChronoUnit.DAYS.between(
                run.getPeriodStart(), run.getPeriodEnd()) + 1;
        BigDecimal lopFactor = lopDays.signum() > 0 && periodDays > 0
                ? BigDecimal.valueOf(periodDays).subtract(lopDays)
                        .max(BigDecimal.ZERO)
                        .divide(BigDecimal.valueOf(periodDays), 6, RoundingMode.HALF_UP)
                : BigDecimal.ONE;

        Payslip payslip = Payslip.builder()
                .orgId(orgId)
                .payrollRunId(run.getId())
                .employeeId(employee.getId())
                .status("DRAFT")
                .lopDays(lopDays)
                .grossPay(BigDecimal.ZERO)
                .totalDeductions(BigDecimal.ZERO)
                .employerContributions(BigDecimal.ZERO)
                .netPay(BigDecimal.ZERO)
                .build();

        // Collect computed amounts by component code for percentage-based lookups
        Map<String, BigDecimal> computedAmounts = new LinkedHashMap<>();

        BigDecimal grossPay = BigDecimal.ZERO;
        BigDecimal totalDeductions = BigDecimal.ZERO;
        BigDecimal employerContributions = BigDecimal.ZERO;

        // First pass: compute structure-defined component amounts (EARNING lines)
        if (structure.getLines() != null) {
            for (EmployeeSalaryComponent esc : structure.getLines()) {
                SalaryComponent comp = esc.getSalaryComponent();
                if (comp == null) continue;

                BigDecimal amount = computeComponentAmount(esc, computedAmounts);
                if ("EARNING".equals(comp.getComponentType()) && lopFactor.compareTo(BigDecimal.ONE) < 0) {
                    amount = amount.multiply(lopFactor).setScale(2, RoundingMode.HALF_UP);
                }
                computedAmounts.put(comp.getCode(), amount);

                PayslipLine line = PayslipLine.builder()
                        .orgId(orgId)
                        .salaryComponent(comp)
                        .componentType(comp.getComponentType())
                        .amount(amount)
                        .build();
                line.setPayslip(payslip);
                payslip.getLines().add(line);

                switch (comp.getComponentType()) {
                    case "EARNING" -> grossPay = grossPay.add(amount);
                    case "DEDUCTION" -> totalDeductions = totalDeductions.add(amount);
                    case "EMPLOYER_CONTRIBUTION" -> employerContributions = employerContributions.add(amount);
                }
            }
        }

        // Production→payroll bridge (tracker #57). For HOURLY / PIECE_RATE
        // structures we add a LABOR_PAY earning computed from the worker's
        // completed job cards in the period. SALARY structures hit the
        // SALARY short-circuit inside computeLaborPay and return zero,
        // so this whole block is a no-op for the legacy path.
        if (productionPayrollService != null
                && structure.getPayType() != null
                && !"SALARY".equals(structure.getPayType())) {
            ProductionPayrollService.LaborPay laborPay = productionPayrollService
                    .computeLaborPay(employee, structure, run.getPeriodStart(), run.getPeriodEnd());
            if (laborPay.amount().signum() > 0) {
                BigDecimal laborAmount = laborPay.amount();
                addStatutoryLine(payslip, orgId, componentsByCode,
                        "LABOR_PAY", "EARNING", laborAmount);
                grossPay = grossPay.add(laborAmount);
                computedAmounts.put("LABOR_PAY", laborAmount);
            }
        }

        // If no structure components produced gross, use structure.grossMonthly as fallback
        if (grossPay.compareTo(BigDecimal.ZERO) == 0 && structure.getGrossMonthly() != null) {
            grossPay = structure.getGrossMonthly();
        }

        // Resolve BASIC amount for PF calculation
        BigDecimal basicAmount = computedAmounts.getOrDefault("BASIC", grossPay);

        // Second pass: statutory deductions (auto-computed, not from structure lines)
        // PF Employee: 12% of Basic
        if (settings.isPfEnabled() && employee.isPfApplicable()) {
            BigDecimal pfEmployee = basicAmount
                    .multiply(new BigDecimal("0.12"))
                    .setScale(2, RoundingMode.HALF_UP);
            addStatutoryLine(payslip, orgId, componentsByCode, "PF_EMPLOYEE", "DEDUCTION", pfEmployee);
            totalDeductions = totalDeductions.add(pfEmployee);

            // PF Employer: 12% of Basic
            BigDecimal pfEmployer = basicAmount
                    .multiply(new BigDecimal("0.12"))
                    .setScale(2, RoundingMode.HALF_UP);
            addStatutoryLine(payslip, orgId, componentsByCode, "PF_EMPLOYER", "EMPLOYER_CONTRIBUTION", pfEmployer);
            employerContributions = employerContributions.add(pfEmployer);
        }

        // ESI Employee: 0.75% of Gross (only if gross <= 21000)
        if (settings.isEsiEnabled() && employee.isEsiApplicable()
                && grossPay.compareTo(new BigDecimal("21000")) <= 0) {
            BigDecimal esiEmployee = grossPay
                    .multiply(new BigDecimal("0.0075"))
                    .setScale(2, RoundingMode.HALF_UP);
            addStatutoryLine(payslip, orgId, componentsByCode, "ESI_EMPLOYEE", "DEDUCTION", esiEmployee);
            totalDeductions = totalDeductions.add(esiEmployee);

            // ESI Employer: 3.25% of Gross
            BigDecimal esiEmployer = grossPay
                    .multiply(new BigDecimal("0.0325"))
                    .setScale(2, RoundingMode.HALF_UP);
            addStatutoryLine(payslip, orgId, componentsByCode, "ESI_EMPLOYER", "EMPLOYER_CONTRIBUTION", esiEmployer);
            employerContributions = employerContributions.add(esiEmployer);
        }

        // PT: fixed 200 default
        if (settings.isPtEnabled() && employee.isPtApplicable()) {
            BigDecimal ptAmount = new BigDecimal("200.00");
            addStatutoryLine(payslip, orgId, componentsByCode, "PT", "DEDUCTION", ptAmount);
            totalDeductions = totalDeductions.add(ptAmount);
        }

        // LWF: fixed 25 employee + 75 employer
        if (settings.isLwfEnabled() && employee.isLwfApplicable()) {
            BigDecimal lwfEmployee = new BigDecimal("25.00");
            addStatutoryLine(payslip, orgId, componentsByCode, "LWF", "DEDUCTION", lwfEmployee);
            totalDeductions = totalDeductions.add(lwfEmployee);

            // LWF employer contribution: 75
            BigDecimal lwfEmployer = new BigDecimal("75.00");
            SalaryComponent lwfComp = componentsByCode.get("LWF");
            if (lwfComp != null) {
                PayslipLine lwfEmployerLine = PayslipLine.builder()
                        .orgId(orgId)
                        .salaryComponent(lwfComp)
                        .componentType("EMPLOYER_CONTRIBUTION")
                        .amount(lwfEmployer)
                        .build();
                lwfEmployerLine.setPayslip(payslip);
                payslip.getLines().add(lwfEmployerLine);
            }
            employerContributions = employerContributions.add(lwfEmployer);
        }

        BigDecimal netPay = grossPay.subtract(totalDeductions);

        payslip.setGrossPay(grossPay);
        payslip.setTotalDeductions(totalDeductions);
        payslip.setEmployerContributions(employerContributions);
        payslip.setNetPay(netPay);

        return payslip;
    }

    private BigDecimal computeComponentAmount(EmployeeSalaryComponent esc, Map<String, BigDecimal> computed) {
        if ("FIXED".equals(esc.getCalculationType())) {
            return esc.getAmount() != null ? esc.getAmount() : BigDecimal.ZERO;
        }
        if ("PERCENTAGE".equals(esc.getCalculationType())) {
            String baseCode = esc.getBaseComponentCode();
            BigDecimal baseAmount = baseCode != null ? computed.getOrDefault(baseCode, BigDecimal.ZERO) : BigDecimal.ZERO;
            BigDecimal percentage = esc.getPercentage() != null ? esc.getPercentage() : BigDecimal.ZERO;
            return baseAmount.multiply(percentage)
                    .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        }
        // FORMULA not supported in v1 — fall back to fixed amount
        return esc.getAmount() != null ? esc.getAmount() : BigDecimal.ZERO;
    }

    private void addStatutoryLine(Payslip payslip, UUID orgId, Map<String, SalaryComponent> componentsByCode,
                                  String code, String componentType, BigDecimal amount) {
        SalaryComponent comp = componentsByCode.get(code);
        if (comp == null) {
            log.warn("Statutory component {} not found in org — skipping line", code);
            return;
        }

        PayslipLine line = PayslipLine.builder()
                .orgId(orgId)
                .salaryComponent(comp)
                .componentType(componentType)
                .amount(amount)
                .build();
        line.setPayslip(payslip);
        payslip.getLines().add(line);
    }

    /**
     * Build journal lines for posting a payroll run.
     * Follows the accounting spec:
     *   DR Staff Salaries (expense) = gross total
     *   DR Employer PF Expense (if PF enabled) = employer PF total
     *   DR Employer ESI Expense (if ESI enabled) = employer ESI total
     *   CR Salary Payable = net pay total
     *   CR PF Payable (if PF enabled) = employee PF + employer PF
     *   CR ESI Payable (if ESI enabled) = employee ESI + employer ESI
     *   CR PT Payable (if PT enabled)
     *   CR LWF Payable (if LWF enabled) = employee LWF + employer LWF
     *   CR TDS Payable (if TDS enabled)
     */
    private List<JournalLineRequest> buildJournalLines(PayrollRun run, PayrollSettings settings) {
        List<JournalLineRequest> lines = new ArrayList<>();
        UUID orgId = TenantContext.getCurrentOrgId();

        // Aggregate statutory amounts from payslips
        List<Payslip> payslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, run.getId());

        BigDecimal pfEmployeeTotal = BigDecimal.ZERO;
        BigDecimal pfEmployerTotal = BigDecimal.ZERO;
        BigDecimal esiEmployeeTotal = BigDecimal.ZERO;
        BigDecimal esiEmployerTotal = BigDecimal.ZERO;
        BigDecimal ptTotal = BigDecimal.ZERO;
        BigDecimal lwfEmployeeTotal = BigDecimal.ZERO;
        BigDecimal lwfEmployerTotal = BigDecimal.ZERO;
        BigDecimal tdsTotal = BigDecimal.ZERO;

        Map<String, SalaryComponent> componentsByCode = new HashMap<>();
        for (SalaryComponent sc : componentRepository.findByOrgIdAndActiveTrueOrderByCodeAsc(orgId)) {
            componentsByCode.put(sc.getCode(), sc);
        }

        for (Payslip payslip : payslips) {
            if (payslip.getLines() != null) {
                for (PayslipLine pl : payslip.getLines()) {
                    String code = pl.getSalaryComponent() != null
                            ? findComponentCode(pl.getSalaryComponent().getId(), componentsByCode)
                            : null;
                    if (code == null) continue;

                    switch (code) {
                        case "PF_EMPLOYEE" -> pfEmployeeTotal = pfEmployeeTotal.add(pl.getAmount());
                        case "PF_EMPLOYER" -> pfEmployerTotal = pfEmployerTotal.add(pl.getAmount());
                        case "ESI_EMPLOYEE" -> esiEmployeeTotal = esiEmployeeTotal.add(pl.getAmount());
                        case "ESI_EMPLOYER" -> esiEmployerTotal = esiEmployerTotal.add(pl.getAmount());
                        case "PT" -> ptTotal = ptTotal.add(pl.getAmount());
                        case "LWF" -> {
                            if ("DEDUCTION".equals(pl.getComponentType())) {
                                lwfEmployeeTotal = lwfEmployeeTotal.add(pl.getAmount());
                            } else if ("EMPLOYER_CONTRIBUTION".equals(pl.getComponentType())) {
                                lwfEmployerTotal = lwfEmployerTotal.add(pl.getAmount());
                            }
                        }
                        case "TDS" -> tdsTotal = tdsTotal.add(pl.getAmount());
                    }
                }
            }
        }

        // DR Staff Salaries (expense) = gross total
        requireAccountCode(settings.getDefaultSalaryExpenseAccountId(), "salary expense");
        lines.add(new JournalLineRequest(
                resolveAccountCode(settings.getDefaultSalaryExpenseAccountId()),
                run.getGrossTotal(), BigDecimal.ZERO,
                "Staff salaries — gross", null, null));

        // DR Employer PF Expense (if PF enabled and there's an amount)
        if (settings.isPfEnabled() && pfEmployerTotal.compareTo(BigDecimal.ZERO) > 0) {
            // Employer PF is an expense; use salary expense account or a dedicated one
            // For v1, debit the salary expense account for employer contributions
            lines.add(new JournalLineRequest(
                    resolveAccountCode(settings.getDefaultSalaryExpenseAccountId()),
                    pfEmployerTotal, BigDecimal.ZERO,
                    "Employer PF contribution", null, null));
        }

        // DR Employer ESI Expense (if ESI enabled and there's an amount)
        if (settings.isEsiEnabled() && esiEmployerTotal.compareTo(BigDecimal.ZERO) > 0) {
            lines.add(new JournalLineRequest(
                    resolveAccountCode(settings.getDefaultSalaryExpenseAccountId()),
                    esiEmployerTotal, BigDecimal.ZERO,
                    "Employer ESI contribution", null, null));
        }

        // DR Employer LWF Expense (if LWF enabled and there's an amount)
        if (settings.isLwfEnabled() && lwfEmployerTotal.compareTo(BigDecimal.ZERO) > 0) {
            lines.add(new JournalLineRequest(
                    resolveAccountCode(settings.getDefaultSalaryExpenseAccountId()),
                    lwfEmployerTotal, BigDecimal.ZERO,
                    "Employer LWF contribution", null, null));
        }

        // CR Salary Payable = net pay total
        requireAccountCode(settings.getDefaultSalaryPayableAccountId(), "salary payable");
        lines.add(new JournalLineRequest(
                resolveAccountCode(settings.getDefaultSalaryPayableAccountId()),
                BigDecimal.ZERO, run.getNetPayTotal(),
                "Net salary payable", null, null));

        // CR PF Payable (employee + employer combined)
        if (settings.isPfEnabled()) {
            BigDecimal pfTotal = pfEmployeeTotal.add(pfEmployerTotal);
            if (pfTotal.compareTo(BigDecimal.ZERO) > 0) {
                requireAccountCode(settings.getDefaultPfPayableAccountId(), "PF payable");
                lines.add(new JournalLineRequest(
                        resolveAccountCode(settings.getDefaultPfPayableAccountId()),
                        BigDecimal.ZERO, pfTotal,
                        "PF payable (employee + employer)", null, null));
            }
        }

        // CR ESI Payable (employee + employer combined)
        if (settings.isEsiEnabled()) {
            BigDecimal esiTotal = esiEmployeeTotal.add(esiEmployerTotal);
            if (esiTotal.compareTo(BigDecimal.ZERO) > 0) {
                requireAccountCode(settings.getDefaultEsiPayableAccountId(), "ESI payable");
                lines.add(new JournalLineRequest(
                        resolveAccountCode(settings.getDefaultEsiPayableAccountId()),
                        BigDecimal.ZERO, esiTotal,
                        "ESI payable (employee + employer)", null, null));
            }
        }

        // CR PT Payable
        if (settings.isPtEnabled() && ptTotal.compareTo(BigDecimal.ZERO) > 0) {
            requireAccountCode(settings.getDefaultPtPayableAccountId(), "PT payable");
            lines.add(new JournalLineRequest(
                    resolveAccountCode(settings.getDefaultPtPayableAccountId()),
                    BigDecimal.ZERO, ptTotal,
                    "Professional tax payable", null, null));
        }

        // CR LWF Payable (employee + employer combined)
        if (settings.isLwfEnabled()) {
            BigDecimal lwfTotal = lwfEmployeeTotal.add(lwfEmployerTotal);
            if (lwfTotal.compareTo(BigDecimal.ZERO) > 0) {
                requireAccountCode(settings.getDefaultLwfPayableAccountId(), "LWF payable");
                lines.add(new JournalLineRequest(
                        resolveAccountCode(settings.getDefaultLwfPayableAccountId()),
                        BigDecimal.ZERO, lwfTotal,
                        "Labour welfare fund payable", null, null));
            }
        }

        // CR TDS Payable
        if (settings.isTdsEnabled() && tdsTotal.compareTo(BigDecimal.ZERO) > 0) {
            requireAccountCode(settings.getDefaultTdsPayableAccountId(), "TDS payable");
            lines.add(new JournalLineRequest(
                    resolveAccountCode(settings.getDefaultTdsPayableAccountId()),
                    BigDecimal.ZERO, tdsTotal,
                    "TDS payable", null, null));
        }

        return lines;
    }

    /**
     * Resolve account UUID to account code for JournalLineRequest.
     * JournalService.postJournal expects account codes, not UUIDs.
     */
    private String resolveAccountCode(UUID accountId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Account account = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .orElseThrow(() -> new BusinessException(
                        "Payroll account not found: " + accountId,
                        "PAYROLL_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST));
        return account.getCode();
    }

    private void requireAccountCode(UUID accountId, String label) {
        if (accountId == null) {
            throw new BusinessException(
                    "Payroll settings missing required account: " + label +
                            ". Configure payroll settings before posting.",
                    "PAYROLL_MISSING_ACCOUNT", HttpStatus.BAD_REQUEST);
        }
    }

    private String findComponentCode(UUID componentId, Map<String, SalaryComponent> byCode) {
        for (Map.Entry<String, SalaryComponent> entry : byCode.entrySet()) {
            if (entry.getValue().getId().equals(componentId)) {
                return entry.getKey();
            }
        }
        return null;
    }

    /**
     * Loss-of-pay days for the run period: approved UNPAID leave of the
     * employee's linked app user, clipped to the period. Employees without
     * a user link (or with no unpaid leave) get zero - behaviour unchanged.
     */
    private BigDecimal lopDays(UUID orgId, Employee employee, PayrollRun run) {
        if (employee.getUserId() == null) return BigDecimal.ZERO;
        long days = 0;
        for (var leave : leaveRequestRepository
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, employee.getUserId(), java.util.List.of("APPROVED"),
                        run.getPeriodEnd(), run.getPeriodStart())) {
            if (!"UNPAID".equals(leave.getLeaveType())) continue;
            LocalDate from = leave.getFromDate().isBefore(run.getPeriodStart())
                    ? run.getPeriodStart() : leave.getFromDate();
            LocalDate to = leave.getToDate().isAfter(run.getPeriodEnd())
                    ? run.getPeriodEnd() : leave.getToDate();
            days += java.time.temporal.ChronoUnit.DAYS.between(from, to) + 1;
        }
        return BigDecimal.valueOf(days);
    }
}
