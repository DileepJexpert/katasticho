# KATASTICHO — COMPLETE SALES CYCLE IMPLEMENTATION (FINAL)
# Sales Orders + Delivery Challans + Mature POS
# Industry-Standard Stock Flow + All Edge Cases

> **Execute ONE DAY at a time. Never paste 2 days together.**
> **Sonnet for all except methods marked [OPUS].**

---

## STOCK DEDUCTION RULES — READ BEFORE ANYTHING

```
RULE #1: Stock deducts when goods PHYSICALLY LEAVE the warehouse.

This is how SAP (PGI), Odoo (Validate Delivery), and
Zoho (Ship Package) all work. No exceptions.

THREE SALES PATHS IN KATASTICHO:

PATH A — B2B (Sales Order → Challan → Invoice):
  ┌─────────────┬─────────────┬───────────────┐
  │ Event       │ Stock       │ Journal       │
  ├─────────────┼─────────────┼───────────────┤
  │ SO Created  │ Nothing     │ Nothing       │
  │ SO Confirmed│ RESERVED    │ Nothing       │
  │ Challan     │ DEDUCTED    │ Nothing       │
  │ dispatched  │ (PGI)       │               │
  │ Invoice     │ Nothing     │ DR AR, CR Rev │
  │ created     │ (already    │ + CR GST      │
  │             │  shipped)   │               │
  │ Payment     │ Nothing     │ DR Cash,CR AR │
  └─────────────┴─────────────┴───────────────┘

PATH B — Direct Invoice (no SO, credit sale):
  ┌─────────────┬─────────────┬───────────────┐
  │ Invoice     │ DEDUCTED    │ DR AR, CR Rev │
  │ posted      │ (no challan │ + CR GST      │
  │             │  = invoice  │               │
  │             │  IS the     │               │
  │             │  dispatch)  │               │
  │ Payment     │ Nothing     │ DR Cash,CR AR │
  └─────────────┴─────────────┴───────────────┘

PATH C — POS / Sales Receipt:
  ┌─────────────┬─────────────┬───────────────┐
  │ Receipt     │ DEDUCTED    │ DR Cash,      │
  │ created     │ + journal   │ CR Rev + GST  │
  │             │ + payment   │ (all at once) │
  └─────────────┴─────────────┴───────────────┘

RESERVATION vs DEDUCTION:
  Reserved = blocked for order, still in warehouse physically
    stock_balance.reserved_qty += qty
    available_qty = current_qty - reserved_qty
    NO stock_movement record

  Deducted = goods physically left warehouse
    inventoryService.recordMovement(type=SALE, qty=-N)
    stock_balance.current_qty -= qty
    stock_balance.reserved_qty -= qty (release reservation)
    stock_movement record with reference to challan
```

---

## COMPLETE SALES ORDER LIFECYCLE

```
┌────────────────────────────────────────────────────────────┐
│                    SALES ORDER LIFECYCLE                    │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  DRAFT ──confirm──→ CONFIRMED                              │
│    │                    │                                   │
│    │cancel              │ create challan(s)                │
│    ↓                    ↓                                   │
│  CANCELLED         PARTIALLY_SHIPPED                       │
│                         │                                   │
│                         │ all lines shipped                │
│                         ↓                                   │
│                      SHIPPED                               │
│                         │                                   │
│                         │ create invoice(s)                │
│                         ↓                                   │
│                    PARTIALLY_INVOICED                       │
│                         │                                   │
│                         │ all lines invoiced               │
│                         ↓                                   │
│                      INVOICED                              │
│                         │                                   │
│                         │ all invoices paid                │
│                         ↓                                   │
│                     COMPLETED                              │
│                                                            │
│  SEPARATE TRACKING:                                        │
│    shipped_status:  NOT_SHIPPED → PARTIALLY → FULLY        │
│    invoiced_status: NOT_INVOICED → PARTIALLY → FULLY       │
│                                                            │
│  SO status is DERIVED from these two:                      │
│    shipped=PARTIAL → SO=PARTIALLY_SHIPPED                  │
│    shipped=FULL + invoiced=NONE → SO=SHIPPED               │
│    shipped=FULL + invoiced=PARTIAL → SO=PARTIALLY_INVOICED │
│    shipped=FULL + invoiced=FULL → SO=INVOICED              │
│    invoiced=FULL + all invoices paid → SO=COMPLETED        │
│                                                            │
│  EDGE CASES:                                               │
│    Cancel before ship → release all reservations           │
│    Partial ship → ship what's available, back-order rest   │
│    Return after ship → Credit Note + restock via reversal  │
│    Invoice cancel → reverse journal, stock already shipped │
└────────────────────────────────────────────────────────────┘
```

