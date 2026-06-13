package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.StockistSalesLine;
import com.katasticho.erp.fieldsales.entity.StockistSalesStatement;
import com.katasticho.erp.fieldsales.repository.StockistSalesLineRepository;
import com.katasticho.erp.fieldsales.repository.StockistSalesStatementRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Stockist secondary sales / Stock &amp; Sales Statement (SSS). Captures what a
 * stockist holds and sells onward per product per month, and rolls it up into
 * secondary-sales and stock-on-hand reports — the downstream half of the
 * primary (company-&gt;stockist) sales the rest of the system already records.
 */
@Service
@RequiredArgsConstructor
public class StockistSalesService {

    private final StockistSalesStatementRepository statementRepository;
    private final StockistSalesLineRepository lineRepository;
    private final ContactRepository contactRepository;

    /** One product line as submitted by the caller. */
    public record LineInput(UUID itemId, String productName,
                            BigDecimal openingQty, BigDecimal purchaseQty,
                            BigDecimal salesQty, BigDecimal returnQty,
                            BigDecimal salesValue) {}

    /**
     * Create or replace (DRAFT only) a stockist's statement for a month. Lines
     * are replaced wholesale; closing qty is derived per line as
     * opening + purchase - sales - return.
     */
    @Transactional
    public Map<String, Object> saveStatement(UUID stockistContactId, LocalDate periodMonth,
                                             String notes, List<LineInput> lines) {
        UUID orgId = TenantContext.getCurrentOrgId();
        contactRepository.findByIdAndOrgIdAndIsDeletedFalse(stockistContactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", stockistContactId));
        LocalDate month = periodMonth.withDayOfMonth(1);

        StockistSalesStatement stmt = statementRepository
                .findByOrgIdAndStockistContactIdAndPeriodMonthAndIsDeletedFalse(orgId, stockistContactId, month)
                .orElseGet(() -> StockistSalesStatement.builder()
                        .orgId(orgId).stockistContactId(stockistContactId).periodMonth(month)
                        .createdBy(TenantContext.getCurrentUserId())
                        .build());

        if (!"DRAFT".equals(stmt.getStatus())) {
            throw new BusinessException(
                    "Only a DRAFT statement can be edited (current: " + stmt.getStatus() + ")",
                    "SSS_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }
        stmt.setNotes(notes);
        stmt = statementRepository.save(stmt);

        lineRepository.deleteByOrgIdAndStatementId(orgId, stmt.getId());
        List<StockistSalesLine> saved = new ArrayList<>();
        for (LineInput in : lines != null ? lines : List.<LineInput>of()) {
            if (in.productName() == null || in.productName().isBlank()) {
                throw new BusinessException("Each line needs a product name",
                        "SSS_LINE_NO_PRODUCT", HttpStatus.BAD_REQUEST);
            }
            BigDecimal opening = nz(in.openingQty());
            BigDecimal purchase = nz(in.purchaseQty());
            BigDecimal sales = nz(in.salesQty());
            BigDecimal ret = nz(in.returnQty());
            BigDecimal closing = opening.add(purchase).subtract(sales).subtract(ret);
            saved.add(lineRepository.save(StockistSalesLine.builder()
                    .orgId(orgId).statementId(stmt.getId())
                    .itemId(in.itemId()).productName(in.productName().trim())
                    .openingQty(opening).purchaseQty(purchase)
                    .salesQty(sales).returnQty(ret).closingQty(closing)
                    .salesValue(nz(in.salesValue()))
                    .build()));
        }
        return view(stmt, saved);
    }

    @Transactional
    public StockistSalesStatement submit(UUID statementId) {
        StockistSalesStatement stmt = load(statementId);
        if (!"DRAFT".equals(stmt.getStatus())) {
            throw new BusinessException("Only a DRAFT statement can be submitted",
                    "SSS_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }
        stmt.setStatus("SUBMITTED");
        return statementRepository.save(stmt);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getStatement(UUID statementId) {
        StockistSalesStatement stmt = load(statementId);
        return view(stmt, lineRepository.findByOrgIdAndStatementIdAndIsDeletedFalseOrderByProductNameAsc(
                stmt.getOrgId(), stmt.getId()));
    }

    @Transactional(readOnly = true)
    public List<StockistSalesStatement> listByStockist(UUID stockistContactId) {
        return statementRepository.findByOrgIdAndStockistContactIdAndIsDeletedFalseOrderByPeriodMonthDesc(
                TenantContext.getCurrentOrgId(), stockistContactId);
    }

    @Transactional(readOnly = true)
    public List<StockistSalesStatement> listByPeriod(LocalDate periodMonth) {
        return statementRepository.findByOrgIdAndPeriodMonthAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), periodMonth.withDayOfMonth(1));
    }

    /** Secondary sales by product across all statements whose month is in range. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> secondarySalesReport(LocalDate from, LocalDate to) {
        Map<String, BigDecimal[]> byProduct = new LinkedHashMap<>();   // [salesQty, returnQty, salesValue]
        for (StockistSalesLine line : linesInRange(from, to)) {
            String key = line.getProductName();
            BigDecimal[] acc = byProduct.computeIfAbsent(key,
                    k -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
            acc[0] = acc[0].add(nz(line.getSalesQty()));
            acc[1] = acc[1].add(nz(line.getReturnQty()));
            acc[2] = acc[2].add(nz(line.getSalesValue()));
        }
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<String, BigDecimal[]> e : byProduct.entrySet()) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("productName", e.getKey());
            row.put("salesQty", e.getValue()[0]);
            row.put("returnQty", e.getValue()[1]);
            row.put("netSalesQty", e.getValue()[0].subtract(e.getValue()[1]));
            row.put("salesValue", e.getValue()[2]);
            rows.add(row);
        }
        rows.sort(Comparator.comparing(r -> ((BigDecimal) r.get("salesValue")).negate()));
        return rows;
    }

    /** Closing stock lying at stockists for a month, by product. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> stockOnHand(LocalDate periodMonth) {
        LocalDate month = periodMonth.withDayOfMonth(1);
        Map<String, BigDecimal> byProduct = new LinkedHashMap<>();
        for (StockistSalesLine line : linesInRange(month, month)) {
            byProduct.merge(line.getProductName(), nz(line.getClosingQty()), BigDecimal::add);
        }
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<String, BigDecimal> e : byProduct.entrySet()) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("productName", e.getKey());
            row.put("closingQty", e.getValue());
            rows.add(row);
        }
        rows.sort(Comparator.comparing(r -> ((BigDecimal) r.get("closingQty")).negate()));
        return rows;
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private List<StockistSalesLine> linesInRange(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<StockistSalesStatement> stmts = statementRepository
                .findByOrgIdAndPeriodMonthBetweenAndIsDeletedFalse(
                        orgId, from.withDayOfMonth(1), to.withDayOfMonth(1));
        if (stmts.isEmpty()) return List.of();
        List<UUID> ids = stmts.stream().map(StockistSalesStatement::getId).toList();
        return lineRepository.findByOrgIdAndStatementIdInAndIsDeletedFalse(orgId, ids);
    }

    private StockistSalesStatement load(UUID id) {
        return statementRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("StockistSalesStatement", id));
    }

    private Map<String, Object> view(StockistSalesStatement stmt, List<StockistSalesLine> lines) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("statement", stmt);
        out.put("lines", lines);
        return out;
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
