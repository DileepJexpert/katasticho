# CLAUDE.md

Reference for working in this repo efficiently. Read this first; avoid re-exploring what's already documented here.

## Stack
- **Backend:** Spring Boot 3.3.5, Java 21, JPA/Hibernate, Flyway, PostgreSQL. Build: Maven (`./mvnw`).
- **Frontend:** Flutter (`flutter_app/`) — Riverpod + GoRouter + Dio.
- **Root layout:** `src/` (backend), `flutter_app/` (mobile/web), `docs/`, `scripts/`, `samples/`, `test-data/`.

## Build & Test
```bash
# Backend compile / test (run from repo root)
./mvnw -q compile
./mvnw -q test
./mvnw -q test -Dtest=ClassName        # single test class

# Flutter
cd flutter_app && flutter analyze
cd flutter_app && flutter test
```

## Backend Architecture
- Package root: `com.katasticho.erp`. Modules by domain: `accounting, ap, ar, auth, banking, contact, dashboard, gst, inventory, loyalty, notification, pharma, pos, pricing, procurement, reporting, sales, tax, workflow`, plus `common` (shared) and `platform`/`admin`.
- **Multi-tenant:** every org-scoped query is filtered by `TenantContext.getCurrentOrgId()`. Org-scoped entities extend the BaseEntity pattern (`org_id`, `is_deleted`, audit timestamps).
- **Controllers** return `ApiResponse.ok(...)` wrapper. Guard with `@PreAuthorize("hasAnyRole(...)")`. Roles: `OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER`.
- **Exceptions:** `BusinessException.notFound("Entity", id)` or `new BusinessException(msg, "CODE", HttpStatus.X)`.
- **Platform-level reference tables** (NO org_id, NO BaseEntity): `salt_master`, `drug_master`, `manufacturer_master`, `hsn_gst_master`, `generic_substitution`, `drug_interaction`, `gst_state_code`. `rack_location` IS org-scoped.

## Flyway Migrations
- Location: `src/main/resources/db/migration/`. **Squashed 2026-06-12** (old V1-V71 chain deleted; DB is recreated from scratch): `V1__baseline_schema.sql` (full schema, CREATE-only, generated via pg_dump after applying the historical chain to PostgreSQL 16 and diff-verified identical) + `V2__seed_reference_data.sql` (drug/salt/manufacturer/HSN masters — deduped, post-GST-2.0 rates — substitutions, interactions, coa_template, currency, ai_model_registry) + `V3__seed_drug_master_extended.sql` (Marg-style preloaded medicine catalog: ~22.5k branded products from the open A-Z Indian medicine dataset, top-3 brands per salt composition with marquee-house preference, MRP/pack/manufacturer/composition, all HSN 3004 @ 5%). `V4__drug_schedule_h1_and_exempt_drugs.sql` (Schedule H1 overlay + 36 nil-rated lifesaving drugs) + `V5__detail_aids.sql` (e-detailing) + `V6__gst_state_code_master.sql` (38 official GST/TIN state codes — platform reference, Marg-parity dropdown/GSTIN-prefix lookup) + `V7__hsn_gst_directory_expansion.sql` (36 common kirana/FMCG/general HSN rows at post-GST-2.0 rates — dairy/produce/staples/oils/personal-care/etc; ambiguous codes salt 2501, tea/coffee, namkeen 2106 deliberately omitted) + `V8__field_reporting_hierarchy.sql` (app_user.reports_to_user_id — field MR→ABM→RBM hierarchy) + `V9__stockist_secondary_sales.sql` (stockist Stock & Sales Statement — secondary-sales loop) + `V10__rcpa_chemist_audit.sql` (Retail Chemist Prescription Audit — own-vs-competitor brand share) + `V11__hr_leave_management.sql` (HR portal leave: types/holidays/balances) + `V12__hr_attendance_regularization.sql` (HR attendance regularization) + `V13__hr_shift_management.sql` (HR shifts + assignments) + `V14__hr_timesheets.sql` (HR project/task timesheets) + `V15__hr_help_desk.sql` (HR help-desk tickets + comments) + `V16__hr_employee_documents.sql` (HR employee documents w/ category+expiry, reuses AttachmentService) + `V17__hr_offboarding.sql` (HR offboarding + clearance tasks) + `V18__hr_employee_profile.sql` (HR self-service employee profile — personal/emergency details on the payroll Employee master) + `V19__contact_portal.sql` (customer/vendor self-service portal accounts — external email+password logins) + `V20__field_sync_log.sql` (field offline-sync idempotency ledger) + `V21__pos_offline_receipt_link.sql` (sales_receipt.offline_receipt_number — ties a synced receipt to the OFF-xxxx number the customer was given offline) + `V22__fixed_assets.sql` (fixed-asset register + dual depreciation: book/Companies-Act SLM|WDV posted to GL, income-tax block-of-assets computed) + `V23__amortization_schedules.sql` (recurring amortization: prepaids/deferred-income/accruals → idempotent monthly recognition journal) + `V24__gst_filing_snapshot.sql` (one row per org+period recording filing-data provenance: source GSTR_2A|GSTR_2B|UPLOAD + refreshed_at + entry_count — powers the ITC-at-risk "how fresh is this signal" line). **Next new migration = V25.**
- Latent fresh-install bugs fixed during the squash: old V59 inserted into non-existent `account.system` (→ `is_system`); old V62's org-scoped `exchange_rate` collided with the V1 platform-level table (V62 shape kept — matches the JPA entity); old V62's currency-column DO-block guards checked the wrong column. The old chain only ever worked on incrementally-migrated DBs.
- V-number references in the phase notes below (V42, V67, ...) are historical — those files now live only in git history (pre-squash commit).
- Use `TIMESTAMPTZ` (not `TIMESTAMP`) for timestamp columns.

## Flutter / API Conventions
- **Dio baseUrl = `http://localhost:8080` with NO `/api/v1` prefix** → every API path string must include `/api/v1/...`.
- Endpoint paths live in `flutter_app/lib/core/api/api_config.dart`.
- `apiClientProvider` cascades invalidation across providers.
- Features under `flutter_app/lib/features/<feature>/presentation/...`.

## Accounting Rules (important domain logic)
- **POS receipts** → Cash/Revenue journal, NOT Accounts Receivable.
- **Contact "outstanding"** = openingBalance + invoices − payments (AR only).
- **HSN → GST mapping (post GST 2.0, Notification 9/2025-CT(Rate), eff. 2025-09-22):** chapter 30 (3001-3006 medicines/vaccines/dressings) = 5%, 9018/9019/9021 medical devices = 5%, 2106 supplements = 18% default (medicinal nutraceuticals may be 5% — override per item). The 33 notified lifesaving drugs are exempt **by drug name**, not HSN → model as items with gst_rate 0. Seeds: `V2__seed_reference_data.sql` hsn_gst_master (10 pharma rows) + `V7__hsn_gst_directory_expansion.sql` (36 common kirana/FMCG/general rows at post-GST-2.0 rates — note detergents 3402 stayed 18% while soap 3401 dropped to 5%; rates reflect pre-packaged retail, override per item for loose/unbranded).
- **Payment lifecycle:** DRAFT → {POSTED | PENDING_APPROVAL}; PENDING_APPROVAL → {POSTED | VOIDED}.
- **Approval workflows:** seeded but `active=false` by default — nothing triggers until an admin activates.
- **Inventory costing (V57):** org setting `inventory.valuation_method` (`FIFO` default | `WEIGHTED_AVERAGE`) is now *honored*. FIFO uses `cost_lot`/`cost_lot_consumption`: each receipt opens a lot; each issue draws lots oldest-first (rows pessimistic-locked so concurrent issues serialize) and bakes the blended FIFO cost into the immutable `stock_movement.unit_cost`/`total_cost` (computed before the row is built). Valuation = Σ(remaining_qty × unit_cost) of active lots. Pre-FIFO stock is seeded as an opening lot from the weighted-average balance on first issue OR first receipt (`seedOpeningLotIfNeeded`), so a receipt-before-issue can't strand it. Reversals close (receipt) or restore (issue) lots — restore is skipped for lots whose backing receipt was itself reversed (no phantom resurrection). **COGS posting (`SalesInvoicePostingRule`) prorates per item**: blended unit cost of the dispatched SALE movements (SO→challans, or the invoice's own movements for direct invoices — stock is deducted BEFORE the journal posts in `InvoiceService.sendInvoice`) × THIS invoice's quantity, so partial invoices take only their share and a second invoice on the same SO never double-books cost; else falls back to `item.purchasePrice` (= weighted-average path, byte-for-byte unchanged). Bill void reverses each PURCHASE movement via `reverseMovement` (closes lots). `TransferOrderService.receive` carries the TRANSFER_OUT leg's recorded cost so a warehouse move can't change total inventory value. Report: `/api/v1/reports/fifo-valuation`; `stock-summary` values FIFO orgs at lot value. Engine: `inventory/service/FifoCostingService.java`.

## Git / Workflow
- Active feature branch: `claude/erp-requirements-doc-g0o1P`. Develop, commit, push here. Do NOT push elsewhere without permission.
- Push with `git push -u origin <branch>`; retry network failures with backoff.
- Do NOT create PRs unless explicitly asked.
- The bulk of existing history is the user's own Codex commits (`DileepJexpert@users.noreply.github.com`) — do not rebase/reauthor them.

## Pharmacy Masters (already implemented backend)
- `PharmacyMasterController` @ `/api/v1/pharmacy-masters`: manufacturers/search, hsn/search, hsn/{code}, rack-locations (GET/POST/seed-demo), substitutions, interactions/check.
- `DrugMasterController` @ `/api/v1/drug-master`: search, {id}, salts/search.

---

## Known Bugs (verified 2026-06-03 — fix by number when asked)

### ~~BUG-1: Sales Register tax JOIN inflates amounts~~ — FIXED (2026-06-04)
- Tax JOINs changed from invoice-level (`i.id`) to line-level (`il.id` via `source_line_id`) in `DetailedReportService.java:168-173`.

### ~~BUG-2: No posted-payment reversal path~~ — FIXED (2026-06-04, Codex)
- `voidPayment()` now handles POSTED payments: reverses journal via `journalService.reverseEntry()`, restores invoice balance via `updatePaymentStatus(amount.negate())`, adds pessimistic locking on invoice. 17 tests pass.
- ~~Residual concern~~ resolved: `voidPayment` calls `adjustContactOutstandingAr(+amount)`; covered by PaymentServiceTest assertion (2026-06-12).

### ~~BUG-3: Self-approval gap in workflows~~ — FIXED (2026-06-04, Codex)
- `ensureRequesterCannotApproveOwnRequest()` added at `ApprovalWorkflowService.java:211-217`. Throws `WORKFLOW_SELF_APPROVAL_FORBIDDEN` when `request.getRequestedBy().equals(currentUserId)`. Also improved `ensureApproverCanDecide()` to prioritize user-specific steps over role fallback. 6 tests pass.

### ~~BUG-4: Empty drug-interaction seeds~~ — FIXED (2026-06-04)
- V37 migration seeds 12 clinically significant interaction pairs using salts from V28 (Aspirin+Ibuprofen, Atorvastatin+Erythromycin, Ciprofloxacin+Theophylline, Sertraline+Tramadol, etc). All `ON CONFLICT DO NOTHING`.

### ~~BUG-5: Empty generic-substitution seeds~~ — FIXED (2026-06-04)
- V37 migration seeds 16 bidirectional substitution pairs using V28 drug_master brands (Crocin↔Calpol, Brufen↔Ibugesic, Omez↔Ocid, Azithral↔Azee, Taxim-O↔Cefix, etc).

### ~~BUG-6: Delivery challan dispatch — no stock validation~~ — FIXED (2026-06-04)
- `validateSufficientStock()` added before `recordMovement()` in `DeliveryChallanService.dispatch()`. Checks `stock_batch_balance` (batch lines) or `stock_balance` (non-batch lines). Throws `DC_INSUFFICIENT_STOCK` if short. 2 new tests + 6 existing pass (8 total).

### ~~BUG-7: POS receipt tax split approximation~~ — FIXED (2026-06-04)
- POS sales register now joins `hsn_gst_master` on `srl.hsn_code` to derive per-line GST rate. Tax computed arithmetically per line instead of equal-division across receipt lines. Handles intra/inter-state split.

### ~~BUG-8: V42 van_stock_balance UNIQUE constraint uses COALESCE expression~~ — FIXED (2026-06-06)
- PostgreSQL disallows expressions in table-level `UNIQUE()`. V42 fixed to use `CREATE UNIQUE INDEX` instead. V44 migration added as safety net for existing databases.

### ~~BUG-9: FieldSalesController OPERATOR can access admin operations~~ — FIXED (2026-06-06)
- Method-level `@PreAuthorize("hasAnyRole('OWNER','ADMIN')")` added to 21 admin endpoints: beat/route/van CRUD, customer assignment, assignments, van-transfers (load/confirm-load/return/confirm-return), day-close approve/reject, target create/update-achievement. Read-only, `/me`, visit action, and dashboard endpoints remain accessible to OPERATOR.

### ~~BUG-10: Field visit actions lack salesperson ownership check~~ — FIXED (2026-06-06)
- `ensureVisitOwnership()` added to checkIn, checkOut, skipVisit, recordVisitOrder, recordVisitCollection. Verifies `TenantContext.getCurrentUserId()` matches `RouteExecution.salespersonId`. Throws `FS_NOT_ASSIGNED_SALESPERSON` (403) if not.

### ~~BUG-11: Payroll payment recording doesn't create journal entries~~ — FIXED (2026-06-06)
- `recordPayment()` now posts DR Salary Payable / CR Payment Account via JournalService. `recordStatutoryPayment()` now posts DR {PF/ESI/PT/LWF/TDS} Payable / CR Payment Account. Both set `journalEntryId` on the payment entity.

### Previously reported as bugs but actually OK:
- **Payment over-collection:** `PaymentService.java:97-102` DOES validate `amount > balanceDue` and throws `AR_PAYMENT_EXCEEDS_BALANCE`. This is correctly implemented.
- **Report date filter params:** `DetailedReportService.java:225-226` correctly passes 10 params for 10 `?` placeholders in the UNION ALL query. No mismatch.

---

## Development Roadmap (follow in sequence)

Product direction: **Indian SMB ERP platform** with shared core + vertical packs.
See `docs/BRD_KATASTICHO_ERP.md` for full Business Requirements Document.
See `docs/DISTRIBUTOR_FIRST_DIRECTION_ASSESSMENT.md` for strategic rationale.

### Phase 0: QA & Bug Fixes (COMPLETE — all 7 bugs fixed)
**Goal:** Stabilize existing flows before adding new features.
**Reference:** `docs/PRODUCT_DEVELOPMENT_ROADMAP.md` (Resume Index 2026-06-03), `docs/how-to/DISTRIBUTOR_MANUAL_QA_CHECKLIST.md`
- Fix BUG-1 through BUG-6 listed above
- Manual QA per the 16-section checklist:
  1. Item master + opening stock
  2. Shortage → Purchase Order
  3. PO → draft Goods Receipt
  4. GRN → Receive Stock (batch, expiry, rack, cost)
  5. POS search + rack visibility
  6. Sales Order creation
  7. SO credit/overdue controls
  8. SO schemes (percent discount, buy-x-get-y)
  9. SO → Delivery Challan
  10. DC dispatch (stock deduction)
  11. DC → Sales Invoice (no duplicate stock movement)
  12. Payment + collection
  13. Credit Note approval
  14. Dashboard + reports
  15. Browser/session switching
  16. Full regression pass

