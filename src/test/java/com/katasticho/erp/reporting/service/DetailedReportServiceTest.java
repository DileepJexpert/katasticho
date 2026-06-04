package com.katasticho.erp.reporting.service;

import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DetailedReportServiceTest {

    @Mock private JdbcTemplate jdbcTemplate;

    private DetailedReportService service;

    @BeforeEach
    void setUp() {
        service = new DetailedReportService(jdbcTemplate);
        TenantContext.setCurrentOrgId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void salesRegister_joinsInvoiceTaxesBySourceLineToAvoidInflatedAmounts() {
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        service.getSalesRegister(
                LocalDate.of(2026, 6, 1),
                LocalDate.of(2026, 6, 30),
                "INVOICE");

        String sql = sqlCaptor.getValue();

        assertTrue(sql.contains("WITH invoice_tax AS"));
        assertTrue(sql.contains("GROUP BY source_id, source_line_id"));
        assertTrue(sql.contains("itax.source_line_id = il.id"));
        assertTrue(!sql.contains("tli_cgst.source_id"));
    }
}
