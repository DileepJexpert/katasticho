package com.katasticho.erp.reporting.service;

import com.katasticho.erp.reporting.dto.*;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class OperationalReportService {

    private final JdbcTemplate jdbcTemplate;

    @Transactional(readOnly = true)
    public CashFlowStatement getCashFlowStatement(LocalDate startDate, LocalDate endDate, String period) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String query = """
            SELECT
              CAST(je.effective_date AS DATE) as period_date,
              SUM(CASE WHEN je.source_module='SALES' THEN jl.base_debit ELSE 0 END) as sales_inflow,
              SUM(CASE WHEN a.code='1000' AND jl.base_debit > 0 THEN jl.base_debit ELSE 0 END) as ar_collections,
              SUM(CASE WHEN je.source_module='PURCHASE' THEN jl.base_credit ELSE 0 END) as cogs_outflow,
              SUM(CASE WHEN a.code='2100' AND jl.base_credit > 0 THEN jl.base_credit ELSE 0 END) as ap_payments
            FROM journal_entry je
            JOIN journal_line jl ON je.id = jl.journal_entry_id
            JOIN account a ON jl.account_id = a.id
            WHERE je.org_id = ? AND je.effective_date BETWEEN ? AND ? AND je.status = 'POSTED'
            GROUP BY CAST(je.effective_date AS DATE)
            ORDER BY period_date
            """;

        List<CashFlowStatement.DailyFlow> flows = jdbcTemplate.query(query,
            (rs, rowNum) -> {
                BigDecimal salesInflow = nullSafe(rs.getBigDecimal("sales_inflow"));
                BigDecimal arCollection = nullSafe(rs.getBigDecimal("ar_collections"));
                BigDecimal cogsOutflow = nullSafe(rs.getBigDecimal("cogs_outflow"));
                BigDecimal apPayments = nullSafe(rs.getBigDecimal("ap_payments"));
                BigDecimal netFlow = salesInflow.add(arCollection).subtract(cogsOutflow).subtract(apPayments);
                return new CashFlowStatement.DailyFlow(
                    rs.getObject("period_date", LocalDate.class),
                    salesInflow,
                    arCollection,
                    cogsOutflow,
                    apPayments,
                    netFlow
                );
            },
            orgId, startDate, endDate
        );

        BigDecimal openingBalance = BigDecimal.ZERO;
        BigDecimal closingBalance = flows.isEmpty() ? BigDecimal.ZERO :
            flows.stream()
                .map(CashFlowStatement.DailyFlow::netFlow)
                .reduce(openingBalance, BigDecimal::add);

        return new CashFlowStatement(startDate, endDate, flows, openingBalance, closingBalance);
    }

    @Transactional(readOnly = true)
    public List<JournalRegisterLine> getJournalRegister(
            LocalDate startDate, LocalDate endDate, String sourceModule, int pageNo, int pageSize) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String query = """
            SELECT
              je.entry_number,
              je.effective_date,
              je.description,
              je.source_module,
              je.source_id,
              COUNT(jl.id) as line_count,
              COALESCE(SUM(jl.base_debit), 0) as total_debit,
              COALESCE(SUM(jl.base_credit), 0) as total_credit
            FROM journal_entry je
            LEFT JOIN journal_line jl ON je.id = jl.journal_entry_id
            WHERE je.org_id = ?
              AND je.effective_date BETWEEN ? AND ?
              AND (? IS NULL OR je.source_module = ?)
            GROUP BY je.id, je.entry_number, je.effective_date, je.description, je.source_module, je.source_id
            ORDER BY je.effective_date DESC, je.entry_number DESC
            LIMIT ? OFFSET ?
            """;

        List<JournalRegisterLine> lines = jdbcTemplate.query(query,
            (rs, rowNum) -> {
                UUID sourceId = (UUID) rs.getObject("source_id");
                return new JournalRegisterLine(
                    rs.getString("entry_number"),
                    rs.getObject("effective_date", LocalDate.class),
                    rs.getString("description"),
                    rs.getString("source_module"),
                    sourceId,
                    rs.getInt("line_count"),
                    rs.getBigDecimal("total_debit"),
                    rs.getBigDecimal("total_credit"),
                    getJournalLineDetails(rs.getString("entry_number"), orgId)
                );
            },
            orgId, startDate, endDate, sourceModule, sourceModule,
            pageSize, (long) pageNo * pageSize
        );

        return lines;
    }

    private List<JournalRegisterLine.Detail> getJournalLineDetails(String entryNumber, UUID orgId) {
        String query = """
            SELECT
              a.code,
              a.name,
              COALESCE(jl.base_debit, 0) as debit,
              COALESCE(jl.base_credit, 0) as credit
            FROM journal_entry je
            JOIN journal_line jl ON je.id = jl.journal_entry_id
            JOIN account a ON jl.account_id = a.id
            WHERE je.org_id = ? AND je.entry_number = ?
            ORDER BY a.code
            """;

        return jdbcTemplate.query(query,
            (rs, rowNum) -> new JournalRegisterLine.Detail(
                rs.getString("code"),
                rs.getString("name"),
                rs.getBigDecimal("debit"),
                rs.getBigDecimal("credit")
            ),
            orgId, entryNumber
        );
    }

    private BigDecimal nullSafe(BigDecimal value) {
        return value != null ? value : BigDecimal.ZERO;
    }
}
