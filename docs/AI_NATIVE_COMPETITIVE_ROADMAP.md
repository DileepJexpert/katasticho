# Katixo — AI-Native Competitive Roadmap & Build Backlog

**Created:** 2026-06-21 · **Owner:** Dileep · **Cadence:** daily, code-first
**Source:** "Katixo Competitive Teardown & Whitespace Map" (Claude research, 2026-06-21)
**Branch in flight:** `claude/keyboard-ux-build-1`

> This is the **execution backlog**, not the strategy memo. Each task has a
> definition-of-done and pointers to the code it touches. Check items off as
> they ship. Re-verify "current state" claims when you pick up a task — the
> codebase moves fast.

---

## 0. The wedge (one paragraph)

No competitor occupies the intersection **AI-native + GST-2.0/IMS-compliant +
distributor-first + WhatsApp/mobile**. Global AI ledgers (DualEntry, Campfire,
Digits, Puzzle) have no India compliance. Indian incumbents (Tally, Marg, Busy)
own compliance + distribution but are desktop-bound, single-user, and have
effectively zero real AI. Katixo already has ~80% of the parity surface; the
moat is **(1) frictionless AI-mapped migration off Tally + (2) agentic GST/IMS
reconciliation + (3) embedded lending on our own ledger+GST data.**

---

## 1. Already built (do NOT rebuild — extend)

Cross-checked against the research doc's "incumbents lack" list. ✅ = exists in code today.

| Capability the doc calls a gap in incumbents | Katixo status | Where |
|---|---|---|
| Native cloud + mobile + multi-user, role-based | ✅ | Spring Boot + Flutter, `@PreAuthorize` roles |
| Real (not rebranded) AI — domain models + LLM | ✅ | `ai/service/RuleBasedAiAgentService`, `BillDraftingService`, `ConversationalEntryService`, `ProactiveAgentService` |
| WhatsApp invoice/receipt + UPI QR + reminders | ✅ | `notification/whatsapp/WhatsAppDocumentService`, POS UPI, `CreditReminderService` |
| Conversational entry (sentence → journal) + NLP query | ✅ | `ConversationalEntryService`, `NlpQueryService` |
| GST 2.0 rates (post 9/2025) | ✅ | `V2` hsn_gst_master + `V7` expansion (folded into baseline) |
| Tally migration (masters + vouchers + CA bridge) | ✅ (rule-based) | `migration/tally/TallyImportService`, `TallyVoucherImportService`, `TallyCaBridgeService` |
| GSTR-2B reconciliation (match/mismatch/missing) | ✅ | `gst/service/Gstr2bReconService` (+ GSP auto-fetch) |
| GSTR-1 (B2B/B2CL/B2CS/CDNR/HSN) + 3B + e-invoice + e-way | ✅ | `GstService`, `EInvoiceService`, `EwayBillService` |
| Distributor: scheme, beat/route/van, MR, RCPA, SSS | ✅ | `fieldsales/*`, `pricing/SchemeService` |
| Photo/bill scan → vendor + GST + DRAFT bill | ✅ | `ai/service/BillDraftingService` |
| Bank statement OCR (Indian formats, AI fallback) | ✅ | `banking/BankStatementParser` |
| Composition / CMP-08, TDS, TCS, e-invoice IRN | ✅ | `CompositionService`, `TdsService`, `TcsService`, `EInvoiceService` |
| Event backbone (foundation for continuous close) | ✅ (partial) | `ai/DomainEventPublisher`, `DomainEventWorker` |

**Implication:** parity is mostly done. Spend the next weeks on the 3 wedges + finishing payroll compliance, not on re-treading parity.

---

## 2. The sharp gaps vs the research (ranked)

