package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class Form12BBPdfServiceTest {

    @Mock private TaxDeclarationService taxDeclarationService;
    @Mock private EmployeeRepository employeeRepository;
    @Mock private DocumentPdfService pdfService;

    private Form12BBPdfService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID employeeId = UUID.randomUUID();
    private final UUID declId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new Form12BBPdfService(taxDeclarationService, employeeRepository, pdfService);
    }

    private Employee employee() {
        Employee e = Employee.builder()
                .orgId(orgId)
                .fullName("Ramesh Kumar")
                .employeeCode("EMP-001")
                .designation("Senior Pharmacist")
                .pan("ABCPK1234D")
                .build();
        e.setId(employeeId);
        return e;
    }

    private EmployeeTaxDeclaration fullOldRegime() {
        return EmployeeTaxDeclaration.builder()
                .orgId(orgId)
                .employeeId(employeeId)
                .fiscalYear("2026-27")
                .taxRegime("OLD")
                .hraRentPaid(new BigDecimal("180000"))
                .hraMetroCity(true)
                .landlordPan("AAAPL1234C")
                .deduction80c(new BigDecimal("150000"))
                .deduction80ccd1b(new BigDecimal("50000"))
                .deduction80dSelf(new BigDecimal("25000"))
                .deduction80dParents(new BigDecimal("50000"))
                .deduction80e(new BigDecimal("12000"))
                .homeLoanInterest(new BigDecimal("200000"))
                .ltaClaim(new BigDecimal("40000"))
                .otherIncome(new BigDecimal("15000"))
                .status("SUBMITTED")
                .submittedAt(Instant.parse("2026-06-01T10:00:00Z"))
                .build();
    }

    @Test
    void renders_all_sections_for_old_regime_declaration() {
        String html = service.buildHtml(fullOldRegime(), employee());

        // Banner + statutory anchor + AY derivation + regime
        assertTrue(html.contains("FORM 12BB"));
        assertTrue(html.contains("Rule 26C"), "must reference Rule 26C");
        assertTrue(html.contains("FY 2026-27"));
        assertTrue(html.contains("Assessment Year 2027-28"));
        assertTrue(html.contains("OLD"));

        // Employee header
        assertTrue(html.contains("Ramesh Kumar"));
        assertTrue(html.contains("EMP-001"));
        assertTrue(html.contains("Senior Pharmacist"));
        assertTrue(html.contains("ABCPK1234D"));

        // 1. HRA — rent (Indian grouping), metro, landlord PAN
        assertTrue(html.contains("House Rent Allowance"));
        assertTrue(html.contains("1,80,000.00"), "Indian grouping for rent paid");
        assertTrue(html.contains("Metro"));
        assertTrue(html.contains("AAAPL1234C"));

        // 2. LTA, 3. home loan
        assertTrue(html.contains("Leave Travel"));
        assertTrue(html.contains("40,000.00"));
        assertTrue(html.contains("interest on borrowing"));
        assertTrue(html.contains("2,00,000.00"), "home loan interest grouped");

        // 4. Chapter VI-A rows + total (150000+50000+25000+50000+12000 = 287000)
        assertTrue(html.contains("Chapter VI-A"));
        assertTrue(html.contains("80C"));
        assertTrue(html.contains("80CCD(1B)"));
        assertTrue(html.contains("80D"));
        assertTrue(html.contains("80E"));
        assertTrue(html.contains("Total Chapter VI-A"));
        assertTrue(html.contains("2,87,000.00"), "Chapter VI-A total grouped");

        // 5. other income + status + verification block
        assertTrue(html.contains("Other income"));
        assertTrue(html.contains("SUBMITTED"));
        assertTrue(html.contains("Verification"));
    }

    @Test
    void new_regime_shows_concessional_warning() {
        EmployeeTaxDeclaration d = fullOldRegime();
        d.setTaxRegime("NEW");
        String html = service.buildHtml(d, employee());
        assertTrue(html.contains("115BAC"), "NEW regime note references Sec 115BAC");
        assertTrue(html.toLowerCase().contains("new tax regime"));
    }

    @Test
    void nil_sections_render_nil_declared() {
        EmployeeTaxDeclaration d = EmployeeTaxDeclaration.builder()
                .orgId(orgId)
                .employeeId(employeeId)
                .fiscalYear("2026-27")
                .taxRegime("OLD")
                .status("DRAFT")
                .build();
        String html = service.buildHtml(d, employee());
        // Three "Nil declared." messages: HRA, LTA, home loan + one in Chapter VI-A
        int nil = countOccurrences(html, "Nil declared");
        assertTrue(nil >= 4, "empty declaration renders Nil for each empty section, got " + nil);
    }

    @Test
    void landlord_pan_missing_is_flagged_when_rent_present() {
        EmployeeTaxDeclaration d = EmployeeTaxDeclaration.builder()
                .orgId(orgId).employeeId(employeeId).fiscalYear("2026-27").taxRegime("OLD")
                .hraRentPaid(new BigDecimal("120000"))
                .hraMetroCity(false)
                .status("DRAFT")
                .build();
        String html = service.buildHtml(d, employee());
        assertTrue(html.contains("Not provided"), "missing landlord PAN flagged");
        assertTrue(html.contains("Non-metro"));
    }

    @Test
    void escapes_xss_in_employee_name_and_notes() {
        Employee e = employee();
        e.setFullName("Ramesh <script>alert(1)</script> & \"Co\"");
        EmployeeTaxDeclaration d = fullOldRegime();
        d.setNotes("Proof <b>attached</b> & verified");
        String html = service.buildHtml(d, e);
        assertFalse(html.contains("<script>alert(1)</script>"));
        assertTrue(html.contains("&lt;script&gt;"));
        assertTrue(html.contains("&amp;"));
        assertTrue(html.contains("&quot;Co&quot;"));
    }

    @Test
    void filename_strips_path_chars_and_carries_fy() {
        EmployeeTaxDeclaration d = fullOldRegime();
        assertEquals("Form12BB-Ramesh Kumar-FY2026-27.pdf",
                service.filename(d, "Ramesh Kumar"));
        String fname = service.filename(d, "Ram/esh:Kumar");
        assertFalse(fname.contains("/"));
        assertFalse(fname.contains(":"));
        assertTrue(fname.endsWith(".pdf"));
        // empty name falls back
        assertEquals("Form12BB-Employee-FY2026-27.pdf", service.filename(d, ""));
    }

    @Test
    void assessment_year_derivation_handles_range_and_blank() {
        assertEquals("2027-28", Form12BBPdfService.assessmentYear("2026-27"));
        assertEquals("2026-27", Form12BBPdfService.assessmentYear("2025"));
        assertEquals("", Form12BBPdfService.assessmentYear(""));
        assertEquals("", Form12BBPdfService.assessmentYear("not-a-year"));
    }

    @Test
    void generatePdf_resolves_employee_and_renders() {
        EmployeeTaxDeclaration d = fullOldRegime();
        d.setId(declId);
        when(taxDeclarationService.get(declId)).thenReturn(d);
        when(employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId))
                .thenReturn(Optional.of(employee()));
        when(pdfService.render(anyString())).thenReturn(new byte[]{1, 2, 3});

        byte[] pdf = service.generatePdf(declId);
        assertEquals(3, pdf.length);

        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(cap.capture());
        assertTrue(cap.getValue().contains("FORM 12BB"));
        verify(employeeRepository).findByIdAndOrgIdAndIsDeletedFalse(eq(employeeId), eq(orgId));
    }

    private static int countOccurrences(String haystack, String needle) {
        int idx = 0, count = 0;
        while ((idx = haystack.indexOf(needle, idx)) != -1) {
            count++; idx += needle.length();
        }
        return count;
    }
}
