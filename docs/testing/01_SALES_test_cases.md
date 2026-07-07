# 01 — Sales — Manual Test Cases

Covers the full order-to-cash chain and the POS counter:
**Customers → Estimates → Sales Orders → Delivery Challans → Invoices →
Payments/Receipts → Credit Notes**, plus **POS** (cash / UPI / bill-freely / khata).

> Read [`README.md`](README.md) first for environment setup, the standard master
> data, role users, and how to fill Actual/Status. Run the Inventory `-001` cases
> first — sales needs sellable items with stock.

**Key business rules exercised here**
- SO does **not** move stock. **DC "Dispatch" is the only stock-deduction step.**
- DC does **not** post accounting. **Invoice posting is the accounting step.**
- Invoicing from an SO/DC path must **not** deduct stock again.
- POS receipts post **Cash/Revenue**, never Accounts Receivable (except khata = credit).
- Payment cannot exceed balance due (`AR_PAYMENT_EXCEEDS_BALANCE`).
- Dispatch cannot exceed available stock (`DC_INSUFFICIENT_STOCK`).

---

## A. Customer master

### TC-SAL-001 — Create a customer (happy path)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/contacts` |
| **Role** | OWNER |
| **Preconditions** | Fresh org, logged in as OWNER |

**Test data**
| Field | Value |
|-------|-------|
| Type | Customer |
| Display name | Sharma Traders |
| GSTIN | 27ABCDE1234F1Z5 |
| State | (leave blank — expect auto-fill) |
| Credit limit | 50000 |
| Opening balance | 0 |
| Mobile | 9820011111 |

**Steps**
1. Open Contacts → **New**.
2. Set Type = Customer; enter the values above.
3. Type the GSTIN and tab out of the field.
4. Save.

**Expected result**
- Contact saves; appears in the customer list.
- **State auto-resolves to Maharashtra (27)** from the GSTIN prefix.
- Outstanding shows **₹0**.

**Actual / Status / Notes:**

---

### TC-SAL-002 — Create second customer in another state
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/contacts` · **Role:** OWNER |

**Test data:** Verma Stores · GSTIN `09ABCDE9876F1Z1` · credit limit 20000.

**Steps:** New → Customer → enter data → save.

**Expected result:** State auto-resolves to **Uttar Pradesh (09)**. This customer
will be used to verify **inter-state IGST** later.

**Actual / Status / Notes:**

---

### TC-SAL-003 — GSTIN format validation
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/contacts` · **Role:** OWNER |

**Steps:** New customer → GSTIN = `27ABC` (too short) → try to save.

**Expected result:** Save is **rejected** with a GSTIN-format message; the record
is not created. (A blank GSTIN is allowed — unregistered/B2C customer.)

**Actual / Status / Notes:**

---

### TC-SAL-004 — Customer with opening balance
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/contacts` · **Role:** OWNER |

**Test data:** name `Old Khata Cust` · opening balance `5000`.

**Expected result:** Contact saves; **outstanding = ₹5,000** immediately (opening
balance is part of AR outstanding). Verify on the contact detail / ledger.

**Actual / Status / Notes:**

---

### TC-SAL-005 — Duplicate-name handling
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/contacts` · **Role:** OWNER |

**Steps:** Create a second contact also named "Sharma Traders".

**Expected result:** Either allowed (different entity) or blocked with a clear
message — record which. No crash; the list stays readable.

**Actual / Status / Notes:**

---

### TC-SAL-006 — VIEWER cannot create a customer
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/contacts` · **Role:** VIEWER |

**Expected result:** The New/Save action is hidden or returns **403**. No contact
created. (Pass = correctly blocked.)

**Actual / Status / Notes:**

---

## B. Estimates / Quotations

### TC-SAL-010 — Create an estimate
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/estimates` · **Role:** OWNER |
| **Preconditions** | TC-SAL-001; items with stock exist |

**Test data**
| Line | Item | Qty | Rate |
|------|------|-----|------|
| 1 | Paracetamol 500mg Strip | 100 | 15.00 |
| 2 | Digital Thermometer | 5 | 180.00 |

