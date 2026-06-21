package com.katasticho.erp.tax.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class Form24QExporterTest {

    @Mock private SalaryTdsService salaryTdsService;
    private Form24QExporter exporter;

    @BeforeEach
    void setUp() { exporter = new Form24QExporter(salaryTdsService); }

    @Test
    void csv_renders_header_rows_and_total() {
        when(salaryTdsService.form24q(2026, 1)).thenReturn(sample());
        String csv = exporter.csv(2026, 1);
        String[] lines = csv.split("\r\n");
        assertEquals("Sr.,Employee Code,Employee Name,PAN,Amount Paid,TDS Deducted,Months,Effective Rate %",
                lines[0]);
        // Two deductee rows + total
        assertEquals(4, lines.length);
        assertTrue(lines[1].contains("Ramesh Kumar"));
        assertTrue(lines[1].contains("ABCPK1234D"));
        assertTrue(lines[1].endsWith(",10.00"), "10% effective rate (5000/50000)");
        assertTrue(lines[3].startsWith(",,,TOTAL,"));
    }

    @Test
    void csv_escapes_commas_in_employee_name() {
        Map<String, Object> data = sample();
        @SuppressWarnings("unchecked")
        var deductees = (List<Map<String, Object>>) data.get("deductees");
        deductees.get(0).put("deducteeName", "Doe, John");
        when(salaryTdsService.form24q(2026, 1)).thenReturn(data);

        String csv = exporter.csv(2026, 1);
        assertTrue(csv.contains("\"Doe, John\""));
    }

    @Test
    void fvu_renders_deductee_records_with_caret_separator() {
        when(salaryTdsService.form24q(2026, 1)).thenReturn(sample());
        String fvu = exporter.fvuDeducteeDetail(2026, 1);
        String[] lines = fvu.split("\r\n");
        assertEquals(2, lines.length);
        String[] cols = lines[0].split("\\^");
        // line ^ DD ^ code ^ pan ^ name ^ 192 ^ paid ^ tds ^ rate
        assertEquals("1", cols[0]);
        assertEquals("DD", cols[1]);
        assertEquals("EMP-001", cols[2]);
        assertEquals("ABCPK1234D", cols[3]);
        assertEquals("Ramesh Kumar", cols[4]);
        assertEquals("192", cols[5]);
        assertEquals("50000.00", cols[6]);
        assertEquals("5000.00", cols[7]);
        assertEquals("10.00", cols[8]);
    }

    @Test
    void fvu_sanitises_caret_in_name() {
        Map<String, Object> data = sample();
        @SuppressWarnings("unchecked")
        var deductees = (List<Map<String, Object>>) data.get("deductees");
        deductees.get(0).put("deducteeName", "Bad^Name");
        when(salaryTdsService.form24q(2026, 1)).thenReturn(data);

        String fvu = exporter.fvuDeducteeDetail(2026, 1);
        String[] cols = fvu.split("\r\n")[0].split("\\^");
        assertEquals("Bad Name", cols[4]);
    }

    @Test
    void empty_quarter_renders_csv_with_header_and_zero_total() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("deductees", List.of());
        data.put("totalAmountPaid", BigDecimal.ZERO);
        data.put("totalTdsDeducted", BigDecimal.ZERO);
        when(salaryTdsService.form24q(2026, 1)).thenReturn(data);

        String csv = exporter.csv(2026, 1);
        String[] lines = csv.split("\r\n");
        assertEquals(2, lines.length);
        assertTrue(lines[1].contains("TOTAL,0.00,0.00"));
    }

    @Test
    void filename_includes_fy_and_quarter() {
        assertEquals("24Q-FY2026-Q1.csv", exporter.filename(2026, 1, "csv"));
        assertEquals("24Q-FY2026-Q4.txt", exporter.filename(2026, 4, "txt"));
    }

    @Test
    void effective_rate_zero_when_no_amount_paid() {
        Map<String, Object> data = new LinkedHashMap<>();
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("employeeCode", "EMP-9");
        row.put("deducteeName", "Zero Paid");
        row.put("deducteePan", "X");
        row.put("amountPaid", BigDecimal.ZERO);
        row.put("tdsDeducted", BigDecimal.ZERO);
        row.put("monthCount", 0);
        data.put("deductees", new java.util.ArrayList<>(List.of(row)));
        data.put("totalAmountPaid", BigDecimal.ZERO);
        data.put("totalTdsDeducted", BigDecimal.ZERO);
        when(salaryTdsService.form24q(2026, 1)).thenReturn(data);

        String csv = exporter.csv(2026, 1);
        assertTrue(csv.split("\r\n")[1].endsWith(",0,0.00"));
    }

    private Map<String, Object> sample() {
        Map<String, Object> d1 = new LinkedHashMap<>();
        d1.put("employeeCode", "EMP-001");
        d1.put("deducteeName", "Ramesh Kumar");
        d1.put("deducteePan", "ABCPK1234D");
        d1.put("amountPaid", new BigDecimal("50000"));
        d1.put("tdsDeducted", new BigDecimal("5000"));
        d1.put("monthCount", 3);

        Map<String, Object> d2 = new LinkedHashMap<>();
        d2.put("employeeCode", "EMP-002");
        d2.put("deducteeName", "Sita Devi");
        d2.put("deducteePan", "ABCPK9999X");
        d2.put("amountPaid", new BigDecimal("30000"));
        d2.put("tdsDeducted", new BigDecimal("0"));
        d2.put("monthCount", 3);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("deductees", new java.util.ArrayList<>(List.of(d1, d2)));
        data.put("totalAmountPaid", new BigDecimal("80000"));
        data.put("totalTdsDeducted", new BigDecimal("5000"));
        return data;
    }
}
