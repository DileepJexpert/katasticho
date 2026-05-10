# P0 Reports Specification (14 Core Reports)

**Status:** Specification only. Implementation roadmap below.

---

## 1. CASH FLOW STATEMENT

**Purpose:** Daily/weekly/monthly operating cash view for decisions.

**API Endpoint:**
```
GET /api/v1/financial-reports/cash-flow
  ?startDate=2026-05-01&endDate=2026-05-31&period=DAILY|WEEKLY|MONTHLY
Response: CashFlowStatement
```

**SQL Logic:**
```sql
SELECT 
  period, 
  opening_balance,
  SUM(CASE WHEN source_module='SALES' THEN base_debit ELSE 0 END) as sales_inflow,
  SUM(CASE WHEN account_code='1000' AND debit > 0 THEN base_debit ELSE 0 END) as ar_collections,
  SUM(CASE WHEN source_module='PURCHASE' THEN base_credit ELSE 0 END) as cogs_outflow,
  SUM(CASE WHEN account_code='2100' AND credit > 0 THEN base_credit ELSE 0 END) as ap_payments,
  closing_balance
FROM journal_line
WHERE org_id = ? AND created_at BETWEEN ? AND ?
GROUP BY period
ORDER BY period;
```

**DTO:**
```java
record CashFlowStatement(
  LocalDate startDate,
  LocalDate endDate,
  List<DailyFlow> flows,
  BigDecimal openingBalance,
  BigDecimal closingBalance
) {}

record DailyFlow(
  LocalDate date,
  BigDecimal salesInflow,
  BigDecimal arCollection,
  BigDecimal cogsOutflow,
  BigDecimal apPayment,
  BigDecimal netFlow
) {}
```

---

## 2. JOURNAL REGISTER

**Purpose:** Chronological log of all journal entries for audit trail.

**API Endpoint:**
```
GET /api/v1/accounting-reports/journal-register
  ?startDate=2026-05-01&endDate=2026-05-31&sourceModule=SALES|PURCHASE|POS|ALL
  &pageNo=1&pageSize=100
Response: Page<JournalRegisterLine>
```

**SQL Logic:**
```sql
SELECT 
  je.entry_number,
  je.journal_date,
  je.description,
  je.source_module,
  je.source_id,
  COUNT(*) as line_count,
  SUM(jl.base_debit) as total_debit,
  SUM(jl.base_credit) as total_credit
FROM journal_entry je
LEFT JOIN journal_line jl ON je.id = jl.journal_entry_id
WHERE je.org_id = ? AND je.journal_date BETWEEN ? AND ?
  AND (? IS NULL OR je.source_module = ?)
GROUP BY je.id, je.entry_number, je.journal_date, je.description, je.source_module, je.source_id
ORDER BY je.journal_date DESC, je.entry_number DESC;
```

**DTO:**
```java
record JournalRegisterLine(
  String entryNumber,
  LocalDate journalDate,
  String description,
  String sourceModule,
  UUID sourceId,
  int lineCount,
  BigDecimal totalDebit,
  BigDecimal totalCredit,
  List<JournalRegisterDetail> details
) {}

record JournalRegisterDetail(
  String accountCode,
  String accountName,
  BigDecimal debit,
  BigDecimal credit
) {}
```

---

## 3. SALES REGISTER (India GST)

**Purpose:** Daily/monthly itemized sales log with HSN, tax breakdown.

**API Endpoint:**
```
GET /api/v1/sales-reports/sales-register
  ?startDate=2026-05-01&endDate=2026-05-31&documentType=INVOICE|POS|ALL
Response: SalesRegisterReport
```