**Steps:** New estimate → customer Sharma Traders → add both lines → save.

**Expected result**
- Estimate saves in DRAFT/OPEN.
- Subtotal = 100×15 + 5×180 = **₹2,400.00**.
- GST 5% intra-state = CGST 2.5% + SGST 2.5% = **₹120.00** total.
- Grand total = **₹2,520.00**.
- **No stock movement, no journal** (estimate is non-committal).

**Actual / Status / Notes:**

---

### TC-SAL-011 — Convert estimate → sales order
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/estimates` · **Role:** OWNER |
| **Preconditions** | TC-SAL-010 |

**Steps:** Open the estimate → **Convert to Sales Order** (or Accept).

**Expected result:** An SO is created with the same lines/amounts; estimate marked
Accepted/Converted. Still **no stock/journal** at this point.

**Actual / Status / Notes:**

---

## C. Sales Orders (credit control, schemes)

### TC-SAL-020 — Create a sales order (happy path)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/sales-orders` · **Role:** OWNER |
| **Preconditions** | TC-SAL-001; Paracetamol has ≥200 opening stock |

**Test data**
| Field | Value |
|-------|-------|
| Customer | Sharma Traders |
| Line 1 | Paracetamol 500mg Strip × 100 @ 15.00 |

**Steps:** New SO → customer → add line → save/confirm.

**Expected result**
- SO saves; status DRAFT then CONFIRMED (per your confirm step).
- Total = ₹1,500 + 5% GST ₹75 = **₹1,575.00**.
- **Stock is unchanged** — SO never deducts stock (verify item on-hand still 200).

**Actual / Status / Notes:**

---

### TC-SAL-021 — Credit-limit warning on SO
| | |
|---|---|
| **Priority / Type** | P0 / Validation |
| **Route** | `/sales-orders` · **Role:** OWNER |
| **Preconditions** | Sharma Traders credit limit = ₹50,000 |

**Test data:** SO for Sharma Traders with a line totalling **> ₹50,000**
(e.g. Digital Thermometer × 300 @ 180 = ₹54,000 + GST).

**Expected result:** On save/confirm the SO surfaces a **credit-limit warning**
(the `warnings` on the response drive a dialog). Recording whether it blocks or
just warns is the point — default behaviour is **warn, not hard-block**.

**Actual / Status / Notes:**

---

### TC-SAL-022 — Overdue-customer control on SO
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/sales-orders` · **Role:** OWNER |
| **Preconditions** | A customer with an overdue invoice (create later, revisit) |

**Expected result:** SO creation for a customer with overdue balances shows an
**overdue warning**. Verify the message names the overdue amount/days.

**Actual / Status / Notes:**

---

### TC-SAL-023 — Scheme / discount application on SO
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/sales-orders` · **Role:** OWNER |
| **Preconditions** | A percent-discount or buy-x-get-y scheme is active for the item |

**Expected result:** When the SO line qualifies, the scheme applies (percent
discount reduces the line, or a free-qty line is added for buy-x-get-y). The SO
total reflects the discount. If schemes are DISABLED for the org, nothing applies.

**Actual / Status / Notes:**

---

### TC-SAL-024 — SO with a backordered (short-stock) line
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/sales-orders` · **Role:** OWNER |

**Test data:** Order qty (e.g. 500) **greater** than on-hand (200).

**Expected result:** SO is **allowed** (SO supports backorder — it's demand, not
fulfilment). No stock error at SO stage. The shortfall shows in dispatch/pending
reports later.

**Actual / Status / Notes:**

---

### TC-SAL-025 — Rate is preserved SO → Invoice
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/sales-orders` · **Role:** OWNER |

**Steps:** On the SO, override the rate to `14.00` (below MRP). Later convert to
invoice (TC-SAL-030).

**Expected result:** The **overridden ₹14.00 rate carries through** to the DC and
invoice — it is not reset to the item's MRP.

