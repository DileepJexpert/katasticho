package com.katasticho.erp.demo;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.BranchRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Seeds the "Sharma Medical" demo org used to validate the owner-view
 * dashboard. Writes 2 branches, 2 warehouses, 4 items, 3 invoices and
 * 2 payments via raw JDBC so we don't have to go through the full
 * InvoiceService → TaxEngine → JournalService chain just to render a
 * mock.
 *
 * Running twice in the same org is a no-op — the method detects an
 * existing "SEC62" branch and returns the already-seeded summary.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DemoSeedService {

    private final JdbcTemplate jdbcTemplate;
    private final BranchRepository branchRepository;

    @Transactional
    public DemoSeedResult seedSharmaMedical() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("No tenant context", "DEMO_NO_TENANT", HttpStatus.UNAUTHORIZED);
        }
        UUID userId = TenantContext.getCurrentUserId();

        // Idempotent: if SEC62 already exists, return existing summary.
        if (branchRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "SEC62")) {
            log.info("Demo seed skipped — SEC62 branch already exists for org {}", orgId);
            return new DemoSeedResult(true, "already seeded", 0, 0, 0);
        }

        LocalDate today = LocalDate.now();

        // ── 1. Branches ──────────────────────────────────────────────────
        // Demote any existing default branch so the first seeded one takes
        // over. Keeps the partial unique index happy.
        jdbcTemplate.update(
                "UPDATE branch SET is_default = FALSE WHERE org_id = ? AND is_default = TRUE",
                orgId);

        UUID sec62 = UUID.randomUUID();
        UUID sec18 = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO branch (id, org_id, code, name, city, state, state_code, is_default, is_active, created_by)
                VALUES (?, ?, 'SEC62', 'Sector 62 Store', 'Noida', 'Uttar Pradesh', '09', TRUE,  TRUE, ?)
                """, sec62, orgId, userId);
        jdbcTemplate.update("""
                INSERT INTO branch (id, org_id, code, name, city, state, state_code, is_default, is_active, created_by)
                VALUES (?, ?, 'SEC18', 'Sector 18 Store', 'Noida', 'Uttar Pradesh', '09', FALSE, TRUE, ?)
                """, sec18, orgId, userId);

        // ── 2. Warehouses (one per branch) ───────────────────────────────
        UUID wh62 = UUID.randomUUID();
        UUID wh18 = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO warehouse (id, org_id, branch_id, code, name, is_default, is_active, created_by)
                VALUES (?, ?, ?, 'WH-SEC62', 'Sector 62 Stockroom', TRUE,  TRUE, ?)
                """, wh62, orgId, sec62, userId);
        jdbcTemplate.update("""
                INSERT INTO warehouse (id, org_id, branch_id, code, name, is_default, is_active, created_by)
                VALUES (?, ?, ?, 'WH-SEC18', 'Sector 18 Stockroom', FALSE, TRUE, ?)
                """, wh18, orgId, sec18, userId);

        // ── 3. Items ─────────────────────────────────────────────────────
        // Reorder levels chosen so Crocin (45) and ORS (12) fall below the
        // line while Paracetamol and Vitamin D3 stay above.
        Map<String, UUID> items = new LinkedHashMap<>();
        items.put("PARA500", insertItem(orgId, userId, "PARA500", "Paracetamol 500mg",  "strips",  new BigDecimal("12.00"), new BigDecimal("20.00"), 20, 5));
        items.put("CROCIN",  insertItem(orgId, userId, "CROCIN",  "Crocin Advance",     "strips",  new BigDecimal("25.00"), new BigDecimal("40.00"), 50, 5));
        items.put("VITD3",   insertItem(orgId, userId, "VITD3",   "Vitamin D3",         "bottles", new BigDecimal("120.00"), new BigDecimal("250.00"), 10, 5));
        items.put("ORSSACH", insertItem(orgId, userId, "ORSSACH", "ORS Sachets",        "packets", new BigDecimal("8.00"),  new BigDecimal("15.00"), 20, 5));

        // ── 4. Stock balances (for low-stock widget) ─────────────────────
        //   Crocin  = 45 strips (below reorder 50) → shows in Low Stock
        //   ORS     = 12 packets (below reorder 20) → shows in Low Stock
        //   Para    = 500 strips, D3 = 80 bottles → healthy
        insertStockBalance(orgId, sec62, items.get("PARA500"), wh62, new BigDecimal("300"));
        insertStockBalance(orgId, sec62, items.get("CROCIN"),  wh62, new BigDecimal("25"));
        insertStockBalance(orgId, sec62, items.get("VITD3"),   wh62, new BigDecimal("40"));
        insertStockBalance(orgId, sec62, items.get("ORSSACH"), wh62, new BigDecimal("7"));
        insertStockBalance(orgId, sec18, items.get("PARA500"), wh18, new BigDecimal("200"));
        insertStockBalance(orgId, sec18, items.get("CROCIN"),  wh18, new BigDecimal("20"));
        insertStockBalance(orgId, sec18, items.get("VITD3"),   wh18, new BigDecimal("40"));
        insertStockBalance(orgId, sec18, items.get("ORSSACH"), wh18, new BigDecimal("5"));

        // ── 5. Contact (walk-in customer) ────────────────────────────────
        UUID contactId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO contact (id, org_id, contact_type, display_name, phone, billing_state, billing_state_code, payment_terms_days, created_by)
                VALUES (?, ?, 'CUSTOMER', 'Walk-in Customer', '9999900000', 'Uttar Pradesh', '09', 0, ?)
                """, contactId, orgId, userId);

        // ── 6. Invoices ──────────────────────────────────────────────────
        // Mock breakdown:
        //   Sector 62: Inv A ₹4,200 (Para 50 × 20 + Crocin 30 × 40 + D3 2 × 250 = 1000+1200+500=2700... adjust!)
        //
        // Easier: compose invoices directly by setting totalAmount to the
        // target mock numbers and having each line contribute to the
        // "top selling" quantities. We don't need the lines to precisely
        // sum to the header totals — this is a read-only dashboard mock.
        // Using gst_rate 0 so tax_amount=0 and total_amount=subtotal.

        // Inv A — Sector 62 — ₹4,200  — Paracetamol 50, Crocin 30
        UUID invA = createInvoice(orgId, sec62, contactId, userId, today, "INV-2026-000001", new BigDecimal("4200.00"));
        insertInvoiceLine(invA, 1, "Paracetamol 500mg", items.get("PARA500"), new BigDecimal("50"), new BigDecimal("20.00"),  new BigDecimal("1000.00"));
        insertInvoiceLine(invA, 2, "Crocin Advance",    items.get("CROCIN"),  new BigDecimal("30"), new BigDecimal("40.00"),  new BigDecimal("1200.00"));
        insertInvoiceLine(invA, 3, "Vitamin D3",        items.get("VITD3"),   new BigDecimal("8"),  new BigDecimal("250.00"), new BigDecimal("2000.00"));

        // Inv B — Sector 62 — ₹3,000  — Paracetamol 37, Crocin 13, D3 4
        UUID invB = createInvoice(orgId, sec62, contactId, userId, today, "INV-2026-000002", new BigDecimal("3000.00"));
        insertInvoiceLine(invB, 1, "Paracetamol 500mg", items.get("PARA500"), new BigDecimal("37"), new BigDecimal("20.00"),  new BigDecimal("740.00"));
        insertInvoiceLine(invB, 2, "Crocin Advance",    items.get("CROCIN"),  new BigDecimal("13"), new BigDecimal("40.00"),  new BigDecimal("520.00"));
        insertInvoiceLine(invB, 3, "Vitamin D3",        items.get("VITD3"),   new BigDecimal("4"),  new BigDecimal("250.00"), new BigDecimal("1000.00"));
        insertInvoiceLine(invB, 4, "ORS Sachets",       items.get("ORSSACH"), new BigDecimal("48"), new BigDecimal("15.00"),  new BigDecimal("740.00"));

        // Inv C — Sector 18 — ₹5,250
        UUID invC = createInvoice(orgId, sec18, contactId, userId, today, "INV-2026-000003", new BigDecimal("5250.00"));
        insertInvoiceLine(invC, 1, "Vitamin D3",        items.get("VITD3"),   new BigDecimal("15"), new BigDecimal("250.00"), new BigDecimal("3750.00"));
        insertInvoiceLine(invC, 2, "ORS Sachets",       items.get("ORSSACH"), new BigDecimal("100"),new BigDecimal("15.00"),  new BigDecimal("1500.00"));

        // ── 7. Payments (₹8,200 total collected) ────────────────────────
        // Payment against Inv A: ₹4,200 (cash) — fully paid
        createPayment(orgId, sec62, contactId, invA, userId, today, "PAY-2026-000001",
                new BigDecimal("4200.00"), "CASH");
        // Payment against Inv C: ₹4,000 partial (bank)
        createPayment(orgId, sec18, contactId, invC, userId, today, "PAY-2026-000002",
                new BigDecimal("4000.00"), "BANK_TRANSFER");

        log.info("Demo seed complete for org {} — 2 branches, 4 items, 3 invoices, 2 payments", orgId);
        return new DemoSeedResult(true, "seeded", 3, 2, 4);
    }

    private UUID insertItem(UUID orgId, UUID userId, String sku, String name, String unit,
                            BigDecimal purchasePrice, BigDecimal salePrice,
                            int reorderLevel, int gstRate) {
        UUID itemId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO item (id, org_id, sku, name, unit_of_measure,
                                  purchase_price, sale_price, gst_rate,
                                  track_inventory, reorder_level, reorder_quantity,
                                  revenue_account_code, is_active, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE, ?, 10, '4010', TRUE, ?)
                """, itemId, orgId, sku, name, unit, purchasePrice, salePrice, gstRate, reorderLevel, userId);
        return itemId;
    }

    private void insertStockBalance(UUID orgId, UUID branchId, UUID itemId, UUID warehouseId, BigDecimal qty) {
        jdbcTemplate.update("""
                INSERT INTO stock_balance (id, org_id, branch_id, item_id, warehouse_id, quantity_on_hand, average_cost)
                VALUES (?, ?, ?, ?, ?, ?, 0)
                """, UUID.randomUUID(), orgId, branchId, itemId, warehouseId, qty);
    }

    private UUID createInvoice(UUID orgId, UUID branchId, UUID contactId, UUID userId,
                               LocalDate date, String number, BigDecimal total) {
        UUID invoiceId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO invoice (id, org_id, branch_id, contact_id, invoice_number,
                                     invoice_date, due_date, status,
                                     subtotal, tax_amount, total_amount, amount_paid, balance_due,
                                     currency, exchange_rate,
                                     base_subtotal, base_tax_amount, base_total,
                                     period_year, period_month, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'SENT',
                        ?, 0, ?, 0, ?,
                        'INR', 1.000000,
                        ?, 0, ?,
                        ?, ?, ?)
                """,
                invoiceId, orgId, branchId, contactId, number,
                date, date,
                total, total, total,
                total, total,
                date.getYear(), date.getMonthValue(), userId);
        return invoiceId;
    }

    private void insertInvoiceLine(UUID invoiceId, int lineNumber, String description, UUID itemId,
                                   BigDecimal quantity, BigDecimal unitPrice, BigDecimal lineTotal) {
        jdbcTemplate.update("""
                INSERT INTO invoice_line (id, invoice_id, line_number, description, item_id,
                                          quantity, unit_price,
                                          taxable_amount, gst_rate, tax_amount, line_total,
                                          account_code,
                                          base_taxable_amount, base_tax_amount, base_line_total)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, '4010', ?, 0, ?)
                """,
                UUID.randomUUID(), invoiceId, lineNumber, description, itemId,
                quantity, unitPrice,
                lineTotal, lineTotal, lineTotal, lineTotal);
    }

    private void createPayment(UUID orgId, UUID branchId, UUID contactId, UUID invoiceId, UUID userId,
                               LocalDate date, String number, BigDecimal amount, String method) {
        jdbcTemplate.update("""
                INSERT INTO payment (id, org_id, branch_id, contact_id, invoice_id,
                                     payment_number, payment_date, amount,
                                     currency, exchange_rate, base_amount,
                                     payment_method, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'INR', 1.000000, ?, ?, ?)
                """,
                UUID.randomUUID(), orgId, branchId, contactId, invoiceId,
                number, date, amount, amount, method, userId);
    }

    /** Thin response wrapper so the controller can return a meaningful payload. */
    public record DemoSeedResult(
            boolean ok,
            String status,
            int invoiceCount,
            int paymentCount,
            int itemCount
    ) {}
}
