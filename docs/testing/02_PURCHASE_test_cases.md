# 02 — Purchase — Manual Test Cases

Covers the full procure-to-pay chain:
**Vendors → Purchase Orders → Goods Receipt (GRN) → Vendor Bills → 3-way match →
Vendor Payments → Vendor Credits.**

> Read [`README.md`](README.md) first. Run Inventory `-001` (items) before this.

**Key business rules exercised here**
- PO does **not** post stock. **GRN "Receive Stock" is the only stock-posting step.**
- GRN posts **no accounting journal** (stock only); the **vendor bill** posts AP + inventory.
- With the full P2P loop (PO→GRN→Bill), the bill must **not** double-count stock
  that the GRN already booked.
- **3-way match** (PO ↔ GRN ↔ Bill) flags QTY_OVER / PRICE_HIKE variances.
- Landed cost (freight/duty) is apportioned into per-unit cost at GRN.
- TDS auto-deducts on vendor bills when the vendor master enables it.

---

## A. Vendor master

### TC-PUR-001 — Create a vendor (happy path)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/contacts` · **Role:** OWNER |

**Test data**
| Field | Value |
|-------|-------|
| Type | Vendor |
| Display name | MediSupply Distributors |
| GSTIN | 27PQRSX4321L1Z9 |
| State | (auto from GSTIN) |
| Payment terms | Net 30 |

**Steps:** Contacts → New → Type = Vendor → enter data → save.

**Expected result:** Vendor saves; state auto-resolves to **Maharashtra (27)**;
appears in the vendor list; outstanding payable = ₹0.

**Actual / Status / Notes:**

---

### TC-PUR-002 — Vendor in another state (inter-state ITC)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/contacts` · **Role:** OWNER |

**Test data:** National Pharma Co · GSTIN `24PQRSX1111L1Z2` (Gujarat/24).

**Expected result:** State = Gujarat (24). Bills from this vendor will show
**IGST** input credit (inter-state), not CGST+SGST.

**Actual / Status / Notes:**

---

### TC-PUR-003 — Vendor with TDS enabled
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/contacts` · **Role:** OWNER |

**Test data:** vendor "Contract Labour Co" · TDS applicable = Yes · section 194C
· PAN filled.

**Expected result:** Vendor saves with TDS flag/section. Later bills for this
vendor will auto-deduct TDS (TC-PUR-024).

**Actual / Status / Notes:**

---

### TC-PUR-004 — MSME-registered vendor flag
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/contacts` · **Role:** OWNER |

**Test data:** vendor with **MSME registered = Yes** + registration no.

**Expected result:** Saved; this vendor's dues feed the **MSME Form 1** 45-day
report later. (India-only.)

**Actual / Status / Notes:**

---

## B. Purchase Orders

### TC-PUR-010 — Create a purchase order
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/purchase-orders` · **Role:** OWNER/OPERATOR |
| **Preconditions** | TC-PUR-001; items exist |

**Test data**
| Line | Item | Qty | Rate |
|------|------|-----|------|
| 1 | Paracetamol 500mg Strip | 500 | 8.00 |
| 2 | Cough Syrup 100ml | 100 | 45.00 |

**Steps:** New PO → vendor MediSupply → add lines → save.

**Expected result**
- PO saves; total = 500×8 + 100×45 = ₹4,000 + ₹4,500 = **₹8,500** + 5% GST ₹425 =
  **₹8,925.00**.
- **No stock movement, no journal** — a PO is an intent to buy.

**Actual / Status / Notes:**

---

### TC-PUR-011 — Cannot save a PO with no lines
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/purchase-orders` · **Role:** OWNER |

**Expected result:** Empty PO rejected with a validation message.

**Actual / Status / Notes:**

---

### TC-PUR-012 — PO → draft GRN (create receipt from PO)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/purchase-orders` → `/stock-receipts` · **Role:** OWNER/OPERATOR |
| **Preconditions** | TC-PUR-010 |

**Steps:** Open the PO → **Create GRN** (Create Goods Receipt).

**Expected result:** A **DRAFT** GRN is created with one line per PO line; qty =
ordered − already-received (so 500 & 100 here). The GRN links back to the PO
(FKs). **Still no stock change** (draft).

**Actual / Status / Notes:**

---

### TC-PUR-013 — PO → draft Bill (create bill from PO)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/purchase-orders` → `/bills` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | TC-PUR-010; a **vendor contact** matching the PO supplier name exists |