**SQL Logic:**
```sql
SELECT 
  CASE 
    WHEN invoice_id IS NOT NULL THEN 'INVOICE'
    WHEN receipt_id IS NOT NULL THEN 'POS'
  END as document_type,
  CASE 
    WHEN invoice_id IS NOT NULL THEN 'INV-2026-000001'
    WHEN receipt_id IS NOT NULL THEN 'SR-2026-000001'
  END as document_number,
  invoice_date OR receipt_date as document_date,
  contact_name,
  line_item_description,
  hsn_code,
  quantity,
  unit,
  unit_price,
  taxable_amount,
  cgst_amount,
  sgst_amount,
  igst_amount,
  total_amount,
  gst_rate,
  place_of_supply
FROM (
  SELECT 
    i.id as invoice_id,
    NULL as receipt_id,
    i.invoice_date,
    NULL as receipt_date,
    c.display_name as contact_name,
    il.description as line_item_description,
    il.hsn_code,
    il.quantity,
    it.name as unit,
    il.unit_price,
    il.taxable_amount,
    tli_cgst.tax_amount as cgst_amount,
    tli_sgst.tax_amount as sgst_amount,
    tli_igst.tax_amount as igst_amount,
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
  
  UNION ALL
  
  SELECT 
    NULL as invoice_id,
    sr.id as receipt_id,
    NULL as invoice_date,
    sr.receipt_date,
    c.display_name as contact_name,
    srl.description as line_item_description,
    srl.hsn_code,
    srl.quantity,
    it.name as unit,
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
  LEFT JOIN item it ON srl.item_id = it.id
  JOIN organisation org ON sr.org_id = org.id
  WHERE sr.org_id = ? AND sr.receipt_date BETWEEN ? AND ?
) combined
ORDER BY document_date, document_number;
```

**DTO:**
```java
record SalesRegisterReport(
  LocalDate startDate,
  LocalDate endDate,
  BigDecimal totalTaxable,
  BigDecimal totalCgst,
  BigDecimal totalSgst,
  BigDecimal totalIgst,
  BigDecimal grandTotal,
  List<SalesRegisterLine> lines
) {}

record SalesRegisterLine(
  String documentType,
  String documentNumber,
  LocalDate documentDate,
  String customerName,
  String itemDescription,
  String hsnCode,
  BigDecimal quantity,
  String unit,
  BigDecimal unitPrice,
  BigDecimal taxableAmount,
  BigDecimal cgstAmount,
  BigDecimal sgstAmount,
  BigDecimal igstAmount,
  BigDecimal totalAmount,
  BigDecimal gstRate,
  String placeOfSupply
) {}
```

---

## 4. PURCHASE REGISTER (India GST)

**Purpose:** Daily/monthly itemized purchases with HSN, tax breakdown.

**API Endpoint:**
```
GET /api/v1/purchase-reports/purchase-register
  ?startDate=2026-05-01&endDate=2026-05-31
Response: PurchaseRegisterReport
```

**SQL Logic:** (Similar to Sales Register but from `bill` and `bill_line` tables)

**DTO:**
```java
record PurchaseRegisterReport(
  LocalDate startDate,
  LocalDate endDate,
  BigDecimal totalTaxable,
  BigDecimal totalCgst,
  BigDecimal totalSgst,
  BigDecimal totalIgst,
  BigDecimal grandTotal,
  List<PurchaseRegisterLine> lines
) {}

record PurchaseRegisterLine(
  String billNumber,
  LocalDate billDate,
  String vendorName,
  String vendorGstin,
  String itemDescription,
  String hsnCode,
  BigDecimal quantity,
  BigDecimal unitPrice,
  BigDecimal taxableAmount,
  BigDecimal cgstAmount,
  BigDecimal sgstAmount,
  BigDecimal igstAmount,
  BigDecimal totalAmount
) {}
```

---

## 5. AR AGING REPORT (Enhanced)

**Purpose:** Who owes you money, how long overdue, drill-down to invoice level.

**API Endpoint:**
```
GET /api/v1/ar-reports/ageing?asOfDate=2026-05-31
Response: AgeingReportResponse
```

**Already Implemented:** See `ArReportService.getAgeingReport()`

**Enhancement Needed:** Add drill-down to show all unpaid invoices per customer with line items.

---

## 6. CUSTOMER STATEMENT