**Actual / Status / Notes:**

---

## D. Delivery Challans (the stock-deduction step)

### TC-SAL-030 — SO → draft Delivery Challan
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/delivery-challans` · **Role:** OWNER/OPERATOR |
| **Preconditions** | TC-SAL-020 (confirmed SO) |

**Steps:** From the SO, **Create Delivery Challan** → review lines → save as DRAFT.

**Expected result:** DC created in **DRAFT**; lines copied from SO.
**Stock is still unchanged** — a draft DC does not dispatch.

**Actual / Status / Notes:**

---

### TC-SAL-031 — Dispatch the DC (stock goes down)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/delivery-challans` · **Role:** OWNER/OPERATOR |
| **Preconditions** | TC-SAL-030; Paracetamol on-hand = 200 |

**Steps:** Open the DRAFT DC → **Dispatch**. For a batch-tracked item, pick the
batch (FEFO — earliest expiry first).

**Expected result**
- DC status → DISPATCHED.
- **On-hand Paracetamol drops from 200 → 100** (a SALE/DISPATCH stock movement is
  recorded). Verify on the item's stock/movements.
- **No accounting journal yet** (DC does not post accounting).

**Actual / Status / Notes:**

---

### TC-SAL-032 — Dispatch blocked by insufficient stock
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | `/delivery-challans` · **Role:** OPERATOR |
| **Preconditions** | Item on-hand < DC qty (e.g. on-hand 100, DC line 500) |

**Steps:** Create a DC whose qty exceeds available stock → Dispatch.

**Expected result:** Dispatch is **rejected** with error **`DC_INSUFFICIENT_STOCK`**.
DC stays DRAFT; **no stock deducted**. (This is the strict-stock path — separate
from POS bill-freely.)

**Actual / Status / Notes:**

---

### TC-SAL-033 — Dispatch a batch item from a specific/expiring batch
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/delivery-challans` · **Role:** OPERATOR |
| **Preconditions** | Two Paracetamol batches with different expiry dates in stock |

**Expected result:** FEFO offers the **earliest-expiry batch first**; the chosen
batch's balance decreases by the dispatched qty; the other batch is untouched.
Attempting to dispatch more than a batch holds is blocked.

**Actual / Status / Notes:**

---

## E. Sales Invoices (the accounting step)

### TC-SAL-040 — DC → Invoice (no duplicate stock movement)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/invoices` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | TC-SAL-031 (DISPATCHED DC) |

**Steps:** From the DC (or SO), **Create Invoice** → review → **Post/Send**.

**Expected result**
- Invoice posts; status SENT/POSTED; balance due = **₹1,575.00**.
- **Stock does NOT change again** (still 100 — already deducted at dispatch).
- A journal posts: **DR Accounts Receivable ₹1,575 / CR Sales Revenue ₹1,500 /
  CR CGST ₹37.50 / CR SGST ₹37.50** (+ COGS legs: DR COGS / CR Inventory at cost).
- Customer **outstanding rises by ₹1,575**.

**Actual / Status / Notes:**

---

### TC-SAL-041 — Direct invoice (no SO/DC) deducts stock at post
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/invoices` · **Role:** OWNER/ACCOUNTANT |

**Test data:** New invoice → Verma Stores (UP/09) → Vitamin C × 10 @ 95.00.

**Expected result**
- This is a **direct** invoice (no DC behind it) → stock **is** deducted at send.
- Because customer is **inter-state (09 ≠ 27)**, tax is a single **IGST 12% =
  ₹114.00** line (not CGST+SGST). Total = ₹950 + ₹114 = **₹1,064.00**.
- Vitamin C on-hand drops by 10.

**Actual / Status / Notes:**

---

### TC-SAL-042 — Intra vs inter-state tax split is correct
| | |
|---|---|
| **Priority / Type** | P0 / Validation |
| **Route** | `/invoices` · **Role:** OWNER |

**Steps:** Create two invoices for the same item: one to Sharma (27), one to
Verma (09).

**Expected result:** Sharma invoice = **CGST + SGST** (half each); Verma invoice
= **IGST** (single line, full rate). Totals equal for equal taxable value.

**Actual / Status / Notes:**

---

### TC-SAL-043 — Line discount reduces taxable value
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/invoices` · **Role:** OWNER |

