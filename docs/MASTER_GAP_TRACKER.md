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
- [ ] **G2 MSME Form 1 annexure** (S) — supplier-wise paid/outstanding within vs
  after 45 days + PAN, CSV export.
- [ ] **G4 Vendor-TDS 26Q FVU/CSV file** (M) — mirror the salary 24Q generator
  for vendor TDS (report exists, file export doesn't).
- [ ] **G5 GST rate history w/ effective dates** per item/HSN (M).
- [ ] **G6 India gratuity provision** (S) — Gulf accrual exists; add IN.

## Phase H — Daily-use money features
- [ ] **G3 POS credit / khata → AR** (M) — CREDIT payment mode on receipt,
  requires contact, posts DR AR (not cash), feeds contact outstanding +
  collections. UI_FIELD_GAP C2.
- [ ] **H1 Payment-gateway links on invoices** (M) — Razorpay/Stripe link +
  webhook → auto payment record (UPI QR exists).
- [ ] **H2 Instalment payment terms + dunning levels** (M) — Odoo parity.
- [ ] **H3 Recurring bills + recurring journals** (S each).
- [ ] **H4 User-defined bank matching rules** (M) — on top of suggestions.
- [ ] **H5 Cheque printing + bank bulk e-payment files** (M).
- [ ] **H6 Connected banking feeds** (L, aggregator dependent).
- [ ] **H7 Voucher classes + single-entry mode** (M) — Tally entry speed.
- [ ] **H8 Interest auto-voucher schedule + period-end forex revaluation
  voucher** (M).

## Phase I — Platform extensibility (the trio every competitor sells against us)
- [ ] **I1 Custom fields** on core entities (L) — typed, org-scoped, on
  contact/item/invoice/bill first; DTO+UI plumbing.
- [ ] **I2 Workflow rules + webhooks** (L) — criteria → email/field-update/
  webhook on document events (domain_event bus already exists).
- [ ] **I3 Custom report builder + scheduled report emails + report tags** (L).
- [ ] **I4 PDF template gallery** per document (M).
- [ ] **I5 Customer & vendor portals** (L) — view/pay/accept/upload; MFA.
- [ ] **I6 Fixed assets + depreciation schedules** (M) · **deferred
  revenue/expense** (M).
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
