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
Vitamin C (supplement, HSN 2106 @ **18%** GST) per the README standard-data
table, each with opening stock.

**Expected result:** All four items exist with correct HSN/GST/price and opening
on-hand. The non-batch Thermometer books opening stock **without** a batch.
Vitamin C's HSN 2106 auto-fills 18% (matches the seed — see TC-INV-003).

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

**Expected result:** Rejected with "Item with SKU PARA500 already exists" —
**`INV_DUPLICATE_SKU`**, HTTP **409**. The same guard fires on rename/update.
(Auto-suffixing exists only in the POS catalog quick-add SKU generator, never on
the item form.) No silent overwrite of the first item.

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

### TC-INV-012 — UoM conversion (price, not quantity)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | item form · **Role:** OWNER |
| **Preconditions** | An item with base + purchase UoM (e.g. Strip / Box of 10, ₹80/box) |

**Expected result:** The purchase-UoM conversion factor converts **PRICE, not
quantity** — an item with purchase UoM "Box of 10" @ ₹80/box gets
`purchasePrice = ₹8/strip`. **GRN and sale quantities must be entered in the
item's base unit** (a GRN qty of 10 means 10 strips → on-hand +10; entering "1
box" as qty 1 books 1 strip). Quantity auto-conversion on GRN/sale is not
implemented — treat it as a feature gap, not a test expectation.

**Actual / Status / Notes:**

---

### TC-INV-013 — Composite (BOM) item — no own stock, components deduct
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/items` (composite) · **Role:** OWNER |
| **Preconditions** | A composite item with a BOM of 2+ components that have stock |

**Expected result**
- Creating a composite **with opening stock is rejected** —
  **`INV_COMPOSITE_OPENING_NOT_ALLOWED`** (composites never hold own stock).
- Selling the composite (invoice/POS) **deducts each BOM child's stock** by
  ratio × qty and records **no movement for the parent**.
- The parent shows no on-hand of its own. (A displayed "min-buildable" quantity
  is **not implemented** — don't test for it.)

**Actual / Status / Notes:**

---

## C. Batches & expiry

### TC-INV-020 — Two batches, FEFO consumption
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/pos` or a **direct** invoice (`/invoices`) · **Role:** OPERATOR |
| **Preconditions** | Paracetamol with Batch-A (expiry 2026-12) qty 100 and Batch-B (expiry 2027-06) qty 100 |

**Steps:** Sell 120 units via POS or a direct sales invoice, **leaving the batch
unselected** (auto-pick).

**Expected result**
- **FEFO auto-pick** consumes Batch-A first (100), then Batch-B (20) — **two**
  SALE movements. Batch-A → 0, Batch-B → 80. Never consumes the later-expiry
  batch while an earlier one has stock. Selling more than both batches hold →
  **`INV_INSUFFICIENT_BATCH_STOCK`** (409).
- **DC path is different:** delivery-challan dispatch does **NOT** auto-FEFO —
  the operator picks the batch **per line** (two lines: 100 from A + 20 from B);
  a single over-sized line against one batch fails with `DC_INSUFFICIENT_STOCK`.

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
| **Route** | `/inventory/transfer-orders` · **Role:** OWNER/ADMIN/ACCOUNTANT (cancel excludes OPERATOR) |

**Expected result:** Cancelling an **IN_TRANSIT** (shipped-but-not-received)
transfer reverses the TRANSFER_OUT legs so the source warehouse returns to its
pre-transfer balance (REVERSAL rows, original cost carried). Cancelling a
**RECEIVED** transfer is **blocked** with **`TO_ALREADY_RECEIVED`** (400) — a
correcting counter-transfer is required. Cancelling a DRAFT is a stock no-op.

**Actual / Status / Notes:**

---

## E. Stock counts (physical count)

### TC-INV-040 — Stock count with a positive variance
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/inventory/stock-counts` · **Role:** OPERATOR creates/counts; **OWNER/ADMIN/ACCOUNTANT posts** |
| **Preconditions** | Paracetamol system on-hand = 200 |

**Steps:** New count (OPERATOR may create + enter quantities) → enter **counted =
205** → post as OWNER/ADMIN/ACCOUNTANT.

**Expected result:** A **+5 variance** movement of type **STOCK_COUNT** is
recorded; on-hand → 205. The count document shows system vs counted vs variance
per line. **Role sub-check:** an OPERATOR attempting the **post** gets **403**
(post/cancel are OWNER/ADMIN/ACCOUNTANT only).

**Actual / Status / Notes:**

---

### TC-INV-041 — Stock count with a negative variance
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/inventory/stock-counts` · **Role:** OWNER/ADMIN/ACCOUNTANT (post step) |

