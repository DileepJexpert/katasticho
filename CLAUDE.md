# CLAUDE.md

Reference for working in this repo efficiently. Read this first; avoid re-exploring what's already documented here.

## Stack
- **Backend:** Spring Boot 3.3.5, Java 21, JPA/Hibernate, Flyway, PostgreSQL. Build: Maven (`./mvnw`).
- **Frontend:** Flutter (`flutter_app/`) — Riverpod + GoRouter + Dio.
- **Root layout:** `src/` (backend), `flutter_app/` (mobile/web), `docs/`, `scripts/`, `samples/`, `test-data/`.

## Design system (read before touching UI)
**All UI must follow `docs/design-system.md`.** Use only its tokens — never invent colours, spacing, or radii. Build screens by composing the primitives in §7 (KButton, KTextField, KBadge/KStatusChip, KDataTable, KCard, KPageHeader, KEmptyState, toast); do not style raw elements per screen. Before writing a component, restate which tokens you are using. North star: Linear / Stripe Dashboard / Campfire / Zoho Books — calm, dense, trustworthy. The implementation lives in `flutter_app/lib/core/theme/{k_colors,k_spacing,k_typography,k_theme}.dart` and `flutter_app/lib/core/widgets/k_*.dart`; if a token/primitive is missing, extend those files (don't fork them in feature code).
- **Money cells:** use `KMoney(amount)` (widget, `k_money.dart`) — it enforces ₹ Indian grouping + tabular figures + right-align by construction (wraps `CurrencyFormatter`). `colorBySign` is OFF by default (a debit is not "bad" — only colour genuinely negative states). Migrate raw money `Text(...)` to `KMoney` whenever you touch a screen.
- **IDs/codes** (GSTIN, invoice no, HSN, UTR): `KTypography.mono(...)` (IBM Plex Mono).
- **Status pills:** `KStatusChip(status: '...')` — `KColors.statusColor/statusBgColor` now keyword-infer tone (paid/overdue/pending/...) when the exact-match list misses, so new statuses read semantically instead of grey.
- **Density/motion tokens:** `KSpacing.rowH(40)/rowHCompact(36)/controlH(36)`, `KSpacing.durFast/durBase/ease`.
- **Token re-skin pending (do as ONE reviewable commit, not piecemeal):** brand blue `#4A7FE0`→teal `#0F8576`, app bg→warm `#F7F7F5`, error→muted `#BE3A34` in `k_colors.dart`; cap radii at 8 (`radiusXl/2xl` used in ~5 files — fix call sites in the same commit); borders-first card/table (drop card shadows) is a separate later visual pass.
- **Sidebar configurability:** every NavItem and NavGroup in `flutter_app/lib/routing/shell_screen.dart` carries a stable `id` (snake-case-dotted, e.g. `sales.invoices`). OWNER/ADMIN can hide entries via `org_settings.nav.disabled` (write via `PUT /api/v1/settings/nav.disabled` with a JSON array of ids) or the **Sidebar Customisation** settings screen at `/settings/nav-customisation`. PLATFORM_ADMIN role bypasses the disable list. Industry/role/country gates live on the NavItem fields directly (`roles`, `industries`, `countries` — null = no constraint).


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
- Location: `src/main/resources/db/migration/`. **Re-squashed 2026-06-21** (third time) to two baseline files — `V1__baseline_schema.sql` (full schema, CREATE-only, **267 tables**) + `V2__seed_reference_data.sql` (platform reference: drug/salt/manufacturer masters, HSN GST, GST state codes, CoA template, currency, generic_substitution, drug_interaction, ai_model_registry, **pt_slab** 60 rows across 14 PT states, **lwf_rule** 14 LWF states). Folded the old V3-V6 (PT/LWF/tax-decl/IMS) into baseline.
- **Internationalization migrations (2026-06-22):** `V3__add_gulf_africa_currencies.sql` (OMR/BHD/KWD=3dp, SAR/QAR/KES=2dp) + `V4__coa_template_country.sql` (coa_template gains `country` col, backfill 'IN'; Gulf 'AE' TRADING template = India minus 9 statutory accts + VAT 2041/1511). See `docs/INTERNATIONALIZATION_PLAN.md`. **Next new migration = V28** (V5-V19 shipped feature-by-feature; V20 = global medicine DB expansion; V21 = number-uniqueness + shedlock; V22 = country CoA matrix completion; V23 = edit_log audit trail; V24 = POS CREDIT payment mode; V25 = India gratuity accounts + accrual table; V26 = HSN GST rate history; V27 = Razorpay payment links + webhook).
- **Why the re-squash:** after the 2026-06-12 squash the chain had diverged into two parallel V18–V27 lines — a documented feature stream (HR depth/subresources, maintenance, linked/parameterized/dependency WOs, alt work centers, production→payroll, pharma BMR) and an undocumented transport/fixed-assets stream (hr_employee_profile, contact_portal, field_sync_log, pos_offline_receipt_link, fixed_assets, amortization, gst_filing_snapshot, courier+COD, lorry_receipt+freight, vehicle_log). Flyway refused to boot ("Found more than one migration with version 18"). `proof_of_delivery` was also CREATE'd twice (V21 sales shape + V27 transport shape). Since the DB is disposable (Docker-only, never deployed), every historical migration was applied in order to a throwaway PostgreSQL 16 instance and the result `pg_dump`'d into the new V1 (`--schema-only`) + V2 (`--data-only --inserts`). De-dup: the V21 sales `proof_of_delivery` shape was kept (its JPA entity survives); the transport POD scaffold (`com.katasticho.erp.transport` POD controller/service/repo/entity/test + Flutter screen) was deleted. Verified: fresh DB → Flyway applied 2 migrations → app boots clean with `ddl-auto: validate` (265 tables, all entities validate).
- **pg_dump 16.13 emits `\restrict`/`\unrestrict` psql meta-commands** at the top/bottom of a dump — these are stripped from V1/V2 because Flyway runs SQL over JDBC where backslash meta-commands are illegal. The data dump uses `--inserts` (not COPY) for the same reason. `CREATE EXTENSION IF NOT EXISTS pg_trgm` is kept (the env supports it; trigram indexes on drug_master depend on it).
- **`mvn clean` is mandatory after any migration squash** — incremental `target/classes/db/migration/` keeps the deleted files and Flyway then re-reports "Found more than one migration with version N" even though `src` is clean.
- Latent fresh-install bugs fixed during the original squash: old V59 inserted into non-existent `account.system` (→ `is_system`); old V62's org-scoped `exchange_rate` collided with the platform-level table (V62 shape kept — matches the JPA entity); old V62's currency-column DO-block guards checked the wrong column.
- V-number references in the phase notes below (V18–V71, V42, V67, ...) are historical — those files were all folded into V1/V2 and now live only in git history (pre-2026-06-20 commits). Their feature descriptions remain accurate; only the file no longer exists.
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
- **Tests:** FieldHierarchyServiceTest (5) + MrReportingServiceTest +3 + FieldCoverageServiceTest +1 (downline scoping). 65 field-sales tests pass. **ERP Flutter org-chart/manager-assignment UI still TODO (backend complete).**

#### Stockist Secondary Sales / SSS (2026-06-13) — CBO-ERP gap #3
- **V9 migration:** `stockist_sales_statement` (one per stockist contact/month, DRAFT→SUBMITTED, unique partial index) + `stockist_sales_line` (per product: opening/purchase/sales/return/closing qty + sales value).
- **`StockistSalesService`:** `saveStatement` (DRAFT-only upsert, replace-style lines, closing = opening+purchase−sales−return derived per line, `SSS_NOT_DRAFT` guard, stockist contact validated), `submit`, `getStatement`, `listByStockist`/`listByPeriod`, `secondarySalesReport(from,to)` (sales qty/value by product across statements in range, value-desc), `stockOnHand(month)` (closing qty by product lying at stockists). Records the downstream half of the primary (company→stockist) sales the rest of the system already captures.
- **`StockistSalesController`** @ `/api/v1/field-sales/secondary-sales` (OWNER/ADMIN/OPERATOR, FIELD_SALES module): statements CRUD+submit, `/reports/secondary-sales`, `/reports/stock-on-hand`.
- **Tests:** StockistSalesServiceTest (4 — closing derivation, non-draft block, secondary-sales aggregation, stock-on-hand sum). **ERP Flutter SSS entry/report UI TODO.**

#### RCPA — Retail Chemist Prescription Audit (2026-06-14) — CBO-ERP gap #2
- **V10 migration:** `rcpa_audit` (per chemist/MR/date, optional field_visit link) + `rcpa_line` (product, brand_type OWN/COMPETITOR check, competitor_name, our_item_id, quantity, value).
- **`RcpaService`:** `record` (create-or-replace lines, salesperson stamped from TenantContext, brand_type normalised, competitor_name kept only for COMPETITOR / our_item_id only for OWN, chemist contact validated), `getAudit`, `listByChemist`, `myAudits`, `shareReport(from,to)` (own vs competitor qty/value + `ownShareByQty/ValuePct`), `competitorBrands(from,to)` (competitor league table by product+competitor, value-desc).
- **`RcpaController`** @ `/api/v1/mr/rcpa` (OWNER/ADMIN/OPERATOR, FIELD_SALES module): record, get, `/me`, `/by-chemist/{id}`, `/reports/share`, `/reports/competitors`.
- **Tests:** RcpaServiceTest (3 — brand-type normalisation + salesperson stamp, own/competitor share %, competitor aggregation+sort). **ERP Flutter RCPA entry/report UI TODO.**

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

#### Provisional COGS + GRN true-up (2026-06-22)
- **The hole:** bill-freely lets POS sell an item before its purchase price is known. Pre-fix, `AccountingPostingEngine.postPosReceipt` simply skipped the COGS journal line when `item.purchasePrice <= 0` → revenue booked, inventory asset stayed flat, profit overstated forever (and the GRN's `DR Inventory / CR AP` never retro-booked the missed COGS).
- **V5 migration:** `stock_movement.cost_provisional` BOOL + `cost_settled_at` TIMESTAMPTZ + partial index `idx_stock_movement_unsettled_provisional` (org_id, item_id) WHERE cost_provisional=TRUE AND cost_settled_at IS NULL. Seeds `2042 'Stock-Out Suspense'` (LIABILITY, parent 2000) into `coa_template` for every (country, industry) that already has a 2031 TCS row, plus AE/TRADING which has no 2031 (no UAE TCS). Existing orgs pick up the new account on next-boot via the idempotent `AccountService.seedFromTemplate` + `DefaultAccountService.seedDefaultsForOrg` repair sweep — no backfill SQL needed.
- **Append-only invariant preserved:** `StockMovement.costProvisional` is `updatable=false` (set at INSERT only); `costSettledAt` is the second mutable field (alongside `reversed`), set once by the reconciler from NULL → timestamp and never cleared.
- **`CostResolverService.resolve(item, orgId)`:** precedence ladder — purchasePrice > 0 → real cost (non-provisional, source=PURCHASE_PRICE); else MRP × (1 − margin) (provisional, MRP_MINUS_MARGIN); else salePrice × (1 − margin) (SALE_PRICE_MINUS_MARGIN); else `null`. Margin defaults 0.25, org-tuneable via `inventory.provisional_margin_pct` (out-of-range values fall back to default).
- **`AccountingPostingEngine.postPosReceipt`** now splits per-line COGS into two buckets (real vs provisional) and posts two journal segments where applicable: real → DR COGS / CR Inventory (1200) (legacy); provisional → DR COGS / CR Stock-Out Suspense (2042). Items with no resolvable basis still skip COGS entirely (legacy fallback). `appendCogsLines` refactored to take the CR-account purpose so the same helper handles both.
- **`SalesReceiptService.deductStock`** now stamps the resolved unit cost (not `line.getRate()` — the SALE price was meaningless as a cost) on the SALE stock movement and sets `costProvisional=true` when the basis came from an MRP/salePrice fallback. `StockMovementRequest` gained an optional `costProvisional` field (defaults false, every other caller byte-for-byte unchanged); `InventoryService.recordMovement` plumbs it through to the builder.
- **`ProvisionalCostReconciler.reconcileForItem(orgId, itemId, actualCost, grnRef)`:** called from `StockReceiptService.receive` after each successful PURCHASE movement. Walks unsettled provisional SALEs for the item (oldest first via the new partial-index-backed repo method), computes per-movement variance = (actualCost − provisional unitCost) × |qty|, posts ONE correction journal: `DR Stock-Out Suspense (totalProvisionalCogs) / CR Inventory (totalProvisional + totalVariance) / DR COGS (variance>0) | CR COGS (variance<0)`, stamps `costSettledAt = now(clock)` on every settled row. Idempotent — re-running with nothing pending returns `settled=0` and posts no journal. Wrapped in try/catch in the GRN flow so an edge case never fails the receipt itself.
- **Net effect:** at GRN time, books fully self-heal. P&L reads correctly even after a bill-freely fresh-shop start; balance sheet matches physical stock; the historical "this row used provisional cost" fact is auditable on every settled `stock_movement`.
- **Tests:** `CostResolverServiceTest` (5 — purchase-price wins / MRP fallback / salePrice fallback / nothing → null / custom margin from org setting), `ProvisionalCostReconcilerTest` (6 — no-pending no-op, over-estimated → CR COGS, under-estimated → DR COGS, multi-movement aggregation with zero net variance, settled-at stamping, null actualCost no-op), `PosReceiptCogsTest` (3 — real path against 1200, provisional path against 2042, no-basis skips COGS entirely). 1273 total backend pass.

#### 3-way match (PO ↔ GRN ↔ Vendor Bill) (2026-06-22)
- **V8 migration:** `purchase_bill` gains `three_way_match_status` (CHECK
  MATCHED/EXCEPTION/BYPASSED/OVERRIDDEN), `three_way_match_at`,
  `three_way_match_overridden_by`, `three_way_match_override_reason`. New
  per-line `bill_match_result_line` table (replace-style: each match run deletes
  the bill's prior rows + writes fresh ones). Status CHECK includes
  MATCHED / QTY_OVER / PRICE_HIKE / AMOUNT_MISMATCH / NO_PO / NO_GRN / BYPASSED.
  Two partial indexes — one for the per-bill lookup, one for the dashboard's
  "exceptions" scan (excludes MATCHED rows).
- **`ThreeWayMatchService.match(billId)`** — walks each `PurchaseBillLine` via
  the V7 FKs, joins to the PO line + sums GRN line(s), classifies per line and
  rolls up to an overall bill status:
  - SERVICE item → skip GRN check, compare price only;
  - no `purchaseOrderLineId` AND bill total < bypass threshold → BYPASSED;
  - no `purchaseOrderLineId` → NO_PO;
  - PO linked, no GRN line with that FK → NO_GRN;
  - `billedQty > sumReceived × (1 + qtyTolerancePct/100)` → QTY_OVER;
  - `|billUnitPrice − poUnitPrice| > max(priceToleranceAbs, poPrice × pct)` → PRICE_HIKE;
  - else MATCHED.
  Overall: all BYPASSED → BYPASSED; any non-MATCHED non-BYPASSED → EXCEPTION;
  otherwise MATCHED. Pre-existing OVERRIDDEN status is preserved (the override is
  the planner's final word).
- **Hook into `PurchaseBillService.createBill`** at the end of the @Transactional
  method, wrapped in try/catch. Match failure NEVER blocks bill creation — a
  configuration / data hiccup just logs a warning. Bean cycle broken with
  `@Lazy` on the `ThreeWayMatchService` field (lombok.config copies @Lazy onto
  the constructor param).
- **EXCEPTION → AI Inbox suggestion** (`THREE_WAY_MATCH_EXCEPTION`, HIGH priority)
  via `AiSuggestionService.createSuggestion`. Idempotent through
  `AiSuggestionRepository.existsOpenSuggestion` — repeat match runs on the same
  bill don't pile up duplicate inbox rows. Payload carries the bill number, the
  worst exception status, and the exception line count.
- **Override (OWNER/ADMIN only):** `ThreeWayMatchService.override(billId, reason)`
  stamps OVERRIDDEN + `overriddenBy` (from TenantContext) + reason on the bill.
  Empty / blank reason throws `THREE_WAY_MATCH_OVERRIDE_REASON_REQUIRED`; second
  override throws `THREE_WAY_MATCH_ALREADY_OVERRIDDEN`.
- **`recordStockForBill` decision (option a — intentional fallback for direct
  bills):** Refactored to skip the PURCHASE stock movement when the bill links
  a PO that already has any non-cancelled GRN. The architectural rule
  (CLAUDE.md) is "GRN is the only stock-posting step" — but small orgs that
  skip the GRN entirely use the bill as their inventory source. The old
  unconditional path double-counted stock whenever an org ran the full P2P
  loop (GRN posted PURCHASE movements, then bill posted PURCHASE movements
  for the same goods). New behaviour: PO + active GRN exists → skip
  (GRN already booked it); else fall through to the legacy path (services-only,
  direct vendor bills, supplier-bill-first shops keep working unchanged).
  Backed by a new `StockReceiptRepository.existsActiveReceiptForPurchaseOrder`
  query that excludes CANCELLED + soft-deleted GRNs.
- **Org settings** (all `ap.three_way_match.*`):
  `required` (`true` default; when `false`, match still runs + surfaces
  EXCEPTION in the inbox but never blocks payment),
  `qty_tolerance_pct` (0 default — zero qty over-receipt tolerated),
  `price_tolerance_abs` (`1` ₹ default),
  `price_tolerance_pct` (`0.005` = 0.5% default),
  `bypass_threshold` (0 default — no bypass).
- **Endpoints** @ `/api/v1/ap/three-way-match`:
  `POST /{billId}/run` (manual re-run, OWNER/ADMIN/ACCOUNTANT),
  `GET /{billId}` (snapshot — status + per-line variances),
  `GET /exceptions?page=&size=` (paginated EXCEPTION lines for the inbox),
  `POST /{billId}/override` body `{reason}` (OWNER/ADMIN),
  `GET/PUT /settings` (OWNER/ADMIN — read/write the five tolerance keys).
- **Tests:** `ThreeWayMatchServiceTest` (15 — exact match, QTY_OVER at zero
  tol, qty within 1% tol, PRICE_HIKE above abs tol, price within abs tol, price
  within pct tol, NO_PO when no link, NO_GRN when PO linked but nothing received,
  BYPASSED below threshold, multi-line one PRICE_HIKE → EXCEPTION, replace-style
  delete + saveAll, override stamps + repeat-blocked, idempotent suggestion when
  one already open, SERVICE item skips GRN check, SERVICE item with matched price).
  1289 → 1304 total backend pass.

#### P2P workflow integration (2026-06-22)
- V7 migration: four new nullable FKs — `purchase_bill.purchase_order_id`,
  `purchase_bill_line.purchase_order_line_id`, `stock_receipt.purchase_order_id`,
  `stock_receipt_line.purchase_order_line_id` + four partial indexes (each only
  covers the rows where the FK is set, so direct GRN/Bill rows stay out of the index).
- **`PurchaseOrderService.createGrnFromPo(poId)`** — drafts a `StockReceipt` (DRAFT)
  with one line per PO line, qty = ordered − already-received (computed from
  `StockReceiptLineRepository.sumQuantityForPurchaseOrderLine` across all
  non-cancelled GRNs, NOT from the legacy `receivedQuantity` field), and stamps
  the FKs end-to-end (header `purchaseOrderId`, each line `purchaseOrderLineId`).
  HSN / GST rate / UoM copied from the item master, unit price from the PO line.
  Throws `PO_FULLY_RECEIVED` (BAD_REQUEST) when nothing remains across any line,
  `PO_CANCELLED` when the PO is cancelled, `PO_EMPTY` when the PO has no lines.
- **`PurchaseOrderService.createBillFromPo(poId)`** — drafts a `PurchaseBill`
  (DRAFT) with the same FK shape. Resolves vendor by looking up a Contact whose
  `displayName` matches `supplier.name` case-insensitively (must be VENDOR or
  BOTH); throws `PO_NO_VENDOR_CONTACT` when no matching vendor contact exists.
  Quantities default to the PO's ordered qty, prices from the PO. Bill date = today.
- **`StockReceiptService.receive`** finally writes to `PurchaseOrderLine.receivedQuantity`
  — for every GRN line with a `purchaseOrderLineId`, the source PO line's
  `receivedQuantity` is incremented by the GRN line's qty. The field was a dead
  schema column before V7; this is the only place that updates it.
- **`StockReceiptService.cancel`** mirrors the increment on RECEIVED → CANCELLED:
  every linked PO line's `receivedQuantity` is decremented by the GRN line's qty
  (clamped at zero so partial-cancel corruption from prior corrupted state can't
  make it negative). DRAFT → CANCELLED never touched the PO ledger, so DRAFT
  cancellation stays a no-op.
- **DTOs:** `CreateStockReceiptRequest` + `StockReceiptLineRequest` +
  `CreatePurchaseBillRequest` + its `BillLineRequest` all gain optional
  `purchaseOrderId / purchaseOrderLineId` fields. `StockReceiptResponse` +
  `StockReceiptResponse.LineResponse` + `PurchaseBillResponse` +
  `PurchaseBillResponse.LineResponse` all surface them. Every existing caller
  (`BillDraftingService`, `LorryReceiptService`, test fixtures) updated with
  explicit `null` for the new optional fields — no behavioural change for
  callers that don't use the P2P loop.
- **New repository:** `StockReceiptLineRepository` with
  `findByPurchaseOrderLineId`, `sumQuantityForPurchaseOrderLine`,
  `sumReceivedQuantityForPurchaseOrderLine` (RECEIVED-only — used by 3-way match
  in the next commit).
- **Endpoints:** `POST /api/v1/purchase-orders/{id}/create-grn` (OWNER/ADMIN/OPERATOR)
  + `POST /api/v1/purchase-orders/{id}/create-bill` (OWNER/ADMIN/ACCOUNTANT).
  Both return the drafted document (201 CREATED).
- **All FKs nullable** — direct GRNs / direct bills (no PO behind them) still work
  byte-for-byte unchanged. Bean cycle broken with `@Lazy` on the two service
  fields PurchaseOrderService injects (lombok.config copies `@Lazy` onto the
  generated constructor parameters).
- **Prerequisite for 3-way match (commit 2)** — match service reads these FKs to
  join Bill ↔ GRN ↔ PO without heuristics.
- Tests: `PurchaseOrderP2PTest` (3 — happy-path GRN draft w/ FK + remaining qty,
  Bill draft w/ FK + PO prices, fully-received throws), `StockReceiptServiceTest +2`
  (receive() increments PO line receivedQuantity when linked, never touches PO
  repo when no FK set). 1289 total backend pass.

#### Statutory pharma registers (H1 / Schedule X / Narcotics) (2026-06-22)
- **V6 migration:** `statutory_register_entry` table (register_type CHECK ∈ {H1, SCHEDULE_X, NARCOTICS}, optional sale_receipt_id / invoice_id with link-required CHECK, drug name + batch + qty + prescriber + patient + sale_date + retention_until) + 3 partial indexes (org+type+date desc, org+retention_until for cleanup sweeps, org+prescriber_reg_number for inspector lookups).
- **`StatutoryRegisterService.recordSaleEntries(receipt, itemMap)`:** hooked into `SalesReceiptService.create` after `deductStock`, wrapped in try/catch — non-business failures (DB hiccup, unmocked path) log warn + are swallowed so a register-writer bug never wedges a sale. `BusinessException` is allowed to bubble so strict-mode `RX_PRESCRIPTION_REQUIRED` rolls the entire receipt back. Resolves prescriber from `PrescriptionRecord` by `receiptId` (existing pharma table); resolves patient from `receipt.contactId`. Retention = sale_date + 3y for H1, + 2y for Schedule X / NARCOTICS (per Rule 65(11)(h) D&C Rules + Form 20G + NDPS Act 1985).
- **Schedule normalisation:** `classify()` tolerates Marg / Tally / paper-form variants — "H1", "H-1", "H1A", "Sch H1", "Schedule H1" all map to H1; "X", "Sch X", "Schedule X" to SCHEDULE_X; "NARC", "NARCO", "NARCOTIC", "NDPS" to NARCOTICS. Plain "H" (general Schedule H) does NOT trigger a register entry — that's a separate audit regime.
- **Org setting `pharma.h1_strict`** (default `false`): when `true`, H1 sale without a linked PrescriptionRecord throws `RX_PRESCRIPTION_REQUIRED` (BAD_REQUEST) → the @Transactional create rolls back. When `false`, the entry is recorded with null prescriber fields so the inspector still sees the sale + a flagged data-quality gap. Strict gate is H1-only — Schedule X / NARCOTICS still record without Rx (regulatory parity).
- **Endpoints** @ `/api/v1/pharma/statutory-registers` (OWNER/ADMIN/ACCOUNTANT, `@RequiresCountry("IN")` because the D&C Rules + NDPS Act are Indian statute): `GET ?type=&from=&to=&page=&size=` (paginated, newest first), `GET /{id}`, `GET /export?type=&from=&to=` (CSV download with CSV-escaped quotes-and-commas, Sl No + Sale Date + Drug + Batch + Qty + Prescriber Name + Reg No + Prescriber Address + Patient Name + Patient Address + Patient Phone + Receipt/Invoice ID + Retention Until), `GET /dashboard?type=` (totalEntries / entriesThisMonth / retentionDueWithin90Days + sample rows).
- **Flutter:** `StatutoryRegistersScreen` (`/pharma/statutory-registers`, command palette "Statutory Registers" — keywords rule 65 / H1 / schedule x / narcotics / NDPS / drug inspector / compliance / prescription register / D&C rules / audit). Three tabs (H1 / Schedule X / Narcotics) + per-register regulatory banner + date range filter + horizontal DataTable + app-bar Export CSV action (uses `Printing.sharePdf` for the native share sheet + clipboard fallback). Retention-Until column colour-coded red (<30 days) / orange (<180 days) / neutral.
- **Tests:** `StatutoryRegisterServiceTest` (11 — H1 → 3y retention, Schedule X → 2y, Narcotics → 2y, non-scheduled item → no entry, linked PrescriptionRecord populates prescriber fields, no Rx in non-strict mode → null prescriber not throw, no Rx in strict mode + H1 → `RX_PRESCRIPTION_REQUIRED`, strict mode only gates H1 not Schedule X / NARCOTICS, schedule normalisation table, batch number resolved from batchId, CSV header + per-row CSV-quoting). 1284 total backend pass.

#### POS Bill-Freely mode (2026-06-20)
- **Org setting `pos.allow_negative_stock`** (default **true** — unset key 404s → treated as true). When on, the POS counter sells retail-style: catalog quick-add is a single tap (no opening-stock dialog — item is created at 0 stock and goes negative, reconciled later via a stock receipt), quantities are never clamped to recorded stock, and a sale is never blocked for being short. The cart's red "0 available" pill stays as a soft cue. When off, the old strict path is byte-for-byte preserved (catalog quick-add shows the opening-stock dialog so the item is sellable, stepper caps at stock, checkout blocks on `hasStockExceededItems`).
- **Why:** a fresh shop has zero items, so every POS search fell through to the catalog quick-add, which forced an opening-stock popup on every medicine AND capped the cart quantity at that opening stock (default 1) — the `+` button hard-disabled at `maxSellQuantity`, so the cashier was frozen at 1. Bill-freely removes both frictions.
- **Backend:** `SalesReceiptService.create` skips `inventoryService.validateStockForSale` when the setting is on (the non-batch SALE movement itself never blocks negative; only the pre-flight validator + the batch gate do — batch-tracked items still can't sell from a non-existent batch). Reads via `OrgSettingsService.get(orgId, "pos.allow_negative_stock", "true")`.
- **Flutter:** `posAllowNegativeStockProvider` (GET `/api/v1/settings/pos.allow_negative_stock`, default true) → mirrored into `PosCartState.allowNegativeStock` (drives `_clampToStock` + the `_QuantityStepper` `+` enable + the checkout `hasStockExceededItems` gate + the `_addToCart` stock<=0 short-circuit). Toggle in POS Receipt Settings → "Billing" → "Bill freely (sell without stock)" (OWNER/ADMIN; writes via generic `PUT /api/v1/settings/{key}`). **No Flutter SDK in the cloud env — `flutter analyze`/`test` must be run locally.**

### Kirana Retail Production Gaps (2026-06-10)
**Goal:** Make the POS + core flows production-ready for Indian small grocery/pharmacy shops.

- **~~P8: Profit margin on POS~~ (DONE):** PosSearchController strips `purchasePrice` for OPERATOR/ACCOUNTANT roles. OWNER/ADMIN see margin breakdown in payment sheet + margin dot per item.
- **~~P4: UPI QR code at POS~~ (DONE):** OrgSettings stores `pos.upi_id`/`pos.upi_display_name`. Payment sheet renders scannable QR via `qr_flutter`. POS Receipt Settings has UPI config section.
- **~~P6: Cash register / day close~~ (DONE):** V48 migration. CashRegisterService: open day, petty cash expenses, close with variance. 7 endpoints. Flutter: Today + History tabs in CashRegisterScreen, accessible from POS overflow menu.
- **~~P7: SMS notifications~~ (DONE):** SmsService (Fast2SMS/MSG91, async fire-and-forget, Indian mobile sanitization). Hooked in SalesReceiptService (receipt SMS) and LowStockAlertJob (per-item alert to org owner). GET/PUT `/api/v1/settings/sms`. Flutter: `_SmsSettingsSection` in POS Receipt Settings screen.
- **~~P1: Thermal/Bluetooth printer~~ (DONE):** ThermalPrintService (ESC/POS via flutter_blue_plus, 58mm/80mm paper, respects ReceiptSettings). PrinterSetupScreen with scan/connect/test/auto-print. POS _handlePrint uses thermal when connected, PDF fallback.
- **~~P2: Offline POS~~ (DONE):** OfflinePosService with SQLite queue (sqflite). Network errors in _completeSale auto-queue receipt locally. Connectivity listener auto-syncs on reconnect. Sync badge in POS app bar shows pending count + manual Sync Now. Max 5 retries per receipt.

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
- `ai/service/ProactiveAgentService.java` — **Proactive agents (Phase G)** — "the system tells you first". `runAll()` drafts AI Inbox suggestions: (1) **collections reminders** — one `COLLECTIONS_REMINDER` per overdue customer (via `CreditReminderService.getOverdueCustomers` + `generateReminderMessage` for a ready-to-send WhatsApp draft), priority by days overdue; (2) **month-close checklist** — if the just-ended month's `FiscalPeriod` is still OPEN, a `MONTH_CLOSE_CHECKLIST` nudge with standard steps + pending-inbox count; (3) **anomaly sweep** — delegates to `RuleBasedAiAgentService.runRuleChecks`. All idempotent via `existsOpenSuggestion`. Driven by `automation/ProactiveAgentJob` (daily 6:30am, per-org TenantContext loop, `app.automation.proactive-agents.cron`). Manual trigger `POST /api/v1/ai/agents/proactive/run`. Flutter: "Run checks" button in AI Inbox.
- `ai/service/ConversationalEntryService.java` — **Conversational entry (Phase B)**: "type a sentence → drafted transaction". `draftFromText()` parses payments/receipts via a rule-based parser (no external AI call: direction from paid/received, amount w/ ₹/k/lakh, instrument cash→1010/bank→1020, party→contact→AR/AP, expense/income by keyword vs CoA, Miscellaneous-Expense fallback) → balanced DRAFT journal via `JournalService.postJournal(autoPost=false)` + `DRAFT_ENTRY` AiSuggestion. `approve()` posts via `postEntry`; `reject()` deletes draft. Unparseable text returns `drafted=false` + a how-to-rephrase message (no draft created). `POST /api/v1/ai/entry[/{id}/approve|/reject]`. Flutter: Quick-entry composer in AI Inbox tab + DRAFT_ENTRY accept/reject routing.
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
1. ~~Cost centre P&L~~ DONE · 2. ~~Budgets + variance~~ DONE · 3. ~~Interest on overdue~~ DONE (~~debit-note draft~~ DONE 2026-06-19: `InterestChargeService.draftInterestDebitNote(invoiceId)` posts `DR AR / CR Interest Income (4110)` as a DRAFT journal — same simple-interest formula as the report so report and journal match to the rupee; `POST /api/v1/reports/overdue-interest/{invoiceId}/draft-debit-note`; new `DefaultAccountPurpose.INTEREST_INCOME` (4110 already seeded for all four industries in V2); tests: InterestChargeServiceTest (6 — DR/CR shape, rate honoured, not-overdue / no-balance / no-due-date / unknown guards)) · 4. ~~Stock ageing~~ DONE · 5. ~~Ratio analysis~~ DONE · Post-dated vouchers DONE (old V56).
6. ~~Realized forex gain/loss~~ DONE both sides (2026-06-12). AR: `postPaymentReceived` books cash at payment rate, clears AR at invoice rate, diff → 5500. AP: `postVendorPayment` clears AP per-allocation at each bill's rate vs cash at payment rate (paying more base = loss DR, less = gain CR); **forex applies only when TDS = 0** (TDS sections govern resident INR payments) — TDS path stays byte-identical legacy. Tests: PaymentForexPostingTest (9).

### C. Pharma/catalog follow-ups
1. ~~HSN master CRUD~~ DONE (2026-06-12): `PharmacyMasterService.upsertHsn` — OWNER/ADMIN may ADD missing codes (rates are statutory facts, shared platform table); editing an EXISTING row needs PLATFORM_ADMIN (`HSN_PLATFORM_ROW_READONLY`). `POST /api/v1/pharmacy-masters/hsn`; ERP `HsnMasterScreen` @ `/inventory/hsn-codes` (sidebar + palette).
2. ~~Schedule H1 overlay~~ DONE: V4 migration flags the 46 notified Schedule H1 substances by salt-name match → drug_schedule='H1' + prescription_required (1,723 products incl. combinations on fresh DB). Full Schedule H (500+ substances) still default GENERAL.
3. ~~36 GST-exempt lifesaving drugs~~ DONE: V4 seeds the 56th-Council nil-rated list (33 from 12% + 3 from 5%) as drug_master rows @ gst_rate 0.
4. ~~Org setting batch-track quick-adds~~ DONE: `pos.catalog_quick_add_track_batches` (default false); when on, opening qty books into an auto 'OPENING' batch.
5. Optional: merge official Jan Aushadhi / NLEM lists (gov sites bot-gated — needs one manual browser download; curated Jan Aushadhi/DavaIndia generic ranges already seeded by V20, and the official CSV can now be loaded through the drug-master import endpoint below).
6. ~~Global medicine DB expansion + bulk importer~~ DONE (2026-07-02): **`V20__medicine_database_global_expansion.sql`** grows the platform masters beyond the India-centric V2 seed — +275 salts (newer classes: GLP-1s, gliflozins, DOACs, biologics, antiretrovirals incl. TLD, antimalarials), +107 manufacturers with country+website (Indian majors, Gulf: Julphar/SPIMACO/Hikma/Jamjoom/NPI-Oman, Africa: Beta Healthcare/Cosmos/Adcock/Aspen/Emzor, global: Haleon/Kenvue/Viatris/Organon/AbbVie/..., 27 countries), +472 drug brands in 5 themed batches (Gulf/GCC retail, East+South Africa staples incl. Coartem/AL antimalarials, global US/EU brands, Jan Aushadhi (PMBI) + DavaIndia (Zota) generic ranges at real low MRPs, Indian retail additions incl. 2024-25 launches Wegovy/Mounjaro/Vymada + ayurvedic OTC + devices/consumables). Counts after V20 on fresh DB: **23,400 drugs / 556 salts / 164 manufacturers**. Idempotency: salts/manufacturers `ON CONFLICT (name) DO NOTHING`; drug batches insert via VALUES-CTE + case-insensitive brand-name `NOT EXISTS` + `DISTINCT ON` (re-run verified zero-delta on live PG 16; full V1→V20 chain applies clean). Conventions: salt_id linked by generic-name match (78% of new rows), MRP = approx INR for Indian rows / NULL for foreign-market rows (PosCatalog passes MRP→salePrice, NULL beats a fabricated cross-currency number), schedules use the Indian H/H1/X buckets (Suprax/cefixime→H1, Ritalin→X) so the POS Rx dialog fires correctly for any org. **Bulk CSV importer:** `DrugMasterImportService` + `POST /api/v1/drug-master/import` (multipart `file`, `?dry_run=`, OWNER/ADMIN — add-only to the shared platform table per the HSN precedent) — header-driven with aliases (brand/company/price/schedule/...) matching root `drugs_reference.csv` + Marg-style exports, RFC-4180 quoted fields, dedupe vs DB + in-file by lower(brand), salts linked-never-created (one bulk `findByNameIgnoreCaseIn`), manufacturers auto-registered, schedule normalisation (`Sch H1`→H1, `NDPS`→NARCOTICS), rx defaults from schedule, 100k rows/upload cap, errors capped at 50. This closes the section-F "254k source list importer" item — the full 1mg-style dump imports in 3 chunks. Repo methods added: `DrugMasterRepository.findAllBrandNamesLower()`. Flutter: `ApiConfig.drugMasterImport` (upload UI TODO). Tests: DrugMasterImportServiceTest (7 — field mapping+salt link+mfg creation+quoted commas, DB+in-file dedupe, dry-run saves nothing, row errors don't kill good rows, schedule normalisation table+rx defaults, header aliases any order, no-brand-column/empty-file guards). 1,459 total backend pass.

### D. Field force leftovers
1. ~~E-detailing~~ DONE (2026-06-12, URL-based): V5 `detail_aid` (org-scoped: name/media_url/PDF-IMAGE-VIDEO-LINK/product, active flag) + `visit_detail_aid_log`. `DetailAidService`: CRUD (OWNER/ADMIN; http(s) URL validated, unknown type → LINK), `listWithUsage()` (shown counts), `logShown(visitId, aidIds)` (replace-style, post-check-in, owner-only, aid org-validated). Endpoints @ `/api/v1/mr/detail-aids[/manage|/{id}]` + `PUT/GET /visits/{id}/detail-aids`. ERP `DetailAidsScreen` (`/field-sales/detail-aids`: usage counts, active toggle, open-media, add/edit dialog). Field app: "Aids" button on IN_PROGRESS visits → sheet (open via url_launcher — dep added to pubspec, marks shown; checkboxes; save). Tests: DetailAidServiceTest (7). 707 total pass. Media stays URL-hosted (Drive/S3) — no file-storage service yet.
2. ~~Attendance → payroll LOP~~ DONE (2026-06-12): `employee.user_id` (baseline) links payroll employees to app users; `payslip.lop_days` records approved UNPAID leave days clipped to the run period; EARNING components prorate by (periodDays − lop)/periodDays in `PayrollService.calculatePayslip`. No user link / no unpaid leave = behaviour unchanged. `EmployeeRequest.userId` exposed (ERP employee-form dropdown still TODO). **LOP unit test DONE (2026-06-13):** PayrollServiceTest +3 (calculateRun w/ unpaid leave prorates earnings + records lopDays; leave spanning the period boundary counts only in-period days; paid/CASUAL leave = no LOP, full pay). 11 PayrollServiceTest tests pass.
3. ~~True background GPS in field app~~ DONE (2026-06-17): `flutter_background_service: ^5.0.10` + `flutter_background_service_android: ^6.2.7` added to the field-app pubspec; new `BackgroundLocationService` runs the ping loop in a separate background isolate so pings continue when the app is backgrounded. Android wires it as a foreground service of type `location` (manifest perms FOREGROUND_SERVICE / FOREGROUND_SERVICE_LOCATION / ACCESS_BACKGROUND_LOCATION / WAKE_LOCK / POST_NOTIFICATIONS / RECEIVE_BOOT_COMPLETED + `<service android:name="id.flutter.flutter_background_service.BackgroundService" android:foregroundServiceType="location">`); iOS uses background modes `location` / `fetch` / `processing` with the three location usage strings added to Info.plist (best-effort — iOS may suspend the isolate aggressively). Background isolate reads auth token + executionId + baseUrl from SharedPreferences (the executionId key it owns; the token key is the same `field.session..accessToken` the `SessionStore` writes, so token refreshes flow through automatically). Ping POST has the same shape and endpoint as the foreground client; failures enqueue into the existing `field.offline.queue` SharedPreferences key so the in-app sync loop replays them once online. `LocationPingTracker.start/stop` now drive the background service (best-effort, plugin failures swallowed) AND keep the original in-app `Timer.periodic` running as a foreground-mode safety net + plugin-missing fallback. `main.dart` calls `BackgroundLocationService.initialize()` at boot (wrapped in try/catch). **Note: cloud env has no Flutter SDK, so `flutter pub get` + `flutter analyze` + a real Android build are required locally before shipping.**

### E. Deployment-day config checklist (no code)
FCM service-account (`app.push.fcm.service-account-file`) · SMS provider keys · WhatsApp Business token · GSP creds (e-invoice/EWB one-click) · Redis.

### F. Bigger tracks (later)
Manufacturing tracker ~20/101 remaining after maintenance + shop-floor mobile + ~~batch assignment on FG receipt~~ + ~~production trends dashboard~~ + ~~batch recall~~ + ~~WO profitability~~ + ~~scrap rate dashboard~~ + ~~BOM version diff~~ + ~~auto-WO from reorder~~ + ~~FEFO in production~~ + ~~work instructions on operations~~ + ~~linked sub-assembly WOs~~ + ~~split / merge WOs~~ + ~~operation dependencies~~ + ~~alternative work centers~~ + ~~production-to-payroll bridge~~ + ~~parameterized BOMs~~ + ~~pharma BMR~~ + ~~food FSSAI~~ tracks (Gantt, garment cut plans; ~~maintenance management~~ DONE 2026-06-17; ~~shop-floor mobile UI~~ DONE 2026-06-17; ~~batch assignment on FG receipt~~ DONE 2026-06-19 — tracker #43+#65; ~~production trends dashboard~~ DONE 2026-06-19 — tracker #52; ~~batch recall~~ DONE 2026-06-19 — tracker #47; ~~WO profitability~~ + ~~scrap rate dashboard~~ DONE 2026-06-19 — tracker #53+#54; ~~BOM version diff~~ DONE 2026-06-19 — tracker #41; ~~auto-WO from reorder~~ DONE 2026-06-19 — tracker #66; ~~FEFO in production~~ + ~~work instructions on operations~~ DONE 2026-06-19 — tracker #45+#13; ~~linked sub-assembly WOs~~ DONE 2026-06-19 — tracker #60; ~~split / merge WOs~~ DONE 2026-06-19 — tracker #64; ~~operation dependencies~~ DONE 2026-06-19 — tracker #16; ~~alternative work centers~~ DONE 2026-06-19 — tracker #15; ~~production→payroll bridge~~ DONE 2026-06-19 — tracker #57; ~~parameterized BOMs~~ DONE 2026-06-19 — tracker #42; ~~pharma BMR~~ DONE 2026-06-19; ~~food FSSAI compliance pack~~ DONE 2026-06-19) · GST polish (~~B2CL in GSTR-1~~ DONE · ~~2B re-upload dedupe~~ DONE 2026-06-13 · ~~2B auto-fetch via GSP~~ DONE 2026-06-17) · ~~POS catalog: full 254k source list importer~~ DONE 2026-07-02 (drug-master CSV import endpoint — see section C item 6).

#### Manufacturing — MTO vs MTS Production Modes (2026-06-19, tracker #34)
- **V30 migration:** `item.production_mode` nullable VARCHAR(10) with CHECK (`production_mode IS NULL OR production_mode IN ('MTO', 'MTS')`). Every existing item stays NULL → legacy behaviour preserved.
- **`Item.productionMode` field** drives which auto-WO automation creates work orders for a composite item:
  - **MTO (Make-to-Order)** — only the SO→WO path (`createWorkOrdersFromSalesOrder`) fires; reorder sweep (`autoCreateWorkOrdersFromReorder`) skips. Build on order only, no inventory build-up for orders that never come.
  - **MTS (Make-to-Stock)** — only the reorder sweep fires; SO→WO skips (stock should already be there from the periodic sweep).
  - **null (legacy default)** — both automations fire, byte-for-byte identical to pre-V30 behaviour for every existing org.
- **Guard placement** matters: the MTO skip in `autoCreateWorkOrdersFromReorder` short-circuits BEFORE the open-WO dedupe check (verified by test); the MTS skip in `createWorkOrdersFromSalesOrder` short-circuits BEFORE the BOM lookup (also verified).
- **`ManufacturingService.setProductionMode(itemId, mode)`** — case-insensitive ("mto" → "MTO"), null/blank clears, `MFG_INVALID_PRODUCTION_MODE` 400 for anything else.
- **Endpoint:** `PATCH /api/v1/manufacturing/items/{itemId}/production-mode` (OWNER/ADMIN). Body: `{"productionMode": "MTO" | "MTS" | null}`.
- **Flutter:** `ProductionModeScreen` (`/manufacturing/production-mode`, command palette "Production Mode (MTO/MTS)" — keywords mto/mts/make to order/make to stock/replenishment/reorder/auto wo) — info card explaining the three modes + item-id input + ChoiceChips (MTO / MTS / Clear) + save button with success/error feedback.
- **Tests:** `ManufacturingServiceTest +3` — MTO item with low stock returns empty + never calls `existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse` (the skip beats the dedupe check); MTS item on a confirmed SO throws `MFG_SO_NO_COMPOSITE_ITEMS` + never queries BOM (skip beats BOM lookup); `setProductionMode` accepts mto/MTS/null/blank, throws `MFG_INVALID_PRODUCTION_MODE` for "FLEXIBLE". 931 total backend pass.

#### Manufacturing — Equipment Reliability MTBF/MTTR (2026-06-19, tracker #86)
- **`MaintenanceService.reliabilityReport(from, to)`** — per-workstation reliability metrics. Pulls every COMPLETED maintenance_work_order in the window, groups by workstation, computes: `MTTR = breakdownDowntime / breakdownCount` (mean time to repair), `MTBF = uptime / breakdownCount` where uptime = windowMinutes − totalDowntime (mean time between failures), `availabilityPct = uptime / windowMinutes × 100`. Only BREAKDOWN MWOs feed MTBF/MTTR — scheduled PREVENTIVE downtime is planned, not a failure. Workstations with zero breakdowns appear with null MTBF/MTTR (can't divide by zero) but 100% availability. Sorted by availabilityPct ascending — worst machine first, which is exactly the rank order an engineer cares about. Includes all org workstations (even ones with no incidents in the window) so good-news machines aren't hidden.
- **Endpoint:** `GET /api/v1/manufacturing/maintenance/reports/reliability?from=&to=`. Companion to the existing `/reports/downtime` aggregation — downtime answers "how much time did we lose", reliability answers "how reliable is each machine".
- **Flutter:** `ReliabilityScreen` (`/manufacturing/reliability`, command palette "Equipment Reliability" — keywords mtbf/mttr/availability/uptime/breakdown/failure/oee) — date range picker + per-workstation card w/ availability % chip color-coded (green ≥95% / orange ≥85% / red <85%), MTBF/MTTR/breakdowns/preventive/downtime stats with tooltips explaining each acronym. Human-formatted minutes (1d 5h, not 1740m).
- **Tests:** `MaintenanceServiceTest +3` — 1-day window with 1 BREAKDOWN (90min) + 1 PREVENTIVE (30min) → MTTR=90 (BREAKDOWN downtime only), MTBF=1320, availability=91.67%; workstation w/ no breakdowns → null MTBF/MTTR + 100% availability; sort order = worst availability first. 928 total backend pass.

#### Manufacturing — CAPA Tracking (2026-06-19, tracker #88)
- **V29 migration:** `capa_action` (org-scoped, soft-delete) — capa_number (auto-numbered `CAPA-YYYY-NNNNN`), optional `ncr_id` FK to `non_conformance_report` (standalone PREVENTIVE actions allowed), capa_type CORRECTIVE | PREVENTIVE (CHECK), title/description/proposed_action, assigned_to, due_date, priority URGENT/HIGH/NORMAL/LOW (CHECK), status OPEN/IN_PROGRESS/COMPLETED/VERIFIED/CANCELLED (CHECK), completion_notes/completed_at/completed_by, verified_at/verified_by/effectiveness_notes. Five partial indexes (capa_number, org+open-status, org+due_date, org+assignee, org+ncr).
- **`CapaService`** (manufacturing.service, Clock-injected for testable date math): `raise` (validates type/title/priority, auto-numbers per year, refuses CAPAs against CLOSED NCRs — close-the-loop ordering matters), `start` (OPEN→IN_PROGRESS), `complete` (OPEN/IN_PROGRESS → COMPLETED, stamps `completedBy` from TenantContext), `verify` (COMPLETED → VERIFIED, **self-verify forbidden** — verifier must differ from completer for independent effectiveness sign-off, `CAPA_SELF_VERIFY_FORBIDDEN`), `cancel` (any non-terminal state, blocks VERIFIED/CANCELLED via `CAPA_FINAL_STATE`). Read methods: `get`, `list(status, pageable)`, `listByNcr`, `myCapas` (current user's assignments, due-date asc), `overdue` (OPEN/IN_PROGRESS with due_date in past), `dashboard` (per-status counts + overdue total).
- **`CapaController`** @ `/api/v1/manufacturing/capa` (`@RequiresModule(MANUFACTURING)`): raise (OWNER/ADMIN/OPERATOR — anyone can flag a quality issue), start/complete (OWNER/ADMIN/OPERATOR), verify/cancel (OWNER/ADMIN — verifier role gates the integrity loop); read endpoints unrestricted.
- **Flutter:** `CapaScreen` (`/manufacturing/capa`, command palette "CAPA" — keywords corrective/preventive/ncr/iso 9001/13485/iatf/audit/root cause) — 4 tabs (All / Open / My CAPAs / Overdue) + per-status dashboard strip (open/in-progress/completed/verified/overdue counts color-coded) + FAB "Raise CAPA" dialog (type + priority dropdowns, title/description/proposed action, optional NCR id + assignee + due date) + per-row action menu (Start / Complete / Verify / Cancel) gated by status. Verification + cancel use a shared notes dialog so the rationale is captured.
- **Tests:** `CapaServiceTest` (11) — happy path raise w/ auto-number (CAPA-2026-00008), invalid type / empty title / invalid priority guards, raise-against-CLOSED-NCR throws, full lifecycle walk (start → complete + completedBy stamp), self-verify by completer throws `CAPA_SELF_VERIFY_FORBIDDEN`, different verifier stamps + moves to VERIFIED, cancel-VERIFIED throws `CAPA_FINAL_STATE`, start-already-in-progress throws `CAPA_INVALID_TRANSITION`, overdue walks repo with fixed-clock today. 925 total backend pass.

#### Manufacturing — Workstation Bottleneck Identification (2026-06-19, tracker #92)
- **`BottleneckService.workstationLoadReport()`** — walks every open (PENDING + IN_PROGRESS) job card via new `JobCardRepository.findOpenForOrg`, computes estimated hours per JC = `(operation.setupTimeMinutes + operation.runTimeMinutesPerUnit × plannedQty) / 60`, sums per workstation. Compares queue to `workstation.capacityHoursPerDay` → `daysOfWork` + `utilisationPctOfDay`. Classifies as BOTTLENECK (>5 days queued), BUSY (>1 day), OK (≤1 day), IDLE (no work), UNCAPACITATED (no capacity set). Sorted by queued hours desc — worst offender at top. Workstations with no open work still appear so planners see headroom they can reassign work to. Orphan job cards (op/ws missing) silently dropped — don't second-guess missing data.
- **`topBottlenecks(limit)`** — first N non-IDLE workstations. Feeds the dashboard tile pattern.
- **Endpoints:** `GET /api/v1/manufacturing/reports/workstation-load` (full table) + `GET /api/v1/manufacturing/reports/bottlenecks?limit=N` (top N only).
- **Flutter:** `WorkstationLoadScreen` (`/manufacturing/workstation-load`, command palette "Workstation Load" — keywords bottleneck/capacity/queue/utilisation/machine) — RefreshIndicator list w/ status chip color-coded (red BOTTLENECK / orange BUSY / green OK / grey IDLE) + per-row stats (queued hours, capacity, days of work, open JCs, in-progress, utilisation %).
- **Tests:** `BottleneckServiceTest` (5) — sums hours per workstation + sorts by queue desc (2 JCs × 530min on A = 17.67h → 2.21 days → BUSY), idle workstation appears in list, >5 days queued → BOTTLENECK classification, topBottlenecks filters IDLE out, orphan job card (unknown operation) silently skipped. 914 total backend pass.

#### Manufacturing — Actual Costing from Time Tracking (2026-06-19, tracker #80)
- **`ManufacturingService.computeActualLaborAndOverhead(wo)`** — walks the WO's job cards, sums `timeLoggedMinutes/60` × `workstation.hourlyRate` for actual labor; multiplies the same total hours by the org setting `manufacturing.overhead_rate_per_hour` for absorbed overhead. Returns an `ActualCost(labor, overhead, totalHours, jobCardCount)` record. Null labor when no logged job card carries a workstation with a rate → caller falls back to the WO's planned estimate (preserves the legacy estimate-only path for orgs without workstation rates configured). Null overhead when the org setting isn't set.
- **`buildCostSummary` hook:** on WO completion the cost summary now uses tracked labor + overhead when available (variance fields finally become meaningful: actual − planned), falls back to the WO's `directLaborCost` / `overheadCost` estimates otherwise. Legacy WOs without routing/job-cards keep byte-for-byte identical cost summaries.
- **Endpoint:** `GET /api/v1/manufacturing/work-orders/{id}/actual-cost-preview` — returns the rollup BEFORE completion (planner-side eyeball to spot missing workstation rates while there's still time to fix them). Shape: `{workOrderId, workOrderNumber, totalHours, jobCardCount, trackedLaborCost, trackedOverheadCost, plannedLaborCost, plannedOverheadCost, rawMaterialCost}`.
- **Flutter:** `ActualCostPreviewScreen` (`/manufacturing/actual-cost-preview`, command palette "Actual Cost Preview" — keywords labor/overhead/time tracking/actual cost/variance) — paste a WO id, see the time-tracked card (hours, job-card count) + the cost card (RM/labour-tracked/labour-planned/overhead-tracked/overhead-planned). Amber warning card explains the null cases (no workstation rates / no org overhead rate).
- **Defensive null-guard:** `computeActualLaborAndOverhead` honours null jobCardRepository/workstationRepository/orgSettingsService — older test fixtures pass nulls for the tracker #80 wiring, so the helper returns "fall back to planned" instead of NPE'ing.
- **Tests:** `ManufacturingServiceTest +4` — sums hours × workstation rate (2h × 250 + 1.5h × 400 = 1100), applies org overhead rate per hour (4h × 150 = 600), no-job-cards returns nulls for fallback, job-card-logged-but-no-rate returns null labor but still tracks hours (so HR can spot mis-configured rates). 909 total backend pass.

#### Food / FSSAI Compliance Pack (2026-06-19)
- **V28 migration:** extends `item` with FSSAI columns — `fssai_license` (14-digit FBO number, varchar 20), `veg_classification` (CHECK: VEGETARIAN | NON_VEGETARIAN | VEGAN | EGG), `allergens` (JSONB list), `nutritional_info` (JSONB map for per-100g/serving values), `date_marking_type` (CHECK: BEST_BEFORE | USE_BY | EXPIRY), `shelf_life_days` (positive int). Extends `organisation` with `fssai_license` + `fssai_license_expiry` for the facility-level FBO license. GIN partial index on `item.allergens` so the exposure report stays fast across 100k items.
- **`FssaiService`:**
  - `updateItemFssai(itemId, FssaiUpdateRequest)` — validates 14-digit license format, veg-class enum, date-marking enum, shelf-life > 0. Normalises allergen codes to upper-case at write time so the exposure report doesn't fan out on casing. Partial-update semantics: any null field on the request is left untouched on the entity.
  - `allergenExposureReport(allergen)` — input case-insensitive. Returns every item whose `allergens` array contains the code (Java-side filter for now; if the org grows past 100k items the JSONB-contains query is the obvious next step). The QA report you actually want during an incident: "which of our products contain peanut?"
  - `licenseRenewalReport(daysAhead)` — org-level FBO license first (losing it shuts the plant), then per-item licenses (per-item expiry not in V28 yet but the report is wired so a follow-up adds it). Returns shape `{scope, license, expiryDate, daysToExpiry}`.
  - `majorAllergens()` — canonical sorted list of the 14 FSSAI/Codex major allergens (MILK, EGGS, FISH, CRUSTACEAN_SHELLFISH, TREE_NUTS, PEANUTS, WHEAT_GLUTEN, SOYBEANS, MUSTARD, SESAME, CELERY, LUPIN, MOLLUSCS, SULPHITES) so Flutter can render checklist UIs without hard-coding the list.
- **Endpoints** (`/api/v1/fssai`): `GET /items/{id}`, `PUT /items/{id}` (OWNER/ADMIN/OPERATOR), `GET /allergens`, `GET /reports/allergen-exposure?allergen=...`, `GET /reports/license-renewal?daysAhead=60`, `GET /items/{itemId}/label?batchId=` (food-label PDF, all roles).
- **`FoodLabelPdfService` (2026-06-19):** regulator-ready FSSAI food-label PDF generator on A6 paper, the size every retail pack legally needs. Renders product header (name + composition), the mandatory veg/non-veg/vegan/egg coloured symbol (FSSAI 2.2.2.4), allergen "Contains: …" line (or explicit "None of the major allergens" / "Not declared" warning), nutritional info table (per 100g/100ml — `calories_kcal` prettified to "Energy (kcal)" per FSSAI 2.2.2.1), manufacturing block (batch number + MFG date + computed expiry from batch's expiryDate OR mfgDate+shelfLifeDays fallback + date-marking label + net quantity), compliance block (item-level FSSAI license falls back to org-level FBO license, manufacturer name + address + GSTIN), and a footer with the consumer-contact line. Batch mismatch → `FSSAI_LABEL_BATCH_ITEM_MISMATCH` 400. All user-supplied strings HTML-escaped (XSS guard). `filename(item, batch)` strips reserved path chars + appends batch number when supplied. HTML→PDF via the shared `DocumentPdfService` (open-html-to-pdf), same pipeline as `BmrPdfService`.
- **Flutter:** `FssaiScreen` (`/inventory/fssai`, command palette "FSSAI Compliance" — keywords fssai/food/allergen/veg/license/label/codex/nutrition) — 3 tabs: Item compliance (paste an item id, edit veg dropdown with 🟢🔴🌱🟡 emojis, shelf-life days, date-marking dropdown, allergens as FilterChips populated from `/allergens`, **Save + Print food label** buttons — "Print food label" downloads the PDF via `Printing.sharePdf` for the native share/save sheet); Allergen exposure (pick allergen → table of items declaring it); License renewal (horizon dropdown 30/60/90/180 days → list of orgs+items expiring, urgent ≤30 days in red).
- **Tests:** `FssaiServiceTest` (12) + `FoodLabelPdfServiceTest` (8 — compliant item renders all mandatory sections incl. product name + Veg label + "Contains:" line + pretty allergen names + nutrient keys prettified ("Energy (kcal)" for calories_kcal, "Protein (g)" for protein_g) + FBO licence + manufacturer name+address; batch info carries batch number + expiry to the label; batch-from-different-item throws `FSSAI_LABEL_BATCH_ITEM_MISMATCH`; missing veg/allergens/nutrition declarations render explicit FSSAI-required warnings; empty-allergens list renders "None of the major allergens" message; user-supplied strings HTML-escaped (XSS guard); MFG+shelfLifeDays computes expiry when batch carries no explicit expiry; filename strips reserved chars + includes batch number suffix). 905 total backend pass.

#### Manufacturing — Pharma BMR (2026-06-19)
- **V27 migration:** three companion tables on top of the existing WO + JobCard machinery — `bmr_step_record` (in-process parameter readings), `bmr_signoff` (OPERATOR/SUPERVISOR/QA/QC sign-offs at each critical step), `bmr_deviation` (exception log with severity + investigation lifecycle). DB-level CHECK constraints on role / severity / status. Unique partial index on signoffs (org, wo, jc, role, user). Targeted indexes on (org, wo) and (org, open-status).
- **`BmrService`:**
  - `recordStepParameter(woId, jcId, key, value, unit, notes)` — guards key/value non-empty, validates jc-to-wo membership (`BMR_JC_WO_MISMATCH`).
  - `recordSignoff(woId, jcId, role, notes)` — role normalised to uppercase, validates against the 4-role enum, refuses unauthenticated callers (`BMR_SIGNOFF_NO_USER`).
  - `logDeviation(woId, jcId, severity, title, description)` — severity normalised + enum-validated, deviations open in OPEN status with `reportedBy` stamp.
  - `resolveDeviation(devId, status, resolution)` — moves through OPEN→INVESTIGATING→RESOLVED/ACCEPTED, stamps `resolvedBy`/`resolvedAt` only on RESOLVED/ACCEPTED transitions.
  - `yieldReconciliation(woId)` — read-only from WO.quantityToProduce vs quantityProduced. Returns planned/produced/yield%/deviation% + status PENDING (in-progress) / WITHIN_TOLERANCE / OUT_OF_TOLERANCE at the pharma-standard ±2% threshold.
  - `bmrSnapshot(woId)` — bundles WO + jobCards + stepRecords + signoffs + deviations + yieldReconciliation + generatedAt. The payload a regulator's PDF generator consumes.
- **Endpoints:** `POST /api/v1/manufacturing/bmr/step-records|signoffs|deviations`, `PUT /deviations/{id}` (status update), `GET /work-orders/{id}/step-records|signoffs|deviations|yield-reconciliation|snapshot`, `GET /deviations/open` (cross-batch open work queue). OPERATOR can record steps/signoffs/deviations; OWNER/ADMIN updates deviation status.
- **Flutter:** `BmrScreen` (`/manufacturing/bmr`, command palette "Batch Manufacturing Record" — keywords bmr/pharma/schedule m/gmp/who/cdsco/deviation/yield/audit) — paste a WO id, tabs for Overview (yield reconciliation card with traffic-light status colour) / Parameters / Sign-offs (4-role dropdown) / Deviations (severity dropdown + investigation status). Floating action button is context-aware: it changes label and action per tab. App-bar PDF icon downloads the regulator-ready BMR PDF via `printing.sharePdf` (native share/save sheet on mobile, print preview on desktop).
- **BMR PDF generator (2026-06-19):** `BmrPdfService` renders a Schedule M / WHO-GMP / 21 CFR 211 layout from the snapshot — header (org name/address/GSTIN + WO + product + composition + batch size + dates + status), §1 yield reconciliation (traffic-light status colour), §2 in-process parameter records (op name + parameter + value + unit + observed-by/at), §3 sign-offs (op step + role + signed-by/at), §4 deviations (severity-coloured cards with description + investigation + resolution + resolved-by/at), footer (generation timestamp + system attribution). HTML→PDF via the shared `DocumentPdfService` (open-html-to-pdf). All user-supplied strings HTML-escaped. Endpoint `GET /api/v1/manufacturing/bmr/work-orders/{id}/pdf` (OWNER/ADMIN/OPERATOR/ACCOUNTANT/VIEWER) → `application/pdf` download. Display names (operation, user) resolved in bulk per snapshot so the row builders don't fan out into per-row repo calls.
- **Tests:** `BmrServiceTest` (13) — step-record save with org+observer stamps, empty-key guard, jc-to-wo mismatch guard, signoff role normalisation + invalid-role guard, deviation OPEN status + reporter stamp, empty-title guard, resolveDeviation RESOLVED stamps resolvedBy/At + invalid-status guard, yield within-tolerance at 1% under, out-of-tolerance at 10%, in-progress PENDING, snapshot bundles all sections. `BmrPdfServiceTest` (5) — minimal batch renders required sections + header fields, populated batch renders parameter operation names + user names + deviation status/resolution, empty optional sections render friendly empty messages, user-supplied strings escaped (XSS guard), filename strips reserved chars. 885 total backend pass.

#### Manufacturing — Parameterized BOMs (2026-06-19, tracker #42)
- **V26 migration:** `bom_component.variant_filter` (JSONB, nullable) + GIN partial index on the non-null rows. NULL means "applies to every variant" (default), so every existing BOM row keeps applying.
- **Match rule:** a line is included for a variant when its `variantFilter` is null/empty OR every key=value in the filter is present and equal in the variant's `Item.variantAttributes`. Equality only — no ranges, no any-of. Planners declare two lines for two combinations.
- **`BomService.resolveBomForVariant(parentItemId, attrs)`** — returns the filtered list. `matchesVariant(filter, attrs)` made public so `ManufacturingService.createWorkOrder` can call it inline.
- **`ManufacturingService.createWorkOrder` hook:** when the FG carries variantAttributes, the BOM is filtered through `BomService.matchesVariant` before lines are materialized. When the FG has NO variantAttributes, lines that DO carry a filter are dropped too (those are variant-specific and shouldn't leak into a non-variant build). Tests guard both branches.
- **`BomComponentRequest` + addComponent:** new optional `variantFilter` field on the DTO. The duplicate-child guard is relaxed when a variantFilter is set — parameterized BOMs deliberately allow multiple lines for the same child with distinct filters (e.g., same dye item with different colour filters).
- **Endpoint:** `GET /api/v1/items/{parentItemId}/bom/resolve?attr1=val1&attr2=val2` returns the filtered BOM lines for the supplied attributes. Spring binds the whole query map directly into the attribute set.
- **Flutter:** `ParameterizedBomScreen` (`/manufacturing/parameterized-bom`, command palette "Parameterized BOM" — keywords variant/size/color/configurable/garment/footwear) — paste a parent item id, add as many key=value attribute rows as needed, tap Resolve to see the filtered BOM with universal lines (green check icon) and variant-specific lines (blue tune icon).
- **Tests:** `BomServiceTest +5` (null filter applies to all, single-key filter excludes non-matching variants, multi-key AND semantics, mixed universal+variant scenario, no-attributes drops variant-specific lines); `ManufacturingServiceTest +1` (createWorkOrder for a Red-M variant FG keeps only the color=Red BOM line and drops color=Blue). 867 total backend pass.

#### Manufacturing — Production→Payroll Bridge (2026-06-19, tracker #57)
- **V25 migration:** `employee_salary_structure.pay_type` (SALARY default | HOURLY | PIECE_RATE) + `hourly_rate` + `piece_rate`, with a CHECK constraint on `pay_type`. Existing structures stay SALARY → behaviour byte-for-byte unchanged for the legacy payroll path.
- **`ProductionPayrollService.computeLaborPay(employee, structure, periodStart, periodEnd)`** — sums COMPLETED job cards via new `JobCardRepository.findCompletedByAssigneeInWindow` (filters on `actualEnd` in `[from, to)`), totals `timeLoggedMinutes / 60` and `completedQty`, multiplies by the structure's rate. Returns a `LaborPay` record with totalHours / totalPieces / jobCardCount / amount / payType. SALARY structures short-circuit to zero without ever hitting the manufacturing repo; employees with no linked `userId` also short-circuit (a desk worker on hourly pay with no shop-floor activity is implicitly zero).
- **Hooked into `PayrollService.calculatePayslip`** between the structure pass and the statutory pass — adds a `LABOR_PAY` EARNING line and bumps `grossPay` when the bridge returns a positive amount. SALARY path is wholly unchanged.
- **Endpoint:** `GET /api/v1/payroll/employees/{employeeId}/labor-pay-preview?periodStart=&periodEnd=` — HR-side preview so the calc can be eyeballed before running the actual payroll. `SalaryStructureRequest` extended with `payType` / `hourlyRate` / `pieceRate`.
- **Flutter:** `LaborPayPreviewScreen` (`/payroll/labor-pay-preview`, command palette "Labor Pay Preview" — keywords hourly/piece-rate/wage/labour) — paste an employee id, pick a date range, see the breakdown (pay type chip, ₹ amount, hours, pieces, job-card count). SALARY workers get an amber info card explaining that production data doesn't apply.
- **Tests:** `ProductionPayrollServiceTest` (5) — SALARY short-circuits without querying job cards, HOURLY sums minutes across 3 cards then × rate (240min = 4h × ₹250 = ₹1000), PIECE_RATE sums completedQty × rate (40 pieces × ₹8.50 = ₹340), no-linked-user returns zero without querying, missing rate returns zero amount but still records hours so HR can spot mis-configured rates. 861 total backend pass.

#### Manufacturing — Alternative Work Centers (2026-06-19, tracker #15)
- **V24 migration:** `workstation_alternate` (org-scoped, soft-delete) — priority-ordered fallback workstations per routing operation, FKs to `routing_operation` + `workstation`, unique partial index on `(org, op, workstation)`. Additive over the existing `routing_operation.workstation_id` (the authoritative primary) — an op with no alternate rows behaves exactly as before.
- **`RoutingService.addWorkstationAlternate / listWorkstationAlternates / deleteWorkstationAlternate`** — mirrors the BomAlternate (substitute-materials) pattern. Guards: `MFG_WS_ALT_SAME_AS_PRIMARY` (can't register the op's primary as its own fallback), `MFG_WS_ALT_DUPLICATE`.
- **`RoutingService.pickAvailableWorkstation(routingOpId, requiredHours)`** — walks primary then alternates by priority, returns the first that is active AND has `capacityHoursPerDay >= requiredHours`. A deliberately simple day-capacity gate (no scheduling calendar — that's the separate capacity-planning track); answers "which sanctioned machine can take this op's daily load right now?". Throws `MFG_NO_AVAILABLE_WORKSTATION` when none qualify.
- **Endpoints:** `POST /api/v1/manufacturing/workstation-alternates` + `DELETE /{id}`, `GET /api/v1/manufacturing/routing-operations/{id}/workstation-alternates`, `GET /api/v1/manufacturing/routing-operations/{id}/available-workstation?requiredHours=`.
- **Flutter:** `WorkstationAlternatesScreen` (`/manufacturing/workstation-alternates`, command palette "Alternate Work Centers" — keywords workstation/machine/fallback/capacity) — routing-op id input → priority-ordered alternate list → FAB "Add alternate" dialog (ws id + priority + notes) → per-row delete + app-bar "Find available" action that calls the picker.
- **Tests:** RoutingServiceTest +6 — add saves with org+priority, same-as-primary throws, duplicate throws, picker returns primary when it has capacity, picker falls back to alternate when primary is inactive, picker throws when neither primary nor alternate can absorb the load. 856 total backend pass.

#### Manufacturing — Operation Dependencies (2026-06-19, tracker #16)
- **V23 migration:** `routing_operation_dependency` (org-scoped, soft-delete) — directed edge `(routing_operation_id → predecessor_routing_operation_id)` with FKs to `routing_operation`, a DB-level CHECK rejecting self-loops, a unique partial index on `(org, succ, pred)` for dedupe, and two indexes on the succ/pred columns for fast neighbour lookups. Additive layer over the existing `sequence_number` — when an op has no dependency rows the planner keeps falling back to sequence ordering, so legacy routings stay unchanged.
- **`RoutingService.addOperationDependency / removeOperationDependency / listPredecessors / listSuccessors`** — full CRUD on the DAG. `addOperationDependency` is idempotent (re-adding an existing edge returns the existing row without saving), enforces same-routing membership (`ROUTING_DEP_CROSS_ROUTING`), and runs a BFS walk up the predecessor's existing upstream chain to refuse cycle-forming edges (`ROUTING_DEP_CYCLE`). Self-loop guard at the service entry (`ROUTING_DEP_SELF_LOOP`) — same constraint also at the DB.
- **Endpoints:** `POST /api/v1/manufacturing/routing-operation-dependencies` + `DELETE /{id}`, `GET /api/v1/manufacturing/routing-operations/{id}/predecessors`, `GET /.../successors`.
- **Flutter:** `OperationDependenciesScreen` (`/manufacturing/operation-dependencies`, command palette "Operation Dependencies" with keywords predecessor/successor/dependency/gantt/sequence/dag/critical/path) — routing-op id input → two cards (Predecessors / Successors) → FAB "Add predecessor" dialog → per-row delete. Foundation that a future Gantt UI can call into without any backend changes.
- **Tests:** RoutingServiceTest +5 — normal edge saves with correct org+ids, self-loop throws `ROUTING_DEP_SELF_LOOP` before any DB call, cross-routing edge throws `ROUTING_DEP_CROSS_ROUTING`, would-form-cycle (A→B already exists, try to add B→A) throws `ROUTING_DEP_CYCLE`, duplicate add returns the existing row without saving. 850 total backend pass.

#### Manufacturing — Split + Merge WOs (2026-06-19, tracker #64)
- **`ManufacturingService.splitWorkOrder(woId, firstQty)`** — keeps `firstQty` on the original DRAFT, creates a sibling DRAFT carrying the residual (`originalQty − firstQty`). BOM lines scale proportionally on both sides (per-unit ratio computed from the original, applied to each new headline qty). Sibling carries the original's parentWorkOrderId so a split inside a sub-assembly tree keeps its parent link. Guards: `MFG_SPLIT_NOT_DRAFT` (post-DRAFT can't split — qty is locked once materials are issued), `MFG_SPLIT_INVALID_QTY` (qty must be strictly between 0 and the original total — either extreme is a no-op).
- **`ManufacturingService.mergeWorkOrders(woIds)`** — consolidates N≥2 DRAFT WOs into a single DRAFT (`createWorkOrder` with summed qty). Sources get soft-deleted with a note pointing at the merged WO; no movements were ever recorded so no reversal is needed. Guards: `MFG_MERGE_NEEDS_TWO`, `MFG_MERGE_NOT_DRAFT`, `MFG_MERGE_DIFFERENT_FG` / `_DIFFERENT_WAREHOUSE` / `_BOM_VERSION_MISMATCH`, `MFG_MERGE_CHILD_LOCKED` (source is a sub-assembly child — merging would orphan its parent's dependency), `MFG_MERGE_HAS_CHILDREN` (source itself has children — same orphan risk in the opposite direction).
- **Endpoints:** `POST /api/v1/manufacturing/work-orders/{id}/split` (body `{firstQty}`) and `POST /api/v1/manufacturing/work-orders/merge` (body `{workOrderIds: [...]}`).
- **Flutter:** "Split work order" entry added to the DRAFT WO overflow menu — opens a qty dialog; result snackbar links to the WO list to find the sibling. Merge UI uses the WO list selection mode (existing pattern) — not yet wired in this commit; backend ready for it.
- **Tests:** ManufacturingServiceTest +5 — split scales BOM lines (3 of 10 → 9/30 on source, 21/30 on sibling), split-not-DRAFT throws, split-qty-equal-to-total throws, merge consolidates two same-FG DRAFTs (sources soft-deleted, merged qty=10), merge-with-one-source throws, merge-different-FG throws. 845 total backend pass.

#### Manufacturing — Linked Sub-assembly WOs (2026-06-19, tracker #60)
- **V22 migration:** `work_order.parent_work_order_id` (nullable) + partial index on `(org_id, parent_work_order_id)`. Top-level WOs (manual + SO→WO + reorder sweep) carry NULL — existing behaviour unchanged.
- **`ManufacturingService.createChildWorkOrdersForSubAssemblies(parentWoId)`** — walks the parent's BOM lines, and for any component whose item is itself a COMPOSITE creates a DRAFT child WO (qty = required for the parent line) linked back via `parentWorkOrderId`. Idempotent — reuses the same `existsByOrgIdAndFinishedGoodIdAndStatusIn` dedupe guard introduced for #66 (reorder sweep). Per-item createWorkOrder failure (no BOM, no default account, etc.) is logged + skipped. Throws `MFG_PARENT_NOT_DRAFT` if the parent's already moved past DRAFT/PENDING_APPROVAL — cascading sub-assemblies once production is running doesn't make sense.
- **Gate:** `issueToProduction` now refuses to start a parent that has any non-COMPLETED / non-CANCELLED child via new `WorkOrderRepository.findByOrgIdAndParentWorkOrderIdAndIsDeletedFalse`. Throws `MFG_CHILD_WO_PENDING` with the offending child's number — planner sees exactly what's blocking.
- **Endpoints:** `POST /api/v1/manufacturing/work-orders/{id}/create-sub-assembly-wos` (OWNER/ADMIN) returns the list of newly-created children; `GET /api/v1/manufacturing/work-orders/{id}/children` lists existing children for the detail screen.
- **Flutter:** "Cascade sub-assembly WOs" entry added to the DRAFT WO detail overflow menu — tap → snackbar reports created count or "No new sub-assemblies — none in BOM or all already drafted".
- **Tests:** ManufacturingServiceTest +4 — composite RM spawns a child linked to the parent (qty carries through), non-composite RM returns empty without even hitting the dedupe check, parent-not-DRAFT throws `MFG_PARENT_NOT_DRAFT`, parent issue blocked by an IN_PROGRESS child throws `MFG_CHILD_WO_PENDING` + no inventory movement. 839 total backend pass.

#### Manufacturing — FEFO in Production + Operation Work Instructions (2026-06-19, tracker #45+#13)
- **#45 FEFO in production material consumption:** new `ManufacturingService.issueRawMaterialToProduction(wo, itemId, qty, unitCost)` replaces the inline `recordMovement` calls in both `issueMaterials` (full upfront issue) and `backflushMaterials` (proportional issue on FG receipt). For non-batch items the helper collapses to a single `recordMovement` byte-for-byte identical to the legacy path. For batch-tracked RM it walks `BatchService.findFefoBatches` (expiry ascending, NULL last), greedy-consumes each batch up to its on-hand, and emits one movement per slice — each slice carries the resolved `batchId` so the `batch_trace` recall walk (#47, shipped earlier today) actually links to the consumed RM batch. Throws `MFG_INSUFFICIENT_BATCH_STOCK` when total available doesn't cover the required qty so the planner sees the shortage at issue time instead of QC. Tests: ManufacturingServiceTest +3 (batch-tracked splits across 2 batches in FEFO order, non-batched RM keeps null batch + skips FEFO lookup, short stock throws + doesn't silently partial-issue).
- **#13 Work instructions / attachments per operation:** `RoutingService.attachOperationFile / listOperationAttachments / deleteOperationAttachment` delegate to the shared `AttachmentService` with `entityType="OPERATION"`. Org ownership enforced by routing the call through `getOperation()` first so the file never hits storage for a foreign-org id. No migration needed — the generic `entity_attachment` table from the AttachmentService rollout handles everything. Endpoints: `POST /api/v1/manufacturing/operations/{id}/attachments` (multipart), `GET /api/v1/manufacturing/operations/{id}/attachments`, `DELETE /api/v1/manufacturing/operations/attachments/{attachmentId}`. Flutter: `OperationAttachmentsScreen` (`/manufacturing/operation-attachments`, command palette "Operation Work Instructions") — operation id input + attachment list + FAB upload (via `file_picker` multipart) + per-row delete. Tests: RoutingServiceTest +3 (upload delegates with the right entityType / unknown operation throws before AttachmentService is ever called / list also routes through the org-scoped lookup). 835 total backend pass.

#### Manufacturing — Auto-WO from Reorder Points (2026-06-19, tracker #66)
- **`ManufacturingService.autoCreateWorkOrdersFromReorder()`** — walks every `stock_balance` row whose `quantity_on_hand` is at or below the item's `reorderLevel` (via existing `StockBalanceRepository.findLowStock`), keeps only COMPOSITE items (the rest belong on a purchase requisition, not a WO), aggregates the deficit across warehouses per item, and drafts one WO per FG with `quantityToProduce = reorderLevel − onHand`. Default warehouse picks the WO's home; planner reviews BOMs / dates before issuing.
- **Idempotent on a cron:** new `WorkOrderRepository.existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse` skips items that already have an open DRAFT / PENDING_APPROVAL / IN_PROGRESS WO so the sweep can run every hour without piling up duplicate tickets. Per-item `createWorkOrder` failure (composite missing a BOM, missing default account, etc.) is logged + skipped — one bad item doesn't kill the sweep.
- **Endpoint:** `POST /api/v1/manufacturing/work-orders/from-reorder` (OWNER/ADMIN). Returns the list of newly-created WOs; the message says "Created N work order(s)".
- **Flutter:** "Replenish from low-stock composites" icon button (replay icon) added to the Work Orders list page header. Snackbar reports either the created count or "No low-stock composite items — nothing to draft". Idempotent on the server, so users can tap repeatedly without consequence.
- **Tests:** ManufacturingServiceTest +4 — happy path (deficit 100−30=70 produces a 70-qty DRAFT WO), skips items with an open WO (no save), skips non-composite RM low-stock rows (purchase-requisition flow's job, not WOs; never hits the dedupe check), no-low-stock returns empty without even touching the warehouse repo. 829 total backend pass.

#### Manufacturing — BOM Version Diff (2026-06-19, tracker #41)
- **`ManufacturingService.diffBomVersions(parentItemId, fromVersion, toVersion)`** — joins the two version snapshots from `bom_component` (already partitioned by `version`), matches by `child_item_id`, splits the result into ADDED / REMOVED / CHANGED. CHANGED picks up any row whose quantity OR scrap percent moved between versions; response carries fromQty/toQty/qtyDelta plus the two scrap %s so the UI can render "5 → 7 (+2)" style deltas. Child item names resolved once per id (single map shared by all three sections — no n×3 lookups). Guards: `BOM_DIFF_SAME_VERSION` (callers asking to diff a version against itself) + `BOM_DIFF_VERSIONS_EMPTY` (neither version has any rows).
- **Endpoint:** `GET /api/v1/manufacturing/bom/{parentItemId}/diff?fromVersion=&toVersion=`.
- **Flutter:** `BomVersionDiffScreen` (`/manufacturing/bom-diff`, command palette "BOM Version Diff") — parent id + from/to version inputs → metrics card (added/removed/changed/unchanged counts) + three sectioned lists (green +, red −, orange ↑↓ with delta). Empty diff renders "No differences between the two versions".
- **Tests:** ManufacturingServiceTest +4 — full A/R/C scenario (qty change picked up + names resolved); identical versions → unchangedCount only; same-version-number throws `BOM_DIFF_SAME_VERSION`; both-empty throws `BOM_DIFF_VERSIONS_EMPTY`. 825 total backend pass.

#### Manufacturing — WO Profitability + Scrap Rate Dashboard (2026-06-19, tracker #53+#54)
- **#53 WO profitability:** `ManufacturingService.workOrderProfitability(from, to)` joins each completed WO's `ProductionCostSummary.actualTotal` with the linked SO line's `rate × quantityProduced` to compute revenue / cost / profit / margin %. Sorted worst-margin-first so loss-making WOs surface to the top. WOs with no SO link return `revenue=0` + `revenueSource="NONE"` (likely make-to-stock — revenue recognised separately through the invoice register). Endpoint `GET /api/v1/manufacturing/reports/work-order-profitability?fromDate=&toDate=`.
- **#54 scrap rate dashboard:** `scrapRateDashboard(from, to)` aggregates `production_scrap` rows in the window by both reason code (sorted by cost desc) and FG item (sorted by scrap rate desc). Rate uses `scrapQty / (producedQty + scrapQty)` so it stays 0–100% even when every produced unit was scrapped. Resolves reason codes + item names for display. Endpoint `GET /api/v1/manufacturing/reports/scrap-rate?fromDate=&toDate=`.
- **Flutter `ProductionAnalyticsScreen`** (`/manufacturing/analytics`, command palette "Production Analytics") — single tabbed surface with Throughput (uses the existing production-trends endpoint) / Profitability (loss rows highlighted red w/ ↓ icon) / Scrap rate (items ≥5% rate highlighted orange).
- **Tests:** ManufacturingServiceTest +4 (profitability w/ SO link computes revenue+cost+profit+margin@28%, profitability w/o SO link → revenue=0 source=NONE, scrap dashboard aggregates by item+reason w/ rate@10%, empty window → zero rollups). 821 total backend pass.

#### Manufacturing — Batch Recall (2026-06-19, tracker #47)
- **Trace auto-recording:** `BatchTraceService.linkTracesForFgReceipt(woId, fgBatchId, fgItemId)` walks every `PRODUCTION_ISSUE` movement on the WO that has a `batchId`, then calls `recordTrace` once per unique RM batch. Idempotent — partial FG receipts on the same WO can call it repeatedly; dedupe sits inside `recordTrace` via new `BatchTraceRepository.existsByOrgIdAndBatchIdAndSourceBatchIdAndWorkOrderIdAndTraceTypeAndIsDeletedFalse`. Wired into `ManufacturingService.receiveFinishedGoods` right after the FG movement so every batch-assigned receipt populates the trace table (was previously empty in production because no one called `recordTrace`).
- **Fixed forward-trace shape:** original `recordTrace` set `sourceBatchId = sourceBatchId` (i.e. RM→RM) on the FORWARD row, losing the FG link entirely. New shape: FORWARD row has `batchId=rmBatch`, `sourceBatchId=fgBatch` — so "where did this RM go?" reads `sourceBatchId` for the FG output.
- **Recall report:** `recallReport(rmBatchId)` returns RM batch info + every affected FG batch (via BACKWARD trace) + every downstream SALE movement of those FG batches, resolved to customer + invoice. Sorted newest shipment first so recall calls go to today's customers before yesterday's. New `StockMovementRepository.findSaleMovementsByBatch` (excludes reversals so a voided invoice doesn't generate a phantom shipment).
- **Endpoint:** `GET /api/v1/inventory/batch-trace/recall/{rmBatchId}` (OWNER/ADMIN/OPERATOR/ACCOUNTANT).
- **Flutter:** `BatchRecallScreen` (`/inventory/batch-recall`, command palette "Batch Recall") — paste suspect RM batch id → top card shows RM batch number + expiry + counts → list of "Shipments to recall (newest first)" with customer name + invoice number + qty + date.
- **Tests:** BatchTraceServiceTest (7 — linkTraces writes one row per unique RM batch incl. dedupe of multi-line same-batch issues + null-batch ignored, dedupe across partial receipts, null FG batch noop, recall walks RM→FG→customer shipments end-to-end, empty trace returns zero counts, recordTrace dedupes on (fg, rm, wo) triple, recordTrace writes BACKWARD + FORWARD rows with FG link on the FORWARD row). 817 total pass.

#### Manufacturing — Batch Assignment on FG Receipt + Production Trends (2026-06-19)
- **Batch assignment on FG receipt (tracker #43 + #65, pharma + food compliance):** `ManufacturingService.receiveFinishedGoods(woId, qty)` now has an overload `(woId, qty, batchNumber, expiryDate)`. `resolveFgBatch()` upserts on the natural key `(org, item, batch_number)` via `StockBatchRepository.findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse` so repeated receipts into the same batch accumulate, then stamps `batchId` on the `PRODUCTION_RECEIVE` movement. Guards: `MFG_BATCH_REQUIRED` (item tracks batches but no number supplied), `MFG_ITEM_NOT_BATCH_TRACKED` (caller insisted on a batch number for a non-batch item — so the ledger isn't silently lossy). Legacy non-batch path skips the item lookup entirely → byte-for-byte unchanged. Endpoint `POST /api/v1/manufacturing/work-orders/{id}/receive` accepts optional `batchNumber` + `expiryDate`. Flutter WO detail "Receive Finished Goods" dialog now captures batch + expiry. Tests: ManufacturingServiceTest +3 (upsert + DB row stamps orgId + expiry + movement carries batchId; batch-tracked item without batch number → guard; non-batch item with batch number → guard).
- **Production trends (tracker #52):** `ManufacturingService.productionTrends(from, to)` returns one daily bucket per day in the inclusive window with `woStarted` / `woCompleted` / `quantityProduced` / `scrapQty` / `scrapCost`. Zero-activity days emit a bucket too so the chart shows a continuous series. WOs attributed to their `actualStartDate` / `actualEndDate` (not createdAt) so the chart matches what actually happened on the floor. Endpoint `GET /api/v1/manufacturing/reports/production-trends?fromDate=&toDate=`. Tests: ManufacturingServiceTest +2 (empty range emits a bucket per day; completed WO attributes producedQty to actualEndDate, not started day).
- Test sweep: 810 total pass.

#### Manufacturing — Shop-floor Mobile (2026-06-17)
- **Backend:** `WorkOrderRepository.findByOrgIdAndWorkOrderNumberIgnoreCaseAndIsDeletedFalse`
  + `ManufacturingService.getWorkOrderByNumber(number)` + `GET /api/v1/manufacturing/
  work-orders/by-number/{number}` so scanning a printed WO sticker resolves to the
  same WO + job cards the existing detail endpoints return. Reuses the existing
  start/complete job-card + scrap endpoints — no new lifecycle. Tests:
  ManufacturingServiceTest +2 (returnsWoForScanInput w/ case-insensitive lookup,
  unknown-number throws). 33/33 + 104/104 mfg sweep green.
- **Flutter `ShopFloorScreen`** (`/manufacturing/shop-floor`, sidebar "Shop floor"
  under Manufacturing, capabilities gated via `canUseManufacturing`) — mobile-first
  operator UI:
  - Autofocused "Scan or enter WO number" field that works with USB keyboard-wedge
    scanners (filters out tab/CR/LF input that some scanners prepend) — Enter
    triggers lookup, clears + refocuses on success so the operator can scan the
    next WO without lifting fingers off the gun.
  - Fallback "Active work orders" list (calls existing list endpoint with
    `status=IN_PROGRESS`) for picking by tap when scanning isn't an option.
  - Loaded WO renders the header card + job-card list w/ status pill (PENDING /
    IN_PROGRESS / COMPLETED / CANCELLED) + big finger-sized action buttons:
    Start (PENDING → IN_PROGRESS), Complete (modal bottom sheet captures
    quantity produced + actual hours + notes), Log scrap (modal sheet w/
    reason-code dropdown + qty + notes; posts to the work-order scrap endpoint
    with `jobCardId` attached so the scrap row is attributed to the right
    operation). All actions refresh the WO + job-cards inline.
  - "Done — scan next WO" link returns to the active-WO list and refocuses
    the scan field.
- **V20 migration:** `maintenance_schedule` (workstation_id + code uniq +
  frequency_days CHECK > 0 + next_due_date NOT NULL + active flag + due-date
  partial index for the daily sweep) + `maintenance_work_order` (mwo_number
  uniq per org, schedule_id nullable for ad-hoc breakdowns, maintenance_type
  PREVENTIVE/BREAKDOWN/INSPECTION CHECK, status DRAFT/IN_PROGRESS/COMPLETED/
  CANCELLED CHECK, priority URGENT/HIGH/NORMAL/LOW CHECK, downtime_minutes +
  cost + completion notes + 4 indexes).
- **`MaintenanceService`:** schedule CRUD (default nextDueDate = today+freq
  when null; `MAINTENANCE_DUPLICATE_CODE`/`MAINTENANCE_BAD_FREQUENCY`
  guards); `listDueSchedules(cutoff)` for the homepage badge;
  `generateWorkOrdersForDueSchedules(asOf)` creates a DRAFT WO per due
  schedule but skips any schedule with an existing DRAFT/IN_PROGRESS WO
  (idempotent sweep). WO lifecycle: `createWorkOrder` (BREAKDOWN/etc,
  validates type + priority, auto-numbers `MWO-YYYY-NNNNN`), `startWorkOrder`
  (DRAFT→IN_PROGRESS, stamps `startedAt`, `MAINTENANCE_NOT_DRAFT` guard),
  `completeWorkOrder(notes, cost)` (IN_PROGRESS→COMPLETED, computes
  `downtimeMinutes = completedAt − startedAt`, rolls linked schedule's
  `lastCompletedDate`/`nextDueDate` forward by frequencyDays,
  `MAINTENANCE_NOT_IN_PROGRESS` guard), `cancelWorkOrder(reason)` (blocks
  COMPLETED/CANCELLED via `MAINTENANCE_FINAL_STATE`). All wall-clock via
  injected `Clock` for testable date math.
- **Downtime report:** `downtimeReport(from, to)` aggregates COMPLETED WOs in
  the window per workstation — count, totalMinutes, totalCost, type
  breakdown — sorted by totalMinutes desc (worst offenders first).
- **`MaintenanceController`** @ `/api/v1/manufacturing/maintenance`
  (`@RequiresModule(MANUFACTURING)`, OWNER/ADMIN/OPERATOR): schedules CRUD +
  `/schedules/due` + `/schedules/generate-due`; work-orders CRUD + start +
  complete + cancel + status/workstation filter; `/reports/downtime`.
- **Flutter:** `MaintenanceScreen` (`/manufacturing/maintenance`, sidebar
  "Maintenance" under Manufacturing group, capabilities gated via
  `canUseManufacturing`) — 3 tabs:
  - **Schedules**: list w/ workstation/due/active info, "Generate due"
    button creates DRAFTs in one tap, add/edit dialog w/ workstation picker.
  - **Work Orders**: list w/ status chip (DRAFT/IN_PROGRESS/COMPLETED/
    CANCELLED), action menu (Start / Complete / Cancel) gated by status,
    "Report issue" creates ad-hoc BREAKDOWN/INSPECTION WO, complete dialog
    captures notes + cost.
  - **Downtime**: date range picker + KPI strip (total minutes / WOs /
    workstations) + per-workstation cards w/ type breakdown.
- **Tests:** MaintenanceServiceTest (13) — schedule defaults next-due,
  bad-frequency throws, duplicate-code conflict, generate-due creates DRAFT
  per due schedule + skips when one already open, WO create assigns number
  + DRAFT, bad type throws, start sets IN_PROGRESS + startedAt, start-not-
  DRAFT throws, complete computes downtime + rolls schedule forward,
  complete-not-IN_PROGRESS throws, cancel-COMPLETED throws, downtime report
  aggregates + sorts desc. Manufacturing sweep 102/102.

#### Proof of Delivery (2026-06-18)
- **V21 migration:** `proof_of_delivery` (org-scoped, soft-delete) — linkable to
  delivery_challan and/or invoice (CHECK enforces at least one), recipient name/
  phone/relation, delivered_at, GPS lat/lng (numeric 10,7), notes, recorded_by.
  Four partial indexes (org+DC, org+invoice, org+contact, org+date).
- **`ProofOfDeliveryService`** (sales package): record (`POD_LINK_REQUIRED` 400
  if neither DC nor invoice; `POD_RECIPIENT_REQUIRED` 400 if no name; defaults
  deliveredAt = now if absent; stamps orgId + recordedBy from TenantContext),
  get / listByChallan / listByInvoice / listByContact / recent (top 50),
  soft delete. Signature + photo attachments delegated to the shared
  `AttachmentService` with `entityType = "POD"` — same per-org storage layout
  as employee documents, single backup target.
- **`ProofOfDeliveryController`** @ `/api/v1/proof-of-delivery` — record/list/
  attach/list-attachments allow OPERATOR (delivery boys can capture from
  the field), delete is OWNER/ADMIN/ACCOUNTANT only. Attachments accept
  multipart `file`.
- **Flutter `ProofOfDeliveryScreen`** (`/proof-of-delivery`, sidebar "Proof
  of Delivery" between Delivery Challans and Receipts) — list of recent
  PODs (recipient/link/delivered-at + Attach/View/Delete actions),
  "Record POD" FAB opens a dialog (DC/invoice id paste-in, recipient
  name/phone/relation, deliveredAt picker, GPS lat+lng, notes). File
  picker → multipart `file` → POST to the attachments endpoint. View
  attachments via bottom sheet.
- **Tests:** ProofOfDeliveryServiceTest (8) — link-required + recipient-
  required guards, orgId+recordedBy stamping, deliveredAt default vs.
  caller-supplied, attach routes through AttachmentService with the "POD"
  entityType, listAttachments routes likewise, attach against unknown
  POD throws + never reaches AttachmentService, soft-delete sets isDeleted.
  26/26 POD + DC + SalesCycle sweep green.

#### GSTR-2B auto-fetch via GSP (2026-06-17)
- **`GspClient.fetch2b(orgId, returnPeriod)`** — GET against the aggregator
  with bearer token + `gstin` header. Path key `gst.gsp_gstr2b_path` (default
  `/gstr2b/fetch`); query `?gstin=&period=YYYY-MM`. Refactored `post()`/GET
  through a single `exchange()` so both flows share auth + error mapping.
- **`Gstr2bReconService.fetchFromGsp(period)`** — gates on `gspClient.isConfigured`
  (else `GSP_NOT_CONFIGURED`), pulls the JSON, and re-uses `upload()` so all
  the existing parse / re-upload-dedupe / reconcile / suggestion-replace logic
  is unchanged. Empty response → `GST_2B_EMPTY`.
- **Endpoint:** `POST /api/v1/gst/gstr2b/fetch?period=` (OWNER/ADMIN/ACCOUNTANT).
- **Flutter:** GSTR-2B tab now renders "Auto-fetch from GSP" + "Upload 2B JSON"
  side-by-side; auto-fetch shows a friendly hint when GSP isn't configured.
- **Tests:** Gstr2bReconServiceTest +3 — GSP not configured throws, configured
  fetches+reconciles via shared pipeline, empty response throws. GST sweep 26/26.

#### Payment-gateway links on invoices — Razorpay (2026-07-02) — MASTER_GAP_TRACKER H1
- **V27 migration:** `payment_link` (org-scoped, BaseEntity — one row per created link; the ONLY mapping the JWT-less webhook has to resolve invoice+org) + `payment_webhook_event` (append-only dedupe log). Idempotency indexes: unique partial `(provider, provider_link_id)`, unique partial `(provider, provider_payment_id)` (a captured payment can never settle twice), unique `(provider, event_id)`.
- **`payment/service/RazorpayClient`** — config-inert (mirrors GspClient/CourierClient): per-org creds in `org_settings` (`payments.razorpay.enabled|key_id|key_secret|webhook_secret|base_url|webhook_token`), `isConfigured` gate, masked `settings()` (secrets → `keySecretSet`/`webhookSecretSet` booleans, never echoed), reuses the shared `gspRestTemplate` bean. `createPaymentLink` POSTs `/v1/payment_links` with HTTP Basic (key_id:key_secret). `verifyWebhookSignature` = HMAC-SHA256 over the **raw body** keyed by the org's webhook secret, `MessageDigest.isEqual` constant-time compare. `ensureWebhookToken` mints `rzpwh_<uuid>` per org.
- **`payment/service/PaymentLinkService`:** `createForInvoice` (invoice must be SENT/PARTIALLY_PAID/OVERDUE with balance > 0; amount = balanceDue × 100 paise; referenceId = invoiceNumber). `handleWebhook(orgId, rawBody, sig, eventId)` — layered idempotency: (1) reject bad HMAC → "invalid signature"; (2) dedupe by event id; (3) captured-payment-id already recorded → no-op; (4) link already PAID → no-op; then records via `PaymentService.recordForInvoice` with method **BANK_TRANSFER** (routes to the BANK GL, not CASH), **clamps to current balanceDue** (never over-collect), force-posts if an approval workflow diverted it to PENDING_APPROVAL (money's already collected), stamps link PAID. Never throws out — the controller always 200s.
- **Public webhook:** `POST /api/v1/webhooks/razorpay/{orgToken}` — resolves org from the per-org path token (`OrgSettingsRepository.findFirstByKeyAndValue`, reusing the courier pattern), takes `@RequestBody String rawBody` (NOT a DTO — the HMAC must see the exact bytes), sets TenantContext org + SYSTEM role in try/finally, always returns 200. Path whitelisted in `SecurityConfig` next to the courier line.
- **Authenticated endpoints:** `POST /api/v1/invoices/{id}/payment-link` (create) + `GET /{id}/payment-links` (OWNER/ADMIN/ACCOUNTANT), `GET/PUT /api/v1/settings/razorpay` (masked, OWNER/ADMIN).
- **Tests:** RazorpayClientTest (5 — isConfigured gate, masked settings, HMAC accept/tamper/wrong/missing, no-secret, token mint-once), PaymentLinkServiceTest (8 — create builds paise + referenceId, non-payable rejected, webhook records + flips to PAID, bad signature no-record, duplicate event, captured-payment replay no-op, amount clamp to balance, force-post PENDING_APPROVAL). **Flutter "Get payment link" button (mirror the wa.me share button) = follow-up (no SDK in cloud env).**

#### India gratuity provision (2026-07-02) — MASTER_GAP_TRACKER G6
- **V25 migration:** seeds two India-only gratuity GLs — `2080` Gratuity Provision (LIABILITY) + `5130` Gratuity Expense — for IN × {TRADING, RETAIL, SERVICES, F_AND_B}. India CANNOT reuse the Gulf pair (2050 = "PF Payable" in the IN chart; 5060 unseeded for IN), so distinct codes, kept OUT of DefaultAccountPurpose (direct-code lookup, same carve-out as Gulf 5060/2050). Existing IN orgs self-seed on next boot via the AccountService/DefaultAccountService repair sweep. Also creates `india_gratuity_accrual` (org + period_year + period_month unique-where-not-deleted) for idempotency + audit.
- **`payroll/india/IndiaGratuityService`** (Payment of Gratuity Act 1972, Clock-injected): `compute(from, to, basic+DA)` — eligible after 5 continuous years (§4), amount = (basic+DA) × 15/26 × §4(2)-rounded completed years (final year ≥6 months rounds up), ₹20L ceiling applied at payout only; `monthlyAccrual(join, asOf, wage)` — annual gratuity ÷ 12 slice, accrued from joining (AS-15/Ind-AS-19) so the cumulative 2080 balance matches the computed gratuity at exit and the payout draws it cleanly to zero (a "defer until vested" toggle was **removed in the review pass** — it under-provisioned pre-cliff and drove 2080 to a debit balance at payout); `resolveMonthlyBasicPlusDa` sums BASIC + DA lines (Gulf uses BASIC only — India §2(s) wage includes DA), gross fallback; `previewAccrual/postAccrual(year, month)` posts ONE consolidated journal DR 5130 / CR 2080 per period (not a payslip line — gratuity is a provision, not a PF-style statutory), idempotent via the accrual table + `GRATUITY_ALREADY_ACCRUED`; gated on `payroll.india_gratuity_enabled` (default off). The accrual sweep selects employees **employed during the period** (joined ≤ periodEnd AND not exited before periodStart) — not just currently-ACTIVE — so an arrears run still accrues a worker who has since exited. `ensureIndiaGratuityAccount` self-heals 2080/5130 (mirror of ensureGulfAccount).
- **Exit payout:** `OffboardingService.payGratuity` now dispatches AE/OM → Gulf (2050) vs IN → India (2080) vs else → `OFFB_GRATUITY_NOT_APPLICABLE`. India uses `IndiaGratuityService.computeFor` (cappedAmount = 0 until eligible, so a sub-5-year exit flags nil with no phantom journal).
- **`IndiaPayrollController`** @ `/api/v1/payroll/gratuity/india` (`@RequiresCountry("IN")`, @RequiresModule(PAYROLL), OWNER/ADMIN/ACCOUNTANT): `GET /{employeeId}` preview, `GET /accrual/preview?year=&month=`, `POST /accrual?year=&month=`. Sibling to `GulfPayrollController`.
- **Tests:** IndiaGratuityServiceTest (9 — under-5 not eligible, exact-5 = 75k, §4(2) rounds 7y7m→8 but not 7y5m→8, ₹20L cap, monthly slice = annual/12, vesting-defer vs accrue-from-joining, bad-input ZERO, range/wage guards), IndiaGratuityAccrualTest (4 — DR 5130/CR 2080 shape, disabled gate, idempotency, preview no-post), OffboardingServiceTest +1 (India payout against 2080, unsupported-country still throws). 13 new. **Live-verified: V25 seeds 8 rows on fresh DB, boots clean.**

#### Vendor-TDS Form 26Q file export (2026-07-02) — MASTER_GAP_TRACKER G4
- **`tax/service/Form26QExporter`** — vendor-TDS mirror of the salary `Form24QExporter`, on top of `TdsService.form26q`. `csv(fy, quarter)` = register (Sr/Vendor/PAN/Section/Amount Paid/TDS/Bills/Effective Rate% + TOTAL). `fvuDeducteeDetail(fy, quarter)` = `^`-delimited NSDL DD block: `line ^ DD ^ deducteeCode ^ PAN ^ name ^ sectionCode ^ paid ^ tds ^ rate`. Unlike 24Q (hardcodes "192"), 26Q carries the REAL per-row section mapped to the FVU analysis code (194C→94C, 194J→94J, ...), a deductee code (01 company / 02 non-company inferred from PAN 4th char = 'C'), and the `PANNOTAVBL` sentinel for blank PANs so the FVU doesn't reject the row.
- **Endpoints** `GET /api/v1/tds/26q/csv` + `/26q/fvu` (OWNER/ADMIN/ACCOUNTANT, `@RequiresCountry("IN")`) — mirror the existing `/24q/csv` + `/24q/fvu` pair; text/csv + text/plain attachments.
- **Deferred (same as 24Q):** the full FH/BH/CD/DD FVU file needs the deductor TAN + per-quarter ITNS-281 challan capture (no `tds_challan` table yet). The CSV + DD block is the RPU-loadable CA deliverable; challan capture is a follow-up for both 24Q and 26Q.
- **Tests:** Form26QExporterTest (7 — CSV header/rows/total, FVU per-row section code + 01/02 deductee code, blank-PAN sentinel, comma escaping, section/deductee-code helpers incl. 193→193 + TDS→empty, empty-quarter header+total only).

#### Phase-G review pass (2026-07-02) — adversarial workflow, 6 defects fixed
An adversarial 3-reviewer + per-finding verifier Workflow over the G4/G5/G6 diffs confirmed 6 real correctness defects, all fixed before push:
- **G6 vesting under-provisioning (medium):** the opt-in `accrue_from_joining=false` "vesting-basis" mode accrued ZERO until the 5-year cliff then only a flat monthly slice — never the vested lump — so a later payout drove the 2080 provision to a debit (negative-liability) balance. **Fix:** removed the toggle; accrual is always from-joining (AS-15), which nets 2080 to zero at payout.
- **G6 arrears accrual omitted exited workers (low):** `buildAccrual` swept only currently-ACTIVE employees, so an accrual posted in arrears for a past month dropped anyone who had since exited. **Fix:** select employees employed *during the period* (joined ≤ periodEnd AND not exited before periodStart) over all non-deleted employees.
- **G5 cross-tenant master mutation (high):** `addRateHistory` wrote the shared `hsn_gst_master.gst_rate` (drives every tenant's tax defaults) with no PLATFORM_ADMIN guard, bypassing the exact protection `upsertHsn` enforces. **Fix:** the open-ended (current-rate-changing) path is now PLATFORM_ADMIN-only; OWNER/ADMIN may still backfill CLOSED historical periods.
- **G5 future-dated period synced master early (medium):** an open-ended period effective in the future overwrote the live master rate immediately. **Fix:** injected Clock; master sync only when `effective_from ≤ today` (rateAsOf still returns the correct period-for-a-date meanwhile).
- **G4 `fvuSectionCode` mis-mapped non-194 sections (medium):** the `19x` fallback stripped the leading digit (193→93). **Fix:** only 194x collapses to 94x; every other section keeps its real number.
- **G4 placeholder section leaked into the FVU (medium):** the `TDS`/blank "no section specified" placeholder was emitted as a bogus section code. **Fix:** `TDS`/blank → empty field so the RPU flags a missing mandatory section instead of accepting garbage.
Regression tests added for each: HsnGstRateHistoryServiceTest +2 (platform-admin gate, future-date no-sync), IndiaGratuityAccrualTest +2 (exited-during-period included, exited-before excluded), Form26QExporterTest +section-helper cases.

#### Edit Log / MCA audit trail (2026-07-02) — MASTER_GAP_TRACKER G1
- **V23 `edit_log`:** append-only, no org_settings toggle, no soft delete — id, org_id, entity_type, entity_id, action CHECK (CREATE/UPDATE/DELETE/RESTORE), entity_label (doc number / display name snapshot), field_changes JSONB `{field: {from, to}}`, changed_by, changed_at + 3 indexes (org+entity+time, org+time, org+user).
- **`audit/listener/EditLogHibernateListener`** — the codebase's FIRST Hibernate event listener (PostInsert/PostUpdate/PostDelete), registered by `EditLogListenerRegistrar` @PostConstruct via `SessionFactoryImplementor.getServiceRegistry().requireService(EventListenerRegistry.class)`. **Same-transaction guarantee:** events are collected per session during flush and written in a `BeforeTransactionCompletionProcess` via `session.doWork` raw-JDBC batch (`?::jsonb`) on the business transaction's own connection — rollback discards log rows with the data, commit carries them; an `AfterTransactionCompletionProcess` cleans the per-session map on both outcomes. Capture failures log-and-swallow (never break the business write).
- **`EditLogPolicy` allowlist (18 entities):** Invoice, Payment, CreditNote, CustomerReceipt, PurchaseBill, VendorPayment, VendorCredit, Expense, JournalEntry, Account, SalesOrder, DeliveryChallan, PurchaseOrder, StockReceipt, SalesReceipt (POS), Estimate, Contact, Item — keyed by FQCN. High-churn operational tables (stock_movement is already an append-only ledger, pings, tokens) deliberately excluded.
- **`EditLogDiffBuilder`** — state-array based (several books entities do NOT extend BaseEntity, so no reflection on the entity): dirty-index diff with `from`/`to` rendering (BigDecimal `stripTrailingZeros().toPlainString()` so scale-only changes are not changes; enums by name; collections/associations skipped; strings truncated at 500), ignored bookkeeping props (createdAt/updatedAt/createdBy/version) — an update touching only those writes no row. **Soft-delete flip is surfaced as its real action**: isDeleted false→true = DELETE, true→false = RESTORE.
- **Read API** `/api/v1/audit/edit-log` (Specification filters: entityType/entityId/action/userId/from/to, paginated ≤200) + `/summary` (totalChanges, byAction, byEntityType, top-10 editors w/ names via AppUserRepository) — OWNER/ADMIN/ACCOUNTANT.
- **Flutter:** `EditLogScreen` @ `/accounting/audit-trail` (sidebar Accounting → "Audit Trail" id `accounting.audit_trail`, palette "Audit Trail (Edit Log)") — entity/action/date-range filters, summary strip, expandable rows w/ mono `field: from → to` diff, load-more paging.
- **Relationship to the old `audit/AuditService` (audit_log table):** that one is manual (explicit `.log()` call sites), @Async (fire-and-forget, can lose rows), no field diff. The edit_log listener is automatic + transactional + diffed. Both coexist; new code should NOT add manual AuditService call sites for entities the listener already covers.
- **Live-verified** on fresh DB: org signup captures 63 ACCOUNT CREATE + 54 parentId UPDATE rows (changed_by null — pre-auth system writes), contact create/rename yields CREATE + UPDATE w/ exact `displayName` diff and resolved user name through both endpoints.
- **Tests:** EditLogDiffBuilderTest (6), EditLogHibernateListenerTest (8 — allowlist gate, same-connection batch write via captured BeforeTransactionCompletionProcess + mocked Work/Connection, diff JSON, soft-delete→DELETE, bookkeeping-only skip, capture-failure swallow, no-org skip, multi-event single batch), EditLogServiceTest (3). 17 new.

#### POS khata / credit sales → AR (2026-07-02) — MASTER_GAP_TRACKER G3
- **V24 migration:** widens `sales_receipt_payment_mode_check` to include `CREDIT` (the V1 baseline CHECK only allowed CASH/UPI/CARD/MIXED — caught live, not by unit tests, since the posting engine is mocked there).
- **`PaymentMode.CREDIT`:** `AccountingPostingEngine.resolvePaidThroughAccount` routes the DR leg to `DefaultAccountPurpose.AR` (1100) — journal becomes DR AR / CR Revenue / CR tax (+ the usual COGS legs). Revenue/tax/COGS paths untouched by the mode.
- **`SalesReceiptService.create` guards** (run inside the same txn, rollback-safe): org setting `pos.allow_credit_sales` (default **false** — khata is opt-in) → `POS_CREDIT_DISABLED`; contact mandatory → `POS_CREDIT_REQUIRES_CONTACT`; contact must be CUSTOMER/BOTH → `POS_CREDIT_CONTACT_NOT_CUSTOMER`. After stock deduction the receipt total is mirrored onto `contact.outstanding_ar` (same clamp-at-zero helper as CustomerReceiptService) so credit ledger / collections / field-sales views pick it up immediately. `voidReceipt` on a CREDIT receipt takes the receivable back off the ledger.
- **Khata settlement:** `CustomerReceiptService.recordKhataSettlement(contactId, amount, method, date, notes)` — collects against invoice-less outstanding: DR Cash/Bank, CR AR via one synthetic `ArAllocationFx(amount, 1)`; receipt saved with `allocatedAmount = amount` and zero allocation rows so the existing `voidReceipt` reverses it correctly. Guards: `AR_KHATA_AMOUNT_INVALID`, `AR_KHATA_EXCEEDS_OUTSTANDING` (keeps the 1100 GL from going credit-negative through this path). Endpoint `POST /api/v1/customer-receipts/khata-settlement` (OPERATOR allowed — counter operation).
- **Flutter POS:** `posAllowCreditSalesProvider` (GET `pos.allow_credit_sales`, default false) → conditional "Khata" button in `PosTotalBar` (warning-amber, selected when mode CREDIT); `_onPaymentTap('CREDIT')` blocks without a selected customer; payment sheet `_buildKhataContent` shows "Goes on <customer>'s khata" + explanation, completes with `amountReceived: 0`; POS Receipt Settings → Billing gains the "Khata (credit) sales" toggle next to bill-freely (OWNER/ADMIN). **flutter analyze locally — no SDK in this env.**
- **Live-verified** on fresh DB: credit sale → DR 1100/CR 4010 + outstanding 100; settlement 40 → DR 1010/CR 1100 + outstanding 60; over-settlement 999 → `AR_KHATA_EXCEEDS_OUTSTANDING`; the V23 edit log captured the whole flow (POS_RECEIPT CREATE/UPDATE, CUSTOMER_RECEIPT CREATE, CONTACT outstanding UPDATEs).
- **Tests:** PosReceiptKhataPostingTest (2 — CREDIT debits 1100 not 1010, CASH unchanged), PosKhataSaleTest (6 — books receivable + outstanding bump, setting-off block, no-contact block, non-customer block, cash never touches outstanding, void restores), KhataSettlementTest (3 — journal shape + outstanding decrease + notes, over-settlement, non-customer/non-positive). ERP-side settlement UI beyond the endpoint = credit-ledger screen follow-up (tracker E).

#### MSME Form 1 annexure (2026-07-02) — MASTER_GAP_TRACKER G2
- **`reporting/service/MsmeForm1Service`** (Clock-injected): supplier-wise dues to MSME-registered vendors (contact master already carries `pan` / `msme_registered` / `msme_registration_no` — no migration). Per-bill statutory deadline = `min(dueDate, billDate + 45d)` (MSMED §15: agreed period binds when shorter, Act caps longer at 45; bill date stands in for acceptance date). Outstanding rows bucket at the deadline vs `asOf` (worst-first); paid rows classify each `vendor_payment_allocation` by payment date vs deadline, filtered to the MCA half-year (Apr–Sep / Oct–Mar, derived from asOf when from/to absent). Supplier summary (4 buckets per vendor) + grand totals. DRAFT/VOID bills excluded; zero-MSME-vendor orgs short-circuit with a note before touching the bill repo.
- **Endpoints** `/api/v1/reports/msme-form1` + `/export` (CSV w/ Section column OUTSTANDING_OVER_45/…/PAID_WITHIN_45, RFC-4180 escaping) — OWNER/ADMIN/ACCOUNTANT, `@RequiresCountry("IN")`.
- **Repo additions:** `ContactRepository.findByOrgIdAndMsmeRegisteredTrueAndIsDeletedFalse`, `PurchaseBillRepository.findByOrgIdAndContactIdInAndIsDeletedFalse`, `VendorPaymentAllocationRepository.findByPurchaseBillIdIn`.
- **Tests:** MsmeForm1ServiceTest (6 — 45-day bucket split w/ totals + PAN column, deadline min/cap/no-terms table, payment classification + half-year period filter, DRAFT/VOID exclusion + no-vendor short-circuit, CSV sections + comma escaping, MCA half-year bucket table). **No dedicated Flutter screen — the CSV export is the CA deliverable; hub entry TODO if asked.**

#### Production-hardening round (2026-07-02) — full-code-review fixes
Five-audit review (multi-tenancy / multi-country-currency / UI coverage / CoA-per-country / scalability) followed by a fix sweep. Commits in order: security wave → V21 numbering → V22 country pack → replica safety → currency labeling → drug-import UI.
1. **AI SQL tenant enforcement (security):** `SqlValidator` rewritten around JSqlParser 5.1 — parses the model's SELECT, walks every subquery/CTE/UNION branch, rejects unknown/non-public/denylisted tables (`app_user`, `api_key`, ...), and **AND-injects `org_id = :caller`** into each select (`organisation` pinned to `id = :caller`). The old substring check was bypassable with a UNION. `NlpQueryService` executes only `sqlValidator.secure(...)` output. Tests: SqlValidatorTest (23) incl. UNION/subquery exfiltration + `OR 1=1`.
2. **Multipart limits:** `spring.servlet.multipart` 50MB/60MB — Boot's 1MB default rejected drug CSVs / Tally XMLs / POD photos.
3. **IDOR fixes:** `CaReportDispatchService.status` (dispatcher-scoped), `CacheAdminController.warmOrg` (own-org only), `RoutingService.addOperationDependency` (org checks), `PartnerNetworkService.getPartner` (party check).
4. **Document numbering (V21):** `InvoiceNumberSequenceRepository.findByOrgIdAndPrefixAndYear` is now `PESSIMISTIC_WRITE` (all 8 sequence-table generators serialize per org/prefix/year); unique partial indexes added for the three MAX+1 documents that had none — `network_order` (per buyer org), `job_work_order`, `non_conformance_report`.
5. **Country CoA/tax pack (V22):** template matrix completed — AE/OM × RETAIL/SERVICES/F_AND_B + KE × all four industries (IN clone minus 9 statutory accts + VAT 1511/2041; Gulf also gratuity 2050/5060). `AccountService.seedFromTemplate` falls back org-country → `CountryProfile.coaTemplateCountry()` → IN. `TaxSeedService`: shared Gulf seeder (AE "UAE VAT" / OM "Oman VAT", flat 5%), Kenya 16% + zero-rated; UK VAT output 2042→**2045** and US sales tax 2050→**2046** (template code collisions); `ensureAccount` uses org base currency. `PayrollService` gratuity self-heals missing 5060/2050 instead of `PAYROLL_GULF_ACCOUNT_MISSING`. `OmanProfile` owns OM keys; `organisation.tax_regime` stamped from profile at signup. Tests: TaxSeedServiceTest (5).
6. **Replica safety:** ShedLock (JDBC provider, `shedlock` table in V21, DB-time) + `@SchedulerLock` on all 16 `@Scheduled` methods — two replicas no longer double-send SMS/push or double-bill AI. `AttachmentStorage` abstraction: `local` disk (default, path-traversal-guarded) or `s3` (AWS SDK v2, MinIO endpoint override) via `app.attachment.storage`; **switch to s3 before running a second replica**. New `GET /api/v1/attachments/{id}/download` — uploads previously had no read-back endpoint at all.
7. **Document currency:** Invoice/Payment/CreditNote/CustomerReceipt/PurchaseBill/VendorPayment/VendorCredit/Journal/StockReceipt/Estimate now stamp `org.baseCurrency` instead of hardcoded "INR" (rate lookup base→base = 1, forex plumbing untouched). A UAE org's invoice finally says AED. Residual: RFQ quotes + rate contracts still default INR (no books impact); true foreign-currency document ENTRY is a separate feature.
8. **Drug-import UI:** `DrugImportScreen` (`/inventory/drug-import`, sidebar "Medicine Import" OWNER/ADMIN, palette "Medicine Catalogue Import") — CSV picker + dry-run toggle + result metrics/errors against `POST /api/v1/drug-master/import`. **flutter analyze locally before building** (no SDK in cloud env).
**Review findings intentionally staged (not fixed this round):** POS credit/khata (C2), trade-ops UI cluster (E5), MR-app cluster incl. FCM registration (E6), Arabic/RTL adoption (~3,030 hardcoded strings), OMR 3-decimal `setScale(2)`/`numeric(15,2)` sweep (blocks Oman go-live, not UAE), foreign-currency document entry, report-finder pagination + item/contact trigram indexes, partitioning/archival for `stock_movement`/`journal_line`/`field_location_ping`.

### G. Marg first-timer master-data parity (2026-06-13)
Goal: match Marg's "ready in minutes" preloaded masters. Audit found UoM already
covered (UomService bootstrap seeds common + industry units incl. pharma Strip/
Bottle/Vial/Tube, kirana Pack/Bora/Katta etc.); drug/salt/manufacturer masters
already strong (23,400 drug / 556 salt / 164 manufacturer after V20 — see C.6).
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
2. ~~Employee management~~ **DONE (module 2, V18+V19, 2026-06-17):** payroll
   Employee master extended with Zoho People profile depth — V18 adds personal
   info (DOB/gender/marital/blood group/nationality/personal email), current +
   permanent addresses, emergency contact, employment type (FULL_TIME/PART_TIME/
   CONTRACT/INTERN/CONSULTANT) + work location + probation/confirmation/notice
   period + profile photo (AttachmentService). V19 adds three subresource tables
   (`hr_employee_family`/`_education`/`_experience`). New package `com.katasticho.
   erp.hr.{entity,repository,service,controller}` for these subresources;
   `HrEmployeeService` owns CRUD + self-service `me()`/`myProfile()`/`updateMe()`
   (the last writes ONLY self-editable fields — designation/department/salary/
   statutory IDs/employment status stay locked even if request body sets them).
   `HrEmployeeController` @ `/api/v1/hr/employees` for OWNER/ADMIN/ACCOUNTANT;
   `MyProfileController` @ `/api/v1/hr/employees/me` for any authenticated user
   (separate class because Spring stacks @PreAuthorize and never widens
   class-level guards). Ownership guards on /me subresource writes — caller can
   only touch their own records (`HR_NOT_OWNER` 403). `HR_EMPLOYEE_NOT_LINKED`
   (404) when the app-user has no payroll Employee linked.
   Tests: HrEmployeeServiceTest (12 — family/education/experience CRUD incl.
   service-nulls-caller-supplied-id + employeeId stamp, unknown-employee throw,
   me + me-not-linked + updateMe field allowlisting locks manager fields +
   myProfile bundles employee/family/education/experience) + PayrollServiceTest
   +2 for the depth round-trip. HR + payroll sweep 52/52.
   Flutter: `MyProfileScreen` (`/hr/my-profile`, sidebar HR > My Profile) —
   header + personal/address/emergency cards w/ edit dialogs + family/
   education/experience lists w/ add/edit/remove. 404 HR_EMPLOYEE_NOT_LINKED
   guidance message. Admin `employee_form_screen.dart` deepened with 4 new
   collapsible sections (Work Info, Personal Info, Address, Emergency Contact)
   between Basic Info and Bank Details so HR can set the new fields on behalf
   of employees. Flutter analyze still requires local SDK (cloud env unchanged).
   **All 9 Core HR modules are now full verticals.**
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
   **All 9 Core HR modules now full verticals — module 2 closed out 2026-06-17 (see entry above).**
**Flutter HR portal UI: Leave + Attendance + Shifts + Timesheets + Help Desk + Documents + Analytics + Offboarding + My Profile (self-service) + deepened admin employee form DONE** (all under sidebar "HR" group). Note: this cloud env has no Flutter SDK on PATH despite earlier note — analyze must be run locally before building.

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
| `docs/AI_NATIVE_COMPETITIVE_ROADMAP.md` | **Live build backlog (2026-06-21):** competitive teardown (DualEntry/Campfire/Digits vs Tally/Marg/Busy/Zoho) → checkbox task lanes A–F (finish P0 payroll → IMS Accept/Reject/Pending → AI Tally migration → WhatsApp order-to-ledger → anomaly/continuous-close → embedded lending). What's already built vs the 3 sharp gaps. | Picking the next feature to build; weekly planning |
| `docs/TALLY_PARITY_AND_MIGRATION_PLAN.md` | **Tally battle plan:** full TallyPrime feature matrix vs us (parity backlog §1), workflow strengths/pains, 5 wedges to beat them, Tally XML migration slices 1–3 | Tally parity work, migration importer, competitive positioning |
| `docs/COMPETITOR_FEATURE_MATRIX_TALLY_ZOHO_ODOO.md` | **Low-level competitor feature inventory (2026-07-02):** granular per-feature matrix of TallyPrime 6.1 / Zoho Books+Inventory 2025 / Odoo 18-19, each row cross-marked ✅/🟡/❌/⬜ vs katasticho, + ranked "steal list" per product (Edit-Log audit trail, custom fields+workflow rules+webhooks, portals, warehouse routes, payment-term instalments, fixed-asset depreciation, ...). Doubles as the competitive gap backlog. | Competitive planning, choosing platform-debt features, "what does X have that we don't" |
| `docs/PARTNER_NETWORK_MODULE_PLAN.md` | B2B ordering: data model, flows, 10 implementation phases | Phase 8 partner network |
| `docs/WORKFLOW_CONTEXT_HINTS_PLAN.md` | Context hints: resolver, widget, hint text per vertical | Adding workflow hints |
| `docs/plans/week-2-ap-module.md` | AP module spec (already implemented) | Debugging AP flows |
| `docs/MANUFACTURING_FEATURE_TRACKER.md` | 101 missing features, prioritized tiers, daily progress log | Manufacturing work |
| `docs/INTERNATIONALIZATION_PLAN.md` | **Multi-country plan (IN→UAE→Oman→Kenya):** code-grounded audit of every i18n/RTL/VAT/payroll/e-invoice gap + 6-week Phase-0 refactor checklist. Tax engine + module-gating already abstracted; Arabic/RTL + Gulf payroll + PINT-AE are the real builds. **Read before any multi-country / Arabic / VAT work.** | Internationalization, Gulf/Africa expansion |
| `docs/UI_FIELD_GAP_AUDIT.md` | **Low-level UI/field gap audit (2026-06-24)** of BOTH repos — every domain's backend entities/DTOs/endpoints vs actual Flutter screens vs ERP norms. ~316 findings (~90 P1): missing screens, form fields the backend supports but the UI drops, orphaned screens, broken-now wiring. 10 systemic patterns + "broken right now" list + corrections to stale CLAUDE.md "DONE" claims. | Picking UI/wiring work; verifying what's actually shipped vs backend-only |
| `docs/UI_FIELD_GAP_EXECUTION_PLAN.md` | **Living work tracker** derived from the audit — Sprints A–E in sequence (A=broken-now fixes, B=reusable EntityPicker/name-resolution/sidebar, C=India-core flows, D=statutory, E=backend-complete-UI-absent) with per-item checkboxes + file paths. **Tick items as they ship.** | Executing the gap-closure work in order |
| `docs/MASTER_GAP_TRACKER.md` | **THE consolidated gap tracker (2026-07-02):** every open item from the five-audit review + competitor matrix in priority phases — G compliance (Edit Log, MSME Form 1, 26Q FVU, GST rate history, IN gratuity), H daily money (POS khata, gateway links, instalments, cheque/bulk-pay), I extensibility (custom fields, workflow rules, report builder, portals, fixed assets), J WMS, K multi-country finish, E→ UI backlog pointer, L scale. Tick items as they ship. | Picking the next feature; weekly planning |
