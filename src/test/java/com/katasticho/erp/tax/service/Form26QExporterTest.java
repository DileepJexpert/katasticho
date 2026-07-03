package com.katasticho.erp.tax.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class Form26QExporterTest {

    @Mock private TdsService tdsService;
    private Form26QExporter exporter;

    @BeforeEach
    void setUp() {
        exporter = new Form26QExporter(tdsService);
    }

    /** Two deductee rows: a company (194J) and a non-company (194C). */
    private Map<String, Object> sample() {
        List<Map<String, Object>> deductees = new ArrayList<>();
        Map<String, Object> a = new LinkedHashMap<>();
        a.put("deducteeName", "Acme Consulting Pvt Ltd");
        a.put("deducteePan", "AACCA1234C");   // 4th char C -> company
        a.put("section", "194J");
        a.put("amountPaid", new BigDecimal("100000"));
        a.put("tdsDeducted", new BigDecimal("10000"));
        a.put("billCount", 3);
        deductees.add(a);
        Map<String, Object> b = new LinkedHashMap<>();
        b.put("deducteeName", "Ravi Contractors");
        b.put("deducteePan", "ABCPR5678K");   // 4th char P -> non-company
        b.put("section", "194C");
        b.put("amountPaid", new BigDecimal("50000"));
        b.put("tdsDeducted", new BigDecimal("500"));
        b.put("billCount", 1);
        deductees.add(b);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("totalAmountPaid", new BigDecimal("150000"));
        data.put("totalTdsDeducted", new BigDecimal("10500"));
        data.put("deductees", deductees);
        return data;
    }

    @Test
    void csv_renders_header_deductee_rows_and_total() {
        when(tdsService.form26q(2026, 1)).thenReturn(sample());
        String[] lines = exporter.csv(2026, 1).split("\r\n");

        assertEquals("Sr.,Vendor,PAN,Section,Amount Paid,TDS Deducted,Bills,Effective Rate %", lines[0]);
        assertEquals(4, lines.length); // 2 deductees + total
        assertTrue(lines[1].contains("Acme Consulting Pvt Ltd"));
        assertTrue(lines[1].contains("AACCA1234C"));
        assertTrue(lines[1].contains("194J"));
        assertTrue(lines[1].endsWith(",10.00"), "10% effective rate (10000/100000)");
        assertTrue(lines[3].startsWith(",,,TOTAL,"));
    }

    @Test
    void fvu_carries_per_row_section_code_and_deductee_code() {
        when(tdsService.form26q(2026, 1)).thenReturn(sample());
        String[] lines = exporter.fvuDeducteeDetail(2026, 1).split("\r\n");

        // line ^ DD ^ deducteeCode ^ PAN ^ name ^ sectionCode ^ paid ^ tds ^ rate
        String[] a = lines[0].split("\\^");
        assertEquals("DD", a[1]);
        assertEquals("01", a[2]);          // company (PAN 4th char C)
        assertEquals("AACCA1234C", a[3]);
        assertEquals("94J", a[5]);         // 194J -> 94J, NOT hardcoded 192
        assertEquals("100000.00", a[6]);

        String[] b = lines[1].split("\\^");
        assertEquals("02", b[2]);          // non-company
        assertEquals("94C", b[5]);         // 194C -> 94C
    }

    @Test
    void blank_pan_becomes_the_fvu_sentinel() {
        Map<String, Object> data = sample();
        @SuppressWarnings("unchecked")
        var deductees = (List<Map<String, Object>>) data.get("deductees");
        deductees.get(0).put("deducteePan", "");
        when(tdsService.form26q(2026, 1)).thenReturn(data);

        String csv = exporter.csv(2026, 1);
        String fvu = exporter.fvuDeducteeDetail(2026, 1);
        assertTrue(csv.contains("PANNOTAVBL"));
        assertTrue(fvu.contains("^PANNOTAVBL^"));
        // sentinel PAN -> non-company deductee code
        assertTrue(fvu.split("\r\n")[0].split("\\^")[2].equals("02"));
    }

    @Test
    void csv_escapes_commas_in_vendor_name() {
        Map<String, Object> data = sample();
        @SuppressWarnings("unchecked")
        var deductees = (List<Map<String, Object>>) data.get("deductees");
        deductees.get(0).put("deducteeName", "Acme, Consulting & Co");
        when(tdsService.form26q(2026, 1)).thenReturn(data);

        assertTrue(exporter.csv(2026, 1).contains("\"Acme, Consulting & Co\""));
    }

    @Test
    void section_and_deductee_code_helpers() {
        assertEquals("94C", Form26QExporter.fvuSectionCode("194C"));
        assertEquals("94Q", Form26QExporter.fvuSectionCode("194Q"));
        // non-194 sections keep their real number — NOT stripped to 93/95
        assertEquals("193", Form26QExporter.fvuSectionCode("193"));
        assertEquals("195", Form26QExporter.fvuSectionCode("195"));
        // the "no section" placeholder + blank map to an empty field, never a bogus code
        assertEquals("", Form26QExporter.fvuSectionCode("TDS"));
        assertEquals("", Form26QExporter.fvuSectionCode(""));
        assertEquals("", Form26QExporter.fvuSectionCode(null));
        assertEquals("01", Form26QExporter.deducteeCode("AACCA1234C"));
        assertEquals("02", Form26QExporter.deducteeCode("ABCPR5678K"));
        assertEquals("02", Form26QExporter.deducteeCode("PANNOTAVBL"));
    }

    @Test
    void empty_quarter_yields_header_and_total_only() {
        Map<String, Object> empty = new LinkedHashMap<>();
        empty.put("totalAmountPaid", BigDecimal.ZERO);
        empty.put("totalTdsDeducted", BigDecimal.ZERO);
        empty.put("deductees", List.of());
        when(tdsService.form26q(2026, 2)).thenReturn(empty);

        String[] lines = exporter.csv(2026, 2).split("\r\n");
        assertEquals(2, lines.length); // header + total
        assertEquals("", exporter.fvuDeducteeDetail(2026, 2));
        assertEquals("26Q-FY2026-Q2.csv", exporter.filename(2026, 2, "csv"));
    }
}