**Steps:** Open the PO → **Create Bill**.

**Expected result:** A DRAFT bill drafts with the PO's lines/prices, dated today,
linked to the PO. If no matching vendor contact exists it fails with
**`PO_NO_VENDOR_CONTACT`**.

**Actual / Status / Notes:**

---

### TC-PUR-014 — Create-GRN on a fully-received PO is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/purchase-orders` · **Role:** OWNER |
| **Preconditions** | A PO already fully received via GRN |

**Expected result:** **`PO_FULLY_RECEIVED`** — nothing remains to receive.
A **cancelled** PO → `PO_CANCELLED`; an empty PO → `PO_EMPTY`.

**Actual / Status / Notes:**

---

## C. Goods Receipt (GRN) — the stock-posting step

### TC-PUR-020 — Receive stock (GRN → Receive)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/stock-receipts` · **Role:** OWNER/OPERATOR |
| **Preconditions** | TC-PUR-012 (draft GRN) |

**Test data** (per line, capture on receive)
| Item | Qty | Batch | Expiry | Rack | Cost |
|------|-----|-------|--------|------|------|
| Paracetamol | 500 | B-PARA-01 | 2027-12-31 | R-A1 | 8.00 |
| Cough Syrup | 100 | B-CGH-01 | 2027-06-30 | R-A2 | 45.00 |

**Steps:** Open the DRAFT GRN → enter batch/expiry/rack/cost per line → **Receive Stock**.

**Expected result**
- GRN → RECEIVED.
- **Stock rises**: Paracetamol +500, Cough Syrup +100 (a PURCHASE movement per line).
- Batch balances created with the entered expiry.
- Item **purchase price updated** to the received cost.
- **No accounting journal** at GRN (stock only).
- The source **PO line `receivedQuantity` increments** (partial-receipt tracking).

**Actual / Status / Notes:**

---

### TC-PUR-021 — Partial receipt then second GRN
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/stock-receipts` · **Role:** OPERATOR |
| **Preconditions** | A PO for 500; first GRN receives 300 |

**Steps:** Receive 300 now. Create a second GRN from the same PO.

**Expected result:** Second GRN's remaining qty = **200** (500 ordered − 300
received). Stock rises by 300 then 200. Over-receiving beyond ordered is either
allowed-with-3-way-flag or blocked — record which.

**Actual / Status / Notes:**

---

### TC-PUR-022 — GRN with landed cost (freight/duty)
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/stock-receipts` · **Role:** OWNER |

**Test data:** GRN for Paracetamol × 500 @ 8.00 + **freight header charge ₹500**.

**Expected result:** ₹500 freight **apportioned across lines by taxable value**
and baked into per-unit landed cost → item purchase price ≈ **8.00 + (500/500) =
9.00**. Still **no journal** (GRN posts no accounting). Residual paisa lands on
the last line.

**Actual / Status / Notes:**

---

### TC-PUR-023 — Cancel a received GRN reverses stock
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/stock-receipts` · **Role:** OWNER |
| **Preconditions** | TC-PUR-020 (a RECEIVED GRN) |

**Steps:** Open the RECEIVED GRN → **Cancel**.

**Expected result:** A **reversing** stock movement is recorded (stock goes back
down by the received qty); the linked **PO line `receivedQuantity` decrements**
(clamped at zero). Movements are append-only (a reverse row, never an edit/delete).

**Actual / Status / Notes:**

---

### TC-PUR-024 — GRN for a batch item requires batch + expiry
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/stock-receipts` · **Role:** OPERATOR |

**Steps:** Try to receive a batch-tracked item **without** a batch number/expiry.

**Expected result:** Blocked with a validation message — a batch-tracked item
cannot be received into stock without a batch + expiry. Non-batch items receive
without a batch.

**Actual / Status / Notes:**

---

## D. Vendor Bills — the accounting step

### TC-PUR-030 — Post a vendor bill (AP + inventory journal)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/bills` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | TC-PUR-013 or a fresh bill for MediSupply |

**Test data:** Paracetamol × 500 @ 8.00 + Cough × 100 @ 45.00, 5% GST.

**Steps:** Open/create the bill → **Post**.

