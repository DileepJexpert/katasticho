# AI-First Accounting for India — Product Vision & Build Plan

**Version:** 1.0
**Date:** 2026-06-10
**Author:** Dileep (solo founder) + Claude
**Status:** Living document — revise as Campfire evolves and as we ship
**Reference product:** [Campfire AI](https://docs.campfire.ai/) — we track their API surface and AI patterns as an ongoing benchmark, not a thing to copy. We are building the **India equivalent**.

---

## 0. How to use this document

This is the north-star document for turning Katasticho's existing accounting core into an **AI-first, API-first accounting product for India**. It is written for a **solo developer using AI as the team**. Every phase is sized to be shippable by one person with Claude.

- When Campfire ships something new, add it to §3 (the benchmark table) and decide: adopt, adapt, or ignore.
- When you finish a phase, update §9 (roadmap) and the roadmap section of `CLAUDE.md`.
- Read this with `docs/AI_APPROACH_AND_ROADMAP.md` (the AI architecture) and `docs/BRD_KATASTICHO_ERP.md` (the ERP product).

---

## 1. The one-sentence vision

> **An accounting system where the human reviews and approves, instead of types and files.**

Indian accounting software today (Tally, BUSY, Marg, Vyapar, even Zoho Books) is a **digital typewriter**: it faithfully records decisions the human already made, one form field at a time. The human is the data-entry operator; the software is the typewriter.

**AI-first accounting inverts this.** The human states intent — a sentence, a photo of a bill, a forwarded WhatsApp message, a bank statement — and the system **drafts the complete, compliant transaction**: the right ledger accounts, the GST split, the HSN, the TDS section, the journal entry. The human's job becomes **review and approve**, not **type and file**.

The deterministic accounting engine stays the source of truth. AI never silently posts to the ledger. But AI becomes the **primary way work enters the system**, not a side panel.

---

## 2. "Typewriter" vs "AI-first" — concretely

This is the distinction the whole product is built around. Make every feature decision pass this test.

| Job to be done | Typewriter way (today's market) | AI-first way (our product) |
|---|---|---|
| **Record a purchase bill** | Open "New Bill" form → pick vendor → add 12 line items → set HSN, GST%, amounts → save | Photograph/forward the bill → system extracts lines, matches vendor, infers HSN→GST, drafts the bill + journal → you tap **Approve** |
| **Categorize an expense** | Operator decides the ledger account from memory | System proposes account from vendor+description pattern it learned; you confirm or correct once, it remembers |
| **Bank reconciliation** | Manually tick statement lines against ledger | System parses the statement (PDF/CSV), auto-matches by amount+date+narration, surfaces only the unmatched |
| **GST return (GSTR-1/3B)** | Export, fix mismatches in Excel, file on portal | System pre-builds the return from posted invoices, flags mismatches vs GSTR-2B, explains each one |
| **"What's my cash position?"** | Run 3 reports, read tables | Ask in plain language → get the number + the drivers + a chart |
| **Chase a payment** | Notice an overdue invoice, manually message | System surfaces "₹2.4L overdue >30 days from 6 customers, draft reminders ready" |
| **Close the month** | Checklist in someone's head | System runs the close checklist, flags anomalies, drafts adjusting entries for review |

**The test for any feature:** *Does the human start from a blank form, or from a draft they review?* If blank form → it's typewriter. If draft-to-review → it's AI-first.

---

## 3. Campfire benchmark (what we learn from them)

Campfire is a US/mid-market, API-first, AI-native general ledger. We are **not** their market (they do ASC 606 revenue recognition, multi-currency consolidation for VC-backed startups). But their **engineering patterns are the gold standard** and worth tracking.

### 3.1 What Campfire does that we should adopt

| Campfire pattern | What it is | Our stance |
|---|---|---|
| **API-first** | Every action is a clean REST endpoint (`POST /coa/api/v1/invoice/`); the UI is just a client | **ADOPT.** Make our backend the product. UI (Flutter) is one client; AI/MCP is another. |
| **Auto journal on AP/AR events** | Creating an invoice immediately generates the GL entry (DR AR / CR Revenue + tax), no separate "post" call needed for the simple path | **ALREADY HAVE.** `InvoiceService`, `JournalService` do this. Keep it. |
| **Nested line items in one call** | Bill/invoice + its lines + tax created atomically in a single POST | **ALREADY HAVE.** Our DTOs are nested. |
| **Token auth + pagination + soft-delete** | `Authorization: Token <key>`, `{count,next,previous,results}`, `include_deleted` flag | **PARTIAL.** We have JWT. Add: a stable paginated envelope, `include_deleted`, and **API keys** (not just user JWT) for programmatic/AI access. |
| **AI bank-statement parsing** | LLM parses uploaded statements; they track input/output tokens + model name per parse | **ADOPT.** We have `BillScanService` + vision routing. Extend to bank statements. Track tokens (we have `ai_usage_log`). |
| **Webhooks with topic subscriptions** | `POST /integrations/api/v1/webhook` with topic filters; event-driven | **ADOPT (later).** We have `domain_events` already — webhooks are just an external delivery of those. |
| **MCP server for AI integration** | 12 MCP tools across 4 categories so Claude Desktop / agents can drive the books | **ADOPT — this is our biggest leverage.** See §7. |
| **Comparative / budget-vs-actual statements** | `GET /ca/api/balance-sheet/comparative` with cadence + entity rollup | **ADAPT.** We have reports; add period comparison + budget. |
| **Approval workflow on reconciliation** | DRAFT → PENDING_APPROVAL → APPROVED with `reconciled_by`/`approved_by` | **ALREADY HAVE the engine** (`ApprovalWorkflowService`). Apply it to recon. |

### 3.2 What Campfire does that we should NOT copy (yet)

- **ASC 606 revenue recognition / deferred revenue schedules** — irrelevant to Indian SMB/distribution. Skip.
- **Multi-currency consolidation / entity rollup** — most of our customers are single-currency INR, single GSTIN or a few. Defer.
- **Their account taxonomy** — US GAAP. We need the **Indian schedule III / GST-aware CoA**.

### 3.3 The gap they don't fill (our entire moat)

Campfire has **zero India compliance**. Our moat is everything in §6: GST returns, e-invoice/IRN, e-way bill, TDS/TCS, GSTR-2B reconciliation, UPI, Indian CoA. **This is where AI-first + India = a product nobody else has.**

---

## 4. What we already have (asset inventory)

We are not starting from zero. Honest accounting of the existing codebase (`com.katasticho.erp`):

**Accounting core — ~70% there:**
- Double-entry `JournalService` (DR/CR balanced, reversal support)
- `InvoiceService` (AR), AP bills, `PaymentService` (lifecycle, void-with-reversal), `CreditNoteService`
- Chart of accounts, contacts (customer/vendor unified ledger via `ContactLedgerService`)
- GST tax-line modeling, HSN→GST mapping (`PharmacyMasterService`), intra/inter-state split
- Reports: P&L, balance sheet inputs, day book, cash flow, journal register, GST summary (`DetailedReportService`, `OperationalReportService`)
- Multi-tenant (`TenantContext`), roles, approval workflow engine

**AI foundation — already scaffolded (Phase 6):**
- `ai_suggestion`, `domain_event`, `ai_pattern`, `ai_training_example`, `org_ai_settings`, `ai_model_run`, `ai_usage_log`, `ai_model_registry` tables
- `RuleBasedAiAgentService` (anomaly, GST compliance, inventory agents)
- `DomainEventPublisher` → `DomainEventProcessor` → handlers (`InvoicePostedAiEventHandler`)
- `BillScanService`, `ItemScanService`, `VisionModelRouter`, `ClaudeApiClient`, `OllamaVisionClient`
- `NlpQueryService` + `SqlValidator` + `SchemaProvider` (natural-language → safe SQL)
- `AiSuggestionService`, Flutter **AI Inbox** (`ai_chat_screen.dart`)

**The honest gap:** The AI exists as a **side feature** (an inbox you visit). To be "AI-first" it must become the **front door**. And we have **no India statutory filing** (GST returns, e-invoice, TDS) and **no API-key/MCP access** for programmatic use.

---

## 5. Target architecture — three AI surfaces + a deterministic core

```
                    ┌─────────────────────────────────────────────┐
                    │   ENTRY SURFACES (how intent comes in)        │
                    │                                               │
   "Bill ABC 50    │  1. CONVERSATIONAL    2. DOCUMENT    3. INBOX │
    Crocin @95"  ──┼─►  (chat / NLP)       (scan/OCR)    (review)  │
   photo of bill ──┼─►       │                  │            │     │
   bank stmt PDF ──┼─►       └──────────┬───────┴────────────┘     │
   MCP/API call  ──┼─►                  ▼                          │
                    │            ┌──────────────┐                  │
                    │            │  AI DRAFTING  │  observe→suggest │
                    │            │  LAYER        │  (never posts)   │
                    │            └──────┬───────┘                   │
                    └───────────────────┼──────────────────────────┘
                                        │ creates ai_suggestion (DRAFT)
                                        ▼
                    ┌──────────────────────────────────────────────┐
                    │   HUMAN REVIEW (approve / correct / reject)   │
                    └───────────────────┬──────────────────────────┘
                                        │ on approve
                                        ▼
                    ┌──────────────────────────────────────────────┐
                    │   DETERMINISTIC CORE (source of truth)         │
                    │   JournalService · InvoiceService · GST engine │
                    │   InventoryService · PaymentService            │
                    │   ── validates, posts, enforces, audits ──     │
                    └───────────────────┬──────────────────────────┘
                                        │ emits domain_event
                                        ▼
                              AI LEARNS (ai_pattern updated)
```

**Non-negotiable invariants (carry over from `CLAUDE.md` + AI roadmap):**
1. AI **never** writes to the ledger, stock, GST records, or payments directly. It only creates `ai_suggestion` drafts. Posting always goes through the existing domain services and their validations.
2. Every AI action is **explainable** (reasoning stored) and **reversible** (it's a draft until a human approves).
3. The deterministic engine is the source of truth. AI is a drafting assistant, not an authority.
4. Multi-tenant isolation (`org_id`) applies to every AI table and every AI query — same as the ERP.

---

## 6. India accounting requirements (our moat — Campfire has none of this)

This is what makes it an **Indian** accounting product. Prioritized.

### 6.1 GST (highest priority — the #1 reason SMBs buy accounting software in India)
- **CoA, Indian-aware:** Schedule III grouping; output/input GST control accounts (CGST/SGST/IGST/Cess payable & ITC).
- **GSTR-1 builder:** B2B, B2C(large/small), exports, credit/debit notes, HSN summary — pre-built from posted invoices, exportable as JSON for the GST portal / GSP.
- **GSTR-3B builder:** Summary of outward supplies + ITC, pre-filled.
- **GSTR-2B reconciliation:** Pull/upload 2B, **auto-match** purchase bills to supplier-filed invoices, flag mismatches (missing ITC, rate mismatch, supplier didn't file). **This is a killer AI use case** — exactly the kind of fuzzy matching AI is good at.
- **e-Invoice (IRN):** For B2B above threshold — generate IRP-compliant JSON, get IRN + signed QR (via GSP/NIC sandbox first).
- **e-Way bill:** Generate from invoice/DC when value > ₹50k and goods move.
- **Place-of-supply logic:** Already partially there (intra/inter-state split). Harden it.

### 6.2 TDS / TCS
- TDS on purchases/expenses by section (194C, 194J, 194Q, etc.), threshold tracking, auto-deduct on bill, TDS payable ledger, Form 26Q data prep.
- TCS on sales (206C(1H)).

### 6.3 Payments — Indian rails
- **UPI** (already at POS — extend to B2B collections with dynamic QR), NEFT/RTGS/IMPS with **IFSC** validation, bank statement import (PDF/CSV/Excel from major Indian banks).

### 6.4 Statutory reports
- Indian P&L + Balance Sheet (Schedule III format), GST returns, TDS returns, **Tally export** (XML) for CA handoff (parked P9 — revive here).

### 6.5 Compliance calendar
- AI-surfaced: "GSTR-3B due in 3 days", "TDS payment due", "GSTR-1 ready to file" — the system tracks deadlines and pre-builds the artifact.

---

## 7. The MCP server — our single biggest leverage point

This is what turns Katasticho from "an app" into "an accounting brain that any AI can operate." Campfire shipped this; for a **solo founder it's a force multiplier** because it means **you (and your customers) can run the books by talking to Claude**, and it makes the product composable.

**What it is:** A [Model Context Protocol](https://modelcontextprotocol.io) server exposing Katasticho's accounting operations as tools. Then Claude Desktop, the Claude API, or any agent can:
- "Create a bill for ABC Pharma, 50 Crocin at ₹95, 12% GST" → drafts it
- "What's my GST liability this month?" → queries it
- "Reconcile this bank statement" → matches it
- "Show overdue receivables over 30 days" → reports it

**Tool categories (model on Campfire's 12-tool layout):**
1. **Read/query** — `get_balance_sheet`, `get_pnl`, `list_invoices`, `get_outstanding`, `nl_query` (wraps existing `NlpQueryService`)
2. **Draft (write-as-suggestion)** — `draft_invoice`, `draft_bill`, `draft_payment`, `draft_journal` → all create `ai_suggestion`, never post directly
3. **Document** — `scan_bill`, `parse_bank_statement` → wrap `BillScanService`
4. **Compliance** — `build_gstr1`, `check_gst_reconciliation`, `compliance_calendar`

**Why it's safe:** MCP tools call the **same domain services** with the **same validations** and the **same suggest-don't-post rule**. The MCP server is just another API client, subject to API-key auth + `org_id` scoping.

**Prereq:** API-key auth (§8) so the MCP server authenticates as the org without a user JWT.

---

## 8. API-first hardening (make the backend the product)

To be API-first like Campfire, do these (small, high-leverage):

1. ~~**API keys** — per-org programmatic credentials, scoped, revocable. Needed for MCP + webhooks + integrations.~~ ✅ **DONE (Phase C):** `X-API-Key: kat_…`, `api_key` table (V49), `ApiKeyAuthenticationFilter`. Manage in Settings → API Keys.
2. **Stable response envelope** — standardize on a paginated shape (`{count,next,previous,results}` or keep `ApiResponse.ok` but make list endpoints consistently paginated).
3. **OpenAPI spec** — add springdoc-openapi; auto-generate `/v3/api-docs`. This becomes the contract, the SDK source, and the MCP tool catalog. *(One dependency + annotations we mostly already imply.)*
4. **`include_deleted` + `last_modified_at` filters** on list endpoints (we already soft-delete via `is_deleted`) — enables incremental sync for integrations.
5. **Webhooks** (later) — external delivery of `domain_events` with topic subscriptions.

---

## 9. Roadmap for a solo developer (sequenced, each phase shippable)

Sized so one person + Claude ships each phase. Don't skip ahead — each builds on the last. **Branch:** `claude/erp-requirements-doc-g0o1P` (per `CLAUDE.md`).

### Phase A — "Draft, don't type" for bills (the first true AI-first flow) ✅ DONE (2026-06-10)
**Goal:** Prove the inversion on the single highest-pain Indian workflow: purchase bill entry.
- ~~Wire `BillScanService` → creates an `ai_suggestion` of type `DRAFT_BILL` with full nested lines (vendor matched, HSN→GST inferred).~~ **`BillDraftingService` does the drafting in the backend** (not the client): match-or-create vendor, match item→GOODS / unmatched→expense SERVICE line, GST from line or HSN master. Creates a DRAFT `purchase_bill` + `DRAFT_BILL` suggestion.
- ~~Flutter: "Scan/Upload Bill" → pre-filled review → approve → posts via AP path.~~ **Scan sheet now has a primary "Approve & Post" (2-tap) action** → `POST /ai/bill-drafts` then `…/{id}/approve` (posts via `PurchaseBillService.postBill`). "Edit in form" kept as the secondary path. AI Inbox routes DRAFT_BILL accept/reject to the drafting endpoints.
- ~~Learn: on approve, write `ai_pattern`.~~ **On approve, records `PURCHASE_LINE_ACCOUNT` patterns** (vendor+HSN→account); drafting reuses them to pre-fill the expense account next time. Best-effort (never blocks posting).
- **Endpoints:** `POST /api/v1/ai/bill-drafts`, `POST /api/v1/ai/bill-drafts/{suggestionId}/approve`, `.../reject`.
- **Safety:** AI only creates the DRAFT + suggestion; a human always approves; posting flows through the normal AP path with all its validations. Reject deletes the DRAFT.
- **Tests:** `BillDraftingServiceTest` (5, green). **Definition of done met:** a photographed bill → posted, GST-correct purchase bill in ≤2 taps, zero typed line items.
- **Follow-ups:** wire the same `/ai/bill-drafts` to a one-shot scan (image→draft in one call); add API-key auth so the MCP server (Phase C) can call it; richer item auto-matching (HSN/barcode, fuzzy).

### Phase B — Conversational entry + read (NL is the front door)
**Goal:** Typing a sentence drafts a transaction; asking a question returns an answer.
- Extend `NlpQueryService`: intent routing — *query* path (already there, NL→SQL read) vs *command* path ("bill X 50 units…" → `draft_*` suggestion).
- Flutter AI screen becomes a **command bar available everywhere**, not a separate tab.
- **DoD:** "Bill ABC Pharma 50 Crocin at 95" drafts a reviewable bill; "cash position this month" returns the number + drivers.

### Phase C — API keys + MCP server (the leverage unlock) ✅ DONE (2026-06-10)
**Goal:** Run the books from Claude Desktop / any agent.
- ~~API-key auth (§8.1)~~ **`api_key` table (V49), `ApiKey`/`ApiKeyService`/`ApiKeyController`** at `/api/v1/api-keys` (create/list/revoke, Owner/Admin). Keys are `kat_<random>`; only the SHA-256 hash is stored; plaintext shown once. **`ApiKeyAuthenticationFilter`** authenticates `X-API-Key` (or `Authorization: Bearer kat_…`) and sets the **same** `TenantContext` + `ROLE_<role>` as JWT, so `@PreAuthorize`/`@RequiresModule` work unchanged. JWT filter skips API-key requests (no collision). Flutter: **Settings → API Keys** (create/copy-once/revoke).
- ~~the MCP server (§7)~~ **`mcp/` — a standalone TypeScript MCP server** (`@modelcontextprotocol/sdk`, stdio) that wraps the REST API with the API key. Tools: `ask` (NL→answer+rows), `list_bills`, `list_invoices`, `list_ai_inbox`, `draft_bill`, `approve_bill_draft`, `reject_bill_draft`. README has the Claude Desktop config.
- **Safety:** the MCP server can only *draft*; posting requires `approve_bill_draft` (reuses Phase A's human-in-the-loop). Key carries org+role; revocable.
- **Tests:** `ApiKeyServiceTest` (6, green). **DoD met:** from Claude Desktop, "draft a bill … / what's my profit this month?" works against a test org, drafts-only-until-approved.
- **Follow-ups:** add tools as the API grows (GST returns, bank rec); per-key scopes/role; rate limiting per key (we have `ai_usage_log`); publish the MCP server to npm.

### Phase D — GST returns + 2B reconciliation (the India moat) ✅ DONE (2026-06-10) — includes e-way bills (pulled forward from Phase F)
**Goal:** Pre-built GSTR-1/3B and AI-matched 2B reconciliation.
- ~~GSTR-1/3B builders~~ **already existed** (`GstService` @ `/api/v1/gst/gstr1|gstr3b` + export). **Enhanced: POS receipts now included** — B2CS + HSN summary in GSTR-1 (per-line tax derived from HSN master, intra/inter from receipt header) and outward supplies in 3B. Material for kirana/retail orgs.
- ~~GSTR-2B upload + match; mismatch inbox.~~ **`Gstr2bReconService`** — upload portal 2B JSON (official `data.docdata.b2b` shape or simplified `entries[]`), rows matched against posted purchase bills by GSTIN + normalized invoice number (case/punctuation/leading-zero tolerant), value tolerance ₹1. Statuses: MATCHED / VALUE_MISMATCH / NOT_IN_BOOKS; the reverse check lists **suppliers who didn't file (ITC at risk)**. Mismatches create `GSTR2B_VALUE_MISMATCH` / `GSTR2B_MISSING_BILL` AI Inbox suggestions. V50 `gstr2b_entry` table. Endpoints: `POST /gst/gstr2b/upload`, `GET /gst/gstr2b`, `GET /gst/gstr2b/summary`.
- ~~Compliance calendar.~~ **`GstComplianceCalendarService`** — GSTR-1 (11th), GSTR-3B (20th), TDS deposit (7th), 2B-recon nudge (after the 14th), pending e-way bill count. Status per item: UPCOMING / DUE_SOON / OVERDUE. `GET /gst/compliance-calendar`. Clock-injected (testable).
- **e-Way bills (user mandate, pulled forward):** **`EwayBillService`** + V50 `eway_bill` table. (1) **Single-document rule:** `InvoicePostedEwayBillHandler` watches INVOICE_POSTED — invoice ≥ threshold (org setting `gst.eway_bill_threshold`, default ₹50,000) auto-creates a PENDING row + `EWAY_BILL_REQUIRED` HIGH suggestion. (2) **Vehicle-aggregate rule:** `POST /gst/eway-bills/check-vehicle` — sub-₹50k documents in one vehicle whose combined value crosses the threshold ALL need EWBs (split bills don't evade it). NIC bulk-upload **portal JSON** generated per invoice (`GET /gst/eway-bills/{id}/portal-json`); record EWB number with validity auto-computed (1 day / 200 km); cancel lifecycle.
- **Flutter:** GST screen ("GST Compliance") extended 3 → 6 tabs: **Calendar**, GSTR-3B, GSTR-1, **2B Recon** (JSON upload via file picker, summary metrics, supplier-not-filed list, entry list), **e-Way Bills** (record/cancel/portal-JSON/check-vehicle), Review.
- **MCP:** 3 new tools — `gst_compliance_calendar`, `get_gstr3b`, `gstr2b_recon_summary` (10 tools total).
- **Tests:** 15 new (Gstr2bRecon 3, EwayBill 8, GstService POS 2, Calendar 2). **Full suite 443 green.**
- **DoD met:** "Your GSTR-1 is ready; 3 ITC mismatches need attention" — mismatches land in the AI Inbox with drill-down; e-way mandate enforced proactively.
- **Follow-ups:** GSP/NIC API integration for direct filing + EWB generation (vs JSON handoff), B2CL section in GSTR-1, 2B auto-fetch via GSP, dedupe suggestions on re-upload, e-invoice/IRN (rest of Phase F).

### Phase E — Bank reconciliation (AI statement parsing) ✅ DONE (2026-06-10)
**Goal:** Upload statement → auto-matched → review only exceptions.
- **Found existing:** `BankReconciliationService` already did CSV-paste import + CREDIT-side invoice matching with confidence scoring + accept→AR-payment. Phase E filled the real gaps:
- **`BankStatementParser`** — real bank exports (.csv/.xlsx upload or pasted text): header auto-detected anywhere in the first 25 rows (banks put account preambles above it), fuzzy column mapping (Txn/Value Date, Narration/Particulars, Withdrawal/Deposit or single Amount, Chq./Ref/UTR), Indian formats (`1,15,000.00`, `₹`, `Cr/Dr` suffixes, `dd-MMM-yy`). **AI fallback** via `ClaudeApiClient.sendMessage` (strict-JSON extraction) when no header is found — tokens land in `ai_usage_log` automatically (the Campfire pattern). `POST /banking/transactions/import-file`.
- **DEBIT-side matching** — outgoing transactions now match **open vendor bills** (amount vs balance due, vendor bill number + vendor name in narration). Accepting a BILL match records a **vendor payment** (allocated to the bill, paid through the default BANK account) — mirror of the credit side. V52: `payment_match.match_type` + `bill_id`.
- **Recon summary** — `GET /banking/summary`: counts per status + unmatched value per side.
- **Flutter:** statement **file upload** button (bank's export as-is), updated import card copy, bill matches rendered with document numbers.
- **Design decision:** match review lives in the banking screen's SUGGESTED queue (its own review surface) — no duplicate `ai_suggestion` rows; the approval-workflow tie-in stays optional/deferred.
- **Tests:** 9 (parser 5: HDFC-style preamble+split columns, legacy format, month-name dates, AI fallback, Indian amounts; service 4: credit regression ×2, debit→bill suggest, accept-bill→vendor payment). **Full suite 471 green.**
- **DoD met:** a month's statement uploads as-is; credits and debits both auto-match; the human touches only exceptions. (Also closes Tally parity gap #1.)
- **Follow-ups:** PDF statements via vision router, bank feeds/AA rails (long-term), multi-bank-account tagging on transactions, recon approval workflow.

### Phase F — e-Invoice (IRN) + e-Way bill + TDS ✅ DONE (2026-06-10)
**Goal:** Full statutory document generation. (e-Way bills shipped early in Phase D.)
- ~~IRP integration for IRN + signed QR.~~ **`EInvoiceService`** + V51 `einvoice` table. When the org enables e-invoicing (`gst.einvoice_enabled`, toggle in the e-Invoice tab), `InvoicePostedEInvoiceHandler` flags every posted **B2B** invoice (buyer has GSTIN) → PENDING row + `EINVOICE_REQUIRED` HIGH suggestion. **IRP INV-01 schema (v1.1) JSON** generated per invoice (TranDtls/DocDtls/Seller/Buyer/ItemList/ValDtls with intra/inter split); record IRN + Ack + signed QR back; cancel lifecycle. Endpoints: `/api/v1/gst/einvoices[/{id}/portal-json|/record|/cancel|/settings]`. (Direct IRP/GSP API call deferred — JSON handoff first, same pattern as e-way.)
- ~~TDS-by-section on bills + 26Q prep.~~ **`TdsService`** (tax pkg) — **auto-deduction on vendor bills** driven by the vendor master (`tdsApplicable`/`tdsSection`/`tdsRate`), honouring section thresholds: 194C (30k single / 1L FY), 194J (30k), 194H (20k), 194I (2.4L), 194A (5k), **194Q (50L — TDS only on the excess)**. Computed on the taxable value (excl GST, CBDT 23/2017); FY = Apr–Mar; posted-bills aggregate per vendor (new repo sum query). Wired into `PurchaseBillService` create/update; vendor owed total − TDS (`balanceDue` + payment status fixed); posting already credits TDS Payable (2030). **Form 26Q** quarterly deductee-wise data (+missing-PAN warning) and a TDS register at `/api/v1/tds/26q|/register`.
- **Calendar:** + Form 26Q quarterly deadline (Jul 31/Oct 31/Jan 31/May 31) and pending e-invoice count.
- **Flutter:** GST Compliance now 8 tabs — adds **e-Invoice** (enable toggle, IRP JSON, record IRN/Ack/QR, cancel) and **TDS** (FY+quarter picker, 26Q summary + deductee list + share JSON, PAN-missing flags).
- **MCP:** `tds_26q_summary` tool (11 tools total).
- **Tests:** 14 new (TdsService 8, EInvoiceService 6) + calendar updated. **Full suite 457 green.**
- **DoD met:** a B2B invoice gets flagged, produces valid INV-01 JSON, and carries its IRN + QR once recorded; TDS auto-deducts by section with thresholds and feeds 26Q.
- **Follow-ups:** direct GSP/IRP API (auto-IRN), TCS 206C(1H) on sales, 26Q TXT/FVU export format, TDS catch-up on earlier sub-threshold bills when the annual threshold is first crossed, lower-deduction certificates (197).

### Phase G — Proactive AI (close, anomalies, collections)
**Goal:** The system tells you what needs attention before you ask.
- Month-end close checklist agent; anomaly agent (extend `RuleBasedAiAgentService`); collections agent (overdue → draft reminders).
- Webhooks + OpenAPI SDK polish.
- **DoD:** "3 things need you before month close" lands proactively, each with a ready-to-approve action.

**Parked (revisit after the queue below):** multi-currency depth, revenue recognition, multi-entity consolidation, push notifications (P5), Hindi i18n (P3).

### Master execution queue (2026-06-10 — work top to bottom)

Status: A ✅ · C ✅ · D ✅ (incl. e-way) · F ✅ (e-invoice + TDS) · Tally slice 1 ✅ · E ✅ · Tally slice 2 ✅ · Tally slice 3 ✅ · B ✅ · G ✅. **Migration complete (1–3). Phase B (conversational entry) + Phase G (proactive agents) shipped. Remaining: parity backlog (#6), keyboard UX (#7).**

| # | Work item | Why this order | Status |
|---|-----------|----------------|--------|
| 1 | **Phase E — AI bank reconciliation** (statement file import + AI parse fallback, debit-side bill matching, recon summary) | Vision Phase E **and** Tally parity gap #1 — one build closed both | ✅ DONE 2026-06-10 |
| 2 | **Tally slice 2 — Day Book voucher import** (all voucher types → journal entries via JournalService; ledger resolution: contact→AR/AP, account→code, well-known→default, bank pattern→1020) | Completes migration for mid-year switchers; builds directly on slice 1 | ✅ DONE 2026-06-10 |
| 3 | **Tally slice 3 + P9 — "CA Bridge"** (TB verification: upload Tally TB → diff vs our books, MATCHED/MISMATCH/MISSING; + Tally-importable voucher XML export, sign convention mirrored) | Kills the #1 switching objection ("my CA only takes Tally") | ✅ DONE 2026-06-10 |
| 4 | **Phase B — conversational entry** (sentence → drafted journal entry via rule-based parser; DRAFT_ENTRY suggestion; approve posts via JournalService; Flutter quick-entry composer in AI Inbox) | AI-first front door; reuses Phase A drafting + AiSuggestion infra | ✅ DONE 2026-06-10 |
| 5 | **Phase G — proactive agents** (collections reminders w/ WhatsApp draft, month-close checklist, anomaly sweep; daily ProactiveAgentJob per-org; manual run endpoint + Inbox button) | The "system tells you first" promise | ✅ DONE 2026-06-10 (webhooks/OpenAPI polish deferred) |
| 6 | **Tally parity backlog** (doc §1 order): landed cost → TCS 206C(1H) + composition CMP-08 → cost centres UI → interest on overdue → budgets → FIFO valuation → stock ageing → GSP direct IRP/EWB APIs → WhatsApp docs → ratio analysis → post-dated vouchers | Steady parity grind; each item small and independent | TODO |
| 7 | **Keyboard-parity UX program** (global command bar `Ctrl+K`, Enter-driven billing, never-touch-the-mouse voucher entry) | Wins the Tally operator, not just the owner — runs as a continuous thread alongside 4 | TODO |

---

## 10. Tech decisions (locked for now)

| Decision | Choice | Why |
|---|---|---|
| **AI for drafting/vision** | Claude API (`ClaudeApiClient` exists) primary; Ollama vision as local/cheap fallback (`OllamaVisionClient` exists) | Already wired; Claude best at structured extraction + reasoning |
| **AI for NL→SQL read** | Existing `NlpQueryService` + `SqlValidator` (read-only, validated) | Safe, already built |
| **Posting path** | **Always** existing domain services. AI only creates `ai_suggestion`. | Invariant #1 — non-negotiable |
| **API auth** | JWT for UI (exists) + **new API keys** for programmatic/MCP | MCP/webhooks need non-user creds |
| **Contract** | OpenAPI via springdoc | Source of SDK + MCP tool catalog |
| **GST filing** | Via GSP/NIC sandbox JSON first, direct portal later | Don't build portal scraping; use the official rails |
| **Migrations** | Flyway, next is **V49** | Per `CLAUDE.md` |

---

## 11. What success looks like (so we know if we're winning)

- **The typewriter test:** For bills, expenses, and payments, the user starts from a **draft they review**, not a blank form. (Phase A/B)
- **The 2-tap bill:** Photograph → approve → posted & GST-correct. (Phase A)
- **The conversation:** You can run the month from a chat box and an inbox. (Phase B/G)
- **The MCP demo:** You operate the entire product from Claude Desktop. (Phase C)
- **The India moat:** GSTR-1 and 2B reconciliation that Campfire/Zoho-for-startups can't touch. (Phase D)
- **The proof of leverage:** A solo founder ships all of A–D in months, because AI does the drafting and Claude does the building.

---

## 12. Open questions (decide before Phase C/D)

1. **GSP partner** for GST filing + e-invoice (ClearTax/Masters India/NIC-direct)? Affects Phase D/F integration shape.
2. **Hosting** for the MCP server — same Spring app (an MCP-over-HTTP controller) or a thin sidecar? Lean: same app, new controller.
3. **Pricing of AI** — do AI tokens get metered per org (we have `ai_usage_log`)? Decide before opening MCP/API to customers.
4. **First customer profile** — kirana/pharma retailer (POS-first, we're strong) vs distributor (B2B bills, more GST pain). The latter feels the AI-first bill pain more acutely.

---

*Revise this document whenever Campfire ships something notable or we complete a phase. It is the contract between the vision and the build.*