1. **IMS Accept / Reject / Pending action loop** — statutory under amended §38 CGST (1 Oct 2025); unactioned invoices are "deemed accepted" into GSTR-2B. We have 2B *matching* but not the *action* workflow. **Highest-leverage wedge.**
2. **AI-mapped Tally import** for unmatched/custom ledger names — converts our rule-based ~80%-mapping to 95%+. Direct lock-in breaker.
3. **GST 2.0 item re-mapping wizard** — onboarding step that walks a migrated org through old-slab → new-slab item review.
4. **WhatsApp order *intake*** (parse incoming "200 amul 1L bhej do" → SO). We send on WhatsApp; we don't ingest orders.
5. **Embedded working-capital lending** on ledger+GST+AA data (Tier 3, needs RBI-licensed partner).
6. **Continuous "always-closing" books** on the event backbone (we have half the plumbing).

---

## 3. Build backlog (work top to bottom)

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · **DoD** = definition of done.

### LANE A — Finish P0 Indian Payroll Compliance (in flight, ~5 days)
*Table stakes: can't onboard any distributor-with-employees without these. Started this week.*

- [x] **A0. Pay slip PDF** — `PayslipPdfService` + `GET /payroll/payslips/{id}/pdf` + Flutter download. *(done 2026-06-21, commit 10e48ac)*
- [x] **A1. State-wise Professional Tax slabs.** Replaces flat ₹200 PT with statutory slabs across 14 states. *(done 2026-06-21)*
  - V3 `pt_slab` master + 60 seed rows (MH gender-split + Feb top-up, KA, WB, TN, AP/TS, GJ, MP, OR, KL, BR/JH, AS, PY). Non-PT states (Delhi, Haryana, UP, …) deliberately absent — calculator returns ₹0 when no slab matches.
  - `ProfessionalTaxCalculator` service resolves org's 2-digit GST code → alphaCode → slab; unknown gender defaults to MALE (more conservative bracket). Wired into `PayrollService.calculatePayslip` (line ~866) — only line that changed in the existing service. Tests: 13 unit (`ProfessionalTaxCalculatorTest`) + zero regression in `PayrollServiceTest` (13/13) + `PayslipPdfServiceTest` (4/4).
- [x] **A2. State-wise LWF.** *(done 2026-06-21, commit `084bccd`)* — V4 `lwf_rule` master, 14 state rules, `LabourWelfareFundCalculator` w/ collection-month gating (Maharashtra Jun/Dec only, Chhattisgarh Mar/Sep, Kerala monthly, …). 10 unit tests.
- [x] **A3. PF ECR file generator.** *(done 2026-06-21, commit `c9c0994`)* — `PfEcrFileGenerator` produces EPFO `#~#`-delimited file at `GET /payroll/runs/{id}/ecr`; ₹15k wage cap, EPS 8.33% recompute, age-58 ceiling, NCP days. 9 tests.
- [x] **A4. ESI contribution file.** *(done 2026-06-21, commit `3f088b6`)* — `EsiReturnFileGenerator` outputs ESIC CSV at `GET /payroll/runs/{id}/esi-return`; days-paid math, last-working-day on exit, name sanitisation. 9 tests.
- [x] **A5. Form 12BB + old/new tax regime.** *(done 2026-06-21, commit `4d69907`)* — V5 `employee_tax_declaration` (DRAFT→SUBMITTED→VERIFIED), regime flag, HRA + 80C/80CCD(1B)/80D/80E/80G/80TTA/80TTB + Sec 24(b) + LTA + other income, statutory cap logic, HRA least-of-three. `/api/v1/payroll/tax-declarations/me` + admin. 16 tests.
- [x] **A6. Form 24Q quarterly TDS return.** *(done 2026-06-21, commit `b5f0dc2`)* — Discovered `SalaryTdsService.form24q()` already existed; added `Form24QExporter` (CSV + NSDL FVU deductee-detail block) at `GET /tds/24q/csv` and `/fvu`. 7 tests.
- [x] **A7. Form 16 (Part A + B) PDF.** *(done 2026-06-21, commit `b0c2ade`)* — `Form16PdfService` renders CBDT layout (Sec 203 banner, deductor/employee header, quarter-wise Part A, salary-breakup Part B, Sec 16(iii) PT line, amount-in-words). `GET /tds/form16/{id}/pdf?fy=`. 7 tests.
- [x] **A8. Bank salary disbursement file.** *(done 2026-06-21)* — `BankSalaryFileGenerator` supports GENERIC/HDFC/ICICI/SBI column orders, skips no-bank/cash-paid/zero-net rows, "SAL-MMYYYY-{code}" reference. `GET /payroll/runs/{id}/bank-file?format=`. 9 tests. **P0 payroll pack complete.**
- [ ] **A9. (stretch) Pay components:** salary advance + auto-EMI, arrears, gratuity provision (4.81% basic), leave encashment on exit, reimbursements (FBP). *Split into sub-tasks when reached.*