**Expected result**
- Bill posts; balance due = ₹8,500 + GST ₹425 = **₹8,925**.
- Journal: **DR Inventory ₹8,500 / DR Input GST ₹425 / CR Accounts Payable ₹8,925**.
- Vendor **outstanding payable rises** by ₹8,925.
- **If this bill is behind a PO with an active GRN, it does NOT re-post the stock
  movement** (GRN already booked it) — verify stock did **not** jump again.

**Actual / Status / Notes:**

---

### TC-PUR-031 — Direct bill (no PO/GRN) books stock
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/bills` · **Role:** ACCOUNTANT |

**Test data:** a **direct** bill (no PO behind it) for Thermometer × 10 @ 90.00.

**Expected result:** For a small-org direct bill (no GRN), the bill **is** the
inventory source → stock rises by 10 and AP + inventory journal posts. (This is
the intentional fallback for shops that skip GRNs.)

**Actual / Status / Notes:**

---

### TC-PUR-032 — Services bill (no stock)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/bills` · **Role:** ACCOUNTANT |

**Test data:** a SERVICE line (e.g. "Transport charges" ₹2,000, 18% GST) — not a
stock item.

**Expected result:** Bill posts to an **expense** account (DR Expense / DR Input
GST / CR AP); **no stock movement**.

**Actual / Status / Notes:**

---

### TC-PUR-033 — TDS auto-deduction on a bill
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/bills` · **Role:** ACCOUNTANT |
| **Preconditions** | TC-PUR-003 (TDS vendor, 194C) |

**Test data:** bill to "Contract Labour Co", base ₹1,00,000 (crosses 194C ₹1L
aggregate threshold).

**Expected result:** TDS deducts on the **base (excl GST)** at the 194C rate;
**balance due = total − TDS**; a TDS payable liability is booked. Below the
threshold, no TDS. FY is Apr–Mar.

**Actual / Status / Notes:**

---

### TC-PUR-034 — Bill into a closed period blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/bills` · **Role:** ACCOUNTANT |
| **Preconditions** | Current period closed |

**Expected result:** Posting a bill dated in a closed period is rejected; an
open-period date posts.

**Actual / Status / Notes:**

---

## E. 3-Way Match (PO ↔ GRN ↔ Bill)

> Default settings: `ap.three_way_match.required = true`, `qty_tolerance_pct = 0`,
> `price_tolerance_abs = ₹1`, `price_tolerance_pct = 0.5%`, `bypass_threshold = 0`.

### TC-PUR-040 — Clean match (all three agree)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/bills` (match panel) or `/api/v1/ap/three-way-match/{billId}` · **Role:** ACCOUNTANT |
| **Preconditions** | PO → GRN (full) → Bill with identical qty & price |

**Steps:** Create the bill from the PO after full receipt → open the match snapshot.

**Expected result:** Overall status **MATCHED**; every line MATCHED; no AI-inbox
exception. Bill posts normally.

**Actual / Status / Notes:**

---

### TC-PUR-041 — Quantity over-billed → QTY_OVER exception
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | match panel · **Role:** ACCOUNTANT |
| **Preconditions** | PO/GRN qty = 500; bill qty = 550 |

**Expected result:** Line = **QTY_OVER**; overall = **EXCEPTION**; a HIGH-priority
**AI-inbox suggestion** (`THREE_WAY_MATCH_EXCEPTION`) is raised (idempotent — no
duplicates on re-run). Because `required=true`, the exception **blocks posting**
until overridden.

**Actual / Status / Notes:**

---

### TC-PUR-042 — Price hike beyond tolerance → PRICE_HIKE
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | match panel · **Role:** ACCOUNTANT |
| **Preconditions** | PO price ₹8.00; bill unit price ₹9.00 (> ₹1 abs & > 0.5%) |

**Expected result:** Line = **PRICE_HIKE**; overall EXCEPTION; inbox suggestion.
A price within tolerance (e.g. ₹8.50) → **MATCHED**.

**Actual / Status / Notes:**

---

### TC-PUR-043 — Override an exception (OWNER/ADMIN)
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | match panel · **Role:** OWNER |
| **Preconditions** | TC-PUR-041 (an EXCEPTION bill) |

**Steps:** Override with a reason → then post.

**Expected result:** Status → **OVERRIDDEN** with `overriddenBy` + reason; the bill
can now post. A **blank reason** is rejected
(`THREE_WAY_MATCH_OVERRIDE_REASON_REQUIRED`); a **second override** is rejected
(`THREE_WAY_MATCH_ALREADY_OVERRIDDEN`). An OPERATOR/ACCOUNTANT cannot override.