---

## DAY 1: SALES ORDER + STOCK RESERVATION — BACKEND

### STEP 1: SCHEMA — Edit V1__initial_schema.sql

Pre-production: edit V1 directly, docker-compose down -v after.

1. Add reserved_qty to stock_balance table:
   `reserved_qty NUMERIC(12,4) NOT NULL DEFAULT 0`

2. Add sales_order, sales_order_line, stock_reservation tables with indexes.

### STEP 2: ENTITIES + REPOSITORIES

Package: com.katasticho.erp.sales

Entities:
- SalesOrder with SalesOrderStatus enum (DRAFT, CONFIRMED, PARTIALLY_SHIPPED, SHIPPED, PARTIALLY_INVOICED, INVOICED, COMPLETED, CANCELLED, VOID)
- SalesOrderLine (@OneToMany from SalesOrder)
- StockReservation with ReservationStatus enum (ACTIVE, FULFILLED, CANCELLED)

### STEP 3: SALES ORDER SERVICE

- create() [SONNET] — validate, calculate, save as DRAFT
- createFromEstimate() [SONNET] — copy from accepted estimate
- confirm() [OPUS] — stock reservation with availability check
- cancel() [SONNET] — release reservations
- convertToInvoice() [OPUS] — journal only, no stock, partial support
- updateStatusFromSubStatuses() [SONNET] — derive SO status
- update/delete — DRAFT only
- get/list — with filters

### STEP 4: Update InvoiceService.post() with skipStockMovement flag

### STEP 5: SalesOrderController — /api/v1/sales-orders (13 endpoints)

### STEP 6: Tests (13 test cases)

---

## DAY 2: DELIVERY CHALLAN — BACKEND + SO FLUTTER

### PART A: Delivery Challan Backend
- Schema: delivery_challan + delivery_challan_line tables
- Entities + Repositories
- DeliveryChallanService with dispatch() [OPUS] for PGI/stock deduction
- Controller: /api/v1/delivery-challans

### PART B: Sales Order Flutter Screens
- List with status filter chips
- Create (like invoice but with shipment fields)
- Detail with tabs: Lines, Challans, Invoices, Reservations, Activity
- ConvertToInvoiceSheet + ConvertToChallanSheet

---

## DAY 3: DELIVERY CHALLAN FLUTTER + POS MATURITY

### PART A: Delivery Challan Flutter
- List, Create, Detail screens
- Print/PDF layout

### PART B: POS Maturity
1. Mixed payment mode (Cash + UPI + Card split)
2. Hold & recall carts (Riverpod, max 5, session-only)
3. Favourite items (quick-tap grid, SharedPreferences)
4. Recent transactions (last 5, reprint/WhatsApp)
5. Barcode support (mobile_scanner)
6. Keyboard shortcuts (F1-F7, Enter, Escape)
7. Receipt template settings

### PART C: Sidebar Final Structure

---

## DAY 4: FULL E2E TEST + EDGE CASES

### PART A: Full Business Cycle Test
Single test covering: Setup → Purchase → B2B Sale (SO→Challan→Invoice→Payment) → POS Sale → Direct Invoice → Financial + Stock Verification

### PART B: Edge Case Tests
- Cannot invoice more than shipped
- Cancel releases reservations
- Cannot cancel dispatched challan
- Partial ship + partial invoice
- Direct invoice deducts stock
- SO invoice does NOT deduct stock
- Reservation prevents overselling
- Mixed payment POS

---

## MODEL SELECTION

| Day | Task | Model |
|-----|------|-------|
| 1 | Schema + Entities + Repos + Controller | Sonnet |
| 1 | confirm() + convertToInvoice() | Opus |
| 2 | Schema + Entities + Flutter | Sonnet |
| 2 | dispatch() (PGI) | Opus |
| 3 | All Flutter + receipt backend | Sonnet |
| 4 | All tests | Sonnet |
