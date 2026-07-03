# MASTER GAP TRACKER — the one list (2026-07-02)

Consolidates every open gap from the five-audit review (multi-tenancy /
multi-country / UI coverage / CoA-per-country / scalability, 2026-07-02) and
the competitor matrix (`COMPETITOR_FEATURE_MATRIX_TALLY_ZOHO_ODOO.md`).
**Work top-to-bottom inside each phase; tick items as they ship** (same
convention as `UI_FIELD_GAP_EXECUTION_PLAN.md`, which stays the detail
tracker for UI-only items — E-items below just point at it).

Effort: S (≤1 day) · M (days) · L (week+). Already-fixed 2026-07-02 hardening
items (AI-SQL tenancy, multipart, IDORs, numbering races, V22 country matrix,
ShedLock, S3 storage, attachment download, org-currency documents, drug-import
UI) are NOT repeated here.

## Phase G — Compliance & trust (statutory, hardest to retrofit)
- [x] **G1 Edit Log / MCA audit trail** (L) — versioned create/alter/delete on
  books documents+masters w/ user+time+field diff; query + summary API; viewer
  screen. Tally 6.1 parity; statutory under MCA account-rules. → DONE 2026-07-02
  (V23 `edit_log`, Hibernate listener w/ same-txn JDBC writes, 18-entity
  allowlist, `/api/v1/audit/edit-log` + `/summary`, `EditLogScreen`
  @ `/accounting/audit-trail`, 17 tests, live-verified on fresh DB)
- [x] **G2 MSME Form 1 annexure** (S) — supplier-wise paid/outstanding within vs
  after 45 days + PAN, CSV export. → DONE 2026-07-02 (`MsmeForm1Service`
  deadline = min(dueDate, billDate+45d), `/api/v1/reports/msme-form1` +
  `/export` CSV, @RequiresCountry("IN"), 6 tests; reads `contact.pan` +
  `msme_registered` + `msme_registration_no` already on the master)