**Actual / Status / Notes:**

---

### TC-PUR-044 — Direct bill below bypass threshold → BYPASSED
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | match panel · **Role:** ACCOUNTANT |
| **Preconditions** | Set `bypass_threshold` > 0; a small no-PO bill under it |

**Expected result:** Status **BYPASSED** (small direct bills skip the match). A
no-PO bill above the threshold → **NO_PO**.

**Actual / Status / Notes:**

---

## F. Vendor Payments

### TC-PUR-050 — Pay a vendor bill in full
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/vendor-payments` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | TC-PUR-030 (bill balance ₹8,925) |

**Test data:** amount 8925 · paid via Bank · allocate to the bill.

**Expected result:** Bill → **PAID**; journal **DR Accounts Payable ₹8,925 / CR
Bank ₹8,925**; vendor outstanding drops to ₹0.

**Actual / Status / Notes:**

---

### TC-PUR-051 — Partial vendor payment
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/vendor-payments` · **Role:** ACCOUNTANT |

**Test data:** pay ₹5,000 against a ₹8,925 bill.

**Expected result:** Bill → PARTIALLY_PAID, balance ₹3,925; payable drops ₹5,000.

**Actual / Status / Notes:**

---

### TC-PUR-052 — Over-payment against a bill is rejected
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/vendor-payments` · **Role:** ACCOUNTANT |

**Expected result:** Paying **more** than the bill balance is rejected/blocked
(mirror of AR over-collection). No payment posted.

**Actual / Status / Notes:**

---

### TC-PUR-053 — Payment allocated across multiple bills
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/vendor-payments` · **Role:** ACCOUNTANT |
| **Preconditions** | Two open bills for the same vendor |

**Expected result:** One payment can allocate across both bills; each bill's
balance reduces by its allocated share; total allocated = amount paid.

**Actual / Status / Notes:**

---

## G. Vendor Credits (purchase returns / debit notes)

### TC-PUR-060 — Create a vendor credit (purchase return)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/vendor-credits` · **Role:** ACCOUNTANT |
| **Preconditions** | A posted bill to credit against |

**Test data:** return Paracetamol × 50 @ 8.00 (₹400 + GST ₹20 = ₹420).

**Expected result:** Vendor credit posts; **reduces AP** (DR AP / CR Inventory,
CR Input-GST-reversal); if it removes stock, **inventory drops by 50**. Can be
applied against an open bill or refunded.

**Actual / Status / Notes:**

---

### TC-PUR-061 — Near-expiry supplier return draft (pharma)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/inventory/near-expiry` → vendor credit · **Role:** OWNER |
| **Preconditions** | A batch nearing expiry in stock |

**Expected result:** Selecting near-expiry batches drafts a supplier return
(debit note) with pre-filled lines; posting removes that batch's stock and
reduces payable.

**Actual / Status / Notes:**

---

## H. Cross-cutting / regression

### TC-PUR-070 — Full P2P loop, single stock post
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | multiple · **Role:** OWNER |

**Steps:** PO → GRN receive → Bill post → Vendor payment, end to end.

**Expected result:** **Stock rises exactly once** (at GRN, not again at bill);
AP + inventory journal posts at the **bill**; payment clears AP; 3-way match =
MATCHED; TB still balances (TC-ACC-030).

**Actual / Status / Notes:**

---

### TC-PUR-071 — Supplier-bill-first (no GRN) books stock once
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/bills` · **Role:** ACCOUNTANT |

**Steps:** PO → Bill (skip GRN entirely) → post.

**Expected result:** With no active GRN, the **bill** books the stock (single
post). Match shows **NO_GRN** but posting is allowed (NO_GRN is not a blocking
variance).

**Actual / Status / Notes:**

---

### Result summary (fill in)

| Section | Cases | Pass | Fail | Blocked |
|---------|-------|------|------|---------|
| A Vendors | 4 | | | |
| B Purchase Orders | 5 | | | |
| C GRN | 5 | | | |
| D Vendor Bills | 5 | | | |
| E 3-Way Match | 5 | | | |
| F Vendor Payments | 4 | | | |
| G Vendor Credits | 2 | | | |
| H Regression | 2 | | | |
| **Total** | **32** | | | |
