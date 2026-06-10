# Tally Parity & Migration Plan — Beating Tally at Its Own Game

**Version:** 1.0
**Date:** 2026-06-10
**Status:** Living document — the feature matrix is the parity backlog; update as we ship.
**Why this exists:** Tally (TallyPrime) is the default accounting software of India — the realistic estimate is 2.5M+ businesses and the overwhelming majority of CAs run it. Every Katasticho customer either uses Tally today or their CA does. Winning means three things: **(1) match the Tally features people actually use, (2) be visibly better where Tally is weak, (3) make switching take an afternoon, not a month.**

---

## 1. TallyPrime feature inventory vs Katasticho

Legend: ✅ have it · 🟡 partial · ❌ missing (backlog) · ➖ deliberately not doing

### 1.1 Core accounting

| Tally feature | What it does | Katasticho | Notes |
|---|---|---|---|
| Ledgers + 28 predefined groups | Chart of accounts via group hierarchy | ✅ | CoA with 5-level hierarchy, seeded Indian template |
| Voucher types: Sales, Purchase, Receipt, Payment, Contra, Journal | The 6 daily-driver entry screens | ✅ | Invoice, Bill, Payment (AR/AP), Journal, POS receipt |
| Debit Note / Credit Note | Returns + adjustments | ✅ | Credit notes (AR, with approval), debit notes (AP) |
| Sales Order / Purchase Order | Pre-invoice commitments | ✅ | Full SO→DC→Invoice, PO→GRN→Stock flows (deeper than Tally) |
| Delivery Note / Receipt Note | Goods movement docs | ✅ | Delivery challan (dispatch deducts stock), GRN |
| Bill-wise details (bill references) | Allocate payments against specific invoices | ✅ | Payment allocation against invoices/bills |
| Outstanding / ageing (receivable & payable) | Who owes what, how old | ✅ | AR/AP ageing reports, contact ledger |
| Cost centres & cost categories | Tag transactions by department/project | 🟡 | `costCentre` field exists on journal lines; no UI/reports yet |
| Budgets & controls | Budget vs actual | ❌ | Backlog (Campfire benchmark has it too) |
| Scenarios (provisional vouchers) | What-if reporting | ➖ | Low usage among SMBs; skip |
| Multi-currency | Forex ledgers, gain/loss | 🟡 | Currency + exchange rate on documents; no realized gain/loss engine |
| Interest calculation | Auto interest on overdue | ❌ | Backlog — useful for distributor credit control |
| Post-dated vouchers / cheques | Future-dated entries | ❌ | Backlog (small) |
| Edit Log (audit trail, MCA-mandated) | Who changed what, immutably | ✅ | Audit log + append-only stock ledger + journal reversal pattern (stronger than Tally's) |
| Cheque printing | Print on bank cheque layouts | ➖ | UPI/NEFT era; revisit only if asked |
| Multiple companies | Many books in one install | ✅ | Multi-tenant orgs + multi-org users (cloud-native, better) |

### 1.2 Inventory

| Tally feature | Katasticho | Notes |
|---|---|---|
| Stock groups/categories/items | ✅ | Items + groups/variants |
| Multiple godowns (warehouses) | ✅ | Warehouses + transfer orders + picklists |
| Batches with mfg/expiry | ✅ | Batch + expiry + FEFO auto-pick (pharma-grade, beyond Tally) |
| Multiple + compound UoM | ✅ | UoM service with conversion factors |
| Price levels / price lists | ✅ | Price lists + customer default price list + schemes (Tally has no scheme engine) |
| Reorder levels | ✅ | Reorder + low-stock alerts + shortbook |
| BOM / manufacturing journal | ✅ | BOM explosion + work orders + job cards (Manufacturing Tier 1 — beyond Tally's mfg journal) |
| Job work in/out | ✅ | Job work orders with GST ITC-04 alerts |
| Physical stock verification | ✅ | Stock count with variance posting |
| Stock valuation methods (FIFO/LIFO/Avg/Std) | 🟡 | Weighted average only; FIFO/others backlog |
| Additional cost on purchase (landed cost) | ❌ | Backlog — distributors ask for freight/duty loading |
| Stock ageing analysis | 🟡 | Near-expiry exists; slow-moving/ageing report backlog |

### 1.3 GST & statutory (our strongest ground)

| Tally feature | Katasticho | Notes |
|---|---|---|
| GSTR-1 prep + export | ✅ | Portal-shaped JSON incl. POS B2CS + HSN summary |
| GSTR-3B prep | ✅ | With ITC + net payable |
| GSTR-2A/2B reconciliation | ✅ | 2B upload + auto-match + **mismatch inbox with AI suggestions** (Tally shows a match screen; we drive actions) |
| e-Invoice (IRN) | 🟡 | INV-01 JSON + record IRN/QR; Tally calls IRP **directly** — GSP/IRP API integration is our gap |
| e-Way bill | 🟡 | Auto-detect ≥₹50k + **vehicle-aggregate rule** (Tally doesn't check aggregates!) + NIC JSON; direct API is the gap |
| TDS | ✅ | Auto-deduct by section with thresholds + 26Q prep (Tally needs manual nature-of-payment setup per ledger) |
| TCS 206C(1H) | ❌ | Backlog |
| Composition scheme (CMP-08) | ❌ | Backlog — many kiranas are composition dealers |
| Payroll statutory (PF/ESI/PT) | ✅ | Full payroll module with journal posting |

### 1.4 Banking

| Tally feature | Katasticho | Notes |
|---|---|---|
| Bank reconciliation (statement import + smart match) | ✅ | Statement file upload (bank export as-is, header auto-detect + AI fallback), credit→invoice + debit→bill matching, accept records the payment (Phase E, 2026-06-10) |
| Connected banking (live balance, pay from Tally via Axis/ICICI/SBI/Kotak) | ❌ | Long-term; needs bank partnerships/AA rails |
| Cheque management | ➖ | Skip |
| UPI collections | ✅ | UPI QR at POS + contact UPI IDs (Tally has nothing equivalent at POS) |

### 1.5 Reports (Tally ships ~400; these are the ones people open)

| Tally report | Katasticho | Notes |
|---|---|---|
| Balance Sheet / P&L / Trial Balance | ✅ | |
| Day Book | ✅ | |
| Cash/Bank book, Cash flow | ✅ | Cash flow + journal register |
| Stock Summary | ✅ | Stock summary/movements |
| Bills receivable/payable (ageing) | ✅ | |
| GST reports | ✅ | + compliance calendar (Tally has none) |
| Ratio analysis | ❌ | Backlog (small) |
| Funds flow | ➖ | Rarely used |
| Cost centre reports | ❌ | With cost centres backlog |
| Budget variance | ❌ | With budgets backlog |
| Dashboards | ✅ | Role dashboards + distributor dashboard v2 (better than Tally's new Report Dashboard) |

### 1.6 Platform & access

| Tally capability | Katasticho | Notes |
|---|---|---|
| Offline desktop (always works without internet) | 🟡 | Offline POS queue ✅; full offline entry ❌ (by design — cloud-first) |
| Multi-user (Gold = unlimited on one LAN) | ✅ | Unlimited users, role-based, **from anywhere** — no LAN required |
| Remote access (Tally.NET / cloud rental ₹) | ✅ | It's just… a web/mobile app. This is our structural win |
| Mobile (view-only browser reports) | ✅ | **Full operations on mobile** — POS, billing, approvals, field sales, GPS check-ins |
| TDL customization / ODBC | 🟡 | No TDL equivalent; instead: org settings, feature flags, workflows, **REST API + API keys + MCP** |
| WhatsApp share | 🟡 | Share/PDF exists; WhatsApp-native templates backlog |
| Security (TallyVault, user levels) | ✅ | JWT + roles + API keys + audit |
| Data backup/corruption | ✅ | Postgres + cloud — no "rewrite company" ritual, no corrupted data files |
| AI | ❌ in Tally | ✅ **bill scan→draft→post, AI inbox, NL queries, MCP/Claude** — Tally has nothing here |

**Parity backlog (ordered by how often Tally users will hit the gap):**
1. ~~Bank statement import + auto-reconciliation~~ ✅ shipped (Phase E, 2026-06-10)
2. Landed cost on purchases
3. TCS 206C(1H) + composition (CMP-08)
4. Cost centres (field exists → UI + report)
5. Interest on overdue receivables
6. Budgets + variance
7. Stock valuation method options; stock ageing report
8. Direct IRP/e-way API via GSP (remove the JSON handoff step)
9. WhatsApp document sending
10. Ratio analysis; post-dated vouchers

---

## 2. Tally's workflows — what's genuinely good, what hurts

### 2.1 Why accountants love Tally (don't dismiss this)

1. **Keyboard-only speed.** An experienced operator posts a sales voucher in ~15 seconds without touching the mouse: `Alt+V → V8 → party → item → qty → Enter Enter Enter`. Muscle memory built over 20 years. **Any replacement that is slower at raw entry loses the operator even if it wins the owner.**
2. **Day Book as home base.** Everything lands in one chronological list; drill into anything, `Ctrl+Enter` to alter. Total transparency.
3. **Instant, offline, local.** Zero latency, works in a power-cut town on a 2014 PC.
4. **Forgiving.** Any voucher can be altered/deleted anytime (Edit Log records it). Accountants fix mistakes in seconds.
5. **CA ecosystem.** Every CA accepts a Tally backup. Audit, IT filing, loans — the data format is the lingua franca.

### 2.2 Where Tally hurts (verified pain points)

| Pain | Detail |
|---|---|
| **Desktop prison** | Mobile is view-only — you cannot post a voucher from a phone. Owner traveling = business blind. Remote needs Tally.NET TSS or renting "Tally on cloud" RDP (₹300–600/user/month on top of license). |
| **Data entry is still typing** | Every purchase bill is keyed line by line. No scan, no AI, no draft. A 20-line pharma bill = 10 minutes of typing + transcription errors. |
| **Costs stack up** | Silver (1 PC) ₹22,500 + TSS ₹4,500/yr; Gold (LAN) ₹67,500 + ₹13,500/yr; + cloud rental + a TDL developer for any customization. |
| **One PC = one point of failure** | Data files corrupt; backups are manual discipline; theft/crash = books gone. |
| **Old UX** | New staff take weeks to learn; no contextual help; errors are cryptic. |
| **Integrations are painful** | TDL/ODBC require specialists; no REST API, no webhooks, no modern auth. |
| **Compliance is semi-connected** | e-invoice/e-way/2B work but need TSS login flows; no proactive "GSTR-1 due in 3 days, here's the file." |
| **No verticals** | Pharma batch discipline, FMCG beats/vans, schemes — all need third-party TDL add-ons. |

*(Sources: [G2 TallyPrime reviews](https://www.g2.com/products/tallyprime/reviews?qs=pros-and-cons), [SoftwareFinder review](https://softwarefinder.com/accounting-software/tally-prime/reviews), [Techjockey reviews](https://www.techjockey.com/reviews/tally-erp-9), [SoftwareConnect 2026 review](https://softwareconnect.com/reviews/tallyprime/), [Softabase review](https://softabase.com/software/erp/tally-prime), [tallysolutions.com](https://tallysolutions.com/tally-prime/).)*

### 2.3 How we do better — the five wedges

1. **"Photograph it" beats "type it."** Tally's fastest sales voucher is 15 seconds of expert typing. Our purchase bill is *a photo + Approve & Post* (Phase A, shipped). Lead every demo with this.
2. **Compliance that acts, not just reports.** Calendar → pre-built GSTR-1/3B → 2B mismatches as AI Inbox actions → e-way/e-invoice auto-flagged with portal JSON ready (shipped). Tally shows screens; we surface *work to approve*.
3. **The whole business in one pocket.** POS + billing + approvals + field sales + dashboards on mobile, true cloud, no TSS/RDP rental. Multi-branch is just… logging in.
4. **Talk to your books.** NL queries + MCP/Claude Desktop (shipped). "Who owes me the most?" is a sentence, not a report path.
5. **Verticals built-in.** Pharma (batch/expiry/FEFO/drug masters/interactions), FMCG (beats/vans/day-close), manufacturing-lite — Tally needs paid TDL add-ons for each.

**And neutralize their strengths:**
- **Keyboard parity program:** global command bar (`/` or `Ctrl+K`), single-keystroke voucher screens, Enter-driven line entry, never-touch-the-mouse billing. (Backlog item — treat as UX P0; keyboard shortcuts doc already exists at `docs/how-to/KEYBOARD_SHORTCUTS.md`.)
- **CA peace treaty:** the CA keeps Tally. We export **Tally-importable XML** (vouchers as Journal/Sales/Purchase) so the CA's workflow is untouched (parked P9 — schedule after Phase E).
- **Day Book parity:** we have the report; make it the operator's drill-everywhere home view.

---

## 3. Migration: Tally → Katasticho in an afternoon

### 3.1 What the customer does in Tally (no tools to install)

TallyPrime exports everything we need as XML, natively:

1. **Masters** (ledgers, stock items, units, godowns): `Gateway of Tally → Top menu **E**xport → **Masters** → Configure: Format = XML, Type of Masters = All Masters → Export`. One file: `Master.xml`.
2. **Vouchers** (transaction history, optional): `Display More Reports → **Day Book** → Alt+F2 (set the FY period) → Alt+E Export → XML`. One file: `DayBook.xml`. *(Slice 2.)*
3. **Closing trial balance** (for verification): `Display → Trial Balance → Alt+E` — used to verify the migration, not to import.

### 3.2 What we import (Slice 1 — SHIPPED with this commit)

`POST /api/v1/migration/tally/preview` then `/import` (multipart XML upload; Flutter: Settings → Migrate from Tally).

| Tally master | Becomes | Mapping detail |
|---|---|---|
| Ledger under **Sundry Debtors** | **Contact (CUSTOMER)** | name, GSTIN, state, address, phone/email, PAN; opening balance → contact opening (Dr = receivable) |
| Ledger under **Sundry Creditors** | **Contact (VENDOR)** | same; opening (Cr = payable) |
| Ledger under **Bank Accounts / Bank OD** | **Account (ASSET/LIABILITY)** | opening balance stored on account |
| **Cash-in-Hand, Fixed Assets, Current Assets, Investments, Deposits, Loans & Advances, Stock-in-Hand** | **Account (ASSET)** | |
| **Capital Account, Reserves & Surplus** | **Account (EQUITY)** | |
| **Loans (Liability), Secured/Unsecured Loans, Current Liabilities, Provisions** | **Account (LIABILITY)** | |
| **Sales Accounts, Direct/Indirect Incomes** | **Account (REVENUE)** | |
| **Purchase Accounts, Direct/Indirect Expenses** | **Account (EXPENSE)** | |
| Ledger under **Duties & Taxes** | **skipped** | We have our own GST/TDS control accounts — importing Tally's causes double-counting |
| `Profit & Loss A/c` special ledger | **skipped** | System ledger |
| **Stock Item** | **Item** | name→name+SKU, base unit, HSN, GST rate, opening qty + rate → opening stock movement + opening journal (via existing `ItemService.createItem`) |

**Sign convention (important):** Tally XML writes **debit balances as negative** (`<OPENINGBALANCE>-15000</OPENINGBALANCE>` = ₹15,000 Dr). The importer normalizes: customers (Dr-normal) and vendors (Cr-normal) both come out positive; accounts are normalized to their natural side.

**Safety:** two-phase (preview shows every row + what it will become + issues; nothing is written until Import). Dedupe: contacts by GSTIN→name, items by name, accounts by name — re-running the import is safe (existing rows are skipped, reported as such).

### 3.3 Slice 2 — Vouchers / history (NEXT)

Day Book XML → transactions. Approach: each `<VOUCHER>` by `VCHTYPE`:
- `Sales` → posted Invoice (party ledger → contact; inventory entries → lines)
- `Purchase` → posted Bill
- `Receipt`/`Payment` → AR/AP payments
- `Journal`/`Contra` → journal entries
- Anything unmappable → journal entry against the right ledgers, flagged for review in the AI Inbox.
Most SMBs migrate **masters + openings at FY start** and keep Tally read-only for history — Slice 1 already covers that path completely. Slice 2 serves mid-year switchers.

### 3.4 Slice 3 — Trust & the CA loop

- **Verification report:** our Trial Balance vs Tally's exported TB, side by side, with diffs highlighted — the CA signs off in minutes.
- **Tally XML export (P9):** monthly vouchers exported in Tally-importable XML so the CA continues filing from Tally. This removes the single biggest switching objection ("my CA only takes Tally").

### 3.5 The pitch, in one line

> *"Export two files from Tally, upload them here, and your customers, suppliers, items, stock, and balances are live in the cloud — your CA still gets Tally files every month, and your next purchase bill is a photograph, not 10 minutes of typing."*

---

## 4. Sequencing impact on the roadmap

The single execution queue lives in `docs/AI_FIRST_ACCOUNTING_PRODUCT_VISION.md`
("Master execution queue") — Tally work is items 2, 3, 6 and 7 there:

1. Phase E — bank statement AI reconciliation (also closes Tally-parity gap #1)
2. Tally Slice 2 — Day Book voucher import
3. Tally Slice 3 + P9 — TB verification + Tally XML export ("CA Bridge")
4. Phase B — conversational entry
5. Phase G — proactive agents
6. Parity backlog (§1 ordered list), one item at a time
7. Keyboard-parity UX as a continuous thread