### Phase 1: Distributor Core Hardening (COMPLETE — 2026-06-04)
**Goal:** Rock-solid SO→DC→Invoice and PO→GRN→Receive flows.
**Reference:** `docs/PRODUCT_DEVELOPMENT_ROADMAP.md` (Phase Roadmap items 1-7)
- ~~Distributor dashboard v2~~ — already complete (14 endpoints, 24 Flutter widgets)
- ~~Distributor operational reports~~ — pendingDispatch + challanNotInvoiced verified correct
- ~~Credit control E2E~~ — `SalesOrderResponse.warnings` added, Flutter dialog on SO create
- ~~Scheme application E2E~~ — MANUAL/AUTO/DISABLED working end-to-end
- ~~Pricing~~ — price-list resolution on SO, rate preservation on SO→Invoice confirmed
- ~~Payment approval E2E~~ — payment list shows PENDING_APPROVAL status
- ~~Credit Note approval E2E~~ — detail screen banner + status-aware menu + approval inbox nav

### Phase 2: Inventory Feature Parity (COMPLETE — 2026-06-04)
**Goal:** Match Zoho Inventory feature surface using existing architecture.
**Reference:** `docs/architecture/inventory-feature-gap.md` (NOTE: gap doc is stale — most S26-S29 backend features already implemented)
- **Sprint 26 (done):** FEFO auto-pick, batch balance, expiry alert job, GRN batch capture — all implemented + tested
- **Sprint 27 (done):** Physical count (StockCountService, 6 tests). Serial number tracking (SerialNumberService + controller). Barcode lookup endpoint (`GET /api/v1/items/by-barcode/{barcode}`).
- **Sprint 28 (done):** BOM/composite items — BomService with explosion, tested. Item groups/variants — entities exist.
- **Sprint 29 (done):** Price lists — PriceListService implemented. UoM — UomService + entities implemented.
- **Sprint 30 (done):** Transfer orders (TransferOrderService, 7 tests). Picklist generation (PicklistService, 8 tests, V39 migration).
- **Flutter screens:** Stock count (list/create/detail), transfer order (list/create/detail), picklist list — all created with routes and API config.

### Phase 3: Pharma Domain Pack (COMPLETE — 2026-06-04)
**Goal:** Complete pharma-specific features on top of distributor core.
**Reference:** Backend already exists in `PharmacyMasterService`. Flutter UI is missing.
- **HSN→GST auto-fill (done):** `HsnGstSearchWidget` — debounced search with GST rate chips. Integrated in item create form (pharmacy orgs). Auto-fills GST % on selection.
- **Manufacturer autocomplete (done):** `ManufacturerSearchWidget` — debounced search with country tags. Integrated in item create form (pharmacy orgs).
- **Rack location management (done):** `RackLocationsScreen` — warehouse dropdown, rack list, create sheet, demo seed button. Route: `/inventory/rack-locations`.
- **Drug interaction warning at POS (done):** `_checkDrugInteractions` in `pos_screen.dart` — collects compositions from cart items, calls `check-by-composition` endpoint, shows severity-coded warning dialog before payment. Non-blocking on API failure.
- **Composition-based interaction check (done):** `GET /api/v1/pharmacy-masters/interactions/check-by-composition?compositions=...` — splits on +/comma, resolves salt names, checks drug_interaction table.
- **Drug interaction seeds (done — BUG-4):** V37 migration seeds 12 clinically significant interaction pairs.
- **Generic substitution seeds (done — BUG-5):** V37 migration seeds 16 bidirectional substitution pairs.
- **Expiry settlement returns (done):** Near-expiry screen supports selecting batches → drafts supplier return (debit note) with pre-filled lines.
- **Near-expiry alert dashboard (done):** `NearExpiryScreen` with configurable days threshold, batch selection, return drafting. Dashboard widget links to `/inventory/near-expiry`.

### Phase 4: Reports Completion (COMPLETE — 2026-06-04)
**Goal:** Finish remaining reports + Flutter UI for all reports.
**Reference:** `docs/REPORTS_IMPLEMENTATION_STATUS.md`, `docs/REPORTS_P0_SPECIFICATION.md`
- **Day Book (done):** `OperationalReportService.dayBook()` — chronological journal entries, exposed via `/api/v1/reports/day-book`.
- **Vendor Statement (done):** `ContactLedgerService.getLedger()` — unified contact ledger for both customers and vendors, exposed via `/api/v1/contacts/{id}/ledger`.
- **Cash Flow (done):** `OperationalReportService.cashFlow()` — daily inflow/outflow from posted journals, via `/api/v1/reports/cash-flow`.
- **Journal Register (done):** `OperationalReportService.journalRegister()` — all journal entries with debit/credit totals, via `/api/v1/reports/journal-register`.
- **Low Stock Alert (done):** `OperationalReportService.lowStockAlert()` — items below reorder level with deficit/cost, via `/api/v1/reports/low-stock`.
- **GST Summary (done):** `OperationalReportService.gstSummary()` — output tax vs input credit for period, via `/api/v1/reports/gst-summary`.
- **Reports Hub (done):** Flutter `ReportsHubScreen` updated with 5 groups: Financial (7 reports), Sales & Receivables (6), Purchases & Payables (2), Inventory (3), Tax & Compliance (1).
- **Database indexes (done):** V40 migration adds 9 indexes for report query performance (invoice_date, bill_date, receipt_date, stock_movement_date, journal_entry_date, tax_line_source, payment_contact).
- **Generic report viewer (done):** `OperationalReportScreen` renders all operational reports with date pickers, search, column display, metrics summary.

### Phase 5: Payroll Module (COMPLETE — 2026-06-05)
**Goal:** Indian SMB payroll with PF/ESI/PT/TDS.
**Reference:** `docs/PAYROLL_IMPLEMENTATION_SPEC.md`
- **V41 migration (done):** 12 new tables (payroll_settings, employee, salary_component, employee_salary_structure, employee_salary_component, payroll_run, payslip, payslip_line, payroll_payment, statutory_payment, payroll_audit_log, payroll_document_snapshot). Added `salary_handling_mode` to organisation.
- **Backend (done):** `com.katasticho.erp.payroll` — 10 entities, 8 repositories, PayrollService (979 lines) with full lifecycle (DRAFT→CALCULATED→APPROVED→POSTED), PayrollController (20+ endpoints at `/api/v1/payroll`). ModuleCode.PAYROLL added.
- **Statutory calculations (done):** PF 12% of Basic, ESI 0.75%/3.25% of Gross (if ≤21000), PT ₹200 default, LWF ₹25+₹75.
- **Journal posting (done):** Via existing JournalService — DR Salary Expense/Employer Contributions, CR Salary Payable/PF/ESI/PT/LWF/TDS Payable accounts.
- **Flutter screens (done):** Employee list, employee create/edit form, payroll run list (with create dialog), payroll run detail (with lifecycle actions + payslip viewer), payroll settings. Routes and sidebar nav integrated.
- **328 tests pass.**

### Phase 6: AI Foundation (COMPLETE — 2026-06-05)
**Goal:** Cross-cutting AI decision layer (observe → suggest → review → learn).
**Reference:** `docs/AI_APPROACH_AND_ROADMAP.md`
- **Database (done):** V7 migration (ai_suggestion, domain_event, ai_pattern, ai_training_example), V13 (org_ai_settings), V14 (ai_model_run, ai_usage_log, ai_model_registry) — 7 tables total.
- **Backend entities & repos (done):** 7 JPA entities, 7 repositories in `com.katasticho.erp.ai`.
- **Rule-based agents (done):** `RuleBasedAiAgentService` (1772 lines) — anomaly detection, GST compliance, inventory intelligence agents. No external AI calls.
- **Domain event infrastructure (done):** `DomainEventPublisher`, `DomainEventProcessor`, `DomainEventHandler` interface, `DomainEventWorker`. `InvoicePostedAiEventHandler` listens to INVOICE_POSTED events.
- **AI services (done):** 14 services — AiSuggestionService, NlpQueryService, BillScanService, ItemScanService, VisionModelRouter, ClaudeApiClient, OllamaVisionClient, SqlValidator, SchemaProvider, AiTelemetryService, AiModelRegistryService, OrgAiSettingsService, plus controllers (AiController, AiSuggestionController).
- **Flutter AI Inbox (done):** `ai_chat_screen.dart` with inbox tab (accept/reject/modify suggestions) + assistant tab. Models and repository.
- **Tests (done):** 6 test classes in `src/test/java/com/katasticho/erp/ai/service/`.
- **Safety:** AI never directly posts journals, changes stock, or files GST — all through existing services.