**Steps:** Counted = 195 (system 205) → post.

**Expected result:** A **−10 variance** movement (type **STOCK_COUNT**); on-hand
→ 195. Ledger shows a new row (append-only; the prior rows are untouched).

**Actual / Status / Notes:**

---

### TC-INV-042 — Cancel a draft stock count
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/inventory/stock-counts` · **Role:** OWNER |

**Expected result:** Cancelling a **draft** (unposted) count records no movement;
stock unchanged. A posted count cannot be silently edited — a correcting count is
required. (Cancel is also OWNER/ADMIN/ACCOUNTANT only.)

**Actual / Status / Notes:**

---

## F. Picklists & serial numbers

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

### TC-INV-051 — Serial-number tracking (receive → sell → return)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/inventory/serial-numbers` (API `/api/v1/serial-numbers`) · **Role:** OWNER/OPERATOR |
| **Preconditions** | A serial-tracked item (e.g. Digital Thermometer with serial tracking on) |

**Steps:** Receive units with serials `SN-001`…`SN-003` → sell `SN-002` → view
the serial list → process a return/damage on one serial.

**Expected result:** Each serial exists in stock **exactly once**; selling a
serial marks it sold (it can't be sold twice); the return/damage transition
updates its status. The serial screen shows the current status per serial.
Record any deviation — this flow has fewer guards than batches.

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

**Expected result:** Average cost on the **stock summary** = (800+1000)/200 =
**₹9.00**; remaining 80 valued at **₹720** (the summary's Value column).
**COGS is different:** the WA path books COGS at the item's current
`purchasePrice`, which the GRN sets to the **latest** receipt cost (₹10) — so
selling 120 posts COGS = 120 × 10 = **₹1,200**, *not* 120 × 9. This asymmetry
(valuation at moving average, COGS at last purchase price) is the implemented
behaviour — don't fail the case when COGS ≠ average. (Compare with the FIFO
numbers in TC-INV-060 — all three figures differ.)

**Actual / Status / Notes:**

---

### TC-INV-062 — Provisional COGS true-up at GRN (bill-freely start)
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | POS + GRN · **Role:** OWNER |
| **Preconditions** | A brand-new item with **no purchase price**, sold via POS bill-freely |

**Steps:** Sell 2 units at POS before any purchase (MRP ₹100; default provisional
margin 25% → provisional cost ₹75/unit) → later receive 10 via a GRN at actual
cost ₹80.

**Expected result**
- The sale journal shows **DR COGS ₹150 / CR Stock-Out Suspense (2042) ₹150**
  (not CR Inventory 1200 — that leg is only for items with a real purchase
  price); the SALE movements are flagged `cost_provisional`.
- At GRN, exactly **one** correction journal (source `GRN_RECONCILE`) posts:
  **DR 2042 ₹150 / CR Inventory (1200) ₹160 / DR COGS ₹10** (variance: actual 80
  > provisional 75, × 2 units); the provisional movements get `cost_settled_at`
  stamped.
- A **second** GRN posts no further correction (idempotent — nothing pending).
- P&L reads correctly afterwards; balance sheet matches physical stock.

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
value for FIFO orgs). The movement ledger shows every row for an item
chronologically with the **real movement types**: `OPENING / PURCHASE / SALE /
TRANSFER_OUT / TRANSFER_IN / STOCK_COUNT / ADJUSTMENT / REVERSAL` — note that
**stock-count variances post as `STOCK_COUNT`** (not ADJUSTMENT) and transfers
appear as the OUT/IN pair. An **append-only** trail: reverses appear as REVERSAL
rows flagged `is_reversal`, never edits.

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
| F Picklists & serials | 2 | | | |
| G Valuation | 3 | | | |
| H Low-stock/reports | 3 | | | |
| **Total** | **29** | | | |
