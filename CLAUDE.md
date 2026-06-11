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
- **Platform-level reference tables** (NO org_id, NO BaseEntity): `salt_master`, `drug_master`, `manufacturer_master`, `hsn_gst_master`, `generic_substitution`, `drug_interaction`. `rack_location` IS org-scoped.

## Flyway Migrations
- Location: `src/main/resources/db/migration/`. Latest is **V58** (WhatsApp message log). Next new migration = V59.
- Use `TIMESTAMPTZ` (not `TIMESTAMP`) for timestamp columns.
- Master tables seeded in V28 (drugs/salts), V29 (pharmacy refs), V34/V36 (drug master seeds).

## Flutter / API Conventions
- **Dio baseUrl = `http://localhost:8080` with NO `/api/v1` prefix** → every API path string must include `/api/v1/...`.
- Endpoint paths live in `flutter_app/lib/core/api/api_config.dart`.
- `apiClientProvider` cascades invalidation across providers.
- Features under `flutter_app/lib/features/<feature>/presentation/...`.

## Accounting Rules (important domain logic)
- **POS receipts** → Cash/Revenue journal, NOT Accounts Receivable.
- **Contact "outstanding"** = openingBalance + invoices − payments (AR only).
- **HSN → GST mapping:** 3004 = 12% (standard medicines), 2106 = 18% (supplements), 3002 = 5% (vaccines).
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
- **Residual concern:** contact.outstandingAr may not be restored on void — verify in integration test.

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
- **Tests (done):** 53 manufacturing tests (ManufacturingServiceTest 15, RoutingServiceTest 9, JobWorkServiceTest 16, QualityControlServiceTest 8, ScrapServiceTest 5). 417 total tests pass.
- **Tier 2 priorities (TODO):** BOM versioning, batch traceability in production, WIP journal entries, production reports (cost variance, consumption, WIP valuation), work order enhancements (priority, approval, disassembly), backflush mode.
- **Tier 3 (DEFERRED):** MRP engine, Gantt scheduling, capacity planning, shop floor mobile, maintenance management, industry-specific (pharma BMR, food FSSAI, garment cut plans).

### Kirana Retail Production Gaps (2026-06-10)
**Goal:** Make the POS + core flows production-ready for Indian small grocery/pharmacy shops.

- **~~P8: Profit margin on POS~~ (DONE):** PosSearchController strips `purchasePrice` for OPERATOR/ACCOUNTANT roles. OWNER/ADMIN see margin breakdown in payment sheet + margin dot per item.
- **~~P4: UPI QR code at POS~~ (DONE):** OrgSettings stores `pos.upi_id`/`pos.upi_display_name`. Payment sheet renders scannable QR via `qr_flutter`. POS Receipt Settings has UPI config section.
- **~~P6: Cash register / day close~~ (DONE):** V48 migration. CashRegisterService: open day, petty cash expenses, close with variance. 7 endpoints. Flutter: Today + History tabs in CashRegisterScreen, accessible from POS overflow menu.
- **~~P7: SMS notifications~~ (DONE):** SmsService (Fast2SMS/MSG91, async fire-and-forget, Indian mobile sanitization). Hooked in SalesReceiptService (receipt SMS) and LowStockAlertJob (per-item alert to org owner). GET/PUT `/api/v1/settings/sms`. Flutter: `_SmsSettingsSection` in POS Receipt Settings screen.
- **~~P1: Thermal/Bluetooth printer~~ (DONE):** ThermalPrintService (ESC/POS via flutter_blue_plus, 58mm/80mm paper, respects ReceiptSettings). PrinterSetupScreen with scan/connect/test/auto-print. POS _handlePrint uses thermal when connected, PDF fallback.
- **~~P2: Offline POS~~ (DONE):** OfflinePosService with SQLite queue (sqflite). Network errors in _completeSale auto-queue receipt locally. Connectivity listener auto-syncs on reconnect. Sync badge in POS app bar shows pending count + manual Sync Now. Max 5 retries per receipt.

**Parked (not needed now):**
- P3: Hindi i18n — Flutter l10n, ARB files, Hindi translations for POS + core screens.
- P5: Push notifications Firebase — FCM setup, server-side token storage, notification triggers.
- P9: Tally export — XML export in Tally format for CA handoff.

