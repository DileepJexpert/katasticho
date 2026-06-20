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
- [ ] **A1. State-wise Professional Tax slabs.** Replace flat ₹200 PT with per-state slabs (MH ₹175/200/300, KA ₹200>₹15k, WB/TN/AP/TS/GJ/MP/OR/KL + others).
  - DoD: `pt_slab` reference seed (state + from/to gross + monthly amount + Feb-extra for MH); `PayrollService.calculatePayslip` picks slab by employee `workLocation` state → org state fallback; nil for no-PT states; unit test per major state.
- [ ] **A2. State-wise LWF.** Currently single rate. Make state-aware (different employee/employer split + frequency: monthly/half-yearly/annual per state).
  - DoD: `lwf_rule` seed (state + employee + employer + frequency); calc honours it; test MH/KA/GJ.
- [ ] **A3. PF ECR file generator.** UAN-wise EE/ER/EPS/EDLI breakdown in EPFO ECR text format for a payroll run.
  - DoD: `GET /payroll/runs/{id}/ecr` → downloadable `#~#`-delimited ECR txt; test asserts column layout + totals.
- [ ] **A4. ESI contribution file.** Employee+employer ESI for ≤₹21k gross, ESIC return format.
  - DoD: `GET /payroll/runs/{id}/esi-return`; test.
- [ ] **A5. Form 12BB + old/new tax regime.** Employee FY investment declaration (HRA/80C/80D/LTA/home-loan) + regime flag that drives monthly TDS.
  - DoD: `employee_tax_declaration` table; regime locked per FY; TDS calc respects regime (new = no 80C/HRA, std deduction only); Flutter declaration form on My Profile.
- [ ] **A6. Form 24Q quarterly TDS return.** TXT for NSDL FVU. (Note: `PayslipLineRepository.findLineRowsForRuns` + `SalaryTdsLineRow` already exist — wiring is half-done.)
  - DoD: `GET /tds/24q?quarter=&fy=` → FVU-importable txt; per-employee salary-TDS aggregation; test.
- [ ] **A7. Form 16 (Part A + B) PDF** per employee, annual. Builds on the PDF pipeline from A0.
  - DoD: `GET /payroll/employees/{id}/form16?fy=`; YTD aggregation across the FY's payslips; test.
- [ ] **A8. Bank salary disbursement file** (NACH/H2H for HDFC/ICICI/SBI corporate banking).
  - DoD: `GET /payroll/runs/{id}/bank-file?format=HDFC|ICICI|SBI`; test per format.
- [ ] **A9. (stretch) Pay components:** salary advance + auto-EMI, arrears, gratuity provision (4.81% basic), leave encashment on exit, reimbursements (FBP). *Split into sub-tasks when reached.*

### LANE B — Agentic GST / IMS (the #1 wedge, ~2–3 weeks)
*Statutorily mandatory + the hardest monthly pain. We have 60% of the data plumbing.*

- [ ] **B1. IMS inbound invoice store + sync.** Pull IMS records (or reuse the 2B JSON/GSP fetch) into an `ims_invoice` table with status NO_ACTION/ACCEPTED/REJECTED/PENDING.
  - DoD: `ims_invoice` migration; `ImsService.sync(period)` reuses `Gstr2bReconService` / `GspClient.fetch2b`; idempotent re-sync.
- [ ] **B2. Accept / Reject / Pending action loop.** Per-invoice action + "deemed accepted" warning for NO_ACTION before cutoff.
  - DoD: `POST /gst/ims/{id}/action {ACCEPT|REJECT|PENDING}`; bulk action; status drives downstream 2B/3B eligibility; audit trail.
- [ ] **B3. AI accept/reject recommendation.** For each inbound invoice, recommend an action with reason (matches a posted bill → ACCEPT; not in books → PENDING + draft bill; value mismatch → REJECT/flag). Reuse `BillDraftingService` to draft the missing bill on PENDING.
  - DoD: recommendation surfaced in AI Inbox; one-click apply; ITC-leakage alert when a real bill would be deemed-rejected.
- [ ] **B4. GST 2.0 item re-mapping wizard.** On first onboarding / after Tally import, list items whose HSN→rate changed under the 9/2025 notification and let the owner review/accept new rates in bulk.
  - DoD: `GET /gst/rate-remap/candidates` (items where item.gstRate ≠ hsn_gst_master rate); Flutter wizard "893 items move 12%→18%, 534 move →5%"; bulk apply writes item rate + audit.
- [ ] **B5. One-click month-end close pack.** Sequence: IMS actioned → 2B reconciled → GSTR-1 prepared → 3B prepared (respecting July-2025 hard-lock of 3.1/3.2) → variance/anomaly summary. Extend `ProactiveAgentService` month-close checklist.
  - DoD: a "Close" screen that shows the checklist with live status + blockers; ≥50% time-cut target (Puzzle-style).

### LANE C — AI-Assisted Tally Migration (moat-breaker, ~1–2 weeks)
*Direct attack on the single biggest switching barrier.*

- [ ] **C1. LLM mapping layer over the rule-based importer.** When `TallyImportService` can't classify a ledger/group by rule, ask the LLM (via `ClaudeApiClient`) to map it to a CoA account type / contact type, with confidence + reason. Human reviews low-confidence rows.
  - DoD: import preview shows rule-matched vs AI-suggested vs unmatched; accept/override per row; >95% master-mapping on a real Tally export; tokens logged to `ai_usage_log`.
- [ ] **C2. Migration progress + "go-live in <1 day" UX.** A guided multi-step importer (masters → opening balances → vouchers → verify TB) with progress + a final trial-balance match against `TallyCaBridgeService`.
  - DoD: one screen, 4 steps, ends with green "Trial balance matches Tally to the rupee."
- [ ] **C3. Marg / Busy import (stretch).** Same pipeline, Marg/Busy export formats. Defer until Tally path proven with a design partner.

### LANE D — WhatsApp Order-to-Ledger (bold bet, Q2)
*Fuses the nFuse/HublerX ordering layer with the accounting layer no one connects.*

- [ ] **D1. Inbound WhatsApp webhook + intent parse.** Receive a retailer message ("200 amul 1L bhej do"), parse to structured lines via LLM + per-customer SKU aliases.
  - DoD: `whatsapp/inbound` webhook; `WhatsAppOrderService.parse(text|image|voice)` → draft SO lines with B2B price-list + credit check; ambiguous items ask a clarifying question back on WhatsApp.
- [ ] **D2. Draft SO → confirm → invoice → ledger → GST.** Retailer/owner confirms on WhatsApp; posts through existing SO→DC→Invoice flow.
  - DoD: end-to-end one demo order from a WhatsApp text to a posted invoice with correct GST.

### LANE E — Continuous Close / Anomaly / Conversational polish (ongoing)
- [ ] **E1. Anomaly/fraud detection productized.** Duplicate vendor payments, scheme/claim leakage, expiry-write-off abuse, credit-limit breaches, margin erosion → AI Inbox alerts. Extend `RuleBasedAiAgentService`.
- [ ] **E2. Conversational reporting in Hindi/regional** over web + WhatsApp ("aaj ka cash position?", "Route 4 ka overdue"). Extend `NlpQueryService` with language detection + the WhatsApp channel.
- [ ] **E3. Always-closing books.** Use `DomainEventPublisher` so trial balance + GST position are always current; a "books are X% closed for June" indicator.

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
