# Katasticho ERP — Manual UAT / QA Test-Case Pack

A deep, execute-from-the-screen test-case library for manual acceptance testing.
Each module doc lists numbered use cases (happy path + validations + negative +
edge cases) with the exact data to type on-screen and the exact result to verify.
Print them, or copy the tables into a sheet, and fill the **Actual result /
Status** columns as you go.

> **Scope of this pack:** Sales, Purchase, Inventory, Accounting, HR, Payroll.
> These are the six modules the business runs on day-to-day. Field-sales, GST
> filing, manufacturing, AI inbox, and partner-network have their own flows — add
> packs for them later using the same format.

---

## 1. Modules in this pack

| # | Module | File | What it covers |
|---|--------|------|----------------|
| 01 | **Sales** | [`01_SALES_test_cases.md`](01_SALES_test_cases.md) | Contacts (customers), Estimates, Sales Orders, Delivery Challans, Invoices, Payments/Receipts, Credit Notes, POS (incl. bill-freely + khata) |
| 02 | **Purchase** | [`02_PURCHASE_test_cases.md`](02_PURCHASE_test_cases.md) | Vendors, Purchase Orders, Goods Receipt (GRN), Vendor Bills, 3-way match, Vendor Payments, Vendor Credits |
| 03 | **Inventory** | [`03_INVENTORY_test_cases.md`](03_INVENTORY_test_cases.md) | Items + opening stock, batches/expiry, warehouses, stock counts, transfer orders, picklists, valuation (FIFO/WA), low-stock |
| 04 | **Accounting** | [`04_ACCOUNTING_test_cases.md`](04_ACCOUNTING_test_cases.md) | Chart of accounts, journal entries, period close, Trial Balance, P&L, Balance Sheet, bank reconciliation, audit trail |
| 05 | **HR** | [`05_HR_test_cases.md`](05_HR_test_cases.md) | Employees + profile, leave, attendance/regularization, shifts, timesheets, help desk, documents, offboarding, analytics |
| 06 | **Payroll** | [`06_PAYROLL_test_cases.md`](06_PAYROLL_test_cases.md) | Employees (payroll), salary structure, payroll run lifecycle, PF/ESI/PT/LWF/TDS, LOP, journal posting, statutory payment |
| 07 | **Settings: Modules** | [`07_SETTINGS_MODULES_test_cases.md`](07_SETTINGS_MODULES_test_cases.md) | Per-org module visibility (`/settings/modules` Show/Hide/Default), vertical defaults, multi-org isolation, fixed QA test login |

---

## 2. Test environment setup

### 2.1 Start the stack

Backend (Spring Boot, port 8080) and the Flutter web app must both be running,
pointed at a **fresh** PostgreSQL so seed data and sequence numbers are clean.

```bash
# Backend (from repo root)
./mvnw spring-boot:run           # or your usual run task; needs Postgres + Redis

# Flutter web app (from flutter_app/)
cd flutter_app && flutter run -d chrome
```

On first boot Flyway applies the baseline migrations and the org-signup flow
seeds the chart of accounts (~64 accounts for an India TRADING org: 61 baseline
+ Stock-Out Suspense 2042 + Gratuity 2080/5130; RETAIL/SERVICES/F&B seed ~59),
reference masters (drug/HSN/GST state codes), and default settings. If the app can't reach `localhost:8080`,
check the Dio `baseUrl` in `flutter_app/lib/core/api/api_config.dart`.

### 2.2 Create the test organisation

Register a brand-new org (this becomes OWNER):

- **Screen:** the app's sign-up / register screen (or `POST /api/v1/auth/register`)
- **Body fields:** `phone`, `password`, `fullName`, `orgName`, `countryCode` (`IN`)
- Registration **auto-approves** — you can log in immediately.

Login uses **`identifier`** (phone or email) + `password` — not a field literally
called "phone". Keep the OWNER credentials handy; you'll switch users for the
role tests.

### 2.3 Seed the users you'll need for role tests

As OWNER, create one user per role you plan to test (Settings → Users, or the
org-users endpoint). Minimum recommended set:

| Login | Role | Used for |
|-------|------|----------|
| owner@test | OWNER | Full access, approvals, settings |
| admin@test | ADMIN | Same as OWNER for most flows |
| acct@test | ACCOUNTANT | Books, payments, reports (no POS admin) |
| op@test | OPERATOR | POS, delivery, field ops (restricted admin) |
| view@test | VIEWER | Read-only |

Role gates are enforced server-side (`@PreAuthorize`). A blocked action returns
**403** and the UI shows a "not permitted" style error — that is a *pass* for the
negative role test, not a bug.

---

## 3. Conventions used in every test case

### 3.1 Test-case fields

