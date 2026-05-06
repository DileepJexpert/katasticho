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

    @Transactional(readOnly = true)
    public SalesRegisterReport getSalesRegister(LocalDate startDate, LocalDate endDate, String documentType) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String query = """
            SELECT
              'INVOICE' as document_type,
              i.invoice_number as document_number,
              i.invoice_date as document_date,
              c.display_name as customer_name,
              il.description as item_description,
              il.hsn_code,
              il.quantity,
              it.name as unit,
              il.unit_price,
              il.taxable_amount,
              COALESCE(tli_cgst.tax_amount, 0) as cgst_amount,
              COALESCE(tli_sgst.tax_amount, 0) as sgst_amount,
              COALESCE(tli_igst.tax_amount, 0) as igst_amount,
              il.line_total as total_amount,
              CASE WHEN tli_cgst.rate IS NOT NULL THEN tli_cgst.rate * 2 ELSE 0 END as gst_rate,
              i.place_of_supply
            FROM invoice i
            JOIN contact c ON i.contact_id = c.id
            JOIN invoice_line il ON i.id = il.invoice_id
            LEFT JOIN item it ON il.item_id = it.id
            LEFT JOIN tax_line_item tli_cgst ON i.id = tli_cgst.source_id
              AND tli_cgst.source_type='INVOICE' AND tli_cgst.component_code LIKE '%CGST%'
            LEFT JOIN tax_line_item tli_sgst ON i.id = tli_sgst.source_id
              AND tli_sgst.source_type='INVOICE' AND tli_sgst.component_code LIKE '%SGST%'
            LEFT JOIN tax_line_item tli_igst ON i.id = tli_igst.source_id
              AND tli_igst.source_type='INVOICE' AND tli_igst.component_code LIKE '%IGST%'
            WHERE i.org_id = ? AND i.invoice_date BETWEEN ? AND ? AND i.status = 'SENT'
              AND (? IS NULL OR 'INVOICE' = ?)

            UNION ALL

            SELECT
              'POS' as document_type,
              sr.receipt_number as document_number,
              sr.receipt_date as document_date,
              COALESCE(c.display_name, 'Walk-in Customer') as customer_name,
              srl.description as item_description,
              srl.hsn_code,
              srl.quantity,
              srl.unit,
              srl.rate,
              srl.amount - (sr.cgst + sr.sgst + sr.igst) / (SELECT COUNT(*) FROM sales_receipt_line WHERE receipt_id = sr.id) as taxable_amount,
              sr.cgst / (SELECT COUNT(*) FROM sales_receipt_line WHERE receipt_id = sr.id) as cgst_amount,
              sr.sgst / (SELECT COUNT(*) FROM sales_receipt_line WHERE receipt_id = sr.id) as sgst_amount,
              sr.igst / (SELECT COUNT(*) FROM sales_receipt_line WHERE receipt_id = sr.id) as igst_amount,
              srl.amount as total_amount,
              (sr.cgst + sr.sgst) * 200 / srl.amount as gst_rate,
              org.state_code as place_of_supply
            FROM sales_receipt sr
            LEFT JOIN contact c ON sr.contact_id = c.id
            JOIN sales_receipt_line srl ON sr.id = srl.receipt_id
            JOIN organisation org ON sr.org_id = org.id
            WHERE sr.org_id = ? AND sr.receipt_date BETWEEN ? AND ?
              AND (? IS NULL OR 'POS' = ?)

            ORDER BY document_date, document_number
            """;

        List<SalesRegisterReport.Line> lines = jdbcTemplate.query(query,
            (rs, rowNum) -> new SalesRegisterReport.Line(
                rs.getString("document_type"),
                rs.getString("document_number"),
                rs.getObject("document_date", LocalDate.class),
                rs.getString("customer_name"),
                rs.getString("item_description"),
                rs.getString("hsn_code"),
                rs.getBigDecimal("quantity"),
                rs.getString("unit"),
                rs.getBigDecimal("unit_price"),
                rs.getBigDecimal("taxable_amount"),
                rs.getBigDecimal("cgst_amount"),
                rs.getBigDecimal("sgst_amount"),
                rs.getBigDecimal("igst_amount"),
                rs.getBigDecimal("total_amount"),
                rs.getBigDecimal("gst_rate"),
                rs.getString("place_of_supply")
            ),
            orgId, startDate, endDate, documentType, documentType,
            orgId, startDate, endDate, documentType, documentType
        );

        BigDecimal totalTaxable = lines.stream()
            .map(SalesRegisterReport.Line::taxableAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalCgst = lines.stream()
            .map(SalesRegisterReport.Line::cgstAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalSgst = lines.stream()
            .map(SalesRegisterReport.Line::sgstAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalIgst = lines.stream()
            .map(SalesRegisterReport.Line::igstAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal grandTotal = lines.stream()
            .map(SalesRegisterReport.Line::totalAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new SalesRegisterReport(
            startDate, endDate,
            totalTaxable, totalCgst, totalSgst, totalIgst, grandTotal,
            lines
        );
    }

    @Transactional(readOnly = true)
    public CustomerStatementReport getCustomerStatement(UUID customerId, LocalDate startDate, LocalDate endDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String contactQuery = """
            SELECT display_name FROM contact WHERE id = ? AND org_id = ?
            """;
        String contactName = jdbcTemplate.queryForObject(contactQuery,
            (rs, rowNum) -> rs.getString("display_name"),
            customerId, orgId);

        String query = """
            SELECT
              'INVOICE' as transaction_type,
              i.invoice_number as document_number,
              i.invoice_date as transaction_date,
              i.base_total as debit_amount,
              0 as credit_amount
            FROM invoice i
            WHERE i.contact_id = ? AND i.org_id = ? AND i.invoice_date BETWEEN ? AND ? AND i.status = 'SENT'

            UNION ALL

            SELECT
              'PAYMENT' as transaction_type,
              p.payment_number as document_number,
              p.payment_date as transaction_date,
              0 as debit_amount,
              p.base_amount as credit_amount
            FROM payment p
            WHERE p.contact_id = ? AND p.org_id = ? AND p.payment_date BETWEEN ? AND ?

            ORDER BY transaction_date, document_number
            """;

        List<CustomerStatementReport.Line> lines = jdbcTemplate.query(query,
            (rs, rowNum) -> new CustomerStatementReport.Line(
                rs.getString("transaction_type"),
                rs.getString("document_number"),
                rs.getObject("transaction_date", LocalDate.class),
                rs.getBigDecimal("debit_amount"),
                rs.getBigDecimal("credit_amount"),
                BigDecimal.ZERO
            ),
            customerId, orgId, startDate, endDate,
            customerId, orgId, startDate, endDate
        );

        BigDecimal openingBalance = BigDecimal.ZERO;
        BigDecimal totalInvoices = BigDecimal.ZERO;
        BigDecimal totalPayments = BigDecimal.ZERO;
        BigDecimal runningBalance = openingBalance;

        for (int i = 0; i < lines.size(); i++) {
            var line = lines.get(i);
            totalInvoices = totalInvoices.add(line.debitAmount());
            totalPayments = totalPayments.add(line.creditAmount());
            runningBalance = runningBalance.add(line.debitAmount()).subtract(line.creditAmount());
            lines.set(i, new CustomerStatementReport.Line(
                line.transactionType(),
                line.documentNumber(),
                line.transactionDate(),
                line.debitAmount(),
                line.creditAmount(),
                runningBalance
            ));
        }

        BigDecimal closingBalance = runningBalance;

        return new CustomerStatementReport(
            customerId,
            contactName,
            startDate,
            endDate,
            openingBalance,
            totalInvoices,
            totalPayments,
            closingBalance,
            lines
        );
    }

    @Transactional(readOnly = true)
    public PurchaseRegisterReport getPurchaseRegister(LocalDate startDate, LocalDate endDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String query = """
            SELECT
              pb.bill_number,
              pb.bill_date,
              c.display_name as vendor_name,
              c.gstin as vendor_gstin,
              pbl.description as item_description,
              pbl.hsn_code,
              pbl.quantity,
              pbl.unit_price,
              pbl.taxable_amount,
              COALESCE(tli_cgst.tax_amount, 0) as cgst_amount,
              COALESCE(tli_sgst.tax_amount, 0) as sgst_amount,
              COALESCE(tli_igst.tax_amount, 0) as igst_amount,
              pbl.line_total as total_amount
            FROM purchase_bill pb
            JOIN contact c ON pb.contact_id = c.id
            JOIN purchase_bill_line pbl ON pb.id = pbl.purchase_bill_id
            LEFT JOIN tax_line_item tli_cgst ON pb.id = tli_cgst.source_id
              AND tli_cgst.source_type='BILL' AND tli_cgst.component_code LIKE '%CGST%'
            LEFT JOIN tax_line_item tli_sgst ON pb.id = tli_sgst.source_id
              AND tli_sgst.source_type='BILL' AND tli_sgst.component_code LIKE '%SGST%'
            LEFT JOIN tax_line_item tli_igst ON pb.id = tli_igst.source_id
              AND tli_igst.source_type='BILL' AND tli_igst.component_code LIKE '%IGST%'
            WHERE pb.org_id = ? AND pb.bill_date BETWEEN ? AND ? AND pb.status IN ('OPEN', 'PARTIALLY_PAID', 'PAID')
            ORDER BY pb.bill_date, pb.bill_number
            """;

        List<PurchaseRegisterReport.Line> lines = jdbcTemplate.query(query,
            (rs, rowNum) -> new PurchaseRegisterReport.Line(
                rs.getString("bill_number"),
                rs.getObject("bill_date", LocalDate.class),
                rs.getString("vendor_name"),
                rs.getString("vendor_gstin"),
                rs.getString("item_description"),
                rs.getString("hsn_code"),
                rs.getBigDecimal("quantity"),
                rs.getBigDecimal("unit_price"),
                rs.getBigDecimal("taxable_amount"),
                rs.getBigDecimal("cgst_amount"),
                rs.getBigDecimal("sgst_amount"),
                rs.getBigDecimal("igst_amount"),
                rs.getBigDecimal("total_amount")
            ),
            orgId, startDate, endDate
        );

        BigDecimal totalTaxable = lines.stream()
            .map(PurchaseRegisterReport.Line::taxableAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalCgst = lines.stream()
            .map(PurchaseRegisterReport.Line::cgstAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalSgst = lines.stream()
            .map(PurchaseRegisterReport.Line::sgstAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalIgst = lines.stream()
            .map(PurchaseRegisterReport.Line::igstAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal grandTotal = lines.stream()
            .map(PurchaseRegisterReport.Line::totalAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new PurchaseRegisterReport(
            startDate, endDate,
            totalTaxable, totalCgst, totalSgst, totalIgst, grandTotal,
            lines
        );
    }

    @Transactional(readOnly = true)
    public DailySalesReport getDailySalesReport(LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String byModeQuery = """
            SELECT
              sr.payment_mode,
              COUNT(DISTINCT sr.id) as transaction_count,
              SUM(sr.total) as total_amount
            FROM sales_receipt sr
            WHERE sr.org_id = ? AND sr.receipt_date = ?
            GROUP BY sr.payment_mode
            ORDER BY sr.payment_mode
            """;

        List<DailySalesReport.ByMode> byMode = jdbcTemplate.query(byModeQuery,
            (rs, rowNum) -> new DailySalesReport.ByMode(
                rs.getString("payment_mode"),
                rs.getInt("transaction_count"),
                rs.getBigDecimal("total_amount")
            ),
            orgId, date
        );

        String topItemsQuery = """
            SELECT
              COALESCE(i.name, srl.description) as item_name,
              SUM(srl.quantity) as total_qty,
              AVG(srl.rate) as unit_price,
              SUM(srl.amount) as total_amount
            FROM sales_receipt sr
            JOIN sales_receipt_line srl ON sr.id = srl.receipt_id
            LEFT JOIN item i ON srl.item_id = i.id
            WHERE sr.org_id = ? AND sr.receipt_date = ?
            GROUP BY COALESCE(i.name, srl.description)
            ORDER BY SUM(srl.amount) DESC
            LIMIT 10
            """;

        List<DailySalesReport.TopItem> topItems = jdbcTemplate.query(topItemsQuery,
            (rs, rowNum) -> new DailySalesReport.TopItem(
                rs.getString("item_name"),
                rs.getBigDecimal("total_qty"),
                rs.getBigDecimal("unit_price"),
                rs.getBigDecimal("total_amount")
            ),
            orgId, date
        );

        String summaryQuery = """
            SELECT
              SUM(sr.subtotal) as total_gross,
              SUM(sr.cgst + sr.sgst + sr.igst) as total_tax,
              SUM(sr.total) as total_net
            FROM sales_receipt sr
            WHERE sr.org_id = ? AND sr.receipt_date = ?
            """;

        var totals = jdbcTemplate.queryForObject(summaryQuery,
            (rs, rowNum) -> new Object[]{
                nullSafe(rs.getBigDecimal("total_gross")),
                nullSafe(rs.getBigDecimal("total_tax")),
                nullSafe(rs.getBigDecimal("total_net"))
            },
            orgId, date
        );

        return new DailySalesReport(
            date,
            (BigDecimal) totals[0],
            (BigDecimal) totals[1],
            (BigDecimal) totals[2],
            byMode,
            topItems
        );
    }

    private BigDecimal nullSafe(BigDecimal value) {
        return value != null ? value : BigDecimal.ZERO;
    }
}