**Purpose:** Individual customer ledger (all invoices, payments, balance).

**API Endpoint:**
```
GET /api/v1/ar-reports/customer-statement/{customerId}
  ?startDate=2026-01-01&endDate=2026-05-31
Response: CustomerStatementReport
```

**SQL Logic:**
```sql
SELECT 
  'INVOICE' as transaction_type,
  i.invoice_number as document_number,
  i.invoice_date as transaction_date,
  i.total_amount as debit_amount,
  0 as credit_amount,
  i.balance_due as running_balance
FROM invoice i
WHERE i.contact_id = ? AND i.invoice_date BETWEEN ? AND ? AND i.status = 'SENT'

UNION ALL

SELECT 
  'PAYMENT' as transaction_type,
  p.payment_number as document_number,
  p.payment_date as transaction_date,
  0 as debit_amount,
  p.amount_applied as credit_amount,
  (SELECT COALESCE(SUM(total_amount), 0) FROM invoice 
   WHERE contact_id = ? AND invoice_date <= p.payment_date AND status = 'SENT')
  - (SELECT COALESCE(SUM(amount_applied), 0) FROM payment 
   WHERE contact_id = ? AND payment_date <= p.payment_date) as running_balance
FROM payment p
WHERE p.contact_id = ? AND p.payment_date BETWEEN ? AND ?

ORDER BY transaction_date, document_number;
```

**DTO:**
```java
record CustomerStatementReport(
  UUID customerId,
  String customerName,
  LocalDate startDate,
  LocalDate endDate,
  BigDecimal openingBalance,
  BigDecimal totalInvoices,
  BigDecimal totalPayments,
  BigDecimal closingBalance,
  List<StatementLine> lines
) {}

record StatementLine(
  String transactionType,
  String documentNumber,
  LocalDate transactionDate,
  BigDecimal debitAmount,
  BigDecimal creditAmount,
  BigDecimal runningBalance
) {}
```

---

## 7. DAILY SALES SUMMARY

**Purpose:** End-of-day summary for shop owner (total, items sold, payment modes).

**API Endpoint:**
```
GET /api/v1/pos-reports/daily-summary?date=2026-05-31
Response: DailySalesReport
```

**SQL Logic:**
```sql
SELECT 
  sr.receipt_date,
  sr.receipt_number,
  COUNT(*) as line_count,
  SUM(srl.quantity) as total_qty,
  SUM(srl.amount) as gross_amount,
  SUM(sr.cgst + sr.sgst + sr.igst) as total_tax,
  SUM(sr.total) as total_amount,
  sr.payment_mode,
  COUNT(DISTINCT sr.id) as transaction_count
FROM sales_receipt sr
JOIN sales_receipt_line srl ON sr.id = srl.receipt_id
WHERE sr.org_id = ? AND sr.receipt_date = ?
GROUP BY sr.receipt_date, sr.payment_mode
ORDER BY sr.receipt_date, sr.payment_mode;
```

**DTO:**
```java
record DailySalesReport(
  LocalDate date,
  BigDecimal totalGrossAmount,
  BigDecimal totalTax,
  BigDecimal totalNetAmount,
  List<DailySalesByMode> byPaymentMode,
  List<DailySalesByItem> topItems
) {}

record DailySalesByMode(
  String paymentMode,
  int transactionCount,
  BigDecimal totalAmount
) {}

record DailySalesByItem(
  String itemName,
  BigDecimal quantity,
  BigDecimal unitPrice,
  BigDecimal totalAmount
) {}
```

---

## 8. STOCK SUMMARY

**Purpose:** Warehouse inventory snapshot (item, qty on hand, value, status).

**API Endpoint:**
```
GET /api/v1/inventory-reports/stock-summary
Response: StockSummaryReport
```

