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
- Location: `src/main/resources/db/migration/`. Latest is **V37**. Next new migration = V38.
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

### Phase 1: Distributor Core Hardening
**Goal:** Rock-solid SO→DC→Invoice and PO→GRN→Receive flows.
**Reference:** `docs/PRODUCT_DEVELOPMENT_ROADMAP.md` (Phase Roadmap items 1-7)
- Distributor dashboard v2 (backend endpoints where existing widgets fall short)
- Distributor operational reports: Pending Dispatch, Challan Not Invoiced (partially done)
- Credit control: WARN/BLOCK/APPROVAL_REQUIRED per policy
- Scheme application: MANUAL/AUTO/DISABLED modes (backend done, need E2E Flutter QA)
- Pricing: price-list resolution on SO and Invoice, rate preservation on SO→Invoice conversion
- Payment approval workflow E2E
- Credit Note approval E2E

### Phase 2: Inventory Feature Parity
**Goal:** Match Zoho Inventory feature surface using existing architecture.
**Reference:** `docs/architecture/inventory-feature-gap.md`
- **Sprint 26:** Batch-aware selling — FEFO consumption on invoice, expiry alert job, damaged-stock UI
- **Sprint 27:** Physical count (bulk stock count form + commit), serial number tracking, barcode scan
- **Sprint 28:** Composite items / BOM (auto-deduction on sale), item variants/groups
- **Sprint 29:** Price list enhancements, UoM + conversion, optional FIFO costing per batch
- **Sprint 30:** Multi-warehouse live, transfer orders, picklist generation

### Phase 3: Pharma Domain Pack
**Goal:** Complete pharma-specific features on top of distributor core.
**Reference:** Backend already exists in `PharmacyMasterService`. Flutter UI is missing.
- Flutter: HSN→GST auto-fill in item/invoice forms
- Flutter: Manufacturer autocomplete in item creation
- Flutter: Rack location management screen (backend: POST /rack-locations, seed-demo)
- Flutter: Generic substitution suggestions at POS checkout
- Flutter: Drug interaction warning at prescription/POS
- Seed real drug interaction data (current seeds are empty — see BUG-4)
- Seed real generic substitution data (see BUG-5)
- Expiry settlement returns workflow
- Near-expiry alert dashboard widget

### Phase 4: Reports Completion
**Goal:** Finish remaining reports + Flutter UI for all reports.
**Reference:** `docs/REPORTS_IMPLEMENTATION_STATUS.md`, `docs/REPORTS_P0_SPECIFICATION.md`
- 10/14 P0 reports implemented (backend). Remaining:
  - Day Book (chronological transaction log)
  - Vendor Statement (vendor ledger)
- Flutter report screens for all 14 reports
- CSV/Excel export
- Database performance indexes (see REPORTS doc)
- AR Aging invoice-level drill-down

### Phase 5: Payroll Module
**Goal:** Indian SMB payroll with PF/ESI/PT/TDS.
**Reference:** `docs/PAYROLL_IMPLEMENTATION_SPEC.md`
- Gated by `PAYROLL` module flag and `salary_handling_mode` (NONE/SIMPLE_EXPENSE/FORMAL_PAYROLL)
- 12 new tables (payroll_settings, employee, salary_component, payroll_run, payslip, etc.)
- Backend: package `com.katasticho.erp.payroll`
- Journal posting via existing `JournalService`, NOT direct ledger writes
- Flutter: 11 screens (dashboard, settings wizard, employees, salary structure, payroll runs, payslips, payments, statutory, reports)

### Phase 6: AI Foundation
**Goal:** Cross-cutting AI decision layer (observe → suggest → review → learn).
**Reference:** `docs/AI_APPROACH_AND_ROADMAP.md`
- Phase 1: `ai_suggestions`, `domain_events`, `ai_patterns`, `ai_training_examples` tables + backend
- Phase 2: Rule-based agents (anomaly, GST compliance, inventory intelligence) — no external AI calls
- Phase 3: Flutter AI Inbox (accept/reject/modify suggestions)
- Phase 4: Pattern learning from reviewed suggestions
- Phase 5: AI assistant endpoint (`POST /api/v1/ai/assistant`)
- Phase 6: Selective business table AI summary fields
- Phase 7: External AI / MCP integrations
- **Safety:** AI must never directly post journals, change stock, or file GST. All through existing services.

### Phase 7: FMCG Field Execution Pack
**Goal:** Route/beat/van workflows for FMCG distributors.
**Reference:** `docs/DISTRIBUTOR_FIRST_DIRECTION_ASSESSMENT.md` (Gap #3)
- Beat/route planning
- Van stock, loading, unloading
- Day-close wizard
- Salesman incentive workflows
- Route collections
- Secondary-sales dashboards
- Likely new modules, but on top of existing sales/inventory/accounting core

### Phase 8: Partner Network (B2B Ordering)
**Goal:** Connected B2B trade network within the same product.
**Reference:** `docs/PARTNER_NETWORK_MODULE_PLAN.md`
- Package: `com.katasticho.erp.partnernetwork`, Flutter: `features/partner_network`
- Trading partner request/approval, published catalog, supplier search from Shortage
- Linked buyer PO ↔ seller incoming B2B order → SO → DC → Invoice
- Must call existing services (PurchaseOrderService, SalesOrderService, etc.) — no direct stock/accounting writes
- 10 implementation phases detailed in the plan doc

### Phase 9: Manufacturing-Lite
**Goal:** Limited finished-goods / BOM extension. NOT full MRP.
**Reference:** `docs/DISTRIBUTOR_FIRST_DIRECTION_ASSESSMENT.md` (Phase 4)
- Work orders, issue to production, finished goods completion
- WIP tracking, production costing
- Only after distributor workflows are fully stable

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
- `reporting/service/DetailedReportService` — no test file (needs one)

## Existing Service Files (key ones)
- `ar/service/PaymentService.java` — payment recording, posting, voiding
- `ar/service/InvoiceService.java` — invoice CRUD, posting, SO→Invoice conversion
- `ar/service/CreditNoteService.java` — credit note with approval workflow
- `sales/service/SalesOrderService.java` — SO CRUD, credit/overdue checks, scheme application
- `sales/service/DeliveryChallanService.java` — DC CRUD, dispatch (stock deduction)
- `procurement/service/PurchaseOrderService.java` — PO CRUD, GRN creation
- `procurement/service/StockReceiptService.java` — GRN receive stock (batch, expiry, rack, cost)
- `inventory/service/InventoryService.java` — single stock movement gate
- `inventory/service/PharmacyMasterService.java` — HSN, manufacturer, rack, substitution, interaction
- `inventory/service/DrugMasterService.java` — drug/salt search
- `common/workflow/ApprovalWorkflowService.java` — workflow engine (approve/reject)
- `pricing/service/PriceListService.java` — price list resolution
- `pricing/service/SchemeService.java` — scheme lookup and application
- `reporting/service/DetailedReportService.java` — cash flow, journal register, sales/purchase register, customer statement
- `reporting/service/InventoryReportService.java` — stock summary, movements, low-stock alert

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
| `docs/PARTNER_NETWORK_MODULE_PLAN.md` | B2B ordering: data model, flows, 10 implementation phases | Phase 8 partner network |
| `docs/WORKFLOW_CONTEXT_HINTS_PLAN.md` | Context hints: resolver, widget, hint text per vertical | Adding workflow hints |
| `docs/plans/week-2-ap-module.md` | AP module spec (already implemented) | Debugging AP flows |