**Test data:** Paracetamol × 100 @ 15.00, line discount 10%.

**Expected result:** Taxable = 1500 − 150 = **₹1,350**; GST 5% = **₹67.50**;
total = **₹1,417.50**. Tax is on the **discounted** value, not gross.

**Actual / Status / Notes:**

---

### TC-SAL-044 — Cannot post an invoice with no lines
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/invoices` · **Role:** OWNER |

**Expected result:** Posting an empty invoice is **rejected** with a validation
message. No journal, no document number consumed for a valid doc.

**Actual / Status / Notes:**

---

### TC-SAL-045 — Invoice into a closed period is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/invoices` · **Role:** ACCOUNTANT |
| **Preconditions** | Close the current period first (see TC-ACC-050) |

**Expected result:** Posting an invoice dated in a **closed** fiscal period is
rejected. Change the date to an open period → posts fine.

**Actual / Status / Notes:**

---

### TC-SAL-046 — Invoice numbering is sequential & unique
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/invoices` · **Role:** OWNER |

**Steps:** Post three invoices back-to-back.

**Expected result:** Numbers increment with no gaps/duplicates (sequence is
serialized per org/prefix/year). Two fast consecutive posts never share a number.

**Actual / Status / Notes:**

---

## F. Payments / Customer Receipts

### TC-SAL-050 — Record a full payment against an invoice
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/customer-receipts` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | TC-SAL-040 (invoice, balance ₹1,575) |

**Test data:** amount 1575 · method Bank/UPI · allocate to that invoice.

**Expected result**
- Receipt posts; invoice balance → **₹0**, status **PAID**.
- Journal: **DR Bank ₹1,575 / CR Accounts Receivable ₹1,575**.
- Customer **outstanding drops by ₹1,575**.

**Actual / Status / Notes:**

---

### TC-SAL-051 — Partial payment
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/customer-receipts` · **Role:** ACCOUNTANT |
| **Preconditions** | An invoice with balance ₹1,064 (TC-SAL-041) |

**Test data:** amount 500.

**Expected result:** Invoice → **PARTIALLY_PAID**, balance ₹564. Outstanding drops
by ₹500.

**Actual / Status / Notes:**

---

### TC-SAL-052 — Over-collection is rejected
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | `/customer-receipts` · **Role:** ACCOUNTANT |
| **Preconditions** | Invoice balance = ₹564 |

**Test data:** amount 1000 (more than balance).

**Expected result:** Rejected with **`AR_PAYMENT_EXCEEDS_BALANCE`**. No receipt
posted; balance unchanged. (Collect exactly ≤ balance.)

**Actual / Status / Notes:**

---

### TC-SAL-053 — Void a posted payment restores the balance
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/customer-receipts` · **Role:** OWNER |
| **Preconditions** | TC-SAL-050 (a PAID invoice) |

**Steps:** Open the receipt → **Void**.

**Expected result:** The receipt journal is **reversed**; the invoice returns to
its prior balance (**₹1,575**, status back to SENT/OVERDUE); customer outstanding
increases by ₹1,575 again. No orphan/half-reversed state.

**Actual / Status / Notes:**

---

### TC-SAL-054 — Khata settlement (invoice-less outstanding)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/customer-receipts` · **Role:** OPERATOR |
| **Preconditions** | A customer with khata/outstanding but no specific invoice (see POS khata TC-SAL-072) |

**Test data:** contact with outstanding ₹100 → settle ₹40 cash.

**Expected result:** **DR Cash / CR AR ₹40**; outstanding drops 100 → 60.
Over-settling (₹999) is rejected with **`AR_KHATA_EXCEEDS_OUTSTANDING`**.

**Actual / Status / Notes:**