**SQL Logic:**
```sql
SELECT 
  i.id,
  i.name,
  i.sku,
  i.unit_of_measure,
  sb.quantity_on_hand,
  i.purchase_price,
  sb.quantity_on_hand * i.purchase_price as inventory_value,
  i.reorder_level,
  CASE 
    WHEN sb.quantity_on_hand <= i.reorder_level THEN 'LOW'
    WHEN sb.quantity_on_hand = 0 THEN 'OUT_OF_STOCK'
    ELSE 'NORMAL'
  END as status,
  sb.average_cost,
  sb.last_movement_at
FROM item i
JOIN stock_balance sb ON i.id = sb.item_id AND i.org_id = sb.org_id
WHERE i.org_id = ? AND i.is_deleted = false AND i.track_inventory = true
ORDER BY status DESC, inventory_value DESC;
```

**DTO:**
```java
record StockSummaryReport(
  LocalDate asOfDate,
  BigDecimal totalInventoryValue,
  int itemCount,
  int lowStockCount,
  int outOfStockCount,
  List<StockLine> items
) {}

record StockLine(
  UUID itemId,
  String itemName,
  String sku,
  String unit,
  BigDecimal quantityOnHand,
  BigDecimal purchasePrice,
  BigDecimal inventoryValue,
  BigDecimal reorderLevel,
  String status,
  BigDecimal averageCost,
  Instant lastMovementAt
) {}
```

---

## 9. STOCK MOVEMENT REPORT

**Purpose:** Audit trail of all stock movements (purchases, sales, adjustments).

**API Endpoint:**
```
GET /api/v1/inventory-reports/stock-movements
  ?itemId=UUID&startDate=2026-05-01&endDate=2026-05-31&pageNo=1&pageSize=100
Response: Page<StockMovementLine>
```

**SQL Logic:**
```sql
SELECT 
  sm.movement_date,
  sm.movement_type,
  i.name as item_name,
  i.sku,
  sm.quantity,
  sm.unit_cost,
  sm.total_cost,
  sm.reference_type,
  sm.reference_number,
  sm.notes,
  sb.quantity_on_hand as balance_after
FROM stock_movement sm
JOIN item i ON sm.item_id = i.id
LEFT JOIN stock_balance sb ON sm.item_id = sb.item_id AND sm.warehouse_id = sb.warehouse_id
WHERE sm.org_id = ? AND sm.movement_date BETWEEN ? AND ?
  AND (? IS NULL OR sm.item_id = ?)
ORDER BY sm.movement_date DESC, sm.id DESC;
```

**DTO:**
```java
record StockMovementReport(
  LocalDate startDate,
  LocalDate endDate,
  UUID itemId,
  List<MovementLine> movements
) {}

record MovementLine(
  LocalDate movementDate,
  String movementType,
  String itemName,
  String itemSku,
  BigDecimal quantity,
  BigDecimal unitCost,
  BigDecimal totalCost,
  String referenceType,
  String referenceNumber,
  String notes,
  BigDecimal balanceAfter
) {}
```

---

## 10. LOW STOCK ALERT

**Purpose:** Items below reorder level (for purchasing).

**API Endpoint:**
```
GET /api/v1/inventory-reports/low-stock-alert
Response: LowStockAlertReport
```

**SQL Logic:**
```sql
SELECT 
  i.id,
  i.name,
  i.sku,
  sb.quantity_on_hand,
  i.reorder_level,
  i.reorder_quantity,
  i.purchase_price,
  i.supplier_id,
  vs.display_name as supplier_name,
  i.reorder_level - sb.quantity_on_hand as deficit_qty,
  (i.reorder_level - sb.quantity_on_hand) * i.purchase_price as estimated_cost
FROM item i
JOIN stock_balance sb ON i.id = sb.item_id AND i.org_id = sb.org_id
LEFT JOIN vendor_supplier vs ON i.supplier_id = vs.id
WHERE i.org_id = ? 
  AND i.is_deleted = false 
  AND i.track_inventory = true
  AND sb.quantity_on_hand < i.reorder_level
ORDER BY (i.reorder_level - sb.quantity_on_hand) DESC;
```