### Keyboard-Parity UX Program (IN PROGRESS — 2026-06-11)
**Goal:** Never-touch-the-mouse voucher entry and app-wide keyboard navigation.

- **KShortcuts registry (done):** Central shortcut catalogue expanded — global (Ctrl+K palette, Ctrl+N context-new, ? help, / search), list (J/K navigate, N create, R refresh, Enter open, X select), form (Ctrl+Enter submit, Ctrl+←→ step nav, Esc cancel), POS (F1-F7, Ctrl+F, Ctrl+Enter).
- **KShortcutHelpOverlay (done):** `?` key opens context-aware shortcut reference overlay (global, list, form, POS sections shown as appropriate). Esc/? to dismiss.
- **Command palette expansion (done):** `buildAppCommands()` expanded from ~40 to ~100 commands covering all modules: Sales Orders, Purchase Orders, Delivery Challans, Debit Notes, Chart of Accounts, Journal Entries, Credit Ledger, Bank Recon, Approval Inbox, Stock Counts, Transfer Orders, Picklists, Payroll, Field Sales (beats/routes/vans/executions/dashboard), Partner Network (partners/catalog/supplier search), Manufacturing (work orders/job work/routings/QC), and all create + settings routes.
- **KKeyboardListWrapper (done):** Reusable Focus wrapper for list screens — J/K or ↑/↓ row navigation, N to create, R to refresh, / to focus search, Enter to open selected, X to toggle selection. Text-field-aware (disables single-key shortcuts when typing).
- **KKeyboardFormWrapper (done):** Reusable Focus wrapper for stepped create forms — Ctrl+Enter to submit, Ctrl+←→ for step navigation, Esc to cancel.
- **List screens wired (done):** Invoices, Bills, Sales Orders, Items, Contacts, Stock Receipts, Purchase Orders, Delivery Challans, Journal Entries, Credit Notes, Vendor Credits, Estimates, Expenses, Recurring Invoices, Work Orders, Employees — all wrapped with KKeyboardListWrapper for keyboard navigation.
- **Form screens wired (done):** Invoice Create, Bill Create, Sales Order Create, Delivery Challan Create, Stock Receipt Create, Estimate Create, Expense Create, Credit Note Create, Vendor Credit Create — all wrapped with KKeyboardFormWrapper for Ctrl+Enter submit and step navigation.
- **ShellScreen global shortcuts (done):** Ctrl+N (context-aware new — detects current route and navigates to create; falls back to command palette), ? (shortcut help overlay). Text-field-aware to avoid conflicts.
- **POS shortcut help (done):** `?` key in POS opens POS-specific shortcut reference.
- **FAB tooltip hints (done):** 30+ list screens show `(N)` keyboard hint on the create FAB tooltip across all modules.

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
- `gst/service/Gstr2bReconServiceTest.java` — portal JSON parse, match/mismatch/missing + suggestions, supplier-not-filed, key normalization (3 tests)
- `gst/service/EwayBillServiceTest.java` — threshold detect/skip/dupe, vehicle aggregate, validity 1d/200km, NIC portal JSON intra-state split (8 tests)
- `gst/service/GstServiceTest.java` — POS receipts in GSTR-1 B2CS/HSN + GSTR-3B outward (2 tests)
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
- `reporting/service/DetailedReportService` — no test file (needs one)

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
- `gst/service/GstService.java` — GSTR-1 (B2B/B2CS/CDNR/CDNUR/HSN) + GSTR-3B builders @ `/api/v1/gst/gstr1|gstr3b` (+`/export`). **POS receipts included** in B2CS/HSN/3B outward (per-line tax via HSN master; intra/inter from receipt header IGST).
- `gst/service/Gstr2bReconService.java` — **GSTR-2B reconciliation**: upload portal JSON → match posted bills by GSTIN+normalized invoice number (₹1 tolerance) → MATCHED/VALUE_MISMATCH/NOT_IN_BOOKS + supplier-not-filed (ITC at risk). Mismatches create AI Inbox suggestions. V50 `gstr2b_entry`. `/api/v1/gst/gstr2b[/upload|/summary]`.
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