---

## G. Credit Notes (returns / approval)

### TC-SAL-060 — Create a credit note (sales return)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/credit-notes` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | A posted invoice to credit against |

**Test data:** credit Paracetamol × 20 @ 15.00 against the Sharma invoice.

**Expected result:** Credit note drafts with value ₹300 + GST ₹15 = **₹315**.
On approval/post it **reduces AR** (DR Sales Return/Revenue, DR tax / CR AR) and,
if it restocks, **adds 20 back to inventory**.

**Actual / Status / Notes:**

---

### TC-SAL-061 — Credit note approval workflow
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/credit-notes` · **Role:** OWNER (approver) |
| **Preconditions** | Credit-note approval workflow **active**; a submitted CN |

**Expected result:** A submitted CN sits **PENDING_APPROVAL**; a banner shows on
the detail screen; only an authorised approver can approve. **Self-approval is
blocked** if the requester = approver (`WORKFLOW_SELF_APPROVAL_FORBIDDEN`).

**Actual / Status / Notes:**

---

### TC-SAL-062 — Credit note cannot exceed the invoice value
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/credit-notes` · **Role:** ACCOUNTANT |

**Expected result:** Crediting **more** than the invoice's value/qty is blocked or
warned. Record the exact behaviour.

**Actual / Status / Notes:**

---

## H. POS (counter sales)

> POS posts **Cash/Revenue** (not AR). Default org setting
> `pos.allow_negative_stock = true` (**bill-freely** — a fresh shop can sell
> before stocking). `pos.allow_credit_sales = false` by default (khata is opt-in).

### TC-SAL-070 — POS cash sale (happy path)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/pos` · **Role:** OPERATOR |
| **Preconditions** | Items exist (with or without stock) |

**Test data:** add Paracetamol × 2, Thermometer × 1 → pay **Cash**.

**Expected result**
- Sale completes; a receipt prints/shows.
- Total = (2×15) + (1×180) = ₹210 + 5% GST ₹10.50 = **₹220.50**.
- Journal: **DR Cash / CR Sales Revenue / CR GST** — **no Accounts Receivable**.
- Stock for both items decreases by the sold qty.

**Actual / Status / Notes:**

---

### TC-SAL-071 — POS bill-freely: sell with zero/negative stock
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/pos` · **Role:** OPERATOR |
| **Preconditions** | `pos.allow_negative_stock = true` (default); item at 0 stock |

**Steps:** Search an item at 0 on-hand (or quick-add from the medicine catalog) →
increase qty past available → checkout.

**Expected result:** The sale is **not blocked**; the `+` stepper is not capped;
the cart may show a soft red "0 available" cue but checkout succeeds. Stock goes
**negative** (reconciled later via a GRN). This is the fresh-shop retail path.

**Actual / Status / Notes:**

---

### TC-SAL-072 — POS bill-freely OFF: strict stock (negative test)
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/pos` · **Role:** OWNER→ set toggle, OPERATOR→ sell |
| **Preconditions** | POS Receipt Settings → Billing → **turn OFF** "Bill freely" |

**Expected result:** With the setting off, the `+` stepper caps at available
stock and checkout is **blocked** when a line exceeds stock (`hasStockExceededItems`).
Quick-add now prompts for opening stock. (Turn it back on afterwards.)

**Actual / Status / Notes:**

---

### TC-SAL-073 — POS khata (credit) sale
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/pos` · **Role:** OWNER→enable, OPERATOR→sell |
| **Preconditions** | POS Settings → Billing → enable **"Khata (credit) sales"** (`pos.allow_credit_sales`) |

**Steps:** Add items → select a **customer** → choose **Khata** → complete
(amount received 0).

**Expected result**
- Journal: **DR Accounts Receivable / CR Revenue / CR GST** (khata is the one POS
  path that hits AR).
- Customer **outstanding rises** by the receipt total.
- Later settle via TC-SAL-054.

**Actual / Status / Notes:**

---

### TC-SAL-074 — Khata sale without a customer is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/pos` · **Role:** OPERATOR |
| **Preconditions** | Khata enabled |

