package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.entity.PayslipLine;
import com.katasticho.erp.payroll.entity.SalaryComponent;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PayslipPdfServiceTest {

    @Mock private PayslipRepository payslipRepository;
    @Mock private PayrollRunRepository payrollRunRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private DocumentPdfService pdfService;

    private PayslipPdfService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID payslipId = UUID.randomUUID();
    private final UUID runId = UUID.randomUUID();
    private final UUID empId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PayslipPdfService(payslipRepository, payrollRunRepository,
                organisationRepository, pdfService);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() {
        TenantContext.clear();
    }

    @Test
    void renders_all_mandatory_sections_with_correct_totals() {
        // Org header
        Organisation org = new Organisation();
        org.setId(orgId);
        org.setName("Sharma Medical Stores");
        org.setAddressLine1("12, MG Road");
        org.setCity("Pune");
        org.setState("Maharashtra");
        org.setPostalCode("411001");
        org.setGstin("27ABCDE1234F1Z5");

        // Employee
        Employee emp = new Employee();
        emp.setId(empId);
        emp.setOrgId(orgId);
        emp.setFullName("Ramesh Kumar");
        emp.setEmployeeCode("EMP-0001");
        emp.setDesignation("Senior Pharmacist");
        emp.setDepartment("Retail");
        emp.setPan("ABCPK1234D");
        emp.setUan("100123456789");
        emp.setEsiNumber("3112345678901");
        emp.setBankAccountNumber("XXXX1234");
        emp.setDateOfJoining(LocalDate.of(2022, 4, 1));
        emp.setWorkLocation("Pune Main Branch");

        // Payroll run — June 2026
        PayrollRun run = new PayrollRun();
        run.setId(runId);
        run.setOrgId(orgId);
        run.setPeriodStart(LocalDate.of(2026, 6, 1));
        run.setPeriodEnd(LocalDate.of(2026, 6, 30));

        // Payslip with 3 earnings, 2 deductions, 1 employer contribution
        Payslip ps = new Payslip();
        ps.setId(payslipId);
        ps.setOrgId(orgId);
        ps.setPayrollRunId(runId);
        ps.setEmployeeId(empId);
        ps.setEmployee(emp);
        ps.setGrossPay(new BigDecimal("50000"));
        ps.setTotalDeductions(new BigDecimal("9200"));
        ps.setEmployerContributions(new BigDecimal("3600"));
        ps.setNetPay(new BigDecimal("40800"));
        ps.setLines(List.of(
                line("BASIC", "Basic", "EARNING", "30000"),
                line("HRA", "House Rent Allowance", "EARNING", "12000"),
                line("CONV", "Conveyance", "EARNING", "8000"),
                line("PF_EE", "Provident Fund", "DEDUCTION", "3600"),
                line("PT", "Professional Tax", "DEDUCTION", "200"),
                line("TDS", "TDS", "DEDUCTION", "5400"),
                line("PF_ER", "Employer PF", "CONTRIBUTION", "3600")));

        when(payslipRepository.findByIdAndOrgId(payslipId, orgId)).thenReturn(Optional.of(ps));
        when(payrollRunRepository.findById(runId)).thenReturn(Optional.of(run));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(pdfService.render(any(String.class))).thenReturn(new byte[]{1, 2, 3});

        byte[] pdf = service.generatePdf(payslipId);
        assertEquals(3, pdf.length);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(html.capture());
        String h = html.getValue();

        // Mandatory headers
        assertTrue(h.contains("Sharma Medical Stores"), "org name");
        assertTrue(h.contains("GSTIN: 27ABCDE1234F1Z5"), "org GSTIN");
        assertTrue(h.contains("PAY SLIP for June 2026"), "period banner");

        // Employee block
        assertTrue(h.contains("Ramesh Kumar"), "employee name");
        assertTrue(h.contains("EMP-0001"), "employee code");
        assertTrue(h.contains("Senior Pharmacist"), "designation");
        assertTrue(h.contains("ABCPK1234D"), "PAN");
        assertTrue(h.contains("100123456789"), "UAN");

        // Earnings + deductions + employer contributions
        assertTrue(h.contains("Basic"), "Basic earning row");
        assertTrue(h.contains("House Rent Allowance"), "HRA row");
        assertTrue(h.contains("Provident Fund"), "PF deduction row");
        assertTrue(h.contains("Professional Tax"), "PT row");
        assertTrue(h.contains("Employer Contributions (not paid to employee)"), "ec section");
        assertTrue(h.contains("Employer PF"), "employer PF row");

        // Totals (Indian grouping)
        assertTrue(h.contains("50,000.00"), "gross total with Indian grouping");
        assertTrue(h.contains("40,800.00"), "net pay with Indian grouping");

        // Amount in words (line shows up; content checked by separate AmountToWords tests)
        assertTrue(h.contains("Forty Thousand Eight Hundred"), "amount in words");

        // System-generated footer (no signature)
        assertTrue(h.contains("system-generated"), "footer");
    }

    @Test
    void filename_strips_reserved_path_chars_and_includes_period() {
        Employee emp = new Employee();
        emp.setFullName("Ramesh/Kumar:Test");
        PayrollRun run = new PayrollRun();
        run.setPeriodStart(LocalDate.of(2026, 6, 1));
        Payslip ps = new Payslip();
        ps.setId(payslipId);

        String fname = service.filename(ps, run, emp);
        // The reserved chars / and : are stripped, period is appended
        assertTrue(fname.startsWith("Payslip-"));
        assertTrue(fname.endsWith("-2026-06.pdf"));
        assertFalse(fname.contains("/"));
        assertFalse(fname.contains(":"));
    }

    @Test
    void missing_employee_renders_friendly_marker_instead_of_NPE() {
        Organisation org = new Organisation();
        org.setId(orgId);
        org.setName("Org");

        PayrollRun run = new PayrollRun();
        run.setId(runId);
        run.setPeriodStart(LocalDate.of(2026, 6, 1));
        run.setPeriodEnd(LocalDate.of(2026, 6, 30));

        Payslip ps = new Payslip();
        ps.setId(payslipId);
        ps.setOrgId(orgId);
        ps.setPayrollRunId(runId);
        ps.setEmployee(null); // simulates an orphaned payslip
        ps.setLines(List.of());

        when(payslipRepository.findByIdAndOrgId(payslipId, orgId)).thenReturn(Optional.of(ps));
        when(payrollRunRepository.findById(runId)).thenReturn(Optional.of(run));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(pdfService.render(any(String.class))).thenReturn(new byte[]{});

        service.generatePdf(payslipId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(html.capture());
        assertTrue(html.getValue().contains("Employee record not found"));
    }

    @Test
    void escapes_html_in_org_and_employee_names_to_prevent_xss() {
        Organisation org = new Organisation();
        org.setId(orgId);
        org.setName("Sharma <script>alert('xss')</script>");

        Employee emp = new Employee();
        emp.setOrgId(orgId);
        emp.setFullName("Ramesh & \"Kumar\"");

        PayrollRun run = new PayrollRun();
        run.setId(runId);
        run.setPeriodStart(LocalDate.of(2026, 6, 1));
        run.setPeriodEnd(LocalDate.of(2026, 6, 30));

        Payslip ps = new Payslip();
        ps.setId(payslipId);
        ps.setOrgId(orgId);
        ps.setPayrollRunId(runId);
        ps.setEmployee(emp);
        ps.setLines(List.of());

        when(payslipRepository.findByIdAndOrgId(payslipId, orgId)).thenReturn(Optional.of(ps));
        when(payrollRunRepository.findById(runId)).thenReturn(Optional.of(run));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(pdfService.render(any(String.class))).thenReturn(new byte[]{});

        service.generatePdf(payslipId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(html.capture());
        String h = html.getValue();
        assertFalse(h.contains("<script>"), "raw script tag must be escaped");
        assertTrue(h.contains("&lt;script&gt;"), "should contain escaped form");
        assertTrue(h.contains("Ramesh &amp; &quot;Kumar&quot;"), "ampersand + quote escaped");
    }

    private PayslipLine line(String code, String name, String type, String amount) {
        SalaryComponent c = new SalaryComponent();
        c.setCode(code);
        c.setName(name);
        PayslipLine line = new PayslipLine();
        line.setSalaryComponent(c);
        line.setComponentType(type);
        line.setAmount(new BigDecimal(amount));
        return line;
    }
}