### LANE B — Agentic GST / IMS (the #1 wedge) — **COMPLETE**

- [x] **B1+B2+B3. IMS Accept/Reject/Pending + AI recommendations.** *(2026-06-21, `45de441`)* — V6 migration extends gstr2b_entry with ims_action / ims_action_at / ims_action_by / ims_remarks + ims_ai_recommendation. `ImsService` w/ single+bulk action, deterministic rule-based recommendations from matchStatus (MATCHED→ACCEPT, VALUE_MISMATCH→REJECT, NOT_IN_BOOKS→PENDING), apply-all, period summary with ₹ITC exposure on no-action rows. `/api/v1/gst/ims`. 14 tests. *Undo / reset added 2026-06-22:* `ImsService.reset(id)` + `bulkReset(ids)` clear action/actor/timestamp/remarks so an operator can fix a misclick before GSTR-3B is filed; `IMS_NOT_ACTIONED` 400 if the row was never actioned. `POST /api/v1/gst/ims/{id}/reset` + `/bulk-reset`. Tests +4 (single reset clears all four fields; reset on never-actioned throws; bulk-reset skips never-actioned rows with skip counter; empty bulk throws).
- [x] **B4. GST 2.0 item re-mapping wizard.** *(2026-06-21, `0b68d44`)* — `Gst20RateRemapper` scans drift between item.gstRate and hsn_gst_master, groups into "from→to" buckets (sorted biggest first), dry-run + bulk apply with skip counters (already-current / no-HSN / no-master). `/api/v1/gst/rate-remap`. 12 tests.
- [x] **B5. Month-end close checklist.** *(2026-06-21, `bd67128`)* — `MonthEndCloseService.checklist(year, month)` aggregates fiscal-period / IMS / 2B-recon / rate-drift / GSTR-1/3B readiness with traffic-light state per item + overall closable flag. 3B BLOCKED while IMS rows unactioned (auto-pop ITC would shift). `/api/v1/gst/close`. 7 tests.

### LANE C — AI-Assisted Tally Migration — **C1 done**

- [x] **C1. LLM mapping layer over the rule-based importer.** *(2026-06-21, `b2bd80c`)* — `LlmTallyMapper` calls Claude on unclassified ledgers; strict JSON output (name/kind/confidence/reason); strips markdown fences; normalises common LLM variants (Income→REVENUE, Capital→EQUITY); falls back to SKIP rather than invent. Inert without `app.ai.anthropic-api-key`. `/api/v1/migration/tally/suggest-mapping`. 11 tests.
- [ ] **C2. Migration progress + "go-live in <1 day" UX.** A guided multi-step importer (masters → opening balances → vouchers → verify TB) with progress + a final trial-balance match against `TallyCaBridgeService`. *(Flutter UI — backend pipeline complete.)*
- [ ] **C3. Marg / Busy import (stretch).** Defer until Tally path proven.

### LANE D — WhatsApp Order-to-Ledger — **D1+D2 done**

