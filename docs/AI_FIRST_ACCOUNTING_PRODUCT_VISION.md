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

1. **API keys** — per-org programmatic credentials (`Authorization: Bearer <key>` or `Token <key>`), scoped, revocable. Needed for MCP + webhooks + integrations. *(New: `api_key` table, auth filter.)*
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

### Phase C — API keys + MCP server (the leverage unlock)
**Goal:** Run the books from Claude Desktop / any agent.
- API-key auth (§8.1), then the MCP server (§7) with the read + draft tool set.
- **DoD:** From Claude Desktop, "create a bill / what's my P&L" works against a test org, safely (drafts only).

### Phase D — GST returns + 2B reconciliation (the India moat) ⭐ BIGGEST DIFFERENTIATOR
**Goal:** Pre-built GSTR-1/3B and AI-matched 2B reconciliation.
- GSTR-1/3B builders from posted invoices → JSON export.
- GSTR-2B upload + AI fuzzy-match to purchase bills; mismatch inbox.
- Compliance calendar surfacing deadlines.
- **DoD:** "Your GSTR-1 is ready; 3 ITC mismatches need attention" — with one-tap drill-down.

### Phase E — Bank reconciliation (AI statement parsing)
**Goal:** Upload statement → auto-matched → review only exceptions.
- Extend vision/parse pipeline to bank statements (track tokens in `ai_usage_log`, like Campfire).
- Auto-match by amount+date+narration → `ai_suggestion` matches; approval workflow on the recon (reuse `ApprovalWorkflowService`).
- **DoD:** A month's statement reconciles with the human touching only unmatched lines.

### Phase F — e-Invoice (IRN) + e-Way bill + TDS
**Goal:** Full statutory document generation.
- IRP/NIC sandbox integration for IRN + signed QR; e-way bill; TDS-by-section on bills + 26Q prep.
- **DoD:** A B2B invoice gets a valid IRN + QR; TDS auto-deducts and tracks.

### Phase G — Proactive AI (close, anomalies, collections)
**Goal:** The system tells you what needs attention before you ask.
- Month-end close checklist agent; anomaly agent (extend `RuleBasedAiAgentService`); collections agent (overdue → draft reminders).
- Webhooks + OpenAPI SDK polish.
- **DoD:** "3 things need you before month close" lands proactively, each with a ready-to-approve action.

**Parked (revisit after A–G):** multi-currency, revenue recognition, multi-entity consolidation, push notifications (P5), Hindi i18n (P3). Tally export (P9) folds into Phase D.

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