### Phase 7: FMCG Field Execution Pack (COMPLETE — 2026-06-05)
**Goal:** Route/beat/van workflows for FMCG distributors.
**Reference:** `docs/DISTRIBUTOR_FIRST_DIRECTION_ASSESSMENT.md` (Gap #3)
- **V42 migration (done):** 13 new tables (beat, beat_customer, route, route_beat, van, van_stock_balance, field_sales_assignment, route_execution, field_visit, van_stock_transfer, van_stock_transfer_line, salesman_target, day_close) + 16 indexes.
- **Backend (done):** `com.katasticho.erp.fieldsales` — 13 entities, 13 repositories, FieldSalesService (1281 lines), FieldSalesController (51 endpoints at `/api/v1/field-sales`). ModuleCode.FIELD_SALES added. ReferenceType extended with VAN_LOAD/VAN_UNLOAD/VAN_RETURN.
- **Beat/Route planning (done):** Beat CRUD with customer assignment (visit sequence + frequency). Route CRUD with ordered beat linking. Route-by-day-of-week filtering.
- **Van stock (done):** Van CRUD with vehicle info + capacity. Van stock balance tracking. Van stock transfer (LOAD/UNLOAD/RETURN) with warehouse stock integration via InventoryService.
- **Field sales assignment (done):** Link salesperson → route + van + territory with effective dates.
- **Route execution (done):** Daily route execution lifecycle (PLANNED → IN_PROGRESS → COMPLETED). Auto-creates field visits from route's beats' customers. GPS check-in/check-out per visit. Order and collection recording per visit.
- **Day-close wizard (done):** Initiate from completed execution. Cash reconciliation (opening/collections/expenses/closing/deposited/variance). Stock and visit summaries. Submit → Approve/Reject lifecycle.
- **Salesman incentives (done):** Target CRUD (REVENUE/VOLUME/VISITS/COLLECTIONS/NEW_CUSTOMERS). Achievement tracking with percentage and incentive amount calculation.
- **Secondary-sales dashboard (done):** Aggregated KPIs (routes, visits, productive %, orders, collections) with date range.
- **Flutter screens (done):** Beat list, route list, van list, route execution (today's routes), execution detail (with visit actions), day close, salesman dashboard. Routes and sidebar nav integrated, gated by `canUseFieldSales`.
- **328 tests pass.**

#### Live Field Tracking (2026-06-12)
- **V67 migration:** `field_location_ping` (append-only GPS breadcrumbs, no soft delete) + `field_visit.geo_verified`/`geo_distance_m`.
- **`FieldTrackingService`:** `recordPings()` (batched, max 500, org/user stamped from TenantContext), `liveLocations()` (latest ping per salesperson today, names via AppUserRepository), `trail(executionId)` (pings + haversine total km). Static `distanceMeters()` haversine.
- **Geofenced check-in:** `FieldSalesService.checkIn` → `applyGeofence()` compares check-in GPS vs `beat_customer.geo_latitude/longitude`; radius org setting `field_sales.geofence_radius_m` (default 250m). Flags (never blocks): sets `geoVerified` true/false + distance; null when customer has no stored coords.
- **Endpoints:** `POST /api/v1/field-sales/locations/ping` (any field role), `GET /locations/live` + `GET /locations/trail/{executionId}` (OWNER/ADMIN).
- **ERP Flutter:** `LiveTrackingScreen` (`/field-sales/live-tracking`) — 30s auto-refresh list, stale (>15min) highlighting, open-in-Google-Maps, trail bottom sheet (distance + ping count). Sidebar + command palette wired.
- **Field app (katasticho-mr-salesman-app):** `LocationPingTracker` (3-min foreground Timer while execution IN_PROGRESS, auto start/stop from visits screen `_syncPingTracker`), pings queue offline as `LOCATION_PING` on network failure, geofence warning snackbar after check-in.
- **Tests:** FieldTrackingServiceTest (7) + 3 geofence tests in FieldSalesServiceTest. 647 total pass.

#### Pharma MR Pack — Phase 1 (2026-06-12)
**Goal:** MR-reporting parity with CBO ERP-style SFA (doctor masters, MTP, DCR). Phases 2-3 pending: samples/gift stock, TA/DA auto-calc, DCR nudges, hierarchy dashboards, coverage/deviation reports, e-detailing.
- **V68 migration:** contact MR columns (`medical_category` DOCTOR/CHEMIST/STOCKIST/HOSPITAL, `specialty`, `mr_class` A/B/C, `visits_per_month`), `tour_plan` + `tour_plan_entry` (MTP, unique org+salesperson+month partial index), `dcr_report` (one per salesperson/day, unique partial index), `visit_product_log` (detailing/samples/gifts per visit), `field_visit.joint_visit_user_id`.
- **`MrReportingService`** (`fieldsales/service/`): tour plan lifecycle DRAFT→SUBMITTED→APPROVED/REJECTED (owner-only edits in DRAFT/REJECTED, entries must fall in plan month, empty-plan submit blocked, self-approval blocked `MR_SELF_APPROVAL_FORBIDDEN`); `logVisitProducts` (replace-style, post-check-in only, ownership via execution salesperson); `buildDcr` (create-or-refresh DRAFT from day's visits: doctor/chemist split via contact.medicalCategory, POB=Σ orderValue, samples from product logs); `submitDcr` (rebuilds first; FIELD_WORK needs ≥1 visit, LEAVE/MEETING/OFFICE don't); approve/reject mirror day-close.
- **`MrReportingController`** @ `/api/v1/mr` (FIELD_SALES module): tour-plans CRUD+lifecycle, `/tour-plans/pending` + `/dcr/pending` + approve/reject (OWNER/ADMIN), `/dcr/build|submit|me`, `PUT/GET /visits/{id}/products`, `POST /visits/{id}/joint-visit`.
- **Contact DTOs:** medicalCategory/specialty/mrClass/visitsPerMonth appended to CreateContactRequest + ContactResponse (single construction site in ContactService.toResponse).
- **ERP Flutter:** contact form "MR Profile" collapsible section; `MrApprovalsScreen` (`/field-sales/mr-approvals`, tabs: Tour Plans w/ entries bottom sheet, DCRs w/ summary line; approve/reject w/ reason dialog). Sidebar + command palette wired.
- **Field app:** app-bar MTP + DCR buttons. `TourPlanScreen` (+detail: add/remove day entries, activity types, submit, rejection banner), `DcrScreen` (today's summary metrics, work type, remarks, submit, history), "Detail" button on IN_PROGRESS/COMPLETED visits → `_DetailingSheet` (products + samples + gifts → PUT products).
- **Tests:** MrReportingServiceTest (16). 663 total pass.

#### Field Force Pack — Phase 2, vertical-neutral (2026-06-12)
**Direction shift:** field app features are for ALL verticals (FMCG/distribution/pharma) — pharma-only naming avoided; doctor/chemist split stays dormant unless contacts are classified.
- V69: `field_sample_txn` (ISSUE/RETURN register per salesperson) + `field_allowance_claim` (one per salesperson/day, unique index, expense-backed).
- **`FieldAllowanceService`:** TA = day's GPS trail km (haversine over `field_location_ping`, UTC day) × org setting `field_sales.ta_per_km`; DA = `field_sales.da_per_day` only on days with movement. `claim()` → dedupe by claim row → creates real expense (Travel & Conveyance 5240 / Cash 1010, mode CASH) via ExpenseService → claim row stores expense_id. Codes: FS_ALLOWANCE_ALREADY_CLAIMED / FS_ALLOWANCE_NOTHING_TO_CLAIM / FS_ALLOWANCE_ACCOUNT_MISSING.
- **`FieldSampleService`:** balance per product = issued − returned (register, JPQL sum) − distributed (native query: visit_product_log→field_visit→route_execution by salesperson), name-normalized merge; un-issued-but-distributed products show negative balance.
- **`DailyReportReminderJob`** (automation, cron `app.automation.daily-report-reminder.cron` default 18:30): per active org (opt-out `field_sales.daily_report_reminder=false`), salespeople with a route execution today but no SUBMITTED/APPROVED dcr_report get a push (`PushNotificationService.sendToUser`).
- **Endpoints (FieldSalesController):** `GET /allowance/me`, `POST /allowance/claim`, `GET /allowance/claims/me` (field roles); `POST /samples/issue|return`, `GET /samples/balance/{id}`, `GET /samples/transactions/{id}` (OWNER/ADMIN); `GET /samples/balance/me`.
- **ERP Flutter:** `FieldSamplesScreen` (`/field-sales/samples`, sidebar "Samples & TA/DA" + palette) — TA/DA rate config card (read/write `/api/v1/settings`), salesperson picker (`/api/v1/org/users`), balance table (issued/returned/distributed/balance, negative red), issue/return dialogs, txn history.
- **Field app:** DCR screen renamed "Daily Report", neutral metrics (Visits/Orders/Samples; Dr/Ch row only when >0), TA/DA card w/ one-tap Claim (hidden until org configures rates), "My sample stock" card. Labels de-pharma'd (Tour Plan, Daily Report).
- **Allowance modes (V70):** org setting `field_sales.allowance_mode` = `FLEXIBLE` (default — GPS km prefilled, salesperson may adjust e.g. to deduct personal detours) | `GPS` (strict, requested km ignored) | `MANUAL` (km required, `FS_ALLOWANCE_KM_REQUIRED`). Claim stores `distance_km` (claimed) + `gps_distance_km` (reference); expense description shows "X km claimed (GPS Y km)" when they differ so approvers see variance. ERP rate card has mode dropdown; field app claim dialog prefills GPS km (editable) or asks for km in MANUAL.
- **Tests:** FieldAllowanceServiceTest (8) + FieldSampleServiceTest (5). 676 total pass.

#### Field Force Pack — Phase 3 + real FCM push (2026-06-12)
- **Real FCM (HTTP v1):** `notification/push/FcmClient` — service-account JSON via `app.push.fcm.service-account-file|-json` property; OAuth2 assertion signed locally with jjwt RS256 (no Firebase Admin SDK), access token cached (expiry−5min, synchronized refresh). `PushNotificationService.dispatchToToken` sends for real when configured (stub log otherwise); 404/UNREGISTERED responses auto-deactivate the stale token. Activates daily-report reminders + all wired pushes.
- **`FieldCoverageService`** (read-only analytics): `deviationReport(month, salesperson)` — tour-plan entries vs route executions day-by-day → AS_PLANNED / MISSED / UNPLANNED_WORK / WORKED_ON_NON_FIELD_DAY / NO_PLAN (future days skipped); `frequencyCompliance(month, salesperson?)` — contacts with `visits_per_month` vs COMPLETED visits (JPQL join visit→execution; two queries, no null-UUID param), worst-gaps-first; `teamDashboard(from,to)` — per salesperson: route days, visits planned/completed/%, orders, collections, GPS km, DCRs submitted. Endpoints `GET /api/v1/mr/reports/deviation|frequency-compliance|team-dashboard` (OWNER/ADMIN).
- **Attendance + leave (V71, new `com.katasticho.erp.attendance` pkg, NOT module-gated):** `field_attendance` (one row/user/day, GPS-stamped punch in/out, unique index) + `leave_request` (PENDING→APPROVED/REJECTED/CANCELLED, overlap check `LEAVE_OVERLAPS`, self-approval blocked). `AttendanceService` + `AttendanceController` @ `/api/v1/attendance`: punch-in|punch-out|today|me|team(date, OWNER/ADMIN), leave apply|me|cancel|pending|approve|reject. Codes: ATT_ALREADY_PUNCHED_IN/OUT, ATT_NOT_PUNCHED_IN.
- **ERP Flutter:** `FieldCoverageScreen` (`/field-sales/coverage`, tabs Team/Deviation/Frequency — team row tap drills into deviation), `AttendanceScreen` (`/field-sales/attendance`, team punches by date + pending-leave approve/reject). Sidebar + palette wired.
- **Field app:** attendance card on Today dashboard (GPS punch in/out, on-duty status, leave-apply dialog w/ date range + type).
- **Tests:** AttendanceServiceTest (8) + FieldCoverageServiceTest (3). 687 total pass.

#### Field Reporting Hierarchy (2026-06-13) — CBO-ERP gap #1
- **V8 migration:** self-referencing `app_user.reports_to_user_id` (nullable) — arbitrary-depth field tree (MR→ABM→RBM→ZBM). `AppUser.reportsToUserId` + `AppUserRepository.findByOrgIdAndReportsToUserIdAndIsDeletedFalseOrderByFullNameAsc`.
- **`FieldHierarchyService`:** `assignManager` (self-manager + cycle guards: `FH_SELF_MANAGER`/`FH_CYCLE`), `directReports`, `downlineUserIds` (transitive BFS), `isAncestor` (walks up the chain w/ cycle-safe seen-set), `orgChart`.
- **Manager-based MR approvals:** `MrReportingService.ensureCanDecide` replaces the OWNER/ADMIN-only gate on tour-plan + DCR approve/reject — now OWNER/ADMIN **or** the submitter's reporting manager (any ancestor); self-approval still blocked (`MR_NOT_MANAGER`). Pending lists (`pendingTourPlans`/`pendingDcrs`) scope to the manager's downline for non-admins. Controller approve/reject/pending endpoints widened to OPERATOR (service enforces the relationship).
- **`FieldHierarchyController`** @ `/api/v1/field-sales/hierarchy`: `PUT /users/{id}/manager` + `GET /org-chart` (OWNER/ADMIN), `GET /my-team` (direct reports + downline count, any field role).
- **Downline-scoped coverage:** `FieldCoverageService` now scopes to the caller's tree — `teamDashboard` retains only the manager's downline (admins see all); `deviationReport`/`frequencyCompliance` guard `ensureCanView` (self or downline, else `FH_NOT_IN_TEAM`). Report endpoints widened to OPERATOR.
- **Tests:** FieldHierarchyServiceTest (5) + MrReportingServiceTest +3 + FieldCoverageServiceTest +1 (downline scoping). 65 field-sales tests pass. **ERP Flutter org-chart/manager-assignment UI DONE** (`FieldOrgChartScreen` @ `/field-sales/org-chart`: indented cycle-safe tree from `/hierarchy/org-chart`, tap a node → assign/clear manager via `/hierarchy/users/{id}/manager`; sidebar "Org Chart").

#### Stockist Secondary Sales / SSS (2026-06-13) — CBO-ERP gap #3
- **V9 migration:** `stockist_sales_statement` (one per stockist contact/month, DRAFT→SUBMITTED, unique partial index) + `stockist_sales_line` (per product: opening/purchase/sales/return/closing qty + sales value).
- **`StockistSalesService`:** `saveStatement` (DRAFT-only upsert, replace-style lines, closing = opening+purchase−sales−return derived per line, `SSS_NOT_DRAFT` guard, stockist contact validated), `submit`, `getStatement`, `listByStockist`/`listByPeriod`, `secondarySalesReport(from,to)` (sales qty/value by product across statements in range, value-desc), `stockOnHand(month)` (closing qty by product lying at stockists). Records the downstream half of the primary (company→stockist) sales the rest of the system already captures.
- **`StockistSalesController`** @ `/api/v1/field-sales/secondary-sales` (OWNER/ADMIN/OPERATOR, FIELD_SALES module): statements CRUD+submit, `/reports/secondary-sales`, `/reports/stock-on-hand`.
- **Tests:** StockistSalesServiceTest (4 — closing derivation, non-draft block, secondary-sales aggregation, stock-on-hand sum). **ERP Flutter SSS UI DONE** (`SecondarySalesScreen` @ `/field-sales/secondary-sales`: Statements tab — stockist+month picker, DRAFT line entry, submit; Reports tab — secondary-sales + stock-on-hand; sidebar "Secondary Sales").

#### RCPA — Retail Chemist Prescription Audit (2026-06-14) — CBO-ERP gap #2
- **V10 migration:** `rcpa_audit` (per chemist/MR/date, optional field_visit link) + `rcpa_line` (product, brand_type OWN/COMPETITOR check, competitor_name, our_item_id, quantity, value).
- **`RcpaService`:** `record` (create-or-replace lines, salesperson stamped from TenantContext, brand_type normalised, competitor_name kept only for COMPETITOR / our_item_id only for OWN, chemist contact validated), `getAudit`, `listByChemist`, `myAudits`, `shareReport(from,to)` (own vs competitor qty/value + `ownShareByQty/ValuePct`), `competitorBrands(from,to)` (competitor league table by product+competitor, value-desc).
- **`RcpaController`** @ `/api/v1/mr/rcpa` (OWNER/ADMIN/OPERATOR, FIELD_SALES module): record, get, `/me`, `/by-chemist/{id}`, `/reports/share`, `/reports/competitors`.
- **Tests:** RcpaServiceTest (3 — brand-type normalisation + salesperson stamp, own/competitor share %, competitor aggregation+sort). **ERP Flutter RCPA UI DONE** (`RcpaScreen` @ `/field-sales/rcpa`: My Audits tab — chemist picker + own/competitor line entry; Reports tab — own-vs-competitor share + competitor league; sidebar "RCPA").

#### Field Force Facade — mobile app backend (2026-06-15)
**Goal:** a narrow, offline-friendly mobile API for the **Katasticho Field** app (`katasticho-mr-salesman-app`) — MR/distributor/FMCG salesmen — instead of exposing the full ERP. `com.katasticho.erp.fieldforce`.
- **`FieldFacadeController`** @ `/api/v1/field` (FIELD_SALES module, OWNER/ADMIN/OPERATOR; scoped to the logged-in salesperson). Endpoints: `GET /today` (today's executions+visits, dealer names cached), `GET /dealers[?search]` + `GET /dealers/{id}` (contact + ledger outstanding + open invoices), `POST /visits/check-in|check-out`, `POST /orders` (books a sales order), `POST /collections` (FIFO settle), `POST /location-pings`, `GET /sync/bootstrap` (profile+today+dealers).
- **`FieldFacadeService`** is a thin delegation layer — reuses `FieldSalesService` (executions/visits/check-in-out/recordVisitOrder/recordVisitCollection), `ContactService`/`ContactLedgerService` (dealers), `SalesOrderService.create` (order booking → credit/scheme/pricing all apply), `PaymentService.recordPayment` (collections), `FieldTrackingService.recordPings` (GPS). **Collections FIFO-allocate** the amount across the dealer's open invoices oldest-first (`PaymentService` needs an invoice per payment); any excess over open balance is reported as `unallocated` with a note. No new tables.
- **Offline sync** `POST /api/v1/field/sync/push` (DONE): flushes a batch of queued actions (CHECK_IN/CHECK_OUT/ORDER/COLLECTION/LOCATION_PINGS) in one call. Each action carries a `clientId`; `FieldSyncActionProcessor` applies it in its OWN transaction (`REQUIRES_NEW`) so one failure never blocks the rest, and records APPLIED actions in the V20 `field_sync_entry` idempotency ledger (unique org+salesperson+clientId) — a replayed batch returns DUPLICATE instead of double-booking; FAILED actions leave no row and stay retryable. Returns per-action results + applied/duplicate/failed counts. Shared `FieldPayloadParser` (map→DTO) used by controller + sync. Field-app side: replace demo data with real API-backed repositories against these endpoints.
- **Tests:** FieldFacadeServiceTest (3 — FIFO allocation, excess, guard) + FieldSyncServiceTest (3) + FieldSyncActionProcessorTest (3 — apply+ledger, replay→DUPLICATE, unknown type). Boot-verified: Flyway V20 + validate clean; `/sync/push` 401-secured.

### Phase 8: Partner Network (B2B Ordering) (COMPLETE — 2026-06-06)
**Goal:** Connected B2B trade network within the same product.
**Reference:** `docs/PARTNER_NETWORK_MODULE_PLAN.md`
- **V43 migration (done):** 5 new tables (trading_partner, published_catalog_item, network_order, network_order_line, network_order_event) + 10 indexes.
- **Backend (done):** `com.katasticho.erp.partnernetwork` — 5 entities, 5 repositories, PartnerNetworkService, PartnerNetworkController (25+ endpoints at `/api/v1/partner-network`). ModuleCode.PARTNER_NETWORK added.
- **Trading partners (done):** Request/approve/reject/suspend partnership. Cross-org relationship (seller_org_id ↔ buyer_org_id). Self-partner and self-approve prevention. Duplicate prevention via unique constraint.
- **Published catalog (done):** Seller publishes items with MRP/PTR/availability/pack size. Buyer searches across approved suppliers' catalogs. Drug master linking for pharma product matching.
- **Network orders (done):** Full order lifecycle: PLACED → CONFIRMED/PARTIALLY_CONFIRMED/REJECTED → DISPATCHED → DELIVERED. Buyer places, seller confirms with per-line quantities. Cancel by buyer. Event audit trail with actor tracking.
- **SO/PO linking (done):** Link network order to buyer's PurchaseOrder and seller's SalesOrder for downstream DC→Invoice flow.
- **Module gating (done):** `@RequiresModule(PARTNER_NETWORK)` on controller. Feature flag seeded for distributor, pharma distributor, pharma manufacturer industries.
- **Flutter screens (done):** Partner list (with tabs for all/pending + request dialog), catalog list (with unpublish), supplier search (with debounced search), outgoing orders, incoming orders, order detail (with lifecycle actions + event timeline). Routes and sidebar nav integrated, gated by `canUsePartnerNetwork`.
- **Tests (done):** 11 tests in PartnerNetworkServiceTest — partnership CRUD, order lifecycle, access control.

### Phase 9: Manufacturing (Tier 1 COMPLETE — 2026-06-07)
**Goal:** Production-ready manufacturing module. Coverage: 30/114 features (26%).
**Reference:** `docs/MANUFACTURING_FEATURE_TRACKER.md` for full tracker with daily progress.
- **V45 migration (done):** 2 tables (work_order, work_order_line) + 6 indexes.
- **V46 migration (done):** 15 new tables (workstation, operation, routing, routing_operation, job_card, job_work_order, job_work_order_line, qc_template, qc_parameter, qc_inspection, qc_inspection_result, scrap_reason_code, production_scrap) + 5 ALTER TABLE on work_order + 20 indexes.
- **Backend (done):** `com.katasticho.erp.manufacturing` — 15 entities, 14 repositories, 5 services (ManufacturingService, RoutingService, JobWorkService, QualityControlService, ScrapService), ManufacturingController (50+ endpoints at `/api/v1/manufacturing`). ModuleCode.MANUFACTURING added.
- **Work order lifecycle (done):** DRAFT → IN_PROGRESS → COMPLETED (or CANCELLED). BOM explosion, issue to production, receive FG, SO→WO automation.
- **Routing/Operations/Job Cards (done):** Workstation CRUD, Operation CRUD, Routing with ordered operations. Job cards created from routing, start/complete lifecycle with time tracking.
- **Job Work (done):** Full lifecycle (DRAFT→SENT→PARTIALLY_RECEIVED→COMPLETED/CANCELLED). JOB_WORK_OUT/IN stock movements, wastage tracking, GST ITC-04 deadline alerts, cancel with reversal.
- **Quality Control (done):** Templates with parameters, inspections (INCOMING/IN_PROCESS/OUTGOING), record results, finalize (PASSED/FAILED/PARTIAL).
- **Scrap/Waste (done):** Reason codes, production scrap recording with PRODUCTION_SCRAP stock movements, WO scrap totals.
- **SO→WO Automation (done):** `createWorkOrdersFromSalesOrder()` finds composite items in confirmed SO, creates linked draft WOs.
- **Flutter screens (done):** Work order list/create/detail with lifecycle actions. Routes and sidebar nav integrated, gated by `canUseManufacturing`.
- **Tests (done):** 59 manufacturing tests (ManufacturingServiceTest 21, RoutingServiceTest 9, JobWorkServiceTest 16, QualityControlServiceTest 8, ScrapServiceTest 5). 556 total tests pass.

#### Tier 2 (COMPLETE — 2026-06-11)
- **V59 migration (done):** BOM versioning columns (version, effective_from/to, change_notes on bom_component), WO enhancements (journal_entry_id, wip_journal_entry_id, backflush_mode, bom_version, approval_status, is_disassembly), batch traceability (batch_id/batch_number on work_order_line), WIP/Manufacturing CoA accounts (1210 WIP, 5030 Mfg Overhead, 5040 Direct Labor, 5050 Material Variance), production_cost_summary table.
- **WIP journal entries (done):** `ManufacturingWipPostingRule` implements `PostingRuleStrategy`. Issue to production: DR WIP (1210) / CR Inventory (1200) + Labor (5040) + Overhead (5030). Completion: DR Inventory (1200) / CR WIP (1210). Variance posted to Material Variance (5050). Cancel reverses WIP journal via `journalService.reverseEntry()`.
- **Backflush mode (done):** `backflushMode` flag on work order. When true, `issueToProduction()` skips material issue; `receiveFinishedGoods()` auto-issues proportional materials on each FG receipt. Ratio = quantityReceived / quantityToProduce.
- **BOM versioning (done):** `createBomVersion(parentItemId, changeNotes)` snapshots current BOM, closes effective dates, creates new version. WO creation can target a specific BOM version. `GET /bom/{id}/version/{n}`, `GET /bom/{id}/latest-version`.
- **Disassembly orders (done):** `createDisassemblyOrder()` creates a WO with `isDisassembly=true`. `executeDisassembly()` consumes FG and recovers components in one step. `POST /work-orders/disassembly`, `POST /work-orders/{id}/disassemble`.
- **Production reports (done):** Cost variance report (planned vs actual RM/labor/overhead, yield %). WIP valuation report (sum of all IN_PROGRESS WO costs). Consumption report (total RM consumed per item across completed WOs). `ProductionCostSummary` built automatically on WO completion.
- **Batch traceability (done):** `batch_id` and `batch_number` on work_order_line for linking consumed batches to production.
- **DefaultAccountPurpose extended:** WIP_INVENTORY (1210), MANUFACTURING_OVERHEAD (5030), DIRECT_LABOR (5040), MATERIAL_VARIANCE (5050).
- **Flutter (done):** Backflush toggle on WO create screen. Repository methods for all Tier 2 APIs (disassembly, BOM versioning, reports).
#### Tier 3 (COMPLETE — 2026-06-11)
- **V61 migration (done):** 4 MRP tables (mrp_run, mrp_demand, mrp_supply, planned_order) + warehouse_zone, shipment, shipment_line, batch_trace.
- **MRP engine (done):** `MrpService` — demand aggregation from SO + forecasts, supply matching (on-hand + open PO + WO), net requirement with safety stock, BOM explosion via queue, planned order generation (PURCHASE/PRODUCTION), convert-to-PO and convert-to-WO.
- **Warehouse zones (done):** `WarehouseZoneService` — STORAGE/QUARANTINE/STAGING/CROSS_DOCK/RETURNS zone types. CRUD at `/api/v1/inventory/warehouse-zones`.
- **Batch traceability (done):** `BatchTraceService` — forward (RM→FG) and backward (FG→RM) trace. `/api/v1/inventory/batch-trace`.
- **Shipment/logistics (done):** `ShipmentService` — DRAFT→IN_TRANSIT→DELIVERED lifecycle, auto-generated SHP numbers. Endpoints on SupplyChainController.
- **Flutter (done):** MRP run screen, warehouse zone screen, batch trace screen, shipment list screen.
- **Tests (done):** 10 MRP tests (SO demand, BOM explosion, net deduction, convert-to-PO/WO, etc.).
- **Still deferred:** Gantt scheduling, shop floor mobile, maintenance management, industry-specific (pharma BMR, food FSSAI, garment cut plans).

#### Gap-Fill Round (COMPLETE — 2026-06-12) — 58/101 tracker features
- **V64 BOM enhancements:** `bom_component.scrap_percent` (issue inflates by 1+scrap%/100, planned qty stays nominal), `item.is_phantom` (explode() flattens phantoms recursively w/ `BOM_PHANTOM_CYCLE` guard; MRP skips PRODUCTION order — components become demand directly), `bom_alternate` (CRUD + DRAFT-only WO-line substitution w/ repricing), `bom_co_product` (FG receipt also receives co-products, cost allocation % split, Σ≤100% guard, no-co-product path byte-for-byte unchanged), `GET /bom/{itemId}/cost-rollup` recursive tree.
- **V65 QC disposition/NCR/CoA:** `recordDisposition()` ACCEPT/REJECT/HOLD on finalized inspections (qty split must equal inspected qty, once-only). REJECT → negative ADJUSTMENT movement (warehouse via WO reference) + auto OPEN/MAJOR NCR. HOLD → validates QUARANTINE zone. `non_conformance_report` (NCR-xxxxx, OPEN→IN_PROGRESS→CLOSED). CoA JSON @ `GET /qc-inspections/{id}/coa`.
- **V66 WO enhancements:** priority (URGENT/HIGH/NORMAL/LOW, URGENT-first default sort, `?priority=` filter), `WorkOrderWorkflowHandler` (mirrors SO pattern, WORK_ORDER workflow seeded `active=false`, PENDING_APPROVAL blocks issue), `POST /work-orders/{id}/clone` (fresh DRAFT, passes approval gate), yield via existing `ProductionCostSummary.yieldPercentage`, `GET /reports/production-summary` (status counts, completion/on-time %, avg yield, scrap by reason).
- **Tests:** 629 total pass (39 new: 14 BOM/mfg, 9 QC, 14 WO enhancements, 2 WO workflow handler).

### POS Catalog Quick-Add — Marg parity (2026-06-12)
- **`PosCatalogService.createItemFromDrug(drugId, warehouseId, openingStock)`** — one tap at the counter creates an org item from a `drug_master` row (name/HSN/GST/MRP/composition/manufacturer/schedule/pack prefilled, salePrice=MRP, trackBatches=false, optional opening stock via ItemService OPENING movement so it's billable immediately) and returns it as a `PosSearchResult` via exact-SKU search. Idempotent by item name (double-tap safe); SKU slug from brand + random suffix on collision. Endpoint `POST /api/v1/items/from-drug/{drugId}?opening_stock=&branch_id=` (OPERATOR allowed by design).
- **POS Flutter:** search results < 5 → "From medicine catalog" section (drug-master search via `posCatalogSearchProvider`, fetched only when the section renders); tap → qty-on-shelf dialog (autofocus, Enter submits) → create+add to cart, current search invalidated.
- **Seller speed:** debounce 300→200ms; stale-while-loading (last results shown dimmed instead of shimmer flicker between keystrokes); Enter-to-add-top-result now awaits the in-flight request (`.future`) instead of no-oping during loading.
- **Tests:** PosCatalogServiceTest (3 — field mapping incl. openingStock, idempotency, SKU collision). 690 total pass.

### Kirana Retail Production Gaps (2026-06-10)
**Goal:** Make the POS + core flows production-ready for Indian small grocery/pharmacy shops.

- **~~P8: Profit margin on POS~~ (DONE):** PosSearchController strips `purchasePrice` for OPERATOR/ACCOUNTANT roles. OWNER/ADMIN see margin breakdown in payment sheet + margin dot per item.
- **~~P4: UPI QR code at POS~~ (DONE):** OrgSettings stores `pos.upi_id`/`pos.upi_display_name`. Payment sheet renders scannable QR via `qr_flutter`. POS Receipt Settings has UPI config section.
- **~~P6: Cash register / day close~~ (DONE):** V48 migration. CashRegisterService: open day, petty cash expenses, close with variance. 7 endpoints. Flutter: Today + History tabs in CashRegisterScreen, accessible from POS overflow menu.
- **~~P7: SMS notifications~~ (DONE):** SmsService (Fast2SMS/MSG91, async fire-and-forget, Indian mobile sanitization). Hooked in SalesReceiptService (receipt SMS) and LowStockAlertJob (per-item alert to org owner). GET/PUT `/api/v1/settings/sms`. Flutter: `_SmsSettingsSection` in POS Receipt Settings screen.
- **~~P1: Thermal/Bluetooth printer~~ (DONE):** ThermalPrintService (ESC/POS via flutter_blue_plus, 58mm/80mm paper, respects ReceiptSettings). PrinterSetupScreen with scan/connect/test/auto-print. POS _handlePrint uses thermal when connected, PDF fallback.
- **~~P2: Offline POS~~ (DONE):** OfflinePosService with SQLite queue (sqflite). **Hardened for Windows-desktop POS (2026-06-15):** plain `sqflite` is mobile-only, so desktop now uses `sqflite_common_ffi` via a conditional-import `core/storage/pos_database.dart` (`initPosDatabaseFactory()` sets `databaseFactoryFfi` on Win/Linux/macOS; web stub keeps `dart:io`/ffi out of the web build — verified web build still green). `posOfflineSupported` (= !kIsWeb) guards all offline calls; main.dart only starts the service where supported. **Windows desktop target scaffolded** (`windows/`). **NEW local catalog cache** (`pos_item_cache` table in the offline DB): `cacheItems()` warms the cache from every online POS search; `searchLocalItems()` does ranked offline search (barcode>SKU>name); `posSearchProvider` caches online results and falls back to the cache on network failure — so item search + cart + GST work offline, not just receipt-submit. Receipt queue + connectivity auto-sync unchanged. **NEW local-first POS search (2026-06-15):** the `posSearchProvider` now searches the LOCAL SQLite catalog first (no network in the hot path — < 5ms typical) and a new `PosCatalogSyncService` runs a 60s background delta sync (and an immediate sync on POS open) via `GET /api/v1/items/pos-sync?since=<Instant>` (returns slim catalog rows + `nextSince` cursor + `hasMore` paging; `isDeleted` rows prune the local cache). Online API only fires when the local cache is cold (first-time or wiped DB). **NEW full offline SALES (2026-06-15):** a cash sale now completes end-to-end with no network — `_completeSale` checks `isOnline()` upfront (no connection-timeout hang) and routes to `_completeSaleOffline`, which assigns a client temp receipt number (`OFF-000n` via `OfflinePosService.nextOfflineReceiptNumber`), queues the receipt, optimistically decrements the cached stock (`decrementCachedStock`, single-counter), builds a local receipt map and runs the SAME success sheet + thermal print as an online sale (the printer renders client-side, so a real bill prints offline; WhatsApp/email defer to sync). Connected-but-unreachable falls through the same path on the network-error catch. `pos-sync` catalog DB bumped to v3 (`pos_meta`). **Multi-terminal safe:** stock counts are advisory; the authoritative check stays at receipt-post on the server, so cross-terminal oversell is impossible. Backend: `PosCatalogSyncService` + `ItemRepository.findChangedSince`. Tested: app boots clean, /pos-sync route 401-secured, web build green. Network errors in _completeSale auto-queue receipt locally. Connectivity listener auto-syncs on reconnect. Sync badge in POS app bar shows pending count + manual Sync Now. Max 5 retries per receipt.

**Previously parked, now DONE:**
- **~~P3: Hindi i18n~~ (DONE):** `l10n.yaml`, `app_en.arb`, `app_hi.arb` with 69 translated keys. Flutter l10n wired in `main.dart`.
- **~~P5: Push notifications~~ (DONE):** V63 migration (push_token table). `PushNotificationService` with FCM stub, token registration/management. `PushNotificationController` at `/api/v1/notifications/push`.
- **~~P9: Tally masters export~~ (DONE):** `TallyCaBridgeService.exportMastersXml()` — accounts, contacts, items as Tally-importable XML. `GET /api/v1/migration/tally/export-masters`.

### Keyboard-Parity UX Program (COMPLETE — 2026-06-11)
**Goal:** Never-touch-the-mouse voucher entry and app-wide keyboard navigation.

- **KShortcuts registry (done):** Central shortcut catalogue — global (Ctrl+K palette, Ctrl+N context-new, ? help, / search), list (J/K navigate, N create, R refresh, Enter open, X select), form (Ctrl+Enter submit, Ctrl+←→ step nav, Esc cancel), POS (F1-F7, Ctrl+F, Ctrl+Enter).
- **KShortcutHelpOverlay (done):** `?` key opens context-aware shortcut reference overlay.
- **Command palette expansion (done):** 100+ commands covering all modules.
- **KKeyboardListWrapper (done):** All list screens wrapped — Invoices, Bills, Sales Orders, Items, Contacts, Stock Receipts, Purchase Orders, Delivery Challans, Journal Entries, Credit Notes, Vendor Credits, Estimates, Expenses, Recurring Invoices, Work Orders, Employees, Accounts, Vendor Payments, Schemes, Price Lists, Item Groups, Stock Counts, Transfer Orders, Picklists, Beats, Routes, Vans, Routings, Job Cards, Job Work, QC Inspections, Partners, Catalog, Payroll Runs.
- **KKeyboardFormWrapper (done):** All create forms wrapped — Invoice, Bill, SO, DC, Stock Receipt, Estimate, Expense, Credit Note, Vendor Credit, Journal, Purchase Order, Recurring Invoice, Contact, Account, Item, Item Group, Price List, Stock Count, Transfer Order, Work Order, Routing, Job Work.
- **ShellScreen global shortcuts (done):** Ctrl+N (context-aware new for all routes), ? (shortcut help overlay).
- **POS shortcut help (done):** `?` key in POS opens POS-specific shortcut reference.
- **FAB tooltip hints (done):** 40+ list screens show `(N)` keyboard hint on the create FAB tooltip.

### Phase 10: Supply Chain Module (COMPLETE — 2026-06-11)
**Goal:** Transform ERP into a supply chain product with demand planning, supplier intelligence, and inventory optimization.
- **V60 migration (done):** 8 new tables (item_supplier, supplier_performance, demand_forecast, purchase_requisition, purchase_requisition_line, return_order, return_order_line, reorder_policy, supply_chain_alert) + supplier enhancements (lead_time_days, quality/delivery/overall_rating) + 15 indexes.
- **Backend (done):** `com.katasticho.erp.supplychain` — 8 entities, 7 repositories, SupplyChainService (500+ lines), SupplyChainController (40+ endpoints at `/api/v1/supply-chain`). ModuleCode.SUPPLY_CHAIN added.
- **Multi-supplier sourcing (done):** Item↔Supplier mapping with lead time, min order qty, unit price, preferred flag. CRUD + set-preferred endpoint.
- **Demand forecasting (done):** Moving average forecast from sales history. Configurable history window and forecast horizon. Confidence scoring based on coefficient of variation.
- **ABC classification (done):** Automatic A/B/C categorization based on 12-month consumption value (80/15/5 split). Stored in reorder_policy with abc_class field.
- **Safety stock & EOQ (done):** Statistical safety stock (Z=1.65 for 95% service level × σ × √L). Economic Order Quantity. Reorder point = avg demand × lead time + safety stock.
- **Purchase requisition workflow (done):** DRAFT → SUBMITTED → APPROVED/REJECTED. Auto-create from low stock alerts. Manual and automated creation.
- **Return order management (done):** DRAFT → APPROVED → PROCESSED (or CANCELLED). Support for PURCHASE_RETURN and SALES_RETURN types. Reason codes, restock flags, condition tracking.
- **Supply chain alerts (done):** Stockout risk detection (below safety stock), low stock alerts. Alert scan, resolve workflow.
- **Supplier performance (done):** Scorecard calculation from PO/GRN data (orders, qty, quality rate, on-time rate). Supplier rankings.
- **Inventory analytics (done):** Turnover ratio, days-on-hand, COGS analysis per item. Supply chain dashboard with KPIs.
- **Flutter screens (done):** Dashboard (metrics + quick actions + navigation), Requisition list (with lifecycle actions), Return order list, Alert list (with scan + resolve), Supplier rankings, Inventory analytics (turnover + ABC). Routes and sidebar nav integrated.
- **Tests (done):** 17 tests in SupplyChainServiceTest — item-supplier CRUD, requisition lifecycle, return order lifecycle, auto-PR, alerts, dashboard.
- **Advanced forecasting (done — 2026-06-11):** Weighted moving average + seasonal decomposition with trend slope in SupplyChainService (`generateWeightedForecast()`, `generateSeasonalForecast()`, `computeTrendSlope()`).

### Phase 11: Multi-Currency + Consignment/VMI + Integration Connectors (COMPLETE — 2026-06-11)
**Goal:** Cross-border currency support, vendor-managed inventory, and third-party ERP connectors.
- **V62 migration (done):** 6 new tables (currency, exchange_rate, consignment_stock, consignment_settlement, integration_config, integration_sync_log) + 30 seeded currencies (INR, USD, EUR, GBP, etc.).
- **Multi-currency (done):** `com.katasticho.erp.common.currency` — `Currency` (platform-level, no org_id), `ExchangeRate` (org-scoped). `CurrencyManagementService`: rate management (upsert), conversion with latest-rate fallback, list rates. `CurrencyController` at `/api/v1/currencies`. 8 tests pass.
- **Consignment/VMI (done):** `com.katasticho.erp.inventory.consignment` — `ConsignmentStock`, `ConsignmentSettlement`. `ConsignmentService`: receive (with weighted-average cost blending on top-up), record-sale (deducts stock, creates DRAFT settlement), settle. `ConsignmentController` at `/api/v1/consignment`.
- **Integration connectors (done):** `com.katasticho.erp.integration` — `IntegrationConfig` (API key stored as SHA-256 hash), `IntegrationSyncLog`. `IntegrationService`: CRUD for TALLY/ZOHO/BUSY/SAP/CUSTOM connectors, test-connection stub, sync with log, sync history. `IntegrationController` at `/api/v1/integrations`.
- **Flutter screens (done):** Currency management (rates, conversion), integration list (CRUD + sync). Routes and sidebar nav integrated.

---

## Key Architecture Decisions (from docs)
- Customer Indent is removed. Sales Order with backorder is the customer demand flow.
- PO does NOT post stock. PO → draft GRN → GRN "Receive Stock" is the only stock posting step.
- SO does NOT post stock. SO → draft DC → DC "Dispatch" is the only stock deduction step.
- DC does NOT post accounting. DC → Invoice → Invoice posting is the accounting step.
- Invoice posting from SO path must NOT deduct stock again (already deducted at DC dispatch).
- Composite item stock = derived from min buildable count across components. Composite never gets its own stock movement.
- Stock movements are append-only (`stock_movement`). Corrections use REVERSE entries, never UPDATE/DELETE.
- `stock_balance` is a derived cache, rebuildable from the ledger.
- Do NOT build a generic rule engine. Use `org_settings` for the first policy layer.
- Distributor capability extends existing flows — never fork them.
- Workflow must be org-configurable, no customer-specific code branches.

---

## Existing Test Files (for reference)
Backend tests exist in `src/test/java/com/katasticho/erp/`:
- `sales/SalesCycleTest.java` — full SO→DC→Invoice cycle
- `sales/service/DeliveryChallanServiceTest.java` — DC dispatch, batch carry
- `sales/service/SalesOrderServiceTest.java` — SO creation, validation
- `sales/service/SalesOrderWorkflowHandlerTest.java` — approval transitions
- `ar/service/PaymentServiceTest.java` — payment recording
- `ar/service/CreditNoteServiceTest.java` — credit note approval
- `inventory/service/InventoryServiceFefoTest.java` — FEFO batch consumption
- `inventory/service/BomServiceTest.java` — BOM explosion
- `inventory/service/UomServiceTest.java` — UoM conversion
- `procurement/service/StockReceiptServiceTest.java` — GRN receive stock
- `common/workflow/ApprovalWorkflowServiceTest.java` — workflow engine
- `accounting/service/JournalServiceTest.java` — journal posting
- `inventory/service/FifoCostingServiceTest.java` — FIFO cost lots: setting detection, oldest-first draw-down w/ blended cost, lazy opening-lot seed, fallback when lots dry, receipt lot open, reversal restore (6 tests)
- `notification/whatsapp/WhatsAppServiceTest.java` — phone normalisation to E.164, not-configured/no-recipient → fail-result-without-throwing (3 tests)
- `notification/whatsapp/WhatsAppDocumentServiceTest.java` — disabled/no-number → SKIPPED w/o provider call, enabled → SENT with template + 3 params (3 tests)
- `inventory/service/StockCountServiceTest.java` — physical stock count (6 tests)
- `inventory/service/TransferOrderServiceTest.java` — transfer orders (7 tests)
- `inventory/service/PicklistServiceTest.java` — picklist generation (8 tests)
- `manufacturing/service/ManufacturingServiceTest.java` — work order lifecycle + SO→WO (15 tests)
- `manufacturing/service/RoutingServiceTest.java` — workstation/operation/routing/job card (9 tests)
- `manufacturing/service/JobWorkServiceTest.java` — job work lifecycle (16 tests)
- `manufacturing/service/QualityControlServiceTest.java` — QC templates/inspections (8 tests)
- `manufacturing/service/ScrapServiceTest.java` — scrap recording (5 tests)
- `ai/service/BillDraftingServiceTest.java` — AI-first bill drafting: vendor match/create, item→GOODS / unmatched→SERVICE, HSN→GST, approve posts+learns, reject deletes (5 tests)
- `auth/service/ApiKeyServiceTest.java` — API-key create (hash-only, plaintext once), resolve-by-hash, reject non-kat/revoked, revoke (6 tests)
- `gst/service/Gstr2bReconServiceTest.java` — portal JSON parse, match/mismatch/missing + suggestions, supplier-not-filed, key normalization, re-upload dedupe of prior PENDING suggestions (4 tests)
- `gst/service/EwayBillServiceTest.java` — threshold detect/skip/dupe, vehicle aggregate, validity 1d/200km, NIC portal JSON intra-state split (8 tests)
- `gst/service/GstServiceTest.java` — POS receipts in GSTR-1 B2CS/HSN + GSTR-3B outward + B2CL split of inter-state B2C > ₹1L (3 tests)
- `gst/service/GstComplianceCalendarServiceTest.java` — deadline statuses by fixed clock, 2B nudge, 26Q quarter, pending EWB + e-invoice rows, composition swap (CMP-08 + GSTR-4 replace GSTR-1/3B/2B) (3 tests)
- `gst/service/CompositionServiceTest.java` — CMP-08: invoice+POS turnover at flat rate w/ CGST/SGST split, restaurant 5% rate, Q4 year-span, bad quarter (4 tests)
- `gst/service/EInvoiceServiceTest.java` — B2B detect + suggestion, disabled/B2C/dupe skip, record IRN, INV-01 JSON shape (6 tests)
- `tax/service/TdsServiceTest.java` — 194C single/aggregate thresholds, 194Q excess-only, missing rate skip, FY Apr–Mar, 26Q grouping (8 tests)
- `tax/service/TcsServiceTest.java` — 206C(1H): below/crossing/above ₹50L threshold (excess-only), disabled setting, custom rate, FY boundary, 27EQ grouping, register filter (8 tests)
- `migration/tally/TallyImportServiceTest.java` — Tally XML parse, subgroup→Sundry Debtors resolution, Dr/Cr sign normalization, duty-ledger skip, item opening stock+GST, rerun dedupe, SKU generation (7 tests)
- `migration/tally/TallyVoucherImportServiceTest.java` — Day Book voucher→journal, Sales/Purchase/Receipt/Journal types, ledger resolution (contact→AR/AP, account→code, well-known→default, bank pattern), unresolved skip, non-Tally rejection (8 tests)
- `migration/tally/TallyCaBridgeServiceTest.java` — TB verification (match/mismatch/missing-in-books/missing-in-tally, problems-first ordering, non-TB rejection) + Tally XML voucher export (sign mirror, XML escaping, range validation, VCHTYPE mapping) (7 tests)
- `ai/service/ConversationalEntryServiceTest.java` — sentence→draft journal: payment w/ expense match, receipt→AR, bank instrument, vendor→AP settle, misc fallback+warning, k/lakh amounts, missing direction/amount not-drafted, approve posts, reject deletes (12 tests)
- `ai/service/ProactiveAgentServiceTest.java` — collections reminders (one per overdue customer, dedup, priority by days, resilient to reminder-text failure), month-close checklist (prior period open/closed/absent, Jan→Dec rollback), runAll aggregation (8 tests)
- `banking/service/BankStatementParserTest.java` — HDFC-style preamble+split columns, legacy format, month-name dates, AI fallback, Indian amount formats (5 tests)
- `banking/service/BankReconciliationServiceTest.java` — credit→invoice suggest+accept (regression), debit→bill suggest, accept-bill→vendor payment with allocation (4 tests)
- `manufacturing/service/MrpServiceTest.java` — MRP engine: SO demand, BOM explosion, net deduction, convert-to-PO/WO (10 tests)
- `common/currency/CurrencyServiceTest.java` — multi-currency: list, convert, rate upsert, fallback, zero-rate validation (8 tests)
- `supplychain/service/SupplyChainServiceTest.java` — item-supplier CRUD, requisition lifecycle, return order, auto-PR, alerts, dashboard (17 tests)
- `reporting/service/DetailedReportServiceTest.java` — sales register line-level tax joins (exists; old 'needs one' note was stale)

## Existing Service Files (key ones)
- `ar/service/PaymentService.java` — payment recording, posting, voiding
- `ar/service/InvoiceService.java` — invoice CRUD, posting, SO→Invoice conversion
- `ar/service/CreditNoteService.java` — credit note with approval workflow
- `sales/service/SalesOrderService.java` — SO CRUD, credit/overdue checks, scheme application
- `sales/service/DeliveryChallanService.java` — DC CRUD, dispatch (stock deduction)
- `procurement/service/PurchaseOrderService.java` — PO CRUD, GRN creation
- `procurement/service/StockReceiptService.java` — GRN receive stock (batch, expiry, rack, cost). **Landed cost (V53):** header charges (freight/duty/insurance/other) apportioned across lines by taxable value (residue on last line) → baked into per-unit `landedUnitCost` passed to the stock gate + item purchase price; GRN posts no journal so zero accounting risk. `apportionLandedCost()` returns empty when no charges (unchanged behaviour).
- `inventory/service/InventoryService.java` — single stock movement gate
- `inventory/service/PharmacyMasterService.java` — HSN, manufacturer, rack, substitution, interaction
- `inventory/service/DrugMasterService.java` — drug/salt search
- `common/workflow/ApprovalWorkflowService.java` — workflow engine (approve/reject)
- `pricing/service/PriceListService.java` — price list resolution
- `pricing/service/SchemeService.java` — scheme lookup and application
- `inventory/service/StockCountService.java` — physical stock count (create, post with variance movements, cancel)
- `inventory/service/TransferOrderService.java` — inter-warehouse transfers (create, ship, receive, cancel with reversal)
- `inventory/service/PicklistService.java` — warehouse picklist generation from sales orders (create, start, update, complete, cancel)
- `inventory/service/SerialNumberService.java` — serial number tracking (receive, assign to sale, damage, return)
- `reporting/service/DetailedReportService.java` — cash flow, journal register, sales/purchase register, customer statement
- `reporting/service/InventoryReportService.java` — stock summary, movements, low-stock alert
- `manufacturing/service/ManufacturingService.java` — work order lifecycle (create, issue, receive, cancel, costs, SO→WO automation)
- `manufacturing/service/RoutingService.java` — workstations, operations, routings, job cards (CRUD + lifecycle)
- `manufacturing/service/JobWorkService.java` — job work orders (create, send, receive, cancel, GST deadline alerts)
- `manufacturing/service/QualityControlService.java` — QC templates, inspections (create, record results, finalize)
- `manufacturing/service/ScrapService.java` — scrap reason codes, production scrap recording
- **AI model settings UI** (`OrgAiSettingsController` @ `/api/v1/settings/ai`): provider regex widened to `CLAUDE|OLLAMA|OPENAI_COMPAT`; new `GET /api/v1/settings/ai/models?baseUrl=` lists models actually installed on a local server (Ollama `/api/tags`). Flutter `AiModelSettingsScreen` (Settings → AI Models): 3 provider cards (Claude/Ollama/OpenAI-compat), a live `_LocalModelPicker` (free-text model name + a **Detect** button that lists your installed models as tappable chips — picks from what `ollama list` shows, not a hardcoded catalogue), base-URL + test-connection for both local providers. Replaces the old curated vision-model list.
- **Local open-source models + fine-tuning** (`docs/LOCAL_AI_AND_FINETUNING.md`): all text AI routes through `VisionModelRouter` which picks the provider per-org from `OrgAiSettings` — `CLAUDE` | `OLLAMA` (native /api/chat) | `OPENAI_COMPAT` (new `OpenAiCompatibleChatClient` → `/v1/chat/completions`, covers vLLM/LM Studio/llama.cpp/Ollama-OpenAI). Flipped the text callers (`FluxAnalysisService`, `NlpQueryService`, `BankStatementParser`) off the direct `ClaudeApiClient` onto the router, so setting `provider` to a local server makes EVERY AI feature run on a self-hosted model with zero code change (flux `aiEnabled` is now provider-aware, not Anthropic-key-gated). **Training loop:** the AI Inbox review already records every accept/modify/reject into `ai_training_example` (input/ai-output/human-output/correction-type); `AiTrainingExportService` + `GET /api/v1/ai/training/export?taskType=&goodOnly=` emits chat-format JSONL ready for LoRA/SFT (Unsloth/Axolotl) → deploy the adapter to Ollama/vLLM → switch `OrgAiSettings.modelName`. Tests: 74 AI+banking pass (3 existing tests reflavoured ClaudeApiClient→VisionModelRouter).
- `ai/service/FluxAnalysisService.java` — **Flux analysis agent** (Campfire/Ember close-prep parity). Compares the just-ended month's P&L against the prior month line-by-line, picks material movements (|Δ| ≥ ₹1,000 AND ≥5% OR a brand-new account), and when `app.ai.anthropic-api-key` is set sends the top-N to Claude for a one-paragraph controller-style explanation (deterministic header always present). Posts ONE `FLUX_ANALYSIS` suggestion per `(org, FiscalPeriod)` to the AI Inbox, idempotent via `existsOpenSuggestion`. Wired into `ProactiveAgentService.runAll()` so it runs nightly with the other agents. `ProactiveRunResult` gained `flux`; daily-job log updated. Tests: FluxAnalysisServiceTest (5 — no period, dedupe, deterministic flow + filter, AI commentary, immaterial-skip). 65/65 AI tests pass.
- `accounting/service/ContinuousCloseService.java` — **Continuous-close agent**: `checklist(year,month)` reports the LIVE status of each close task (draft invoices/bills outstanding, depreciation run, amortization run, flux reviewed, AI inbox cleared) with per-item DONE/PENDING/NA + `percentComplete` + `readyToClose`; `closeGuarded(year,month,force)` refuses (`CLOSE_NOT_READY` 409) to shut the books while tasks are PENDING unless forced, else delegates to `FiscalPeriodService.closePeriod`. `ContinuousCloseController` @ `/api/v1/accounting/continuous-close/{year}/{month}/checklist|/close`. Added count finders (Invoice/Bill DRAFT-in-period; FixedAssetDepreciation/AmortizationEntry exists-in-period). Tests: ContinuousCloseServiceTest (5). Unlike the old one-shot month-close *reminder*, every item reflects real data and now also checks the new depreciation + amortization runs.
- `ai/service/ProactiveAgentService.java` — **Proactive agents (Phase G)** — "the system tells you first". `runAll()` drafts AI Inbox suggestions: (1) **collections reminders** — one `COLLECTIONS_REMINDER` per overdue customer (via `CreditReminderService.getOverdueCustomers` + `generateReminderMessage` for a ready-to-send WhatsApp draft), priority by days overdue; (2) **month-close checklist** — if the just-ended month's `FiscalPeriod` is still OPEN, a `MONTH_CLOSE_CHECKLIST` nudge with standard steps + pending-inbox count; (3) **anomaly sweep** — delegates to `RuleBasedAiAgentService.runRuleChecks`. All idempotent via `existsOpenSuggestion`. Driven by `automation/ProactiveAgentJob` (daily 6:30am, per-org TenantContext loop, `app.automation.proactive-agents.cron`). Manual trigger `POST /api/v1/ai/agents/proactive/run`. Flutter: "Run checks" button in AI Inbox.
- `ai/service/ConversationalEntryService.java` — **Conversational entry (Phase B)**: "type a sentence → drafted transaction". `draftFromText()` parses payments/receipts via a rule-based parser (no external AI call: direction from paid/received, amount w/ ₹/k/lakh, instrument cash→1010/bank→1020, party→contact→AR/AP, expense/income by keyword vs CoA, Miscellaneous-Expense fallback) → balanced DRAFT journal via `JournalService.postJournal(autoPost=false)` + `DRAFT_ENTRY` AiSuggestion. `approve()` posts via `postEntry`; `reject()` deletes draft. Unparseable text returns `drafted=false` + a how-to-rephrase message (no draft created). `POST /api/v1/ai/entry[/{id}/approve|/reject]`. Flutter: Quick-entry composer in AI Inbox tab + DRAFT_ENTRY accept/reject routing.
- `ai/service/ConversationalAgentService.java` — **Conversational agent with tool-use (2026-06-17)**: the chat front door that *acts*, not just answers. `chat(message)` → the org's configured model (`VisionModelRouter`) returns a small JSON `{tool,args}` choosing ONE tool, then it runs through existing services: **query_data** (read) → `NlpQueryService` NL→SQL; **draft_entry** (write-as-DRAFT) → `ConversationalEntryService.draftFromText` (sets `actionRequired`+`draftSuggestionId`); **list_overdue** (read) → `CreditReminderService.getOverdueCustomers` (deterministic summary). If the model is unavailable/garbles, a keyword router (`PAYMENT_WORDS`+digit→draft, `OVERDUE_WORDS`→overdue, else query) takes over so offline-capable intents still work. Tolerant JSON extraction (first `{...}` block). **Safety:** write tools only ever DRAFT — never posts. `POST /api/v1/ai/agent` (OWNER/ADMIN/ACCOUNTANT/OPERATOR, AI_INBOX module). Flutter: Assistant tab now calls `agent()` (was `query()`), shows the reply, renders query rows, and shows an "approve in AI Inbox" hint when `actionRequired`. Tests: ConversationalAgentServiceTest (8 — LLM plans for each tool, rules fallback on model-throws + on garbage, none/greeting, query-failure friendly msg, blank short-circuit).
- `ai/service/BillDraftingService.java` — **AI-first bill entry** ("draft, don't type"): scanned bill → match-or-create vendor + match item (GOODS) / expense (SERVICE) + HSN→GST → DRAFT purchase_bill + `DRAFT_BILL` suggestion. Approve posts via `PurchaseBillService` + learns `ai_pattern` (vendor+HSN→account); reject deletes draft. Endpoints `/api/v1/ai/bill-drafts[/{id}/approve|/reject]`. See `docs/AI_FIRST_ACCOUNTING_PRODUCT_VISION.md` Phase A.
- `auth/service/ApiKeyService.java` — **API-key auth** for programmatic/MCP access. `kat_<random>` keys, SHA-256 hashed (plaintext shown once), org+user scoped. `ApiKeyAuthenticationFilter` reads `X-API-Key`/`Bearer kat_…` and sets the same `TenantContext`+`ROLE_<role>` as JWT. Endpoints `/api/v1/api-keys` (create/list/revoke, OWNER/ADMIN). V49 migration. See Phase C.
- `gst/service/GstService.java` — GSTR-1 (B2B/**B2CL**/B2CS/CDNR/CDNUR/HSN) + GSTR-3B builders @ `/api/v1/gst/gstr1|gstr3b` (+`/export`). **B2CL** inter-state B2C invoices > ₹1L (Notification 12/2024, eff 1 Aug 2024) split out invoice-level (Table 5) and excluded from B2CS. **POS receipts included** in B2CS/HSN/3B outward (per-line tax via HSN master; intra/inter from receipt header IGST).
- `gst/service/Gstr2bReconService.java` — **GSTR-2B reconciliation**: upload portal JSON → match posted bills by GSTIN+normalized invoice number (₹1 tolerance) → MATCHED/VALUE_MISMATCH/NOT_IN_BOOKS + supplier-not-filed (ITC at risk). Mismatches create AI Inbox suggestions. **Re-upload dedupe:** upload() clears the period's prior PENDING GSTR2B_ENTRY suggestions (via `AiSuggestionService.dismissPendingForEntities`) before replacing entries, so re-uploading the same 2B doesn't pile up duplicate inbox items (reviewed rows preserved). V50 `gstr2b_entry`. `/api/v1/gst/gstr2b[/upload|/summary]`.
- `gst/service/EwayBillService.java` — **e-way bills**: INVOICE_POSTED handler auto-flags invoices ≥ `gst.eway_bill_threshold` (default ₹50k) → PENDING row + HIGH suggestion. Vehicle-aggregate rule via `/gst/eway-bills/check-vehicle` (split sub-50k bills in one vehicle). NIC portal JSON per invoice, record EWB (validity 1 day/200km), cancel. V50 `eway_bill`.
- `gst/service/GstComplianceCalendarService.java` — deadlines (GSTR-1 11th, 3B 20th, TDS 7th, 26Q quarterly, 2B recon nudge after 14th, pending EWBs + e-invoices) with UPCOMING/DUE_SOON/OVERDUE. Clock-injected. **Composition orgs swap GSTR-1/3B/2B for CMP-08 (18th after quarter) + annual GSTR-4 (Apr 30).** `/api/v1/gst/compliance-calendar`.
- `gst/service/CompositionService.java` — **GST composition scheme (CMP-08)**: org settings `gst.composition_enabled` + `gst.composition_rate` (1% trader default, 5% restaurant, 6% services). `cmp08(fy, quarter)` = posted invoice turnover + POS receipts × flat rate, split CGST/SGST. `/api/v1/gst/composition/cmp08|/settings`. Calendar swap above is driven by `isEnabled()`.
- `gst/service/EInvoiceService.java` — **e-invoice (IRN)**: `gst.einvoice_enabled` org setting; INVOICE_POSTED handler flags posted B2B invoices (buyer GSTIN) → PENDING + suggestion. IRP INV-01 v1.1 JSON per invoice; record IRN/Ack/signed QR; cancel. V51 `einvoice`. `/api/v1/gst/einvoices`. **`generateViaGsp(id)`** (one-click) POSTs the INV-01 payload to the configured GSP and records the IRN it returns; throws `GSP_NOT_CONFIGURED` when no GSP set so manual Download-JSON stays the alternative.
- `gst/service/GspClient.java` — **GSP / e-invoice-aggregator client** (provider-agnostic, RestTemplate `gspRestTemplate`). Settings under `org_settings`: `gst.gsp_enabled|gsp_provider|gsp_base_url|gsp_einvoice_path|gsp_ewaybill_path|gsp_token|gsp_gstin`. `isConfigured()` = enabled + base URL + token. `generateEInvoice/generateEwayBill(orgId, payload)` POST bearer+gstin headers, tolerant response parsing (`firstNonBlank` walks data/result/response wrappers + casing). Inert until creds set — manual portal-upload flow unchanged. `EwayBillService.generateViaGsp(id)` mirrors it for NIC EWBs. Settings @ `/api/v1/gst/gsp-settings` (token write-only/masked); one-click @ `POST /api/v1/gst/einvoices/{id}/generate-gsp` and `/api/v1/gst/eway-bills/{id}/generate-gsp`. Targets the common aggregator REST shape (Masters India / ClearTax), not NIC's raw RSA/AES handshake which aggregators abstract.
- `tax/service/TdsService.java` — **TDS auto-deduction** on vendor bills via vendor master (tdsApplicable/section/rate) with section thresholds (194C 30k/1L, 194J 30k, 194H 20k, 194I 2.4L, 194A 5k, 194Q 50L excess-only). Base = subtotal (excl GST), FY Apr–Mar. Wired into PurchaseBillService create/update; balanceDue = total − TDS. Form 26Q + register @ `/api/v1/tds/26q|/register`.
- `tax/service/SalaryTdsService.java` — **Salary TDS (Form 24Q + Form 16)**, the salary-side mirror of 26Q. Salary TDS is deducted inside payroll (each payslip carries a `TDS` deduction line); this rolls **POSTED** payroll runs up into: `form24q(fy, quarter)` (deductee/employee-wise salary paid + TDS, missing-PAN flag), `form16(employeeId, fy)` (Part A quarter-wise TDS via `quarterIndexOf`, Part B salary breakup by component + professional tax + total TDS), and `register(from, to)` (employee-wise TDS for the ITNS-281 deposit, zero-TDS excluded). Deductor TAN/PAN/name from org settings `tax.deductor_tan|_pan|_name` (fallback to Organisation master). Endpoints on **TdsController** `/api/v1/tds/24q|/form16/{employeeId}|/salary-register`. Projection `tax/dto/SalaryTdsLineRow` + `PayslipLineRepository.findLineRowsForRuns` (no N+1). Flutter: "Salary TDS" tab in GST dashboard (24Q quarter view + Form 16 employee picker, both share-JSON). Tests: SalaryTdsServiceTest (4). FY Apr–Mar, quarters Q1 Apr–Jun…Q4 Jan–Mar.
- `portal/service/PortalAuthService.java` + `PortalDataService.java` — **Customer/Vendor self-service portal** (full accounts). External parties (a Contact) get email+password logins separate from the app's AppUser. Lifecycle: admin **invites** a contact (INVITED + one-time `cpt_` token) → contact **accepts** (sets password, → ACTIVE) → **logs in** (email+password → portal JWT signed with an isolated key derived from the main secret). `PortalAuthenticationFilter` guards `/api/v1/portal/**` (except public `/api/v1/portal/auth/**`), sets `ROLE_PORTAL` + TenantContext scoped to the portal user's org; the app JWT filter skips `/api/v1/portal/`. `PortalDataService` serves the user's OWN data only — customer: invoices/outstanding/ledger (reuses `ContactLedgerService`); vendor: POs/bills/payment status. V19 `portal_user` (email globally unique, one account per contact). Controllers: `PortalUserAdminController` @ `/api/v1/portal-users` (OWNER/ADMIN invite/list/resend/suspend/reactivate/delete), `PortalAuthController` @ `/api/v1/portal/auth` (public accept-invite/login), `PortalSelfController` @ `/api/v1/portal` (ROLE_PORTAL: me/dashboard/invoices/statement/purchase-orders/bills/change-password). Tests: PortalAuthServiceTest (7). Boot-verified: Flyway V19 + Hibernate validate + live security smoke (public login reaches controller; portal/admin paths return correct 401s). **Portal Flutter DONE:** ERP-side admin management screen (`PortalUsersScreen`, Settings → Portal Users) + the external consumer front-end (`features/portal_app/`: `/portal/login`, `/portal/accept`, `/portal/home` — independent portal JWT via `portalDioProvider`/`portalTokenProvider`, router auth-guard skips `/portal/*`; customer invoices/statement + vendor POs/bills tabs).
- `tax/service/TcsService.java` — **TCS 206C(1H) auto-collection** on sales invoices (seller-side mirror of 194Q): org setting `tax.tcs_enabled` + `tax.tcs_rate` (default 0.1%); once a buyer's FY consideration (incl GST, per CBDT 17/2020) crosses ₹50L, TCS collects on the **excess only**, added to invoice.tcsAmount/totalAmount/balanceDue. Posting: CR TCS Payable (2031, `DefaultAccountPurpose.TCS_PAYABLE`, V54 backfills CoA for existing orgs) inside SalesInvoicePostingRule. Register + Form 27EQ + settings @ `/api/v1/tcs/register|/27eq|/settings`. Flutter: TCS tab (toggle + 27EQ) in GST dashboard.
- `migration/tally/TallyImportService.java` — **Tally Masters XML import** (slice 1): GROUP-hierarchy-aware classification (Sundry Debtors→CUSTOMER, Creditors→VENDOR, BS/P&L groups→Account types, Duties & Taxes→skip), stock items→Items with opening stock via `ItemService.createItem`. Tally sign convention (negative=Dr) normalized. Two-phase preview/import, dedupe-safe rerun. `/api/v1/migration/tally/preview|/import` (multipart, OWNER/ADMIN). Flutter: Settings → Migrate from Tally. See `docs/TALLY_PARITY_AND_MIGRATION_PLAN.md`.
- `migration/tally/TallyVoucherImportService.java` — **Tally Day Book voucher import** (slice 2): parses `<VOUCHER>` elements from Day Book XML, maps each to a journal entry via JournalService. Ledger resolution: contact name→AR(1100)/AP(2010), account name→code, well-known Tally names→default codes, bank pattern match→1020. Sales/Purchase/Receipt/Payment/Journal/Contra/Debit Note/Credit Note all supported. Tiny rounding gaps (≤₹1) auto-balanced. Two-phase preview/import. `/api/v1/migration/tally/vouchers/preview|/import`. **Format verified vs TallyPrime real XML:** Tally sign convention is debit=NEGATIVE AMOUNT + `ISDEEMEDPOSITIVE=Yes` (parser normalizes to debit-positive); voucher-mode uses `ALLLEDGERENTRIES.LIST`, invoice-mode uses `LEDGERENTRIES.LIST` (party+tax) + nested `ALLINVENTORYENTRIES.LIST>ACCOUNTINGALLOCATIONS.LIST` (revenue/purchase ledger). Only direct-child AMOUNT read → nested BILLALLOCATIONS/BATCHALLOCATIONS never double-counted.
- `migration/tally/TallyCaBridgeService.java` — **Tally "CA Bridge"** (slice 3): (1) **TB verification** — `verifyTrialBalance()` parses an uploaded Tally Trial Balance XML (`TallyXmlParser.parseTrialBalance()`: TB report `DSPACCNAME`/`DSPCLDRAMTA`/`DSPCLCRAMTA`, fallback to Masters `LEDGER`/`CLOSINGBALANCE`) and diffs vs our `FinancialReportService.generateTrialBalance()` by normalized name → MATCHED/MISMATCH/MISSING_IN_BOOKS/MISSING_IN_TALLY (₹1 tol), problems sorted first, grand-total Dr/Cr compare. (2) **Tally XML export** — `exportVouchersXml()` writes posted journals in a date range as Tally-importable XML (`Import Data`/`Vouchers` envelope, one `<VOUCHER>` per entry, `<ALLLEDGERENTRIES.LIST>` per line); sign mirrors importer (our debit→negative AMOUNT+`ISDEEMEDPOSITIVE=Yes`), source module→VCHTYPE, account name→ledger name, XML-escaped. `POST /api/v1/migration/tally/verify-trial-balance` (multipart + asOfDate), `GET /api/v1/migration/tally/export-vouchers?fromDate=&toDate=` (XML download). Flutter: Step 3 in Tally Import Screen.
- `banking/service/BankStatementParser.java` — **real bank statement parsing** (Phase E): .csv/.xlsx upload or pasted text, header auto-detected in first 25 rows (preamble-safe), fuzzy columns (Txn/Value Date, Withdrawal/Deposit, Particulars, Chq/Ref/UTR), Indian amounts (`1,15,000.00`, ₹, Cr/Dr), AI fallback via ClaudeApiClient when no header (tokens → ai_usage_log).
- `banking/service/BankReconciliationService.java` — CREDIT→outstanding invoices AND **DEBIT→open vendor bills** matching (V52: payment_match.match_type/bill_id). Accept records AR payment or **vendor payment** (allocated to bill, paid via default BANK account). `POST /banking/transactions/import-file`, `GET /banking/summary`.
- `notification/whatsapp/WhatsAppService.java` + `WhatsAppDocumentService.java` — **WhatsApp document templates** (V58 `whatsapp_message` log). Send invoices/receipts (with PDF) + reminders/statements (text params) over the WhatsApp Business API using approved templates. Mirrors `SmsService` (per-org `org_settings` `whatsapp.*`, native HttpClient, failures recorded not thrown). Two providers: **META** (Cloud API — PDF uploaded as media → template with document header + body params, no public URL needed) and **CUSTOM** (POST normalised JSON incl. base64 doc to `whatsapp.custom_url`). `WhatsAppDocumentService` resolves recipient (contact mobile/phone → E.164 via `toWhatsAppNumber`), renders PDF via existing `InvoicePdfService`/`ReceiptPdfService`, picks the org template, and records a `WhatsAppMessage` row (SENT/FAILED/**SKIPPED** when disabled/no number — never throws). POS receipt auto-send (`whatsapp.auto_send_receipt`) fires after-commit + async so checkout is never blocked. Endpoints: `POST /api/v1/whatsapp/{invoices|receipts}/{id}`, `/{reminders|statements}/{contactId}`, `GET /api/v1/whatsapp/messages`; settings @ `/api/v1/settings/whatsapp` (token write-only/masked). Distinct from the existing wa.me share-link endpoints.
- **`mcp/`** (TypeScript, not Java) — **MCP server** so Claude Desktop / agents can run the books via the REST API using an API key. Tools: ask, list_bills, list_invoices, list_ai_inbox, draft_bill, approve_bill_draft, reject_bill_draft. `mcp/README.md` has Claude Desktop setup. Drafts-only-until-approved.
- `manufacturing/service/MrpService.java` — **MRP engine**: `runMrp()` aggregates demand (SO + forecasts), matches supply (on-hand + PO + WO), computes net requirement with safety stock, BOM explosion for composites, generates planned orders (PURCHASE/PRODUCTION). `convertPlannedToPO()` / `convertPlannedToWO()`. Endpoints on ManufacturingController.
- `inventory/service/WarehouseZoneService.java` — Warehouse zone CRUD (STORAGE/QUARANTINE/STAGING/CROSS_DOCK/RETURNS). `/api/v1/inventory/warehouse-zones`.
- `inventory/service/BatchTraceService.java` — Forward (RM→FG) and backward (FG→RM) batch traceability. `/api/v1/inventory/batch-trace`.
- `supplychain/service/ShipmentService.java` — Shipment lifecycle (DRAFT→IN_TRANSIT→DELIVERED/CANCELLED). Auto-generated SHP numbers.
- `supplychain/service/SupplyChainService.java` — Multi-supplier, demand forecasting (moving avg + weighted + seasonal), ABC classification, safety stock/EOQ, purchase requisitions, return orders, supply chain alerts, supplier performance, inventory analytics.
- `common/currency/service/CurrencyManagementService.java` — Multi-currency: rate management, conversion, latest-rate fallback. `/api/v1/currencies`.
- `inventory/consignment/service/ConsignmentService.java` — Consignment/VMI: receive, record-sale, settle. `/api/v1/consignment`.
- `integration/service/IntegrationService.java` — ERP connector CRUD (Tally/Zoho/Busy/SAP/Custom), sync history. `/api/v1/integrations`.
- `notification/push/PushNotificationService.java` + `FcmClient.java` — real FCM HTTP v1 (service-account via `app.push.fcm.*`, locally-signed OAuth2, stale-token auto-deactivate); stub logging until configured. `/api/v1/notifications/push`.

---

## PENDING BACKLOG (2026-06-12 — work top to bottom, update as items ship)

### A. Verification debt (FIRST)
1. ~~BUG-2 residual~~ — RESOLVED in code: `PaymentService.voidPayment` line ~248 calls `adjustContactOutstandingAr(+amount)`; test assertion added to PaymentServiceTest.
2. `flutter analyze` + `flutter test` on BOTH apps — recent screens were written without an SDK in the cloud env (POS catalog section, Coverage, Attendance, Samples, MR Approvals, Live Tracking; field app Tour Plan/Daily Report/detailing/punch card). MUST run locally before building.
3. ~~Fresh-DB boot smoke~~ DONE (2026-06-13, in cloud env w/ local Postgres+Redis): app boots, Flyway V1-V5 applied, org registered via API (61 CoA accounts seeded), login, drug search, HSN search, and POS catalog quick-add w/ opening stock all verified live. **Three latent fresh-boot bugs found & fixed:** (a) 9 tables from old V59-V62 era missing `created_by` vs their BaseEntity mappings (Hibernate validate failed) — added to V1 baseline; (b) WhatsAppDocumentService↔SalesReceiptService bean cycle via two paths — `@Lazy` on the common edge (lombok.config already copies @Lazy); (c) SecurityConfig anchored the API-key filter to JwtAuthenticationFilter BEFORE registering it — reordered. **CI note: `mvn clean` is mandatory after the migration squash** — incremental target/classes still carried deleted V6-V71 files → "Found more than one migration with version 1".
4. ~~DetailedReportService has no test~~ — stale note: DetailedReportServiceTest.java exists.

### B. Tally "CA pack"
**Discovery 2026-06-12: items 1-5 were ALREADY IMPLEMENTED in the old chain (undocumented):** `OperationalReportService.costCentres()/overdueInterest()/stockAgeing()/ratioAnalysis()/budgetVariance()`, `BudgetService` (+ `budget_line` table in baseline), endpoints on FinancialReportController, hub entries in reports_hub_screen, journal form has costCentre, budgets screen @ `/settings/budgets`. Tests: BudgetServiceTest + OperationalReportServiceTest.
1. ~~Cost centre P&L~~ DONE · 2. ~~Budgets + variance~~ DONE · 3. ~~Interest on overdue~~ DONE (debit-note draft still optional) · 4. ~~Stock ageing~~ DONE · 5. ~~Ratio analysis~~ DONE · Post-dated vouchers DONE (old V56).
6. ~~Realized forex gain/loss~~ DONE both sides (2026-06-12). AR: `postPaymentReceived` books cash at payment rate, clears AR at invoice rate, diff → 5500. AP: `postVendorPayment` clears AP per-allocation at each bill's rate vs cash at payment rate (paying more base = loss DR, less = gain CR); **forex applies only when TDS = 0** (TDS sections govern resident INR payments) — TDS path stays byte-identical legacy. Tests: PaymentForexPostingTest (9).

### C. Pharma/catalog follow-ups
1. ~~HSN master CRUD~~ DONE (2026-06-12): `PharmacyMasterService.upsertHsn` — OWNER/ADMIN may ADD missing codes (rates are statutory facts, shared platform table); editing an EXISTING row needs PLATFORM_ADMIN (`HSN_PLATFORM_ROW_READONLY`). `POST /api/v1/pharmacy-masters/hsn`; ERP `HsnMasterScreen` @ `/inventory/hsn-codes` (sidebar + palette).
2. ~~Schedule H1 overlay~~ DONE: V4 migration flags the 46 notified Schedule H1 substances by salt-name match → drug_schedule='H1' + prescription_required (1,723 products incl. combinations on fresh DB). Full Schedule H (500+ substances) still default GENERAL.
3. ~~36 GST-exempt lifesaving drugs~~ DONE: V4 seeds the 56th-Council nil-rated list (33 from 12% + 3 from 5%) as drug_master rows @ gst_rate 0.
4. ~~Org setting batch-track quick-adds~~ DONE: `pos.catalog_quick_add_track_batches` (default false); when on, opening qty books into an auto 'OPENING' batch.
5. Optional: merge official Jan Aushadhi / NLEM lists (gov sites bot-gated — needs one manual browser download).

### D. Field force leftovers
1. ~~E-detailing~~ DONE (2026-06-12, URL-based): V5 `detail_aid` (org-scoped: name/media_url/PDF-IMAGE-VIDEO-LINK/product, active flag) + `visit_detail_aid_log`. `DetailAidService`: CRUD (OWNER/ADMIN; http(s) URL validated, unknown type → LINK), `listWithUsage()` (shown counts), `logShown(visitId, aidIds)` (replace-style, post-check-in, owner-only, aid org-validated). Endpoints @ `/api/v1/mr/detail-aids[/manage|/{id}]` + `PUT/GET /visits/{id}/detail-aids`. ERP `DetailAidsScreen` (`/field-sales/detail-aids`: usage counts, active toggle, open-media, add/edit dialog). Field app: "Aids" button on IN_PROGRESS visits → sheet (open via url_launcher — dep added to pubspec, marks shown; checkboxes; save). Tests: DetailAidServiceTest (7). 707 total pass. Media stays URL-hosted (Drive/S3) — no file-storage service yet.
2. ~~Attendance → payroll LOP~~ DONE (2026-06-12): `employee.user_id` (baseline) links payroll employees to app users; `payslip.lop_days` records approved UNPAID leave days clipped to the run period; EARNING components prorate by (periodDays − lop)/periodDays in `PayrollService.calculatePayslip`. No user link / no unpaid leave = behaviour unchanged. `EmployeeRequest.userId` exposed and the **ERP employee-form "App login" dropdown is DONE** (links a payroll employee to an app user → activates attendance/leave-driven payroll LOP). **LOP unit test DONE (2026-06-13):** PayrollServiceTest +3 (calculateRun w/ unpaid leave prorates earnings + records lopDays; leave spanning the period boundary counts only in-period days; paid/CASUAL leave = no LOP, full pay). 11 PayrollServiceTest tests pass.
3. True background GPS in field app (current tracking is foreground Timer only).

### E. Deployment-day config checklist (no code)
FCM service-account (`app.push.fcm.service-account-file`) · SMS provider keys · WhatsApp Business token · GSP creds (e-invoice/EWB one-click) · Redis.

### F. Bigger tracks (later)
Manufacturing tracker 43/101 remaining (Gantt, shop-floor mobile, maintenance, pharma BMR/FSSAI) · GST polish (~~B2CL in GSTR-1~~ DONE · ~~2B re-upload dedupe~~ DONE 2026-06-13 · ~~2B auto-fetch via GSP~~ DONE 2026-06-17) · POS catalog: full 254k source list importer.

#### GSTR-2B auto-fetch via GSP (2026-06-17)
- `GspClient.fetchGstr2b(orgId, returnPeriod)` GETs the 2B JSON from the configured aggregator (new setting `gst.gsp_gstr2b_path`, default `/gstr2b/fetch`; `?rtnprd=MMYYYY&gstin=`). New `get()` helper mirrors `post()` (bearer+gstin headers, tolerant parse, GSP_UNREACHABLE/GSP_BAD_RESPONSE).
- `Gstr2bReconService.fetchAndReconcile(period)` — guards `GSP_NOT_CONFIGURED`, converts YYYY-MM→MMYYYY, pulls JSON, then runs the SAME `upload()` parse/match/dedupe path (no portal download). `POST /api/v1/gst/gstr2b/fetch?period=` (OWNER/ADMIN/ACCOUNTANT). `GspController` settings gained `gstr2bPath`.
- ERP Flutter: GSTR-2B tab now has a primary "Fetch from GSP" button (manual JSON upload demoted to outlined fallback); `fetchGstr2bFromGsp` repo method + `gstr2bFetch` api_config. GSP_NOT_CONFIGURED → friendly "set up GSP / upload manually" snackbar.
- Tests: Gstr2bReconServiceTest +2 (not-configured throws; configured pulls "052026" + reconciles). 6 pass.
- **GSP settings screen + test-connection (2026-06-17):** `GspSettingsScreen` (Settings → GSP Connection, `/settings/gsp`; sidebar tile + command palette) — enable toggle, provider/base-URL/GSTIN/write-only-token, optional endpoint paths, explainer. `gst_repository.getGspSettings/updateGspSettings`. `GspClient.testConnection(orgId)` — GETs the base URL; any HTTP status (incl. 401/404) = reachable, transport error = unreachable; never throws, returns `{ok,reachable,statusCode,message}`. `POST /api/v1/gst/gsp-settings/test` (OWNER/ADMIN) + "Test connection" button w/ inline result. Tests: GspClientTest (4 — not-configured / 200 / 401-still-reachable / transport-unreachable).

#### ITC-at-Risk Monitor — preventive, pre-cutoff (2026-06-17)
**The wedge incumbents skip:** every 2B recon tool is a *post-cutoff* autopsy (2B freezes the 14th, after the 11th GSTR-1 deadline). From Apr-2026 GSTR-3B can only claim ITC that 2B reflects, so one unfiled supplier blocks your credit (Sec 16(2)(c)). This monitors the **real-time GSTR-2A** in the window *before* the lock and nudges the owner to chase laggards.
- `GspClient.fetchGstr2a(orgId, MMYYYY)` (new setting `gst.gsp_gstr2a_path`, default `/gstr2a/fetch`) — 2A is the live feed (updates as suppliers file); shared `getReturn()` helper with `fetchGstr2b`. `gstr2aPath` added to settings()/GspController.
- `ItcRiskMonitorService` (`gst.service`): `assessRisk(period)` (read) — posted bills (registered suppliers w/ vendor bill no.) vs filed set from `gstr2b_entry` (reuses `Gstr2bReconService.matchKey`); per-supplier ₹ITC-at-risk + ready WhatsApp nudge + wa.me deep link, sorted desc. **Honest degradation:** empty filed set → `dataAvailable=false`, flags NOBODY (no crying wolf — doesn't even read books). `refreshAndAlert(period)` — best-effort 2A pull via GSP (ingested through `Gstr2bReconService.upload`), then `raiseAlerts`. `raiseAlerts` — idempotent `ITC_AT_RISK` AiSuggestion per supplier (entityType CONTACT), HIGH ≥₹10k.
- `ItcRiskMonitorJob` (cron `app.automation.itc-risk-monitor.cron` default `0 0 9 5 * *` — 9am on the 5th) scans the PRIOR month (whose GSTR-1 deadline is the 11th), per active org.
- Endpoints: `GET /api/v1/gst/itc-risk?period=` (assess) + `POST /api/v1/gst/itc-risk/alert?period=` (refresh+alert).
- ERP Flutter: `ItcRiskScreen` (`/gst/itc-risk`; command palette + a "Catch it before the cutoff" card on the 2B tab) — month picker, "Check latest filings now", total + per-supplier cards w/ one-tap "Remind on WhatsApp" (url_launcher wa.me), dataAvailable empty state.
- Tests: ItcRiskMonitorServiceTest (6 — no-data silent, flags unfiled-registered-only + aggregates, idempotent alerts + HIGH priority, 2A pull via GSP, GSP-failure still alerts on existing data, provenance+freshness surfaced).
- **2A provenance + freshness (V24, 2026-06-17):** `gst_filing_snapshot` (one row/org/period: source GSTR_2A|GSTR_2B|UPLOAD + refreshed_at + entry_count). `Gstr2bReconService.upload(period,json,source)` overload upserts the snapshot via `recordSnapshot` (manual `upload`→UPLOAD, `fetchAndReconcile`→GSTR_2B, ITC monitor 2A pull→GSTR_2A). `ItcRiskReport` gains `source`+`lastRefreshedAt`; ERP `ItcRiskScreen` shows a "Signal: real-time GSTR-2A · refreshed 3h ago" line that flags amber + "may be outdated" when >24h stale — so the owner knows how trustworthy the alert is.
- **Dedicated GSTR-2A parser (2026-06-17):** `Gstr2aParser` (gst.service) parses the real 2A shape the 2B parser would silently drop — tax keys `iamt/camt/samt/csamt` (not igst/cgst/sgst/cess), item tax nested under `itm_det`, `b2b` at `data.b2b`/top-level (not `data.docdata.b2b`), `cfs` filing status; tolerates flat-item + simplified `entries[]` too. `Gstr2bReconService.upload(period,json,source)` now routes `source=="GSTR_2A"` through it, else the 2B `parsePortalJson` (unchanged) — so the ITC monitor's 2A pull gets the right parser with zero call-site churn. Output reuses `Gstr2bEntry` so reconcile/store is identical. Tests: Gstr2aParserTest (3 — real itm_det/iamt shape, flat+top-level b2b, empty).
- **Recoverable-this-cycle rollup (2026-06-17):** `recoverableRollup(months)` (default 3, cap 12) walks back from `YearMonth.now(clock)` calling `assessRisk` per period → `RecoverableRollup(totalRecoverable, totalPassed, List<PeriodSummary>)` splitting at-risk ITC by whether the deadline is still open (`daysToDeadline>=0`). `GET /api/v1/gst/itc-risk/rollup?months=`. ERP ITC screen shows a money headline card ("₹X still recoverable · ₹Y deadline passed"). Tests: +1 (recoverable vs passed split). The money framing that sells the wedge.
- **Escalating urgency (2026-06-17):** alerts get louder as the 11th nears (the whole point is the timing window). Clock-injected `daysToDeadline(period)` (= 11th of P+1 − today) → urgency OVERDUE/CRITICAL(≤3d)/URGENT(≤7d)/NORMAL; `scoreFor`=amount floor (₹10k→70 else 50) + time bonus (OVERDUE+29/CRITICAL+25/URGENT+15, cap 99), priority HIGH at ≥75. `raiseAlerts` now **escalate-or-create**: a new `AiSuggestionRepository.findFirst...StatusInOrderByCreatedAtDesc` finds the open alert and bumps priority/score/reasoning in place on re-run (never downgrades a seen alert) instead of skipping — so a NORMAL alert raised on the 4th auto-promotes to HIGH by the 9th. `ItcRiskReport` gains `daysToDeadline`+`urgency`; ERP screen shows a colour-ramping countdown banner ("3 days to the GSTR-1 deadline (11th)", red when CRITICAL/OVERDUE). Tests: ItcRiskMonitorServiceTest 8 (+escalation, +freshness).

### G. Marg first-timer master-data parity (2026-06-13)
Goal: match Marg's "ready in minutes" preloaded masters. Audit found UoM already
covered (UomService bootstrap seeds common + industry units incl. pharma Strip/
Bottle/Vial/Tube, kirana Pack/Bora/Katta etc.); drug/salt/manufacturer masters
already strong (22,928 drug / 256 salt / 57 manufacturer).
1. ~~GST state-code master~~ DONE: `V6__gst_state_code_master.sql` — `gst_state_code`
   platform table + 38 rows (36 states/UTs current GST codes + Other Territory 97 +
   Centre Jurisdiction 99; obsolete 25/28 omitted). `gst/entity/GstStateCode`,
   `GstStateCodeRepository`, `GstStateCodeService` (listAll, findByCode,
   resolveFromGstin = first 2 digits), `StateCodeController` @ `/api/v1/reference/
   state-codes[/by-gstin/{gstin}]` (UNGATED — any role; every org needs it). Flutter
   `ApiConfig.gstStateCodes`. Tests: GstStateCodeServiceTest (5). **UI wiring (state
   dropdown in org/contact address forms + GSTIN auto-resolve) still TODO.**
2. ~~HSN/GST directory expansion~~ DONE (2026-06-13): `V7__hsn_gst_directory_expansion.sql`
   adds 36 common kirana/FMCG/general HSN rows (dairy, fresh produce, staples,
   edible oils, sugar, bakery, beverages, personal care, household, stationery,
   footwear) at post-GST-2.0 rates per Notification 9/2025, corroborated across
   CAclubindia/CMAKnowledge + ClearTax. Rates = pre-packaged retail case (loose/
   unbranded staples may be nil → override per item). Caught: detergents 3402 stayed
   18% (only soap 3401 dropped to 5%); aerated drinks 2202 = 40%. Omitted ambiguous
   codes: salt 2501, tea 0902/coffee 0901 (processed-vs-unprocessed), namkeen 2106
   (already @ 18% for supplements — one rate per code). hsn_gst_master now 46 rows.
3. **GSTIN auto-resolve UI** DONE (2026-06-13): org details + contact forms fill
   State + Code from the GSTIN prefix via `/api/v1/reference/state-codes/by-gstin`.
   (Explicit state dropdown still optional — auto-resolve covers the common path.)
4. Optional later: GST tax-slab pick-list, pincode/city master, bank IFSC master.

---

### HR Portal — Zoho People "Core HR" parity (2026-06-14, IN PROGRESS)
Goal: a full production HR portal (not a demo). Benchmark = Zoho People Core HR
(9 modules). Build module by module, backend + tests first; Flutter UI follows.
New package `com.katasticho.erp.hr`. Existing base: payroll (Phase 5), basic
attendance + leave (V71 `attendance` pkg), employee master, field hierarchy (V8),
generic `AttachmentService`/`EntityAttachment` for documents.

**The 9 Core HR modules + status:**
1. ~~Leave management (Time off)~~ **DONE (module 1, V11):** `hr_leave_type`
   (paid/unpaid, annual_quota, ANNUAL/MONTHLY/NONE accrual, carry_forward, requires_approval),
   `hr_holiday` (org calendar), `hr_leave_balance` (per user/type/year, available = entitled+carried−used).
   `leave_request` gains `leave_type_id` + `working_days`. `LeaveManagementService`:
   type CRUD, holiday CRUD, `workingDays` (excludes weekends + holidays), balance-aware
   `applyLeave` (paid→balance check, unpaid→leaveType "UNPAID" so payroll LOP path is
   unchanged; auto-approve when type doesn't require approval), approve/reject/cancel
   (balance deduct/restore), `myBalances`. `LeaveController` @ `/api/v1/hr/leave`
   (types+holidays OWNER/ADMIN; apply/cancel/me/my-balances any; approve/reject/pending
   OWNER/ADMIN). Tests: LeaveManagementServiceTest (5). Payroll LOP + attendance regression-clean.
   **Flutter UI DONE:** `LeaveManagementScreen` (`/hr/leave`, tabs Apply/My Leave (balances+requests)/Approvals) under a new sidebar "HR" group. (Flutter SDK now installed in the cloud env — analyze runs clean.)
2. ~~Employee management~~ **DONE (module 2, V18):** self-service employee profile
   layered on the payroll Employee master. `hr_employee_profile` (one row/user:
   DOB/gender/blood group/marital status/personal email+phone/current address +
   emergency contact name/phone/relation; unique partial index org+user).
   `EmployeeProfileService`: `getMyProfile`/`getProfile(userId)` (combined view —
   payroll Employee basics [code/name/designation/department/DOJ/status] + the
   personal-details row), `upsertMine`/`upsertFor(userId)` (replace-style, blanks
   nulled). `EmployeeProfileController` @ `/api/v1/hr/profile` (GET/PUT `/me` any
   signed-in user; GET/PUT `/{userId}` OWNER/ADMIN). Tests: EmployeeProfileServiceTest (4).
   Flutter `MyProfileScreen` (`/hr/profile`) — employee card + personal/emergency
   card + edit bottom-sheet + quick-link cards to Leave/Attendance/Timesheets/
   Documents/Help Desk. Sidebar "My Profile" (top of HR group). analyze-clean.
3. ~~Attendance management~~ **DONE (module 2, V12):** `attendance_regularization`
   (employee requests a punch correction, manager approves -> writes the corrected
   punch onto field_attendance). `AttendanceManagementService` (hr.service):
   request/approve/reject/my/pending + `monthlySummary(user, month)` = working days
   (excl weekends+holidays, reuses LeaveManagementService) vs present (punches),
   approved leave (clipped to month), holidays, weekends, absent, total hours,
   payableDays (present+paid leave). `AttendanceManagementController` @
   `/api/v1/hr/attendance` (regularizations; summary/me + summary/{userId} OWNER/ADMIN).
   Tests: AttendanceManagementServiceTest (2). Reuses existing field_attendance punches.
4. ~~Shift management~~ **DONE (module 3, V13):** `hr_shift` (code/name/start/end/
   weekly_offs/active) + `hr_shift_assignment` (user/shift/effective_from/to, null=open).
   `ShiftManagementService`: shift CRUD, `assignShift` (auto-closes the prior open
   assignment the day before the new one — no overlap), `listAssignments`, `shiftOn(user,
   date)` (latest assignment covering the date). `ShiftController` @ `/api/v1/hr/shifts`
   (defs+assign OWNER/ADMIN; list/on any). Tests: ShiftManagementServiceTest (3).
5. ~~Timesheets~~ **DONE (module 4, V14):** `hr_timesheet_entry` (per-day project/
   task hours, billable flag, DRAFT→SUBMITTED→APPROVED/REJECTED). `TimesheetService`:
   log/update/delete (owner DRAFT-only, hours 0–24 guard), `submitRange(from,to)`
   (batch-submit a user's DRAFTs), approve/reject (OWNER/ADMIN), myEntries, pending,
   `summary(user,from,to)` (total/billable/non-billable hours + by-project breakdown).
   `TimesheetController` @ `/api/v1/hr/timesheets`. Tests: TimesheetServiceTest (5).
6. ~~HR help desk~~ **DONE (module 5, V15):** `hr_ticket` (raised_by, category,
   subject, priority LOW/NORMAL/HIGH, status OPEN→IN_PROGRESS→RESOLVED→CLOSED,
   assigned_to, resolution) + `hr_ticket_comment` (thread). `HrHelpDeskService`:
   raise, getTicket(+comments), addComment, assign (OPEN→IN_PROGRESS), setStatus
   (stores resolution on RESOLVED/CLOSED), myTickets/assignedToMe/openTickets.
   `HrHelpDeskController` @ `/api/v1/hr/helpdesk` (raise/comment/mine any;
   assign/status/open OWNER/ADMIN). Tests: HrHelpDeskServiceTest (4). Flutter
   `HelpDeskScreen` (`/hr/helpdesk`, tabs My Tickets/HR Inbox, raise dialog,
   detail bottom-sheet w/ comments + status actions). analyze-clean.
7. ~~Document management~~ **DONE (module 7, V16):** `hr_employee_document`
   (employee_user_id, category, title, expiry_date, denormalised file info +
   attachment_id). `EmployeeDocumentService` reuses the shared `AttachmentService`
   for real file storage: `upload` (multipart → AttachmentService.upload + HR
   metadata), `listForEmployee`/`myDocuments`, `expiring(days)` (renewal watchlist),
   `delete` (owner-or-admin, soft-delete + AttachmentService.delete). Controller @
   `/api/v1/hr/documents` (POST /me self-upload + POST /{userId} OWNER/ADMIN multipart;
   GET /me, /{userId}, /expiring; DELETE /{id}). Tests: EmployeeDocumentServiceTest (4).
   Flutter `EmployeeDocumentsScreen` (`/hr/documents`, tabs My Documents (file_picker
   multipart upload + delete) / Expiring (HR)). analyze-clean.
8. ~~HR analytics~~ **DONE (module 8):** `HrAnalyticsService.dashboard()` — read-only
   org snapshot rolling up the other modules: headcount + by-department (active payroll
   employees), onLeaveToday, pendingLeaves, pendingRegularizations, pendingTimesheets,
   openTickets, documentsExpiringIn30Days. No new tables. `HrAnalyticsController` @
   `/api/v1/hr/analytics/dashboard` (OWNER/ADMIN). Tests: HrAnalyticsServiceTest (1).
   Flutter `HrAnalyticsScreen` (`/hr/analytics`) — metric cards + dept breakdown. analyze-clean.
9. ~~Offboarding~~ **DONE (module 9, V17):** `hr_offboarding` (employee_user_id,
   resignation/last-working-day, reason, status INITIATED/COMPLETED/CANCELLED, fnf_amount/
   settled) + `hr_offboarding_task` (clearance checklist: IT/FINANCE/HR/ADMIN). `OffboardingService`:
   `initiate` (seeds 5 default clearance tasks), getOffboarding(+tasks), completeTask, settleFnf,
   `complete` (requires all tasks done → marks the linked payroll Employee EXITED + dateOfExit;
   `OFFB_TASKS_PENDING`/`OFFB_NOT_OPEN` guards), cancel, list. `EmployeeRepository` gained
   findByOrgIdAndUserId. `OffboardingController` @ `/api/v1/hr/offboarding` (OWNER/ADMIN).
   Tests: OffboardingServiceTest (3). Flutter `OffboardingScreen` (`/hr/offboarding`: list +
   initiate dialog w/ employee picker + detail sheet w/ checklist + F&F + complete/cancel). analyze-clean.
   **ALL 9 Core HR modules now complete as full verticals (backend + tests + Flutter UI).**
**Flutter HR portal UI: My Profile + Leave + Attendance + Shifts + Timesheets + Help Desk + Documents + Analytics + Offboarding all DONE** (all under sidebar "HR" group, analyze-clean). (Flutter 3.44.2 installed in the env — both apps analyze with 0 errors.)

## Doc Files Index
| Doc | Purpose | Read when |
|-----|---------|-----------|
| `docs/PRODUCT_DEVELOPMENT_ROADMAP.md` | Master roadmap, resume checkpoints, active decisions | Starting any new phase |
| `docs/DISTRIBUTOR_FIRST_DIRECTION_ASSESSMENT.md` | Why distributor-first, gap analysis, phase sequencing | Questioning product direction |
| `docs/how-to/DISTRIBUTOR_MANUAL_QA_CHECKLIST.md` | 16-section QA checklist with corner cases | Phase 0 QA work |
| `docs/architecture/inventory-feature-gap.md` | Zoho parity gap analysis, sprint 26-30 schema sketches | Phase 2 inventory work |
| `docs/REPORTS_IMPLEMENTATION_STATUS.md` | Which reports exist, endpoints, what's missing | Phase 4 reports work |
| `docs/REPORTS_P0_SPECIFICATION.md` | Detailed SQL/DTO specs for all 14 reports | Implementing a report |
| `docs/PAYROLL_IMPLEMENTATION_SPEC.md` | Full payroll spec: tables, APIs, Flutter screens, accounting | Phase 5 payroll work |
| `docs/AI_APPROACH_AND_ROADMAP.md` | AI architecture: tables, agents, safety rules, 7 phases | Phase 6 AI work |
| `docs/AI_FIRST_ACCOUNTING_PRODUCT_VISION.md` | **North-star vision:** AI-first (not "typewriter") accounting for India, Campfire benchmark, MCP server, India moat (GST/TDS/e-invoice), solo-dev roadmap A–G | Strategic direction, AI-first product work |
| `docs/TALLY_PARITY_AND_MIGRATION_PLAN.md` | **Tally battle plan:** full TallyPrime feature matrix vs us (parity backlog §1), workflow strengths/pains, 5 wedges to beat them, Tally XML migration slices 1–3 | Tally parity work, migration importer, competitive positioning |
| `docs/PARTNER_NETWORK_MODULE_PLAN.md` | B2B ordering: data model, flows, 10 implementation phases | Phase 8 partner network |
| `docs/WORKFLOW_CONTEXT_HINTS_PLAN.md` | Context hints: resolver, widget, hint text per vertical | Adding workflow hints |
| `docs/plans/week-2-ap-module.md` | AP module spec (already implemented) | Debugging AP flows |
| `docs/MANUFACTURING_FEATURE_TRACKER.md` | 101 missing features, prioritized tiers, daily progress log | Manufacturing work |