- [x] **D1. Inbound order parser.** *(2026-06-21, `2b13fd5`)* — `WhatsAppOrderService.parse(message)` splits on newlines/commas/and, extracts qty + unit (kg/g/l/ml/pcs/strip/tab/…) leading or trailing, strips Hindi+English noise (bhej, do, please, kindly, chahiye, …), matches against `ItemRepository.search`, returns lines with confidence + alternates. 12 tests.
- [x] **D2. Draft SO from parsed message.** *(2026-06-21, `b34ceac`)* — `confirmAndCreate(parsed, contactId, ref)` drafts a real SO via `SalesOrderService.create()` carrying only matched lines, `allowBackorder=true`, WA-tagged reference, notes preserving the original message. Routes through standard SO→DC→Invoice. 3 tests (15 total for the service).
- *Webhook receiver and per-customer SKU aliases — follow-up.*

### LANE E — Continuous Close / Anomaly / Conversational polish — **E1 done**
- [x] **E1. Anomaly/fraud detection productised.** *(2026-06-21)* — `DistributionAnomalyDetector` raises AI Inbox suggestions: duplicate vendor payments (same vendor + same amount within N days), margin erosion (sale ≤ cost or below threshold), credit-limit breaches (sum of outstanding > limit). Idempotent via `existsOpenSuggestion`. `runAll()` dispatcher. 12 tests.
- [ ] **E2. Conversational reporting in Hindi/regional** over web + WhatsApp.
- [ ] **E3. Always-closing books** on `DomainEventPublisher`.

### LANE F — Embedded Lending (Tier 3, needs partner — later)
- [ ] **F1. Lending data export** — clean ledger + GST + AA-consented bundle per org (the underwriting trail). Build first; it's also useful standalone.
- [ ] **F2. Event-driven credit triggers** at PO/invoice/collection (signal only, until an NBFC/AA partner is integrated). **Blocked on:** RBI-licensed lending partner + digital-lending compliance review.

---

## 4. Suggested week-1 cadence (adjust freely)

| Day | Focus | Ship |
|---|---|---|
| 1 | A1 State PT slabs | per-state PT in payslip + tests |
| 2 | A2 LWF + A3 PF ECR | LWF state rates + ECR txt download |
| 3 | A4 ESI + A6 Form 24Q | ESI return + 24Q FVU txt |
| 4 | A5 regime + 12BB | declaration form + regime-aware TDS |
| 5 | A7 Form 16 + A8 bank file | Form 16 PDF + NACH file |
| 6 | B1 IMS store + sync | `ims_invoice` + sync from GSP/2B |
| 7 | B2 Accept/Reject/Pending | action loop + deemed-accept warning |

Then roll into B3–B5 (AI recommendations + rate re-mapper + close pack), then Lane C.

---

## 5. Guardrails carried from the research

- **Models:** domain-specific + LLM, never raw GPT wrappers; human-in-the-loop approval + full audit trail (we already do this — AI drafts, never auto-posts).
- **Vendor AI accuracy claims (90/95/97%) are marketing** — set our own measured bars (e.g., 2B match ≥95% on real data).
- **GST regime is in flux** — IMS "mandatory" is nuanced (deemed-acceptance, not forced action); ₹2cr e-invoice threshold is *proposed not in force* (still ₹5cr); ITC hard-lock Phase 2 signalled ~July 2026. Build for the trajectory, track GSTN/CBIC notifications before hard-coding thresholds.
- **Don't rebuild full SFA** (Bizom/FieldAssist territory) — own the ledger-connected slice only.
- **Lending is Phase 3** — regulatory weight, licensed partner required.

---

## 6. Re-evaluate triggers
- Tally (TallyPrime 7.x) or Zoho (Zia) ship genuinely *agentic* India AI → accelerate Lane B/C.
- A funded India-native AI-ledger startup (hisabkitab, AI Accountant, Flick AI) moves from overlay to full ledger replacement **with distributor depth** → compresses our window.