**DTO:**
```java
record LowStockAlertReport(
  LocalDate generatedAt,
  int itemCount,
  BigDecimal estimatedPurchaseCost,
  List<LowStockItem> items
) {}

record LowStockItem(
  UUID itemId,
  String itemName,
  String sku,
  BigDecimal currentStock,
  BigDecimal reorderLevel,
  BigDecimal reorderQuantity,
  BigDecimal deficitQty,
  UUID supplierId,
  String supplierName,
  BigDecimal estimatedCost
) {}
```

---

## 11. GSTR-1 (GST Return - Sales)

**Purpose:** India GST compliance — monthly sales summary for GSTR-1 filing.

**API Endpoint:**
```
GET /api/v1/gst-reports/gstr1?year=2026&month=5
Response: Gstr1Report
```

**Already Implemented:** See `ArReportService.generateGstr1()`

**Structure (standard Indian format):**
- B2B invoices (supply to registered dealers)
- B2C invoices (supply to consumers)
- Exports
- Exempted supplies
- Tax summary by rate (5%, 12%, 18%, 28%)

---

## 12. GSTR-3B (GST Summary Return)

**Purpose:** India GST compliance — monthly tax liability summary.

**API Endpoint:**
```
GET /api/v1/gst-reports/gstr3b?year=2026&month=5
Response: Gstr3bReport
```

**Already Implemented:** See `ArReportService.generateGstr3b()`

**Structure (standard Indian format):**
- Outward supplies (sales)
- Inward supplies (purchases)
- CGST/SGST/IGST payable
- ITC (Input Tax Credit) available
- Net tax due

---

## 13. DAY BOOK (Optional for P0, include if time permits)

**Purpose:** Chronological transaction log per day (all documents).

**API Endpoint:**
```
GET /api/v1/operational-reports/day-book?date=2026-05-31
Response: DayBookReport
```

---

## 14. VENDOR STATEMENT (Optional for P0)

**Purpose:** Individual vendor ledger (all bills, payments, balance due).

**API Endpoint:** (Similar to Customer Statement but for AP)

---

## Implementation Roadmap

### Phase 1 (Week 1-2): Core GL + Sales
- [x] Cash Flow Statement (new service)
- [x] Journal Register (new service)
- [x] Sales Register (new service)
- [x] Purchase Register (new service)
- [x] AR Aging (enhance existing)
- [x] Customer Statement (new service)

### Phase 2 (Week 3): POS + Inventory
- [ ] Daily Sales Summary (new service)
- [ ] Stock Summary (new service)
- [ ] Stock Movement (new service)
- [ ] Low Stock Alert (new service)

### Phase 3 (Week 4): GST + Polish
- [x] GSTR-1 (already exists)
- [x] GSTR-3B (already exists)
- [ ] Test all endpoints
- [ ] Add Flutter screens (dashboard, drill-down)

### Phase 4 (Future): P1 Reports
- Day Book
- Sales by Item / Customer
- Vendor Statement
- Expiry Report
- Stock Valuation

---

## Architecture

**New Service Classes to Create:**
1. `OperationalReportService` — Sales register, Purchase register, Daily summary, Stock reports
2. `ArReportService.` (extend) — Add Customer Statement, vendor statement helpers
3. `InventoryReportService` (new) — Stock summary, movement, low stock

**New Controller:**
- `OperationalReportController` — Expose all operational endpoints

**New DTOs:**
- `com.katasticho.erp.reporting.dto.*` — All response records above

**SQL Enhancements:**
- Add indexes on `invoice_date`, `bill_date`, `receipt_date`, `stock_movement_date`
- Add indexes on `org_id` + date columns for fast filtering

---

## Notes

- All amounts use **base_debit/base_credit** (multi-currency safe)
- All reports are **read-only transactional** (`@Transactional(readOnly = true)`)
- All reports include **org_id filtering** for multi-tenancy
- Date ranges are **inclusive** on both ends
- Pagination is **optional** for small reports, required for large ones (Sales/Purchase/Movement)

