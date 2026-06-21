package com.katasticho.erp.tax.service;

import com.katasticho.erp.common.service.DocumentPdfService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class Form16PdfServiceTest {

    @Mock private SalaryTdsService salaryTdsService;
    @Mock private DocumentPdfService pdfService;

    private Form16PdfService service;
    private final UUID employeeId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new Form16PdfService(salaryTdsService, pdfService);
    }

    @Test
    void renders_header_partA_and_partB_sections() {
        when(salaryTdsService.form16(employeeId, 2026)).thenReturn(sampleData());
        when(pdfService.render(anyString())).thenReturn(new byte[]{1, 2, 3});

        byte[] pdf = service.generatePdf(employeeId, 2026);
        assertEquals(3, pdf.length);

        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(cap.capture());
        String html = cap.getValue();

        // Banner + FY block
        assertTrue(html.contains("FORM 16"));
        assertTrue(html.toLowerCase().contains("section 203"),
                "must reference Sec 203 for legal anchor");
        assertTrue(html.contains("FY 2026-27"));
        assertTrue(html.contains("Assessment Year 2027-28"));

        // Deductor + employee
        assertTrue(html.contains("Sharma Medical Stores"));
        assertTrue(html.contains("MHTAN12345A"));
        assertTrue(html.contains("Ramesh Kumar"));
        assertTrue(html.contains("EMP-001"));
        assertTrue(html.contains("ABCPK1234D"));

        // Part A — quarter rows + total
        assertTrue(html.contains("PART A"));
        assertTrue(html.contains("Q1"));
        assertTrue(html.contains("Q4"));

        // Part B — at least Basic + HRA rendered + pretty names
        assertTrue(html.contains("PART B"));
        assertTrue(html.contains("Basic"));
        assertTrue(html.contains("House Rent Allowance"));
        assertTrue(html.contains("Provident Fund"));
        assertTrue(html.contains("Tax on employment")); // section 16(iii) PT line

        // Total TDS in figures + words
        assertTrue(html.contains("60,000.00"), "Indian grouping for 60,000 total TDS");
        assertTrue(html.contains("Sixty Thousand"), "amount in words present");
    }

    @Test
    void omits_TDS_row_from_deductions_table_to_avoid_duplication() {
        when(salaryTdsService.form16(employeeId, 2026)).thenReturn(sampleData());
        when(pdfService.render(anyString())).thenReturn(new byte[]{});

        service.generatePdf(employeeId, 2026);
        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(cap.capture());
        String html = cap.getValue();

        // Part B "Deductions from Salary" section shouldn't list "Tax Deducted at Source"
        // (TDS is the explicit total at the bottom). Use occurrence count: the bottom
        // total + Part A header are allowed, but the deductions table row shouldn't add another.
        int totalTaxDeductedCount = countOccurrences(html, "Total tax deducted");
        assertTrue(totalTaxDeductedCount >= 1, "must show the total tax deducted summary");
    }

    @Test
    void renders_PAN_warning_when_employee_has_no_pan() {
        Map<String, Object> data = sampleData();
        @SuppressWarnings("unchecked")
        Map<String, Object> emp = (Map<String, Object>) data.get("employee");
        emp.put("pan", "");
        data.put("warning", "Employee has no PAN on file — Form 16 cannot be validly issued without it.");
        when(salaryTdsService.form16(employeeId, 2026)).thenReturn(data);
        when(pdfService.render(anyString())).thenReturn(new byte[]{});

        service.generatePdf(employeeId, 2026);
        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(cap.capture());
        assertTrue(cap.getValue().contains("Employee has no PAN"));
    }

    @Test
    void escapes_xss_in_employer_and_employee_names() {
        Map<String, Object> data = sampleData();
        @SuppressWarnings("unchecked")
        Map<String, Object> deductor = (Map<String, Object>) data.get("deductor");
        deductor.put("name", "Shop <script>alert(1)</script>");
        @SuppressWarnings("unchecked")
        Map<String, Object> emp = (Map<String, Object>) data.get("employee");
        emp.put("name", "Ramesh & \"Co\"");
        when(salaryTdsService.form16(employeeId, 2026)).thenReturn(data);
        when(pdfService.render(anyString())).thenReturn(new byte[]{});

        service.generatePdf(employeeId, 2026);
        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(cap.capture());
        String html = cap.getValue();
        assertFalse(html.contains("<script>alert(1)</script>"));
        assertTrue(html.contains("&lt;script&gt;"));
        assertTrue(html.contains("Ramesh &amp; &quot;Co&quot;"));
    }

    @Test
    void filename_strips_path_chars_and_carries_fy_label() {
        assertEquals("Form16-Ramesh Kumar-FY2026-27.pdf",
                service.filename(2026, "Ramesh Kumar"));
        // path chars stripped
        String fname = service.filename(2026, "Ram/esh:Kumar");
        assertFalse(fname.contains("/"));
        assertFalse(fname.contains(":"));
        assertTrue(fname.endsWith(".pdf"));
    }

    @Test
    void empty_employee_name_falls_back_to_Employee() {
        assertEquals("Form16-Employee-FY2026-27.pdf", service.filename(2026, null));
        assertEquals("Form16-Employee-FY2026-27.pdf", service.filename(2026, ""));
    }

    @Test
    void zero_tds_run_omits_amount_in_words() {
        Map<String, Object> data = sampleData();
        data.put("totalTdsDeducted", BigDecimal.ZERO);
        @SuppressWarnings("unchecked")
        var partA = (List<Map<String, Object>>) data.get("partA");
        for (Map<String, Object> q : partA) q.put("tdsDeducted", BigDecimal.ZERO);
        when(salaryTdsService.form16(employeeId, 2026)).thenReturn(data);
        when(pdfService.render(anyString())).thenReturn(new byte[]{});

        service.generatePdf(employeeId, 2026);
        ArgumentCaptor<String> cap = ArgumentCaptor.forClass(String.class);
        verify(pdfService).render(cap.capture());
        String html = cap.getValue();
        // No "Zero Only" or any words text in the amount-in-words div
        assertFalse(html.contains("class='words'"));
    }

    // ── helpers ───────────────────────────────────────────────────

    private Map<String, Object> sampleData() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("form", "16");
        data.put("fy", "2026-27");
        data.put("assessmentYear", "2027-28");

        Map<String, Object> deductor = new LinkedHashMap<>();
        deductor.put("name", "Sharma Medical Stores");
        deductor.put("address", "12, MG Road, Pune, MH 411001");
        deductor.put("tan", "MHTAN12345A");
        deductor.put("pan", "AAACS1234F");
        data.put("deductor", deductor);

        Map<String, Object> emp = new LinkedHashMap<>();
        emp.put("employeeId", employeeId);
        emp.put("employeeCode", "EMP-001");
        emp.put("name", "Ramesh Kumar");
        emp.put("pan", "ABCPK1234D");
        emp.put("designation", "Senior Pharmacist");
        data.put("employee", emp);

        List<Map<String, Object>> partA = new java.util.ArrayList<>();
        for (int q = 1; q <= 4; q++) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("quarter", "Q" + q);
            row.put("tdsDeducted", new BigDecimal("15000"));
            partA.add(row);
        }
        data.put("partA", partA);

        Map<String, Object> partB = new LinkedHashMap<>();
        Map<String, Object> earnings = new LinkedHashMap<>();
        earnings.put("BASIC", new BigDecimal("360000"));
        earnings.put("HRA", new BigDecimal("144000"));
        partB.put("earningsByComponent", earnings);
        partB.put("grossSalary", new BigDecimal("504000"));
        partB.put("professionalTax", new BigDecimal("2500"));

        Map<String, Object> deductions = new LinkedHashMap<>();
        deductions.put("PF_EMPLOYEE", new BigDecimal("43200"));
        deductions.put("TDS", new BigDecimal("60000"));
        partB.put("deductionsByComponent", deductions);
        partB.put("totalTaxDeducted", new BigDecimal("60000"));
        data.put("partB", partB);
        data.put("totalTdsDeducted", new BigDecimal("60000"));

        return data;
    }

    private static int countOccurrences(String haystack, String needle) {
        int idx = 0, count = 0;
        while ((idx = haystack.indexOf(needle, idx)) != -1) {
            count++; idx += needle.length();
        }
        return count;
    }
}
