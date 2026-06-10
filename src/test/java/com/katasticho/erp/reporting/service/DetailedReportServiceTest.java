package com.katasticho.erp.reporting.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.reporting.dto.CustomerStatementReport;
import com.katasticho.erp.reporting.dto.SalesRegisterReport;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DetailedReportServiceTest {

    @Mock private JdbcTemplate jdbcTemplate;

    private DetailedReportService service;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        service = new DetailedReportService(jdbcTemplate);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── getSalesRegister ───────────────────────────────────────────────────

    @Test
    void salesRegister_emptyResult_returnsZeroTotals() {
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        SalesRegisterReport report = service.getSalesRegister(
                LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30), null);

        assertNotNull(report);
        assertTrue(report.lines().isEmpty());
        assertEquals(0, BigDecimal.ZERO.compareTo(report.totalTaxable()));
        assertEquals(0, BigDecimal.ZERO.compareTo(report.grandTotal()));
    }

    @Test
    void salesRegister_singleInvoiceLine_computesTotals() {
        SalesRegisterReport.Line line = new SalesRegisterReport.Line(
                "INVOICE", "INV-2026-000001", LocalDate.of(2026, 4, 10),
                "Ramesh Traders", "Paracetamol 500mg Strip", "3004",
                new BigDecimal("10"), "Strip",
                new BigDecimal("50.00"), new BigDecimal("446.43"),
                new BigDecimal("26.79"), new BigDecimal("26.79"), BigDecimal.ZERO,
                new BigDecimal("500.00"), new BigDecimal("12"), "29");

        when(jdbcTemplate.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of(line));

        SalesRegisterReport report = service.getSalesRegister(
                LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30), null);

        assertEquals(1, report.lines().size());
        assertEquals(0, new BigDecimal("446.43").compareTo(report.totalTaxable()));
        assertEquals(0, new BigDecimal("26.79").compareTo(report.totalCgst()));
        assertEquals(0, new BigDecimal("26.79").compareTo(report.totalSgst()));
        assertEquals(0, BigDecimal.ZERO.compareTo(report.totalIgst()));
        assertEquals(0, new BigDecimal("500.00").compareTo(report.grandTotal()));
    }

    @Test
    void salesRegister_multipleLines_sumsAllTotals() {
        SalesRegisterReport.Line line1 = new SalesRegisterReport.Line(
                "INVOICE", "INV-001", LocalDate.of(2026, 4, 10),
                "Customer A", "Item A", "3004", new BigDecimal("5"), "Pcs",
                new BigDecimal("100"), new BigDecimal("446.43"),
                new BigDecimal("26.79"), new BigDecimal("26.79"), BigDecimal.ZERO,
                new BigDecimal("500"), new BigDecimal("12"), "29");

        SalesRegisterReport.Line line2 = new SalesRegisterReport.Line(
                "POS", "RCP-001", LocalDate.of(2026, 4, 11),
                "Walk-in Customer", "Item B", "2106", new BigDecimal("2"), "Pcs",
                new BigDecimal("200"), new BigDecimal("338.98"),
                new BigDecimal("30.51"), new BigDecimal("30.51"), BigDecimal.ZERO,
                new BigDecimal("400"), new BigDecimal("18"), "29");

        when(jdbcTemplate.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of(line1, line2));

        SalesRegisterReport report = service.getSalesRegister(
                LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30), null);

        assertEquals(2, report.lines().size());
        assertEquals(0, new BigDecimal("900").compareTo(report.grandTotal()));
        assertEquals(0, new BigDecimal("57.30").compareTo(report.totalCgst()));
    }

    @Test
    void salesRegister_sqlJoinsBySourceLineNotSourceId() {
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        service.getSalesRegister(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30), "INVOICE");

        String sql = sqlCaptor.getValue();
        assertTrue(sql.contains("WITH invoice_tax AS"), "should use CTE for tax aggregation");
        assertTrue(sql.contains("GROUP BY source_id, source_line_id"), "should group by line not invoice");
        assertTrue(sql.contains("itax.source_line_id = il.id"), "should join on line id, not invoice id");
    }

    // ── getCustomerStatement ──────────────────────────────────────────────

    @Test
    void customerStatement_emptyResult_returnsZeroBalance() {
        UUID contactId = UUID.randomUUID();

        when(jdbcTemplate.queryForObject(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn("Test Customer");
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        CustomerStatementReport report = service.getCustomerStatement(
                contactId, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30));

        assertNotNull(report);
        assertEquals("Test Customer", report.customerName());
        assertTrue(report.lines().isEmpty());
        assertEquals(0, BigDecimal.ZERO.compareTo(report.closingBalance()));
    }

    @Test
    void customerStatement_invoiceAndPayment_computesRunningBalance() {
        UUID contactId = UUID.randomUUID();

        CustomerStatementReport.Line invoiceLine = new CustomerStatementReport.Line(
                "INVOICE", "INV-001", LocalDate.of(2026, 4, 5),
                new BigDecimal("1000"), BigDecimal.ZERO, BigDecimal.ZERO);
        CustomerStatementReport.Line paymentLine = new CustomerStatementReport.Line(
                "PAYMENT", "PAY-001", LocalDate.of(2026, 4, 15),
                BigDecimal.ZERO, new BigDecimal("600"), BigDecimal.ZERO);

        when(jdbcTemplate.queryForObject(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn("Ramesh Traders");
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(new ArrayList<>(List.of(invoiceLine, paymentLine)));

        CustomerStatementReport report = service.getCustomerStatement(
                contactId, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30));

        assertEquals(2, report.lines().size());
        assertEquals(0, new BigDecimal("400").compareTo(report.closingBalance()));
        assertEquals(0, new BigDecimal("1000").compareTo(report.lines().get(0).runningBalance()));
        assertEquals(0, new BigDecimal("400").compareTo(report.lines().get(1).runningBalance()));
    }

    @Test
    void customerStatement_multipleInvoicesNoPayments_fullAmountOutstanding() {
        UUID contactId = UUID.randomUUID();

        CustomerStatementReport.Line inv1 = new CustomerStatementReport.Line(
                "INVOICE", "INV-001", LocalDate.of(2026, 4, 1),
                new BigDecimal("500"), BigDecimal.ZERO, BigDecimal.ZERO);
        CustomerStatementReport.Line inv2 = new CustomerStatementReport.Line(
                "INVOICE", "INV-002", LocalDate.of(2026, 4, 20),
                new BigDecimal("300"), BigDecimal.ZERO, BigDecimal.ZERO);

        when(jdbcTemplate.queryForObject(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn("Suresh Kirana");
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(new ArrayList<>(List.of(inv1, inv2)));

        CustomerStatementReport report = service.getCustomerStatement(
                contactId, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30));

        assertEquals(2, report.lines().size());
        assertEquals(0, new BigDecimal("800").compareTo(report.closingBalance()));
        assertEquals(0, new BigDecimal("500").compareTo(report.lines().get(0).runningBalance()));
        assertEquals(0, new BigDecimal("800").compareTo(report.lines().get(1).runningBalance()));
    }
}