**Steps:** Choose Khata **without** selecting a customer.

**Expected result:** Blocked with **`POS_CREDIT_REQUIRES_CONTACT`** — no receipt.
Selecting a **non-customer** contact (e.g. a vendor-only) fails with
**`POS_CREDIT_CONTACT_NOT_CUSTOMER`**.

**Actual / Status / Notes:**

---

### TC-SAL-075 — Khata disabled → khata button hidden/blocked
| | |
|---|---|
| **Priority / Type** | P2 / Negative |
| **Route** | `/pos` · **Role:** OPERATOR |
| **Preconditions** | `pos.allow_credit_sales = false` (default) |

**Expected result:** No Khata option; if forced via API it returns
**`POS_CREDIT_DISABLED`**. Cash/UPI still work.

**Actual / Status / Notes:**

---

### TC-SAL-076 — POS UPI payment shows QR
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/pos` · **Role:** OPERATOR |
| **Preconditions** | UPI id configured in POS Receipt Settings |

**Expected result:** Selecting UPI renders a scannable QR for the sale amount;
completing books **DR Bank / CR Revenue / CR GST**.

**Actual / Status / Notes:**

---

### TC-SAL-077 — OPERATOR does not see profit margin
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/pos` · **Role:** OPERATOR |

**Expected result:** The payment sheet shows **no margin/purchase-price** info for
OPERATOR/ACCOUNTANT (purchasePrice stripped server-side). Log in as OWNER →
margin dot + breakdown **is** visible.

**Actual / Status / Notes:**

---

### TC-SAL-078 — POS drug-interaction warning (pharma)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/pos` · **Role:** OPERATOR |
| **Preconditions** | Two cart items whose compositions interact (seeded pairs) |

**Expected result:** Before payment a **severity-coded interaction dialog** shows;
it is non-blocking (can proceed). If the check API fails, checkout is not blocked.

**Actual / Status / Notes:**

---

### TC-SAL-079 — Void a POS receipt
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/pos` (or receipts list) · **Role:** OWNER |

**Expected result:** Voiding reverses the cash/revenue journal and **restores
stock**; a khata receipt void also **removes the receivable** from outstanding.

**Actual / Status / Notes:**

---

## I. Cross-cutting / regression

### TC-SAL-090 — Second invoice on same SO doesn't double-book COGS
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/invoices` · **Role:** ACCOUNTANT |
| **Preconditions** | An SO dispatched in two partial DCs, each invoiced |

**Expected result:** Each invoice books only **its share** of COGS (prorated from
the dispatched movements). Total COGS across both invoices = cost of goods
actually dispatched — never doubled.

**Actual / Status / Notes:**

---

### TC-SAL-091 — Session/role switch mid-flow
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | any · **Role:** switch OWNER↔OPERATOR |

**Expected result:** After switching users, data is scoped correctly to the org;
role gates apply to the new user immediately; no stale data leaks from the prior
session.

**Actual / Status / Notes:**

---

### TC-SAL-092 — Full order-to-cash regression
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | multiple · **Role:** OWNER |

**Steps:** Customer → SO → DC dispatch → Invoice → Payment, end to end with fresh
numbers.

**Expected result:** Stock deducts **once** (at dispatch); accounting posts
**once** (at invoice); AR clears on payment; every document links to the next; TB
still balances afterwards (cross-check in TC-ACC-030).

**Actual / Status / Notes:**

---

### Result summary (fill in)

| Section | Cases | Pass | Fail | Blocked |
|---------|-------|------|------|---------|
| A Customers | 6 | | | |
| B Estimates | 2 | | | |
| C Sales Orders | 6 | | | |
| D Delivery Challans | 4 | | | |
| E Invoices | 7 | | | |
| F Payments | 5 | | | |
| G Credit Notes | 3 | | | |
| H POS | 10 | | | |
| I Regression | 3 | | | |
| **Total** | **46** | | | |
