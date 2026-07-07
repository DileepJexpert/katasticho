# 03 — Inventory — Manual Test Cases

Covers item masters and every stock movement path:
**Items + opening stock → batches/expiry → warehouses → stock counts →
transfer orders → picklists → valuation (FIFO / weighted-average) → low-stock.**

> Read [`README.md`](README.md) first. **Run this module's `-001` cases before
> Sales and Purchase** — everything downstream needs sellable/purchasable items.

**Key business rules exercised here**
- `stock_movement` is an **append-only ledger**; corrections are **reverse**
  entries, never edit/delete.
- `stock_balance` is a **derived cache** rebuildable from the ledger.
- Composite (BOM) item stock = **derived** from min-buildable of components; a
  composite never gets its own stock movement.
- Valuation follows org setting `inventory.valuation_method` — **FIFO** (default)
  or **WEIGHTED_AVERAGE**.
- Batch consumption is **FEFO** (earliest expiry first).

---

## A. Item master + opening stock

### TC-INV-001 — Create a stock item with opening stock (happy path)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/items` · **Role:** OWNER |

**Test data**
| Field | Value |
|-------|-------|
| Name | Paracetamol 500mg Strip |
| SKU | PARA500 |
| HSN | 3004 |
| GST % | 5 |
| Track batches | Yes |
| Purchase price | 8.00 |
| Sale price (MRP) | 15.00 |
| Reorder level | 50 |
| Opening stock | 200 (batch B-OPEN, expiry 2027-12-31, warehouse Main) |

**Steps:** Items → New → fill fields → set opening stock → save.

**Expected result**
- Item saves; appears in the item list.
- **On-hand = 200** immediately (an OPENING stock movement is recorded).
- For a batch item, a batch balance of 200 exists with the entered expiry.

**Actual / Status / Notes:**

---

### TC-INV-002 — Create the rest of the standard items
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/items` · **Role:** OWNER |

**Test data:** create Cough Syrup 100ml, Digital Thermometer (non-batch),
Vitamin C (12% GST) per the README standard-data table, each with opening stock.

**Expected result:** All four items exist with correct HSN/GST/price and opening
on-hand. The non-batch Thermometer books opening stock **without** a batch.

**Actual / Status / Notes:**

---

### TC-INV-003 — HSN → GST auto-fill (pharma)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/items` · **Role:** OWNER |

**Steps:** In the item form, search HSN `3004` via the HSN widget and select it.

**Expected result:** GST % auto-fills to **5%** from the HSN master; a rate chip
shows. Selecting `2106` (supplements) fills **18%**.

**Actual / Status / Notes:**

---

### TC-INV-004 — SKU uniqueness
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/items` · **Role:** OWNER |

**Steps:** Create a second item with SKU `PARA500`.

**Expected result:** Duplicate SKU rejected with a clear message (or auto-suffixed
— record which). No silent overwrite of the first item.

**Actual / Status / Notes:**

---

### TC-INV-005 — Negative / zero price validation
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/items` · **Role:** OWNER |

**Steps:** Enter sale price `-5` (or an obviously invalid value) → save.

**Expected result:** Rejected with a validation message. Zero price may be allowed
(free sample) — record the behaviour.

**Actual / Status / Notes:**

---

### TC-INV-006 — Barcode lookup
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/items` / POS · **Role:** OPERATOR |
| **Preconditions** | An item with a barcode set |

**Expected result:** Looking up by barcode (`GET /api/v1/items/by-barcode/{barcode}`)
returns the exact item. Unknown barcode returns not-found, not a crash.

**Actual / Status / Notes:**

---

### TC-INV-007 — VIEWER cannot edit an item
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/items` · **Role:** VIEWER |

**Expected result:** Edit/Save blocked (**403** / hidden). Read is allowed.

**Actual / Status / Notes:**

---

## B. Item groups, UoM, price lists, BOM

### TC-INV-010 — Create an item group
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/item-groups` · **Role:** OWNER |

**Expected result:** Group saves; items can be assigned to it; list filters by group.

**Actual / Status / Notes:**

---

### TC-INV-011 — Price list resolution
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/price-lists` · **Role:** OWNER |
| **Preconditions** | A price list with a special rate for Paracetamol |

**Expected result:** When a customer/SO on that price list orders Paracetamol, the
**price-list rate** is resolved (not the default MRP). Removing the price list
reverts to MRP.

