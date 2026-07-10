# 04 — Accounting — Manual Test Cases

Covers the general ledger and financial reporting:
**Chart of accounts → Journal entries → Period close → Trial Balance → P&L →
Balance Sheet → Bank reconciliation → Audit trail.**

> Read [`README.md`](README.md) first. Best run **after** Sales and Purchase, so
> there are real journals (invoices, bills, payments, COGS) to verify the reports
> against. Several cases cross-check numbers produced by those modules.

**Key business rules exercised here**
- Every posting is **double-entry**: Σ debits = Σ credits, always.
- POS receipts → **Cash/Revenue**, never AR.
- Contact "outstanding" (AR) = opening balance + invoices − payments.
- Posting into a **closed** period is blocked.
- Journals are posted through services; the **Edit Log** captures create/update/
  delete automatically with a field-level diff.

---

## A. Chart of Accounts

### TC-ACC-001 — Default chart is seeded on org creation
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/accounts` · **Role:** OWNER |
| **Preconditions** | Fresh org |

**Expected result:** The chart of accounts is pre-seeded — **~64 accounts for an
India TRADING org** (61 base template rows + 2042 Stock-Out Suspense + 2080
Gratuity Provision + 5130 Gratuity Expense); **RETAIL/SERVICES/F&B orgs seed
~59** (56 base + the same 3) — covering Assets (Cash 1010, Bank 1020, AR 1100,
Inventory 1200), Liabilities (AP 2010, GST payable, TCS/TDS payable), Equity,
Income (Sales 4010), Expenses (COGS 5xxx). No manual setup needed to start
trading.

**Actual / Status / Notes:**

---

### TC-ACC-002 — Create a custom ledger account
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/accounts` · **Role:** OWNER/ACCOUNTANT |

**Test data:** name "Courier Charges", type Expense, parent Operating Expenses.

**Expected result:** Account saves with a code; usable on journals/bills; shows
under its parent in the hierarchy.

**Actual / Status / Notes:**

---

### TC-ACC-003 — Cannot delete a system/used account
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/accounts` · **Role:** OWNER |

**Steps:** Try to delete a system default (e.g. Accounts Receivable 1100) or an
account with postings.

**Expected result:** Blocked with a clear message. A custom, **unused** account
can be deactivated/deleted.

**Actual / Status / Notes:**

---

### TC-ACC-004 — Account code uniqueness
| | |
|---|---|
| **Priority / Type** | P2 / Validation |
| **Route** | `/accounts` · **Role:** ACCOUNTANT |

**Expected result:** Creating an account with a duplicate code is rejected.

**Actual / Status / Notes:**

---

## B. Journal entries

### TC-ACC-010 — Post a balanced manual journal
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/accounting/journal-entries` · **Role:** ACCOUNTANT |

**Test data**
| Line | Account | Debit | Credit |
|------|---------|-------|--------|
| 1 | Bank (1020) | 10000 | |
| 2 | Capital/Equity | | 10000 |

**Steps:** New journal → add both lines → post.

**Expected result:** Journal posts; Bank +10,000; equity +10,000. It appears in
the Day Book / Journal Register. TB stays balanced.

**Actual / Status / Notes:**

---

### TC-ACC-011 — Unbalanced journal is rejected
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | `/accounting/journal-entries` · **Role:** ACCOUNTANT |

**Test data:** Debit Bank 10,000 / Credit Capital **9,000** (Σ ≠).