| Field | Meaning |
|-------|---------|
| **ID** | `TC-<MOD>-NNN` — stable identifier (e.g. `TC-SAL-014`). Reference it in bug reports. |
| **Priority** | **P0** = money/stock correctness or a blocker; **P1** = important validation; **P2** = edge/nice-to-have. Run P0 first. |
| **Type** | `Happy` (golden path) · `Validation` (field rules) · `Negative` (must be rejected) · `Edge` (boundary/unusual) · `Role` (permission) |
| **Route** | The Flutter screen path to open (e.g. `/invoices`). |
| **Role** | The user role to log in as for this case. |
| **Preconditions** | Data/state that must exist first (often "run TC-XXX-001 first"). |
| **Test data** | Exact values to type. Copy them verbatim so results are reproducible. |
| **Steps** | Numbered on-screen actions. |
| **Expected result** | What must be true afterwards — UI state **and** the money/stock effect. |
| **Actual / Status / Notes** | You fill these: Actual = what happened; Status = ✅ Pass / ❌ Fail / ⏭ Blocked; Notes = bug id, screenshot ref. |

### 3.2 Standard test master data

Create these once (in the module docs' `-001` cases) and reuse them everywhere.
Using the same names/values makes every downstream expected-result number exact.

**Customers**
| Name | GSTIN | State | Credit limit | Opening balance |
|------|-------|-------|--------------|-----------------|
| Sharma Traders | 27ABCDE1234F1Z5 | Maharashtra (27) | ₹50,000 | ₹0 |
| Verma Stores | 09ABCDE9876F1Z1 | Uttar Pradesh (09) | ₹20,000 | ₹0 |

**Vendors**
| Name | GSTIN | State |
|------|-------|-------|
| MediSupply Distributors | 27PQRSX4321L1Z9 | Maharashtra (27) |
| National Pharma Co | 24PQRSX1111L1Z2 | Gujarat (24) |

**Items** (org's home state = Maharashtra/27 for intra vs inter-state GST)
| Name | SKU | HSN | GST% | Purchase ₹ | Sale (MRP) ₹ | Batch tracked |
|------|-----|-----|------|-----------|--------------|---------------|
| Paracetamol 500mg Strip | PARA500 | 3004 | 5 | 8.00 | 15.00 | Yes |
| Cough Syrup 100ml | COUGH100 | 3004 | 5 | 45.00 | 78.00 | Yes |
| Digital Thermometer | THERMO1 | 9018 | 5 | 90.00 | 180.00 | No |
| Vitamin C Tablets (supplement) | VITC | 2106 | 18 | 40.00 | 95.00 | No |

> Vitamin C is deliberately classified as a **supplement (HSN 2106 @ 18%)** —
> that matches the seeded `hsn_gst_master` rate and gives the pack a non-5%
> item. (As a chapter-30 medicament it would auto-fill 5%; don't mix the two.)

> **GST intra vs inter-state:** when customer state = org state (both 27) GST
> splits **CGST + SGST** (2.5% + 2.5% for a 5% item). When customer state ≠ org
> state (e.g. UP/09) it is a single **IGST** line (5%). Verify the split matches
> the customer's state on every invoice case.

### 3.3 Money & rounding

- All amounts are **₹ (INR)** with Indian digit grouping (`₹1,15,000.00`).
- Line total = qty × rate − line discount; tax computed **per line** on the
  taxable value; invoice total = Σ line totals + Σ tax (+ TCS/round-off if any).
- Cross-check the on-screen total against a hand calculation for every P0 case.

### 3.4 Recording results

For each case, set **Status** to ✅/❌/⏭ and, on failure, capture: the exact input,
the screen, the error text or wrong number, and (if visible) the API error
**code** (e.g. `DC_INSUFFICIENT_STOCK`). The codes are the fastest way for a
developer to locate the failing rule.

---

## 4. Suggested execution order (end-to-end)

The modules interlock. To exercise the real document chains, run in this order:

1. **Inventory 03** `-001…` — create items + opening stock (everything else needs sellable/purchasable items).
2. **Purchase 02** — vendors → PO → GRN (receive stock) → bill → payment.
3. **Sales 01** — customers → SO → DC (dispatch) → invoice → receipt; then POS.
4. **Accounting 04** — verify the journals the above produced; TB/P&L/Balance Sheet; bank rec; audit trail.
5. **HR 05** and **Payroll 06** — independent of the trade flow; can run any time after users exist.

Within a module, run `-001` (setup/happy path) before the validation/negative
cases that depend on it. Each doc's preconditions call out the ordering.

---

## 5. Regression pass checklist (quick smoke)

Before a release, run just the **P0 Happy** case from each module for a 20-minute
smoke test:

- [ ] TC-INV-001 — Create item + opening stock
- [ ] TC-PUR-020 — GRN receive (stock goes up)
- [ ] TC-PUR-030 — Vendor bill posts (AP + purchase-account journal)
- [ ] TC-SAL-031 — DC dispatch (stock goes down)
- [ ] TC-SAL-040 — DC → Invoice (no double stock movement)
- [ ] TC-SAL-050 — Record payment (AR clears)
- [ ] TC-SAL-070 — POS cash sale (cash + revenue, no AR)
- [ ] TC-ACC-030 — Trial Balance balances (Dr = Cr)
- [ ] TC-HR-010 — Apply + approve leave
- [ ] TC-PAY-020 — Payroll run DRAFT→POSTED with PF/ESI/PT

If all ten pass, the core is healthy. Then drill into the full per-module tables.