- [x] **G4 Vendor-TDS 26Q FVU/CSV file** (M) — mirror the salary 24Q generator
  for vendor TDS (report exists, file export doesn't). → DONE 2026-07-02
  (`Form26QExporter` CSV register + `^`-delimited FVU deductee-detail block
  w/ per-row section→FVU-code map, 01/02 deductee code, PANNOTAVBL sentinel;
  `GET /api/v1/tds/26q/{csv,fvu}` mirroring the 24Q pair; 6 tests. Full
  FH/BH/CD/DD file — needs TAN + ITNS-281 challan capture — deferred exactly
  like the 24Q side.)
- [x] **G5 GST rate history w/ effective dates** per item/HSN (M).
  → DONE 2026-07-02 (V26 `hsn_gst_rate_history` platform table + baseline seed;
  `rateAsOf(code, date)` / `rateHistory(code)` / `addRateHistory` (auto-closes
  prior open period + syncs hsn_gst_master current rate) on PharmacyMasterService;
  `GET/POST /api/v1/pharmacy-masters/hsn/{code}/rate-history` + `/rate-as-of`;
  7 tests. REFERENCE/report layer only — document posting still snapshots the
  line rate, unchanged, so GSTR reconciliation is untouched.)
- [x] **G6 India gratuity provision** (S) — Gulf accrual exists; add IN.
  → DONE 2026-07-02 (V25 seeds 2080/5130 for IN×4 industries + `india_gratuity_accrual`
  idempotency table; `IndiaGratuityService` 15/26 formula w/ §4(2) rounding + 5-year
  eligibility + ₹20L cap, monthly accrual DR 5130/CR 2080 idempotent per period,
  exit payout wired into OffboardingService; `IndiaPayrollController` @RequiresCountry(IN);
  13 tests; live-verified V25 seeds 8 rows)

## Phase H — Daily-use money features
- [x] **G3 POS credit / khata → AR** (M) — CREDIT payment mode on receipt,
  requires contact, posts DR AR (not cash), feeds contact outstanding +
  collections. UI_FIELD_GAP C2. → DONE 2026-07-02 (V24 CHECK widen,
  `PaymentMode.CREDIT` → DR 1100, `pos.allow_credit_sales` gate +
  `POS_CREDIT_REQUIRES_CONTACT`, void restores outstanding, khata
  settlement `POST /customer-receipts/khata-settlement` DR Cash / CR AR,
  POS "Khata" button + sheet + settings toggle, 11 tests, live-verified)
- [x] **H1 Payment-gateway links on invoices** (M) — Razorpay/Stripe link +
  webhook → auto payment record (UPI QR exists). → DONE 2026-07-02
  (V27 `payment_link` + `payment_webhook_event`; `RazorpayClient` config-inert
  w/ HMAC-SHA256 constant-time verify; `PaymentLinkService` create + signed
  webhook → records AR payment idempotently (double dedupe: event-id + captured-
  payment-id) → settles invoice; public `POST /api/v1/webhooks/razorpay/{orgToken}`
  (per-org path token, permit-all + per-org HMAC); `POST /invoices/{id}/payment-link`
  + masked `/settings/razorpay`; 13 tests. Flutter "Get payment link" button = follow-up.)
- [x] **H2 Instalment payment terms + dunning levels** (M) — Odoo parity. DONE 2026-07-03.
  V31 `payment_term`/`payment_term_line`/`invoice_instalment` + `dunning_level`/`dunning_log`.
  `PaymentTermService` (percent/BALANCE schedule, remainder-on-last, apply-to-invoice, derived
  per-instalment status from amountPaid waterfall — payment engine untouched); `DunningService` +
  `DunningDispatcher` (REQUIRES_NEW claim-before-send, instalment-aware overdue, EMAIL/WHATSAPP/
  AI_INBOX/NONE, escalate-in-place) + ShedLock `DunningJob`. Endpoints `/api/v1/payment-terms`,
  `/api/v1/invoices/{id}/instalments`, `/api/v1/dunning`. Adversarial review fixed 3 defects
  (concurrent-sweep double-send/poison, duplicate-seq collision, >100% negative instalment).
  27 tests; V31 boot-verified; 1622 backend pass. **Flutter UI = follow-up.**
- [x] **H3 Recurring bills + recurring journals** (S each). → DONE 2026-07-02
  (V28 `recurring_bill`/`recurring_journal` + generation audit tables, JSONB
  line payload mirroring recurring_invoice; `RecurringBillService` drafts a
  PurchaseBill each period, `RecurringJournalService` posts a JournalEntry
  (DRAFT default, auto_post opt-in, template balance validated); ShedLock-guarded
  `RecurringDocumentJob` sweeps both; `/api/v1/recurring-bills` + `/recurring-journals`
  full CRUD + generate-now; 14 tests. Flutter screens = follow-up.)
- [ ] **H4 User-defined bank matching rules** (M) — on top of suggestions.
- [ ] **H5 Cheque printing + bank bulk e-payment files** (M).
- [ ] **H6 Connected banking feeds** (L, aggregator dependent).
- [ ] **H7 Voucher classes + single-entry mode** (M) — Tally entry speed.
- [ ] **H8 Interest auto-voucher schedule + period-end forex revaluation
  voucher** (M).

> **PROGRESS (2026-07-03):** two research gaps — *accounting module* (I6) +
> *custom workflow* (I2) — **both DONE.**
> - **I6 DONE** (see the ticked I6 line below). Fixed-asset auto-depreciation
>   scheduler + terminal status + preview shipped, tested, boot-verified.
> - **I2 DONE** (see the ticked I2 line below). Workflow-rules engine shipped:
>   V30 `workflow_rule`/`workflow_rule_execution`, criteria evaluator, field
>   resolver (event payload + snapshot), EMAIL/WEBHOOK/AI_SUGGESTION/FIELD_UPDATE
>   actions, domain-event handler (supports=ALL), controller + dry-run + metadata,
>   BILL_POSTED/PAYMENT_RECORDED publish. Adversarial review caught + fixed 3
>   defects (worker-thread null TenantContext, SSRF resolve-and-inspect, LT/LTE
>   on missing field). 1595 backend tests pass; V30 boot-verified.

## Phase I — Platform extensibility (the trio every competitor sells against us)
- [ ] **I1 Custom fields** on core entities (L) — typed, org-scoped, on
  contact/item/invoice/bill first; DTO+UI plumbing.
- [x] **I2 Workflow rules + webhooks** (L) — DONE 2026-07-03. Criteria →
  EMAIL/WEBHOOK(signed, SSRF-guarded)/AI_SUGGESTION/FIELD_UPDATE(allowlisted) on
  document events, riding the existing domain-event bus (handler supports=ALL).
  V30 `workflow_rule` + `workflow_rule_execution` (idempotency); `WorkflowRuleService`
  (CRUD + evaluate + per-rule isolation + REQUIRES_NEW execution recorder);
  `WorkflowCriteriaEvaluator` (EQ/NE/GT/GTE/LT/LTE/CONTAINS/IN/IS_EMPTY numeric-coercing);
  `WorkflowFieldResolver` (payload + snapshot); controller @ `/api/v1/workflow-rules`
  (+dry-run + executions + metadata); BILL_POSTED/PAYMENT_RECORDED publish added.
  Adversarial review fixed 3 defects (worker-thread TenantContext, SSRF, LT/LTE-null).
  1595 backend tests pass. **Flutter rule-builder UI = follow-up.**
- [ ] **I3 Custom report builder + scheduled report emails + report tags** (L).
- [ ] **I4 PDF template gallery** per document (M).
- [ ] **I5 Customer & vendor portals** (L) — view/pay/accept/upload; MFA.
- [x] **I6 Fixed assets + depreciation schedules** (M) — DONE 2026-07-03. Register
  + SLM/WDV depreciation + dispose + income-tax schedule already existed; this
  session completed the "auto monthly journals": V29 `fixed_asset.status` CHECK
  (+FULLY_DEPRECIATED), `DepreciationJob` (monthly ShedLock cron, per-org, gated on
  `assets.auto_depreciation`, idempotent), terminal residue sweep + status flip in
  `runDepreciation`, `computeScheduleFor` + `GET /fixed-assets/{id}/schedule-preview`,
  FixedAsset in the G1 edit-log allowlist. 11 asset tests (2 new) + DepreciationJobTest
  (2); live-verified V29 constraint + endpoint on fresh DB.
  · **deferred revenue/expense** (M) — not started (amortization_schedule/entry
  tables already exist in baseline; same DepreciationJob pattern would drive it).
- [ ] **I7 Cash-basis report toggle** (M) · multi-dimension analytic plans (L).

## Phase J — Warehouse/WMS layer (Odoo parity)
- [ ] J1 Configurable routes (multi-step receipt/delivery) (L)
- [ ] J2 Putaway + removal strategies per location (M)
- [ ] J3 Warehouse barcode ops app (receive/pick/count) (L)
- [ ] J4 Packages / pack-in-pack (M) · J5 scheduled cycle counts (S)
- [ ] J6 Barcode label design/print (M) · J7 value-only adjustments (S)

## Phase K — Multi-country finish line (gate: first Gulf/Kenya customer)
- [ ] K1 Foreign-currency document ENTRY w/ live rates (L)
- [ ] K2 OMR 3-decimal sweep — ~200 setScale(2) + numeric(15,2) (L, blocks Oman)
- [ ] K3 Arabic/RTL adoption — ~3,030 strings + EdgeInsetsDirectional (L)
- [ ] K4 EmaraTax direct filing (M) · real PINT-AE ASP (M)
- [ ] K5 Kenya: eTIMS e-invoice (L), M-Pesa recon (M), PAYE/NHIF/NSSF (L)
- [ ] K6 Swahili l10n adoption (M)

## Phase E→ — UI backlog (detail lives in UI_FIELD_GAP_EXECUTION_PLAN.md)
- [ ] E5 trade-ops cluster: partner order loop, SCM create/detail, courier
  book/track, consignment UI
- [ ] E6 MR field app: RCPA capture, customer onboarding, **FCM token
  registration (both apps — pushes currently reach zero devices)**,
  collection mode/UTR, offline-first
- [ ] QC template management · GST rate-remap + month-end-close screens ·
  WhatsApp inbound-order inbox · org profile fields · contact form fields

## Phase L — Scale (gate: first heavyweight org / second replica)
- [ ] L1 Page or cap the unbounded report finders (M)
- [ ] L2 Trigram indexes for item/contact %search% (S)
- [ ] L3 Invoice-list N+1 batch fetch (S)
- [ ] L4 Partitioning/archival: stock_movement, journal_line,
  field_location_ping (L)

## Deliberately NOT doing (⬜)
TDL-style scripting, restaurant/kiosk POS, rentals, website/eCommerce,
IoT boxes, EU-specific VAT edges, group-company consolidation (multi-tenant
orgs ≠ statutory consolidation — revisit only if a customer asks).