**Actual / Status / Notes:**

---

### TC-INV-012 — UoM conversion
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | item form · **Role:** OWNER |
| **Preconditions** | An item with base + purchase UoM (e.g. Strip / Box of 10) |

**Expected result:** Buying in "Box of 10" adds the right base-unit qty to stock
(1 box → 10 strips). Conversion factor is honoured on GRN and sale.

**Actual / Status / Notes:**

---

### TC-INV-013 — Composite (BOM) item stock is derived
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/items` (composite) · **Role:** OWNER |
| **Preconditions** | A composite item with a BOM of 2+ components that have stock |

**Expected result:** The composite's available qty = **min buildable** across
components (e.g. component A=100, B=40, ratio 1:1 → buildable 40). The composite
**never** has its own stock movement; changing a component's stock changes the
derived buildable count.

**Actual / Status / Notes:**

---

## C. Batches & expiry

### TC-INV-020 — Two batches, FEFO consumption
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/items` + `/delivery-challans` · **Role:** OPERATOR |
| **Preconditions** | Paracetamol with Batch-A (expiry 2026-06) qty 100 and Batch-B (expiry 2027-06) qty 100 |

**Steps:** Sell/dispatch 120 units.

**Expected result:** **FEFO** consumes Batch-A first (100), then Batch-B (20).
Batch-A → 0, Batch-B → 80. Never consumes the later-expiry batch while an earlier
one has stock.

**Actual / Status / Notes:**

---

### TC-INV-021 — Near-expiry alert
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/inventory/near-expiry` · **Role:** OWNER |
| **Preconditions** | A batch within the near-expiry threshold |

**Expected result:** The batch shows on the near-expiry screen; adjusting the days
threshold changes what's listed; batches can be selected to draft a supplier
return.

**Actual / Status / Notes:**

---

### TC-INV-022 — Cannot sell from a non-existent batch (strict path)
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/delivery-challans` · **Role:** OPERATOR |

**Expected result:** Dispatching a batch-tracked item from a batch with **no
balance** is blocked (batch gate) even under bill-freely — POS negative-stock
only relaxes the non-batch path.

**Actual / Status / Notes:**

---

## D. Warehouses & transfers

### TC-INV-030 — Create a second warehouse
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/inventory/warehouses` · **Role:** OWNER |

**Expected result:** A second warehouse (e.g. "Branch-2") is created and selectable
on stock movements.

**Actual / Status / Notes:**

---

### TC-INV-031 — Transfer order (ship + receive)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/inventory/transfer-orders` · **Role:** OWNER/OPERATOR |
| **Preconditions** | Two warehouses; Main has 200 Paracetamol |

**Steps:** New transfer Main → Branch-2, Paracetamol × 50 → **Ship** → **Receive**.

**Expected result**
- On **ship**: Main −50 (TRANSFER_OUT).
- On **receive**: Branch-2 +50 (TRANSFER_IN).
- **Total on-hand across warehouses is unchanged** (still 200); the receive leg
  carries the ship leg's recorded cost so **total inventory value doesn't change**.

**Actual / Status / Notes:**

---

### TC-INV-032 — Transfer more than available is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/inventory/transfer-orders` · **Role:** OPERATOR |

**Steps:** Ship a transfer of 999 from a warehouse holding 150.

**Expected result:** Ship blocked (insufficient source stock). Nothing moves.

**Actual / Status / Notes:**

---

### TC-INV-033 — Cancel a transfer reverses cleanly
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/inventory/transfer-orders` · **Role:** OWNER |

**Expected result:** Cancelling a shipped-but-not-received (or received) transfer
reverses the legs so both warehouse balances return to pre-transfer values.

**Actual / Status / Notes:**

---

## E. Stock counts (physical count)

### TC-INV-040 — Stock count with a positive variance
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/inventory/stock-counts` · **Role:** OWNER/OPERATOR |
| **Preconditions** | Paracetamol system on-hand = 200 |

**Steps:** New count → enter **counted = 205** → post.

**Expected result:** A **+5 variance** adjustment movement is recorded; on-hand →
205. The count document shows system vs counted vs variance per line.

**Actual / Status / Notes:**

---