**Expected result:** In the **UI** the unbalanced journal cannot even be
submitted — the balance indicator turns red showing **"Difference: ₹1,000"** and
both **Save Draft** and **Post** stay disabled until Σdebits = Σcredits. Via
**API**, creation is rejected with **`ACCT_JOURNAL_IMBALANCE`** (400 — "Journal
does not balance. Debit: 10000.00, Credit: 9000.00"). An all-zero journal is
rejected with **`ACCT_JOURNAL_ZERO`**. No partial post either way.

**Actual / Status / Notes:**

---

### TC-ACC-012 — Save a draft journal, then post
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/accounting/journal-entries` (post = API) · **Role:** ACCOUNTANT |

**Expected result:** A DRAFT journal (created via **Save Draft**) does not affect
balances or reports; posting it does. A draft **cannot be edited** — there is no
update endpoint and no edit screen; to change one, **delete it** (Delete on the
journal detail, manual entries only) and re-create. Posting an existing draft is
currently **API-only**: `POST /api/v1/journal-entries/{id}/post`
(OWNER/ADMIN/ACCOUNTANT) — the detail screen has no Post action (known UI gap;
note it in Actual/Notes).

**Actual / Status / Notes:**

---

### TC-ACC-013 — Reverse a posted journal
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | **API only** — `POST /api/v1/journal-entries/{id}/reverse` (no Reverse button in the UI yet) · **Role:** OWNER/ADMIN/ACCOUNTANT |

**Steps:** Reverse a posted journal via the API.

**Expected result:** A mirror-image reversing entry is created as a **new POSTED
entry dated TODAY** (not the original's date — today's period must be open, else
**`ACCT_PERIOD_CLOSED`** 409) with debits↔credits swapped; net effect on all
accounts = 0. The original is not edited/deleted — it only gets
`isReversed=true`. Reversing a non-POSTED entry → **`ACCT_ENTRY_NOT_POSTED`**
(400); reversing twice → **`ACCT_ENTRY_ALREADY_REVERSED`** (409).

**Actual / Status / Notes:**

---

### TC-ACC-014 — Cost-centre tag on a journal line
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/accounting/journal-entries` · **Role:** ACCOUNTANT |
| **Preconditions** | None — cost centre is a **free-text tag** typed on the journal line (there is no cost-centre master) |

**Expected result:** A line tagged with a cost centre appears in the **Cost-centre
P&L** report under that centre. Use a consistent spelling (e.g. "MUMBAI") across
lines — the report groups by the **exact tag string**, so "Mumbai" and "MUMBAI"
would appear as two different centres.

**Actual / Status / Notes:**

---

### TC-ACC-015 — Journal into a closed period blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/accounting/journal-entries` · **Role:** ACCOUNTANT |
| **Preconditions** | TC-ACC-050 (period closed) |

**Expected result:** A journal dated in a closed period is rejected; an open-period
date posts.

**Actual / Status / Notes:**

---

### TC-ACC-016 — Post-dated journal (stays DRAFT until effective date)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/accounting/journal-entries` (create form) · **Role:** ACCOUNTANT |

**Test data:** balanced journal (DR Bank 1020 ₹5,000 / CR Capital ₹5,000),
effective date = **tomorrow**; tick the **"Post-dated voucher"** checkbox (it
appears only once a future effective date is picked).

**Expected result:** The entry is created **DRAFT** even if "Post" was chosen —
post-dated vouchers always stay DRAFT. Today's Trial Balance / Day Book do
**not** include it. After the post-dated job fires on/after the effective date
(daily, default 00:15), the entry flips to **POSTED** automatically and balances
update as of the effective date. TB balanced after auto-post.

**Actual / Status / Notes:**

---

## B2. Expenses

### TC-ACC-020 — Record an expense
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/expenses` · **Role:** ACCOUNTANT/OWNER |

**Test data:** expense "Shop electricity" ₹2,500 · category/account an expense GL
(e.g. Utilities) · paid via Cash.

**Steps:** Expenses → New → fill amount/account/payment mode → save/post.

**Expected result:** Expense posts **DR Expense account ₹2,500 / CR Cash (1010)
₹2,500** (Bank if paid via bank). It appears in the expense list, the Day Book,
and reduces net profit on the P&L. No stock, no AR/AP involvement.

**Actual / Status / Notes:**

---

## C. Trial Balance, P&L, Balance Sheet

### TC-ACC-030 — Trial Balance balances (Dr = Cr)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/reports/trial-balance` · **Role:** ACCOUNTANT |
| **Preconditions** | Sales + Purchase flows have posted journals |

**Expected result:** The Trial Balance lists every account with a non-zero
balance; **total debits = total credits** to the paisa. This is the single most
important integrity check — if it doesn't balance, a posting rule is broken.

**Actual / Status / Notes:**

---

### TC-ACC-031 — P&L reflects sales, COGS, expenses
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/reports/profit-loss` · **Role:** ACCOUNTANT |
| **Preconditions** | Posted invoices (revenue + COGS) and expense bills |

**Expected result:** Revenue = Σ posted sales (invoices + POS); COGS = Σ cost of
goods sold; Gross profit = Revenue − COGS; Net profit = Gross − operating
expenses. Cross-check revenue against the sales register total.

**Actual / Status / Notes:**

---

### TC-ACC-032 — Balance Sheet ties out
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/reports/balance-sheet` · **Role:** ACCOUNTANT |

**Expected result:** **Assets = Liabilities + Equity** (including current-period
net profit). Inventory on the balance sheet equals the stock valuation total
(TC-INV-060/061). AR equals Σ customer outstanding; AP equals Σ vendor
outstanding.

**Actual / Status / Notes:**

---

### TC-ACC-033 — Reports respect the date filter
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/reports/profit-loss` · **Role:** ACCOUNTANT |

**Steps:** Run P&L for a narrow date range that excludes some transactions.

**Expected result:** Only transactions within the range are included; the same
report over a wider range includes more. Numbers are consistent between overlapping
ranges.

**Actual / Status / Notes:**

---

### TC-ACC-034 — Day Book / Journal Register completeness
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/reports` → Day Book / Journal Register · **Role:** ACCOUNTANT |

**Expected result:** Every posted journal (from invoices, bills, payments, POS,
manual entries) appears exactly once, chronologically, with matching debit/credit
totals. No document is missing or duplicated.

**Actual / Status / Notes:**

---

### TC-ACC-035 — Contact ledger (customer/vendor statement)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | contact detail → overflow menu → **View Statement** (`/contacts/:id/statement`; API `GET /api/v1/contacts/{id}/ledger`) · **Role:** ACCOUNTANT |
| **Preconditions** | A customer with invoices + a payment |

**Expected result:** The ledger shows opening balance, each invoice (debit), each
receipt (credit), and a running balance that equals the contact's current
outstanding. Same for a vendor (bills/payments).

**Actual / Status / Notes:**

---

## D. Period close

### TC-ACC-050 — Close a fiscal period
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/accounting/period-close` · **Role:** OWNER/ACCOUNTANT |

**Steps:** Select the current month → **Close**.

**Expected result:** The period is marked **CLOSED**. Subsequent postings dated in
it are blocked (verified by TC-SAL-045 / TC-PUR-034 / TC-ACC-015).

**Actual / Status / Notes:**

---

### TC-ACC-051 — Re-open a period
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/accounting/period-close` (`POST /api/v1/accounting/periods/{year}/{month}/reopen`) · **Role:** OWNER/ADMIN/ACCOUNTANT |

**Expected result:** Re-open **is permitted** for a CLOSED period with the **same
roles as close** (no elevated gate). After re-open, postings into that period
succeed again. A **LOCKED** period cannot be re-opened — rejected with
**`ACCT_PERIOD_LOCKED`** (409). Locking (`POST .../lock`) is the only
OWNER/ADMIN-restricted period action, and only CLOSED periods can be locked
(**`ACCT_PERIOD_NOT_CLOSED`**, 400).

**Actual / Status / Notes:**

---

### TC-ACC-052 — Year-end close sweeps P&L to Retained Earnings
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/accounting/period-close` (`POST /api/v1/accounting/periods/year-end-close/{fiscalYear}`) · **Role:** OWNER/ADMIN/ACCOUNTANT |
| **Preconditions** | A fiscal year with posted revenue + expense journals |

**Steps:** Run the year-end close → try to re-run it → then reopen it.

**Expected result**
- One posted closing journal (source `YEAR_END_CLOSE`) zeroes every REVENUE and
  EXPENSE account's FY net into **Retained Earnings**; next-FY P&L starts from
  zero; the Balance Sheet equity includes the swept profit; TB still balances.
- Re-running the same close → **`YEAR_END_ALREADY_CLOSED`** (409) — no doubled
  Retained Earnings.
- Reopen (`POST .../year-end-close/{fiscalYear}/reopen`) reverses the close
  journal **in the closed year's period** (dated the close entry's own date, not
  today); P&L balances reappear; reopening a never-closed year →
  **`YEAR_END_NOT_CLOSED`** (400). The year can then be re-closed.

**Actual / Status / Notes:**

---

## E. Bank reconciliation

### TC-ACC-060 — Import a bank statement
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/banking/reconciliation` · **Role:** ACCOUNTANT |
| **Preconditions** | A CSV/XLSX bank statement (or pasted text) |

**Expected result:** Rows parse (dates, withdrawal/deposit, narration, ref/UTR);
Indian amount formats (`1,15,000.00`, Cr/Dr) are handled; a preamble before the
header doesn't break parsing.

**Actual / Status / Notes:**

---

### TC-ACC-061 — Credit line → suggest invoice, accept
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/banking/reconciliation` · **Role:** ACCOUNTANT |
| **Preconditions** | An outstanding customer invoice matching a credit line |

**Expected result:** The credit (money in) is suggested against the matching
invoice; **accepting records an AR receipt** (DR Bank / CR AR) and clears the
invoice.

**Actual / Status / Notes:**

---

### TC-ACC-062 — Debit line → suggest vendor bill, accept
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/banking/reconciliation` · **Role:** ACCOUNTANT |
| **Preconditions** | An open vendor bill matching a debit line |

**Expected result:** The debit (money out) is suggested against the bill;
**accepting records a vendor payment** (DR AP / CR Bank), allocated to the bill.

**Actual / Status / Notes:**

---

### TC-ACC-063 — Bank rule categorises a non-document line
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/banking/rules` + `/banking/reconciliation` · **Role:** ACCOUNTANT |
| **Preconditions** | A bank rule (e.g. narration CONTAINS "BANK CHARGES" → account Bank Charges, DEBIT) |

**Steps:** Create the rule → import a statement with a matching "BANK CHARGES" debit.

**Expected result:** The rule **takes precedence** over invoice/bill scoring →
an ACCOUNT match; accepting posts **DR Bank Charges / CR Bank**. An `auto_apply`
rule posts on import (only when the row has a reference, so a reference-less
re-import can't double-post).

**Actual / Status / Notes:**

---

### TC-ACC-064 — Re-accepting a matched transaction is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/banking/reconciliation` · **Role:** ACCOUNTANT |
| **Preconditions** | An already-MATCHED (posted) transaction |

**Expected result:** Re-running/re-accepting a MATCHED transaction is rejected
(`BANK_TX_ALREADY_MATCHED` / `BANK_MATCH_NOT_SUGGESTED`) — no second journal. This
guards against double-posting.

**Actual / Status / Notes:**

---

## F. Forex revaluation & fixed assets

### TC-ACC-070 — Preview + post period-end forex revaluation
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/accounting/forex-revaluation` · **Role:** ACCOUNTANT |
| **Preconditions** | An open **foreign-currency** AR invoice/AP bill + a closing rate entered |

**Steps:** Pick an as-of date → **Preview** → review AR/AP delta + net gain/loss →
**Post**.

**Expected result:** Preview shows per-document deltas and warnings (skips
base-currency/zero-balance/no-rate docs). Post books one consolidated revaluation
journal on the as-of date **plus an auto-reversing entry the next day**. A
**zero-delta** run posts nothing and does **not** lock the date.

**Actual / Status / Notes:**

---

### TC-ACC-072 — Fixed asset depreciation run (SLM, idempotent)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/accounting/fixed-assets` · **Role:** ACCOUNTANT |

**Test data:** asset FA-01 · cost 1,20,000 · residual 0 · method SLM · useful
life 12 months.

**Steps**
1. Create the asset. Validation: SLM without life → **`FA_NEED_LIFE`**; WDV
   without rate → **`FA_NEED_RATE`**; duplicate code → **`FA_CODE_DUP`** (409).
2. Open the schedule preview — verify 12 monthly charges of **₹10,000**.
3. Run depreciation for the current month
   (`POST /api/v1/fixed-assets/depreciation/run?year=&month=`).
4. Re-run the same month.
5. Dispose the asset; dispose again.

**Expected result**
- (3) **One** posted journal dated month-end: **DR Depreciation Expense (5270)
  ₹10,000 / CR Accumulated Depreciation (1690) ₹10,000**; book value drops to
  ₹1,10,000; TB balanced.
- (4) Idempotent — 0 assets charged, no second journal.
- Final period sweeps the exact residue so book value lands on residualValue to
  the paisa and the asset flips FULLY_DEPRECIATED.
- (5) Second dispose → **`FA_NOT_ACTIVE`** (400).

**Actual / Status / Notes:**

---

## G. Audit trail (Edit Log)

### TC-ACC-080 — Create/edit is captured with a field diff
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/accounting/audit-trail` · **Role:** OWNER/ACCOUNTANT |

**Steps:** Rename a contact (e.g. "Sharma Traders" → "Sharma Traders Pvt Ltd") →
open the audit trail.

**Expected result:** A **CREATE** row (from when it was made) and an **UPDATE** row
with the exact `displayName: old → new` diff, the user who changed it, and the
timestamp. Filters by entity/action/date work; a soft-delete shows as **DELETE**,
a restore as **RESTORE**.

**Actual / Status / Notes:**

---

### TC-ACC-081 — Audit summary
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/accounting/audit-trail` (summary) · **Role:** OWNER |

**Expected result:** Summary shows total changes, counts by action and by entity
type, and the top editors (resolved to user names).

**Actual / Status / Notes:**

---

## H. Cross-cutting / regression

### TC-ACC-090 — Every module posting keeps TB balanced
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/reports/trial-balance` · **Role:** ACCOUNTANT |

**Steps:** After running the Sales, Purchase, and Payroll happy paths, re-run the TB.

**Expected result:** Still **Dr = Cr**. Invoices, bills, payments, COGS, POS, and
payroll journals all net to a balanced TB. This is the master regression assertion
for the whole system.

**Actual / Status / Notes:**

---

### TC-ACC-091 — POS never touches AR (except khata)
| | |
|---|---|
| **Priority / Type** | P0 / Validation |
| **Route** | Day Book · **Role:** ACCOUNTANT |

**Expected result:** A **cash/UPI** POS receipt's journal debits **Cash/Bank**, not
AR. Only a **khata** POS sale debits AR. Confirm by inspecting the POS journals in
the Day Book.

**Actual / Status / Notes:**

---

### Result summary (fill in)

| Section | Cases | Pass | Fail | Blocked |
|---------|-------|------|------|---------|
| A Chart of Accounts | 4 | | | |
| B Journal entries | 7 | | | |
| B2 Expenses | 1 | | | |
| C TB / P&L / BS | 6 | | | |
| D Period close | 3 | | | |
| E Bank reconciliation | 5 | | | |
| F Forex reval & fixed assets | 2 | | | |
| G Audit trail | 2 | | | |
| H Regression | 2 | | | |
| **Total** | **32** | | | |
