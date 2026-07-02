# Competitor Feature Matrix — TallyPrime · Zoho Books/Inventory · Odoo

**Purpose:** the granular ("low-level") feature inventory of the three benchmark
products, cross-marked against what katasticho has TODAY, so this doubles as a
gap backlog. Compiled 2026-07-02 from product knowledge + release notes
(TallyPrime 6.0/6.1, Odoo 18/19, Zoho Books 2025 updates).

**Legend (katasticho status):**
- ✅ built (backend + UI unless noted)
- 🟡 partial / backend-only / weaker shape
- ❌ missing
- ⬜ deliberately out of scope for an Indian-SMB + Gulf/Africa ERP

**Related internal docs (don't duplicate their detail):**
`TALLY_PARITY_AND_MIGRATION_PLAN.md` (Tally battle plan),
`architecture/inventory-feature-gap.md` (Zoho Inventory sprints),
`MANUFACTURING_FEATURE_TRACKER.md` (101 mfg features),
`AI_NATIVE_COMPETITIVE_ROADMAP.md`, `UI_FIELD_GAP_EXECUTION_PLAN.md`.

---

## 1. TallyPrime (through Release 6.1, Jun 2025)

### 1.1 Company & masters
- ✅ Multi-company data (we: multi-tenant orgs) — Tally: unlimited companies, company groups
- ❌ Group company / consolidated financials across companies
- ✅ Ledger master with opening balance (we: contacts + accounts w/ opening)
- ✅ Account groups hierarchy (28 predefined groups; nested subgroups)
- 🟡 Multiple addresses per ledger (we: billing+shipping on contact; not N addresses)
- ✅ Cost centres on ledger entries · ❌ cost CATEGORIES (parallel cost-centre dimensions)
- ✅ Stock groups / categories / godowns (we: item groups, warehouses, zones)
- ✅ Multiple UoM + alternate/compound units (we: UomService conversions)
- ✅ Standard rates (price lists) with applicability dates
- ❌ Ledger-wise credit period AND credit limit both enforced at voucher time (we: credit limit at SO only)
- ✅ Batch-wise + expiry masters · ✅ mfg date on batch
- ❌ Multiple mailing names / PAN per branch on one company
- ✅ HSN/SAC master at item/group level with effective-date slabs (we: hsn_gst_master + per-item override)

### 1.2 Voucher engine (the heart of Tally)
- ✅ Voucher types: Sales, Purchase, Receipt, Payment, Contra, Journal, Debit/Credit Note (we: all as documents/journals)
- 🟡 Custom voucher types (clone a type, own numbering/behaviour) — we: per-doc prefix only
- ❌ Voucher CLASS (pre-configured ledger allocation templates per voucher type — auto-splits freight/tax/rounding)
- ✅ Auto + manual voucher numbering, per-type prefix/suffix, per-FY restart
- ❌ Retain original voucher no. on insertion/deletion (renumbering policies)
- ✅ Post-dated vouchers (we: post-dated journals V56)
- 🟡 Optional vouchers (parked, excluded from books until regularised) — we: DRAFT status covers most of it
- ❌ Reversing journals (auto-reverse on a set date, scenario-only)
- ❌ Memorandum vouchers (non-posting scratch entries)
- ❌ Scenarios (include optional/reversing vouchers in what-if reports)
- ✅ Zero-valued entries (free samples) (we: zero-value SO/invoice lines)
- ✅ As-voucher vs as-invoice entry modes (we: journal form + document forms)
- ❌ Single-entry mode for payment/receipt/contra (list many ledgers against one cash/bank)
- ✅ Narration per voucher + 🟡 narration per LINE (we: per-line description on journals only)
- ❌ Voucher insertion between dates with automatic renumber
- ✅ Duplicate/clone voucher (we: WO clone, invoice from estimate etc.) · ❌ universal "duplicate any voucher" key
- ✅ Actual vs BILLED quantity on one line (bill 10, deliver 12 free) — 🟡 we: free-qty scheme lines approximate it
- ✅ Item + expense mixed invoices (we: GOODS + SERVICE lines)
- ✅ Discount column (percent) + ❌ separate trade vs cash discount columns
- ❌ Interest calculation ON a voucher (simple/compound, per-ledger rates, auto debit-note from interest) — we: report + one-click debit-note draft (🟡 close)
- ✅ Bill-wise details: new ref / against ref / advance / on account (we: invoice allocation, advances via customer receipts)
- ❌ Bill-wise SPLIT of one payment across N refs at entry keyboard-first (we: multi-invoice allocation exists in UI, heavier)
- ✅ Keyboard-first entry throughout (we: keyboard-parity program) — Tally still faster on pure numeric entry

### 1.3 Accounting features
- ✅ Trial balance, P&L, Balance Sheet, Day Book (all)
- ✅ Group summary drill-down → ledger → voucher → edit-in-place (we: report drill partial 🟡 — no edit-in-place from report)
- ✅ Cash/Bank books, columnar registers
- ✅ Outstanding receivables/payables, ageing buckets, bill-wise
- ✅ Cost centre reports + cost-centre P&L · ❌ cost category cross-tab
- ✅ Budgets (ledger/group) + variance (we: BudgetService)
- ✅ Interest on overdue (report) · 🟡 auto interest ledger postings
- ✅ Forex: multi-currency ledgers, realized gain/loss on settlement (we: engine built; docs are base-currency until FX entry ships 🟡)
- ❌ Unadjusted forex gain/loss auto-revaluation voucher at period end
- ✅ Year-end close + P&L transfer (we: YearEndCloseService)
- 🟡 Period locking (we: fiscal period close; Tally: date-based entry lock + Edit Log)
- ✅ Opening balance import (we: Tally masters import)
- ❌ Stock journal as accounting-inventory bridge voucher (we: separate transfer/adjustment docs — equivalent, different shape)

### 1.4 Inventory
- ✅ Godown-wise stock, transfers (we: warehouses + transfer orders)
- ✅ Batch/expiry/mfg-date tracking, batch-wise reports
- ✅ Stock valuation methods: FIFO, weighted avg (we: both, org setting) · ❌ LIFO, std cost, last purchase cost as alternatives
- ✅ Reorder levels + shortfall report (we: low-stock + requisitions)
- ✅ Stock ageing (we: stock ageing report)
- ✅ Movement analysis (in/out per item/party)
- ✅ Physical stock voucher (we: stock counts w/ variance)
- ❌ Stock item cost tracking per JOB (job costing via godowns/cost tracking numbers)
- ✅ Item-wise profitability (we: margin reports) · ❌ invoice-line gross profit shown DURING entry
- ✅ Alternate units billing (buy in boxes, sell in pcs)
- ❌ Tail-end conversions ("1 box = 10.5 pcs" fractional compound units edge cases we should verify
- ✅ Delivery note / receipt note (challans) with pending-doc tracking
- ✅ Rejection in/out vouchers (we: return orders + QC disposition)
- ❌ Sales/purchase order PENDING registers exactly Tally-shaped (we: have pendingDispatch etc. 🟡)

### 1.5 GST & statutory (India)
- ✅ GSTR-1 (B2B/B2CL/B2CS/CDNR/CDNUR/HSN/docs) + JSON/Excel export
- ✅ GSTR-3B computation
- ✅ GSTR-2B reconciliation (auto-fetch via GSP + upload) — Tally 6.1: IMS
- ✅ IMS (Invoice Management System) accept/reject/pending (we: D4 done)
- ✅ e-invoice IRN generate/cancel (GSP one-click + offline JSON)
- ✅ e-way bill generate/cancel, threshold detection, vehicle aggregate
- ✅ Composition scheme (CMP-08, GSTR-4 calendar swap)
- ✅ TDS (194x sections, thresholds, 26Q) + TCS (206C(1H), 27EQ)
- ✅ HSN summary B2B/B2C split (Phase III, eff Apr-2025) — verify our HSN summary splits B2B vs B2C 🟡
- ❌ TDS on GST-inclusive edge configurations per-nature-of-payment master UI
- ✅ RCM flags 🟡 (we: partial — verify reverse-charge purchase flow end-to-end)
- ❌ GST rate SETUP wizard with effective-date rate history per item/group (we: single rate + override; no dated history)
- ✅ GSTR-1 offline Excel/CSV upload prep (6.1) — we: JSON; Excel export 🟡
- ❌ Form 26Q/27EQ FVU-file generation for TDS on payments other than salary (we: salary 24Q FVU done; vendor-TDS 26Q is report-only)
- ✅ MSME 45-day payable tracking (we: OverdueBillJob + ageing) · ❌ MSME Form 1 Annexure export (supplier-wise, PAN, within/after 45 days)
- ❌ Audit trail (MCA Edit Log) — every create/alter/delete versioned with user+time, Edit Log SUMMARY report (we: audit_log rows for some flows only 🟡)

### 1.6 Banking
- ✅ Bank reconciliation: import statement (CSV/XLSX), auto-match suggestions, create-voucher-from-statement (we: full recon + AI fallback)
- ✅ 6.0 enhanced BRS: unreconciled ageing, opening BRS carry-forward 🟡 (we: no opening-BRS carry concept)
- ❌ Connected Banking (live bank feeds: balances + statements pulled in-product, payment initiation from Tally)
- ✅ Cheque printing ❌ (we: none) — cheque register, post-dated cheque management ❌
- ✅ Payment advice / remittance emails 🟡 (we: WhatsApp/E-mail docs; no formal payment advice template)
- ❌ e-payments file export (bank-specific bulk payment files: HDFC/ICICI/SBI formats)
- ✅ UPI QR on invoices/receipts (we: POS UPI QR; invoice PDF QR 🟡 pending)

### 1.7 Payroll (Tally payroll is basic; we exceed in most areas)
- ✅ Employee masters, salary structures, attendance-linked pay
- ✅ PF/ESI/PT/TDS statutory + challans/returns (we: full incl. 24Q FVU + Form 16)
- ✅ Payslips, payment posting
- ❌ Employee category/group-wise cost allocation to cost centres
- ✅ Loans/advances 🟡 (we: advance via payroll components; no EMI schedule)
- ✅ Gratuity (we: Gulf gratuity; India gratuity provision ❌)

### 1.8 Data, security, platform
- ✅ User roles + per-feature rights (we: 5 roles + module gating; Tally: custom security levels per report/voucher ❌ finer)
- ❌ Tally Vault (password-encrypt whole company data at rest)
- ✅ Data export: Excel/CSV/PDF/XML (we: CSV/XML/PDF per report; universal any-report export 🟡)
- ✅ Import: masters + vouchers XML/Excel (we: Tally XML both, Excel items/contacts)
- ✅ Backup/restore (we: pg scripts) · ❌ in-product one-key backup/restore UX
- ❌ Data split by financial year / verify+repair tooling
- ✅ ODBC/API access (we: REST + API keys + MCP)
- ❌ TDL extensibility (custom reports/screens via definition language) — our analog: none (⬜ by design; org_settings + code)
- ✅ Multi-user concurrent entry (we: web-native)
- ✅ Remote access (we: cloud-native; Tally: browser reports read-only + AWS hosting)
- ✅ WhatsApp document delivery (6.x: send invoices via WhatsApp Business) (we: full WhatsApp doc templates)
- ❌ "TallyCapital" embedded lending / bill discounting marketplace (we: roadmap F)
- ✅ Dashboards (Tally 3.0+ tiles) (we: richer)
- ❌ Change-voucher-date/period keys + calculator pane at bottom (micro-UX; keyboard parity program covers most)

---

## 2. Zoho Books + Zoho Inventory (2025)

### 2.1 Org & setup
- ✅ Multi-org, per-org base currency, fiscal year, industry (we: same + country profiles)
- ✅ Multi-branch with branch-wise reporting + GSTIN per branch 🟡 (we: branches exist; branch GSTIN/series partial)
- ✅ Roles & fine-grained permissions 🟡 (Zoho: per-module create/edit/delete/approve matrix; we: 5 fixed roles)
- ✅ Custom fields on every entity (Zoho: 40+ types incl. lookup, formula) ❌ (we: none — big platform gap)
- ❌ Custom buttons / links, page layouts per module
- ✅ Org-level templates: invoice/estimate/PO PDF templates, multiple per type 🟡 (we: fixed PDF layouts + receipt settings)
- ❌ Client portal branding, custom domain
- ✅ Audit trail per entity 🟡 (we: some)
- ✅ Data backup export (full org zip) ❌ (we: DB-level only)

### 2.2 Items & inventory (Books + Inventory app)
- ✅ Item types: goods/service; sales+purchase info double-sided
- ✅ Item groups with attribute-based variants (we: groups/variants entities; UI 🟡)
- ✅ Composite items/kits + BOM assembly (we: BOM + composite)
- ✅ Batch tracking + expiry, serial tracking (we: both)
- ✅ Multi-warehouse, bin locations 🟡 (we: zones + racks)
- ✅ Reorder point per item(+warehouse) with notification
- ✅ Barcode generation/printing ❌ (we: scan yes, label design/print no)
- ✅ Price lists (sales+purchase, per-currency, per-customer) — we: sales; purchase price lists 🟡 (rate contracts)
- ✅ Inventory adjustments (qty + VALUE types) with reason + approval 🟡 (we: qty adjustments; value-only adjustment ❌)
- ✅ Inventory adjustment summary/details reports (2025) 🟡
- ✅ FIFO valuation + landed cost on bills (we: FIFO + GRN landed cost)
- ✅ Transfer orders between warehouses
- ✅ Picklists, packing slips, shipment tracking w/ carrier integrations (we: picklist+shipment; live carrier tracking via Shiprocket-style ❌, courier module 🟡)
- ✅ Backorders + dropship (from SO create dropship PO) — dropship ❌ (we: backorder yes)
- ❌ Inventory age / FSN-style analysis (we: stock ageing ✅, FSN ❌)

### 2.3 Sales cycle
- ✅ Estimates/quotes → invoice conversion, expiry, customer accept/decline in portal (portal ❌)
- ✅ Sales orders → invoice/DC; partial fulfilment
- ✅ Retainer invoices (advance collection) 🟡 (we: customer receipts/advances — not a retainer doc)
- ✅ Recurring invoices with card autocharge ❌ autocharge (we: recurring invoices ✅)
- ✅ Payment reminders (auto, per-contact schedule) + thank-you note (we: PaymentReminderJob + WhatsApp)
- ✅ Customer credits: credit notes, apply across invoices, refunds
- ✅ Delivery challans (India) + e-invoice/e-way (we: full)
- ✅ Write-off invoice / bad debt
- ✅ Payment gateways (Razorpay/Stripe/...) with payment links on invoice ❌ (we: UPI QR only)
- ✅ Customer portal: view/pay invoices, statements, accept quotes, upload docs ❌ (we: none — contact_portal table vestigial)
- ✅ Invoice PDF: multi-template, multilingual invoice, digital signature ❌ DSC-signing (we: single layout, ₹-locale)
- ✅ TCS/TDS on receivables (we: TCS ✅, TDS-receivable 🟡)

### 2.4 Purchases
- ✅ Purchase orders → bills → payments made; expected delivery, dropship/backorder linkage (dropship ❌)
- ✅ Bills with landed cost allocation; three-way context (we: 3-way match stronger than Zoho's)
- ✅ Recurring bills ❌ (we: recurring invoices only, not bills)
- ✅ Vendor credits, refunds, apply to bills
- ✅ Payments made w/ multi-bill allocation + advance (we: vendor payments + allocations)
- ✅ Purchase approvals (multi-level) (we: approval workflows, org-configurable)
- ✅ Vendor portal (view POs, submit invoices) ❌

### 2.5 Banking
- ✅ Bank feeds (auto-fetch via aggregators) ❌ live feeds (we: file import + AI parse)
- ✅ Matching rules engine (auto-categorise txns by rules) 🟡 (we: suggestion heuristics; user-defined rules ❌)
- ✅ Uncategorised-transactions workbench (we: recon screen)
- ✅ Bank rules for transfer/customer payment/vendor payment classification 🟡

### 2.6 Accountant & books hygiene
- ✅ Manual journals + recurring journals 🟡 (recurring journals ❌) + journal workflow rules (2025) ❌
- ✅ Chart of accounts w/ custom accounts, account codes, parenting
- ✅ Opening balances editor (per-account+per-contact screen) 🟡 (we: via imports)
- ✅ Base-currency adjustment (unrealised forex revaluation) ❌
- ✅ Transaction locking (date lock w/ reason; partial unlock for specific users) 🟡 (we: period close; user-scoped unlock ❌)
- ✅ Accountant/adviser seat + comments on transactions (we: CommentService ✅ on docs)

### 2.7 GST India & global tax editions
- ✅ GSTR-1/3B, 2A/2B recon, e-invoice, e-way (we: parity or better)
- ✅ GST payment challan tracking + ITC utilisation 🟡 (we: gst/close month-end exists; challan record UI ❌)
- ✅ Multi-edition tax: US sales tax, UK/EU VAT+MTD, UAE VAT + EmaraTax direct filing (2025), KSA, Australia, Kenya... (we: IN full, AE/OM VAT return ✅, EmaraTax API filing ❌, KE seeded ✅ no eTIMS)
- ✅ VAT MOSS/reverse charge/self-billing edges ⬜ (EU-specific)

### 2.8 Automation & extensibility (Zoho's real moat)
- ❌ Workflow rules on ANY module (criteria → email/field-update/webhook/custom function) — we have some hardcoded automations
- ❌ Custom functions (Deluge scripting) + schedules
- ❌ Webhooks per event, incoming/outgoing
- ✅ API (full REST) + rate limits (we: REST + API keys)
- ❌ Zoho Flow / marketplace of 500+ integrations (we: integration connectors CRUD stub)
- ❌ Client-facing approval + esign (Zoho Sign) on estimates
- ✅ WhatsApp/SMS/email document channels (we: parity+)
- 🟡 AI: Zia — anomaly detection ✅ (we better), auto-categorisation ❌ UI, invoice-from-voice ⬜

### 2.9 Reporting
- ✅ 60+ canned reports; ours cover the core set
- ❌ Custom report builder (choose columns/filters/grouping, save, schedule email)
- ✅ Scheduled report emails ❌ (we: none)
- ✅ Report tags (segment P&L by tag/dimension) 🟡 (we: cost centres only)
- ✅ Cash-basis AND accrual-basis toggle on reports ❌ (we: accrual only)
- ✅ Consolidated multi-branch reports 🟡

---

## 3. Odoo 18/19 (Community + Enterprise)

### 3.1 Accounting
- ✅ Full double-entry, multi-journal (sale/purchase/bank/cash/misc) (we: source-module journals)
- ✅ Multi-currency with rate feeds ❌ auto rate feeds (we: manual rates)
- ❌ Multi-company with inter-company auto-transactions (⬜/❌ — our multi-tenant ≠ consolidation)
- ✅ Analytic accounting: plans, distributions %-split across dimensions ❌ (we: single cost centre)
- ✅ Budgets (19: standalone, subplans) ✅ basic
- ✅ Bank reconciliation widget + rules (19: keyboard-first, mobile) (we: ✅ recon, rules ❌)
- ✅ Payment terms w/ instalments (30% now, 70% 30d) ❌ instalment terms (we: single due date)
- ✅ Follow-up levels (dunning: escalating reminder letters per ageing bucket) 🟡 (we: single reminder cadence)
- ✅ Assets: purchase → depreciation board → auto monthly entries ❌ (we: fixed assets vestigial)
- ✅ Deferred revenue/expense recognition ❌
- ✅ Storno/negative-line accounting for some locales ⬜
- ✅ Tax engine: tax groups, incl/excl price, cash-basis taxes ✅ (we: group-based engine; cash-basis ❌)
- ✅ Fiscal positions (auto tax/account swap by customer country/type) 🟡 (we: country-gated tax; per-contact override ❌)
- ✅ PEPPOL e-invoicing (19: send+receive) ⬜ EU; UAE PINT stub 🟡 ours
- ✅ Combined statement report (BS+P&L+TB single view, 19) ❌
- ✅ Audit trail "light" (19) 🟡
- ✅ Check printing, SEPA payment files ⬜/❌
- ✅ Loans management (19) ❌
- ✅ Disallowed expenses, tax lock date, hash-chained entries (inalterability, FR) ❌ hash-chain (relevant for MCA audit trail later)

### 3.2 Sales & CRM edge
- ✅ Quotation templates + optional lines + online sign+pay ❌ portal sign/pay
- ✅ Pricelists: rules by qty/date/category, formula (cost+margin) 🟡 (we: flat price lists + schemes)
- ✅ Discounts, loyalty, gift cards, eWallet (POS+sales) 🟡 (we: loyalty module basic)
- ✅ Upsell alerts on delivered>ordered, invoice policies (ordered vs delivered qty) 🟡
- ✅ Subscriptions (recurring w/ prorations, upsell mid-term) ❌ (we: recurring invoices only)
- ✅ Rental management ❌ ⬜?
- ✅ Commissions plans (19) ❌ (we: salesman incentives 🟡 targets only)

### 3.3 Purchase
- ✅ RFQ → compare quotes → PO (call for tender) (we: RFQ compare ✅)
- ✅ Blanket orders / purchase agreements (we: rate contracts ✅)
- ✅ Reordering rules (min/max) + procurement run (we: reorder + MRP)
- ✅ Vendor pricelists + lead times per vendor (we: item_supplier ✅)
- ✅ 3-way matching (we: ✅ richer statuses)
- ✅ Purchase approvals by amount threshold (we: workflow ✅)

### 3.4 Inventory (WMS-grade)
- ✅ Multi-warehouse, multi-step routes (pick→pack→ship, input→QC→stock) ❌ configurable ROUTES (we: fixed flows + zones)
- ✅ Push/pull rules, replenish-on-order (MTO route) 🟡 (we: MTO/MTS per item ✅ but not route engine)
- ✅ Lots/serials w/ full traceability up/down (we: ✅ batch trace/recall)
- ✅ Expiry: alert/removal dates, FEFO removal strategy (we: FEFO ✅)
- ✅ Removal strategies: FIFO/LIFO/FEFO/closest location ❌ per-location removal config
- ✅ Putaway rules (product/category → bin) ❌
- ✅ Barcode app: receive/pick/pack/adjust/cycle-count via scanner (19 rework) 🟡 (we: POS scan + shop-floor scan; warehouse-ops scanning app ❌)
- ✅ Cycle counts (19: during ops) 🟡 (we: stock counts, not cycle-scheduled)
- ✅ Packages & multi-level packaging ("pack-in-pack", 19 unified UoM) ❌ package entity
- ✅ Landed costs (we ✅)
- ✅ Consignment stock (we ✅ backend, UI ❌)
- ✅ Scrap, quality holds (we ✅)
- ✅ Forecasted stock report w/ direct replenish buttons (19) 🟡 (we: MRP + ATP badge)
- ✅ Dropshipping route ❌
- ✅ Inter-warehouse resupply rules ❌ (we: manual transfer orders)

### 3.5 Manufacturing suite (MRP + Quality + Maintenance + PLM)
- ✅ BOMs: multi-level, variants ("apply on variant"), by-products, kits (we: all ✅)
- ✅ Routings/work centers, capacity, OEE, costs (we ✅)
- ✅ Work orders + shop-floor tablet UI (19: kanban card ops) (we: shop-floor ✅)
- ✅ MPS (master production schedule) ❌ (we: MRP ✅, MPS grid ❌)
- ✅ Gantt planning of MOs w/ finite capacity (19) ❌ (tracked: tracker Gantt)
- ✅ Subcontracting (ship components → receive finished) (we: job work ✅)
- ✅ Quality control points/checks per operation, SPC charts ❌ SPC (we: QC ✅)
- ✅ Maintenance: preventive calendar, MTBF/MTTR (we ✅)
- ✅ PLM: ECOs w/ approval + BOM version diff (we: BOM versions+diff ✅; ECO workflow ❌)
- ✅ Unbuild orders (we: disassembly ✅)
- ✅ IoT boxes (scale/camera/footswitch) ⬜

### 3.6 POS
- ✅ Offline-capable POS, multi-session, cashier PINs (we: offline queue ✅; sessions/PINs 🟡 cash register)
- ✅ Restaurant mode: floors/tables/kitchen display ⬜ (unless F&B vertical matters → ❌)
- ✅ Self-order kiosk/QR menu ⬜
- ✅ Loyalty/gift cards at POS 🟡
- ✅ Payment terminals integration (card machines) ❌ (we: UPI QR)
- ✅ Combo products (19) ❌

### 3.7 HR & Payroll
- ✅ Employees, contracts, leaves, attendances, appraisal, recruitment, fleet — we: 9 Core-HR modules ✅; appraisal/recruitment/fleet ❌
- ✅ Payroll rule engine per-country (salary rules as code) 🟡 (we: IN + Gulf hardcoded-but-tested)
- ✅ Expenses w/ OCR receipt scan + approval (we: expenses ✅, OCR 🟡 via bill scan only)
- ✅ Timesheets → invoicing (billable) 🟡 (we: timesheets ✅, timesheet→invoice ❌)

### 3.8 Platform (why Odoo wins deals)
- ❌ Studio: drag-drop add fields/views/automations without code
- ❌ Website + eCommerce natively sharing inventory/pricing (⬜? — partner-network is our B2B answer)
- ✅ Documents/DMS w/ OCR inbox → create bill (we: bill drafting ✅)
- ❌ Discuss (chat) / activities / chatter-on-every-record (we: comments on some docs 🟡)
- ✅ Email templates+servers per company 🟡
- ✅ Access rights per record rules (row-level rules language) ❌ finer than our roles
- ✅ AI (19): AI fields, agent on database ✅ (we: AI-first is our thesis — ahead on accounting agents, behind on generic "AI fields")
- ✅ Data import UX: column-map w/ preview on every list ❌ generic importer (we: per-domain importers)
- ❌ Multi-language record translations (product names per language)

---

## 4. Synthesis — ranked "steal list" for katasticho

**From Tally (defend the home turf):**
1. ❌ Edit Log / MCA audit trail (versioned voucher history + summary report) — compliance table-stakes for India Pvt Ltd cos; we have partial audit rows only.
2. ❌ MSME Form 1 export (supplier-wise 45-day annexure) — cheap on top of existing ageing.
3. ❌ Voucher classes + single-entry mode — the two biggest data-entry speed features we lack.
4. ❌ Connected banking (live feeds + payment initiation) — Tally 6.0 raised the bar; our aggregator-file import is one step behind.
5. ❌ Cheque printing + bank e-payment files — small-firm reality.
6. 🟡 Interest auto-voucher, forex revaluation voucher, reversing/memorandum vouchers, scenarios.

**From Zoho (SaaS hygiene):**
1. ❌ Custom fields everywhere + workflow rules + webhooks — the extensibility trio; biggest structural gap vs both Zoho and Odoo.
2. ❌ Customer/vendor portals (view/pay/accept) with payment-gateway links.
3. ❌ Custom report builder + scheduled report emails + report tags.
4. ❌ Bank matching RULES (user-defined) on top of our suggestions.
5. ❌ Recurring bills, recurring journals; cash-basis report toggle.
6. ❌ PDF template gallery per document + DSC signing; EmaraTax direct filing for UAE.

**From Odoo (ops depth):**
1. ❌ Configurable warehouse routes + putaway/removal strategies + barcode ops app — the WMS layer above our fixed flows.
2. ❌ Payment terms with instalments + dunning levels.
3. ❌ Fixed assets w/ depreciation schedules; deferred revenue/expense.
4. ❌ Analytic plans (multi-dimension P&L) beyond single cost centre.
5. ❌ MPS + Gantt scheduling (mfg tracker already lists Gantt).
6. ❌ Subscriptions engine; commission plans for field force.

**Cross-product theme:** all three ship (a) user-defined automation, (b) portals,
(c) template/report customisation. We compensate with AI-first flows + vertical
packs (pharma/FMCG/field-force) that none of them have at our depth — but the
extensibility trio is the platform debt to schedule first.

---

*Sources: TallyHelp release notes 6.0/6.1; Odoo 18/19 release notes; Zoho Books
2025 product-update posts + feature/release-notes pages; product knowledge
through Jan 2026. Statuses reflect CLAUDE.md + the 2026-07-02 five-audit review.*