### TC-INV-041 — Stock count with a negative variance
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/inventory/stock-counts` · **Role:** OPERATOR |

**Steps:** Counted = 195 (system 205) → post.

**Expected result:** A **−10 variance** adjustment; on-hand → 195. Ledger shows a
new adjustment row (append-only; the prior rows are untouched).

**Actual / Status / Notes:**

---

### TC-INV-042 — Cancel a draft stock count
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/inventory/stock-counts` · **Role:** OWNER |

**Expected result:** Cancelling a **draft** (unposted) count records no movement;
stock unchanged. A posted count cannot be silently edited — a correcting count is
required.

**Actual / Status / Notes:**

---

## F. Picklists

### TC-INV-050 — Generate a picklist from a sales order
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/inventory/picklists` · **Role:** OPERATOR |
| **Preconditions** | A confirmed SO |

**Expected result:** A picklist generates with lines/quantities/rack locations
from the SO; lifecycle create → start → complete works; completing does **not**
itself deduct stock (dispatch does that).

**Actual / Status / Notes:**

---

## G. Valuation

### TC-INV-060 — FIFO valuation (default)
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | reports → FIFO valuation · **Role:** ACCOUNTANT |
| **Preconditions** | `inventory.valuation_method = FIFO`; two receipts at different costs |

**Test data:** Receive 100 @ ₹8, then 100 @ ₹10. Then sell 120.

**Expected result:** FIFO draws the **oldest lot first** — COGS = 100×8 + 20×10 =
**₹1,000**; remaining 80 valued at ₹10 = **₹800**. The valuation report equals
Σ(remaining_qty × lot cost).

**Actual / Status / Notes:**

---

### TC-INV-061 — Weighted-average valuation
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | Settings + reports · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | Set `inventory.valuation_method = WEIGHTED_AVERAGE`; two receipts 100@8 + 100@10 |

**Expected result:** Average cost = (800+1000)/200 = **₹9.00**; selling 120 →
COGS = 120×9 = **₹1,080**; remaining 80 valued at ₹9 = **₹720**. (Compare with the
FIFO numbers in TC-INV-060 — they should differ.)

**Actual / Status / Notes:**

---

### TC-INV-062 — Provisional COGS true-up at GRN (bill-freely start)
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | POS + GRN · **Role:** OWNER |
| **Preconditions** | A brand-new item with **no purchase price**, sold via POS bill-freely |

**Steps:** Sell the item at POS before any purchase (provisional COGS booked
against Stock-Out Suspense) → later receive it via a GRN at a real cost.

**Expected result:** At GRN, a **true-up correction journal** posts — Stock-Out
Suspense clears, COGS adjusts to the real cost, the settled movements are stamped.
P&L reads correctly afterwards; balance sheet matches physical stock.

**Actual / Status / Notes:**

---

## H. Low-stock & reports

### TC-INV-070 — Low-stock alert list
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | reports → low-stock · **Role:** OWNER |
| **Preconditions** | Drive Paracetamol below its reorder level (50) by selling |

**Expected result:** Paracetamol appears in the low-stock report with the deficit
(reorder − on-hand) and cost. Restocking removes it from the list.

**Actual / Status / Notes:**

---

### TC-INV-071 — Stock summary & movement ledger
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | reports → stock summary / item movements · **Role:** ACCOUNTANT |

**Expected result:** Stock summary lists each item's on-hand + value (FIFO lot
value for FIFO orgs). The movement ledger shows every OPENING/PURCHASE/SALE/
TRANSFER/ADJUSTMENT row for an item, chronologically — an **append-only** trail
(reverses appear as new rows, never edits).

**Actual / Status / Notes:**

---

### TC-INV-072 — Rebuild balance from ledger (integrity)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | reports · **Role:** OWNER |

**Expected result:** For any item, **on-hand = Σ signed movements** in the ledger.
Sum the movement rows by hand and confirm they equal the displayed on-hand — the
balance cache never drifts from the ledger.

**Actual / Status / Notes:**

---

### Result summary (fill in)

| Section | Cases | Pass | Fail | Blocked |
|---------|-------|------|------|---------|
| A Item master | 7 | | | |
| B Groups/UoM/BOM | 4 | | | |
| C Batches/expiry | 3 | | | |
| D Warehouses/transfers | 4 | | | |
| E Stock counts | 3 | | | |
| F Picklists | 1 | | | |
| G Valuation | 3 | | | |
| H Low-stock/reports | 3 | | | |
| **Total** | **28** | | | |
