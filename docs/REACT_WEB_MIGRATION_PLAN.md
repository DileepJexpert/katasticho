# Katasticho React Web Migration Plan

**Status:** Active implementation through Wave 5 - partner network, supply planning, external portal, HR/payroll review and field-sales corrections added on 2026-09-05; full parity and live acceptance remain open. See the dated reconciliation and executive tracker below.
**Purpose:** The single planning and tracking document for replacing the Flutter
web/admin client with a production-quality React web ERP while keeping the
Spring Boot backend, database, accounting rules, and business workflows safe.

## 1. Decision Summary

Build **one React web ERP for desktop and tablet**, including the Admin ERP and
the browser POS workspace. A user with the right role can move from POS to
sales, inventory, accounting, and reports within the same application and
session. Do not attempt a big-bang replacement of every Flutter capability on
day one.

The target is a React application served alongside the existing Spring Boot API.
It will preserve the existing REST paths, `ApiResponse` envelope, organisation
header, roles, capability-based menus, and multi-tenant backend enforcement.
The first live React modules will run in parallel with Flutter. A Flutter module
is retired only after the matching React workflow passes its business acceptance
tests.

### Migration contract freeze - 2026-09-03

React migration consumes the Spring API exactly as it exists. It must not change
Java source, Spring security, request or response DTOs, Flyway migrations,
backend configuration, or `flutter_app/` code. Any missing or defective API is
a separately scoped backend task, not a React migration workaround. Existing
Flutter remains the comparison client and rollback path until each React
workflow passes its acceptance evidence.

### Recommended product boundary

| Surface | Migration decision | Reason |
|---|---|---|
| Admin ERP and browser POS | Move to React | One role-aware app gives owners a continuous path from counter sales to stock, accounting, and reports. Dense tables, keyboard-first entry, rich filters, and browser delivery are the primary need. |
| Spring Boot API and PostgreSQL | Keep | The domain rules, journals, inventory ledger, GST, tenant controls, and workflow services are the product's safety boundary. |
| Flutter web | Keep during parallel run, then retire module-by-module | It is the current reference implementation and a safe rollback path. |
| Flutter POS and native field hardware | Transitional fallback until independently certified | A browser/PWA is not automatically equivalent to native SQLite, Bluetooth, camera, background location, or offline sync behaviour. The final product goal remains React POS; Flutter remains only while those capabilities are being proven. |
| Customer/vendor portal | Move after the internal ERP core | It is a separate user journey and should not delay financial workflow parity. |

**Explicit non-goal:** this is not a backend rewrite, schema migration, visual
reskin of incomplete Flutter screens, or a permanent split between an Admin
application and a POS application. React must expose the complete approved
business workflow, including the backend capabilities that the Flutter UI has
not yet surfaced.

## 2. Research Baseline

The plan is based on the current repository, not only historical feature claims.

| Observed area | Current finding | Planning implication |
|---|---|---|
| Flutter client | 579 Dart files across more than 60 feature folders | A full web migration is a programme of work, not a one-week screen conversion. |
| Navigation | `app_router.dart` defines a large, role/capability-aware route surface; `shell_screen.dart` owns the menu model and stable nav IDs | React must have one typed route and navigation registry, rather than scattered route strings. |
| API layer | Flutter centralises REST paths in `api_config.dart`, uses Dio, JWT refresh, and `X-Org-Id` | React needs one generated and typed client that retains the same request semantics. |
| Shared UI | Flutter has a design system (`KButton`, `KTextField`, `KDataTable`, `KMoney`, etc.) | React starts by recreating these primitives and tokens, not individual screens. |
| Backend surface | A current source scan finds 197 Spring `@RestController` classes | The backend OpenAPI document, not Flutter calls alone, must define React feature coverage. |
| Existing quality assets | Twelve executable module QA packs plus the distributor QA checklist exist under `docs/testing/` | These become the React release acceptance suite. |
| Known UI gap audit | `docs/UI_FIELD_GAP_AUDIT.md` documents backend-complete but UI-absent paths and incomplete forms | Do not copy missing fields, UUID inputs, orphaned routes, or unreachable actions into React. |

### Source-of-truth order

When sources disagree, use this order:

1. Backend behaviour, DTO validation, permission rules, and accounting/inventory
   invariants.
2. The BRD and approved product documents.
3. The executable manual QA packs and critical end-to-end scenarios.
4. The current Flutter UI as a behavioural and wording reference.
5. Historical "complete" trackers only after verification against code and tests.

## 3. Target Architecture

### 3.1 Application shape

```text
Browser
  |
  +-- React web app (static assets, same origin)
  |      |- route and capability registry
  |      |- design-system primitives
  |      |- typed API client and query cache
  |      |- feature modules
  |
  +-- /api/v1/* reverse proxy --> Spring Boot
                                  |- JWT + role enforcement
                                  |- X-Org-Id tenant context
                                  |- accounting / inventory / tax rules
                                  `- PostgreSQL / Redis
```

Use a static single-page React application, not an SSR application. ERP pages
are authenticated, data-heavy workspaces; public search-engine indexing and
server-rendered marketing content are not requirements for this client. A Vite
build gives fast local feedback and optimised static output while Spring Boot
remains the API authority. [Vite documentation](https://vite.dev/guide/)

### 3.2 Proposed stack

Pin exact versions only when the implementation branch is created. Use current
stable releases that pass the project security and build checks.

| Concern | Choice | Why |
|---|---|---|
| Language and UI | React with TypeScript in strict mode | Components are an appropriate unit for ERP screens and strict types catch API/form mistakes early. [React](https://react.dev/learn) |
| Build and local dev | Vite | Fast HMR, static production output, and no needless SSR layer. [Vite](https://vite.dev/guide/) |
| Navigation | React Router data mode | Nested layouts, protected routes, URL search parameters, route-level loading/error states, and lazy feature chunks. [React Router](https://reactrouter.com/home) |
| Server state | TanStack Query | One cache, request lifecycle, invalidation after mutations, pagination, optimistic UI only where safe, and retry policy by operation. [TanStack Query](https://tanstack.com/query/latest/docs/framework/react/overview) |
| Client-only state | Small Zustand stores plus URL state | Session/org context, shell state, and temporary drafts only; server records do not live in a global mutable store. |
| API contract | Springdoc OpenAPI snapshot -> `openapi-typescript` generated types -> thin fetch client | Stops contract drift and replaces map/dynamic payloads with compile-time checking. [openapi-typescript](https://openapi-ts.dev/introduction) |
| Forms | React Hook Form plus Zod schemas | Fast forms, field-level validation, server-error mapping, and reusable document-line editors. |
| Styling and primitives | Tailwind CSS plus a locally owned shadcn/Radix component layer | Fast token adoption, accessible dialogs/selects/menus, and full control of the Katasticho visual language. [Tailwind](https://tailwindcss.com/docs/installation/using-vite), [Radix](https://www.radix-ui.com/primitives/docs/overview/introduction) |
| Tables | TanStack Table with server pagination, column visibility, pinned action columns, and row virtualisation where required | Tables are the heart of the ERP; this avoids per-screen table implementations. |
| Charts | One chart library chosen in foundation phase | Dashboards and reports must share number formats, empty states, and accessibility behaviour. |
| Unit/component tests | Vitest plus React Testing Library | Vite-native tests for formatters, permission gates, forms, and reusable components. [Vitest](https://vitest.dev/guide/) |
| Browser acceptance | Playwright | Cross-browser, visual, keyboard, and end-to-end testing with traces. [Playwright](https://playwright.dev/docs/intro) |
| Observability | Existing API errors plus browser error/performance telemetry | Correlate a user-visible issue to API path, route, org, and release without exposing tokens or private data. |

### 3.3 Repository layout

Create the web app in `react_app/` so the Spring Boot root, Flutter client, and
React client can coexist during migration.

```text
react_app/
  src/
    app/                 # providers, router, bootstrapping, global guards
    api/
      generated/         # generated from committed OpenAPI snapshot; never hand-edit
      client/            # envelope unwrap, auth refresh, X-Org-Id, error normalisation
    design-system/       # tokens and owned primitives only
    features/
      contacts/
      inventory/
      procurement/
      sales/
      ...
    shared/              # formatters, entity pickers, permissions, document helpers
  tests/                 # Playwright end-to-end and visual tests
  public/
  package.json
```

Every feature follows the same boundary:

```text
route -> page -> feature hooks -> typed API client -> Spring API
```

Pages do not call `fetch` directly, do not define colour values, and do not
duplicate entity picker, money, status, document-header, or table behaviour.

## 4. Mandatory UX and Design Rules

The React client implements `docs/design-system.md` as CSS variables and
owned primitives before feature screens are built.

### 4.1 First primitives

- `AppShell`, capability-aware sidebar, top bar, command palette, and mobile
  navigation drawer.
- `PageHeader`, `SectionCard`, `DetailPanel`, `EmptyState`, `LoadingState`, and
  `ErrorState`.
- `Button`, `IconButton`, `TextField`, `Select`, `Combobox`, date picker,
  checkbox, switch, and form error summary.
- `StatusChip`, `Money`, `Quantity`, `DocumentNumber`, `GSTIN`, and date
  formatters.
- `DataTable` with server pagination, sticky header, row selection, column
  visibility, saved filters, and keyboard navigation.
- `EntityPicker` with debounced backend search, role/type badges, useful
  disambiguation details, and a bounded scroll area. No raw UUID entry.
- `LineEditor` for purchase, sales, stock, journal, and manufacturing lines.
- `ConfirmDialog`, `ActionMenu`, `Toast`, and activity/audit timeline.

### 4.2 ERP quality rules

- Use the approved warm-neutral/teal design tokens only; no gradients or
  decorative colour.
- Money is always `en-IN`, tabular, right-aligned, and never rounded silently.
- GSTINs, invoice numbers, HSNs, and internal codes use a mono style.
- Every picker shows enough detail to distinguish same-name contacts/items.
- Tables remain dense on desktop and horizontally deliberate on tablet; never
  allow an unbounded popover/list to run off screen.
- Keyboard use is a first-class requirement for document entry and table work.
- All interactive controls must be usable with keyboard and screen readers.
- Mobile responsiveness is required for read/review tasks. Native-heavy
  execution workflows remain Flutter-owned until separately migrated.

## 5. API, Security, and Tenant Contract

### 5.1 Rules that must not change

- The Spring backend remains the only authority for tenant scope, permissions,
  accounting, stock movements, GST, approvals, and document lifecycle.
- React UI role/capability checks only improve navigation. They never replace
  `@PreAuthorize` or server-side tenant filtering.
- Every organisation-scoped request carries `X-Org-Id`, exactly as the Flutter
  interceptor does today.
- The typed client unwraps the standard `ApiResponse` envelope and maps backend
  business error codes to field errors or actionable toasts.
- Mutations invalidate only related query keys. Financial/stock mutations must
  refresh their source document and relevant balances/reports after success.

### 5.2 Browser session decision

The current Flutter app stores access and refresh tokens in native secure
storage. Browser local storage is not an equivalent safe default.

Before the first React login page is shipped, add a web-safe session contract:

1. Serve the web app and API from the same site in production.
2. Put the refresh token in a `Secure`, `HttpOnly`, `SameSite=Lax` cookie.
3. Keep the short-lived access token in memory only; refresh it through the
   cookie when the app reloads or receives a 401.
4. Rotate and revoke refresh tokens server-side as the existing lifecycle
   requires.
5. Keep CSRF protection appropriate to the final cookie model.

This is a small, deliberate backend-auth enhancement, not a change to business
logic. Do not ship a React app that persists long-lived refresh tokens in
`localStorage` merely to avoid this work.

### 5.3 Contract discipline

- Export and commit an OpenAPI snapshot from Springdoc before React feature work.
- Generate types from that snapshot in CI; fail if generation changes without a
  reviewed contract update.
- Each React feature owns typed request/response adapters. Never pass
  `Record<string, unknown>` payloads through a page.
- Every new or corrected backend endpoint must include: OpenAPI description,
  permission rule, tenant rule, error codes, a service test, and a React path
  in the feature-coverage ledger.

## 6. Scope and Delivery Waves

The order below is intentional. It delivers and proves the flows that change
money and stock before secondary/admin surfaces. A wave can begin only after
the prior wave's quality gate passes.

### Wave 0 - Inventory, decisions, and contract baseline

**Goal:** establish a trustworthy conversion backlog before implementation.

- [ ] Export current OpenAPI document and establish generated type workflow.
- [ ] Create an API coverage ledger: controller/endpoint -> React route -> test
  case -> migration status.
- [ ] Reconcile `app_router.dart`, `shell_screen.dart`, `docs/testing/`, and
  `docs/UI_FIELD_GAP_AUDIT.md` into one feature inventory.
- [ ] Classify every Flutter route: migrate now, migrate later, native-only,
  intentionally retired, or backend-only.
- [ ] Identify all incomplete Flutter workflows and decide whether React closes
  the gap or the backend contract is first corrected.
- [ ] Approve the browser session/cookie model and production same-origin setup.
- [x] Freeze Java backend, database, API, and Flutter changes during the React
  migration stream. Track contract defects as separate work.

**Exit gate:** a traceable backlog exists for every route and every P0/P1 QA
case; no team member has to guess whether an endpoint is in scope.

### Wave 1 - React foundation and visual system

**Goal:** create one excellent, reusable ERP shell rather than a collection of
page-specific components.

- [x] Scaffold `react_app/` with TypeScript strict mode, linting, unit tests,
  production builds, and a local Vite server. Playwright remains pending.
- [x] Implement token CSS variables from `docs/design-system.md`.
- [x] Build the first reviewed primitives: Button, TextField, StatusChip,
  Money, PageHeader, and DataTable.
- [x] Connect browser-only login, restore, refresh, logout, tenant headers,
  organisation switching, and server-error handling to the web-session contract.
- [ ] Complete the nav registry from stable IDs, roles, industries, countries,
  capability gates, and `nav.disabled` settings. Role/industry gates and the
  organisation's `nav.disabled` setting are live; country and capability inputs
  remain blocked until the browser-session contract provides authoritative data.
- [ ] Add URL-driven global search, command palette skeleton, dark mode, locale
  switching, and RTL verification for Arabic.
- [ ] Establish table, picker, document-line, and bulk-action accessibility
  standards with component tests.

**Exit gate:** login -> org switch -> role/capability-aware shell works against
the live backend; all primitives have visual and keyboard tests; no business
feature page is built with ad-hoc styling.

### Wave 2 - Core master data and the two golden document chains

**Goal:** prove that React can safely run the financial and inventory heart of
the ERP.

#### Master data

- [x] Contacts: Customer/Vendor/Both/Supplier roles, filtering, role counts,
  search, detail view, statement with date range filter, ledger entries, and
  same-name disambiguation through company, phone, GSTIN, and role badges.
  Contact create/edit/import remain pending.
- [ ] Items: server-paginated directory, detail review, and typed create/edit
  workflow for catalog identity, pricing, GST/HSN, primary and transaction
  units, batch controls, preferred vendor, and create-only opening stock. Stock
  adjustments, reversals, and barcode/serial mutations remain outside the
  accepted React scope. CSV/XLSX preview, explicit import commit, server template
  download, and per-row results now have React source wiring. Item writes use the existing ItemController request contracts
  and preserve its opening-stock audit rule. Manual acceptance is pending.
- [x] Sales Orders: server-paginated, lifecycle-filtered directory, searchable
  customer/item creation, confirmation, cancellation, safe challan hand-off,
  and only-dispatched-quantity invoice conversion use the existing contracts.
  Document download remains pending in React.
- [x] Invoices: server-paginated, searchable receivables directory, direct
  invoice drafts, sending, invoice-scoped partial receipt recording, and
  detail/payment review use the existing contracts. Direct drafts resolve the
  organisation's configured sales-revenue account rather than relying on a
  fixed account code. Sharing and exports remain pending.
- [x] Picklists source workflow: paginated order selection, required order-line
  UUIDs and shippable quantities, PENDING -> IN_PROGRESS -> COMPLETED/CANCELLED,
  picked-quantity/batch updates, and role-aware confirmations now use the frozen
  API. Completion can be partial and does not dispatch inventory. Runtime
  acceptance remains pending.
- [ ] Items: serial mutations, stock adjustments/reversals, and other
  stock-execution actions. Item master create/edit, create-only opening stock,
  and preview/commit imports have source wiring; serial history and warehouse
  availability are read-only. The stock ledger now pages beyond 50 movements,
  exposes audit/reversal references, and distinguishes request errors from no data.
- [x] Shared masters: warehouse, price-list, Units of Measure (UoM), and tax-group
  read-only directories and detail reviews are complete. Price-list creation,
  tiers, customer assignments, and retirement now have React source wiring;
  runtime acceptance remains pending under R-06. Warehouse and zone maintenance
  now have source wiring with the existing role and default-warehouse rules.
  Rack creation and putaway task create/confirm/cancel, plus UoM metadata CRUD,
  now have source wiring. Rack edit/delete, rack-quantity accounting, serial
  mutation integration and UoM conversion rules remain outside the supported
  contract. Tax-group maintenance has no write endpoint; its active-only React
  review now matches controller roles and paginates. Branches and users remain
  outside this reviewed slice. Payment Terms and the
  Chart of Accounts have read-only reviews; their writes remain Flutter-only.

#### Purchase-to-pay golden chain

- [x] React source uses the approved supplier projection for PO/GRN selection,
  not contact-name filtering; AP bills and payments use the correct vendor
  contact projection.
- [x] React source wiring: purchase order -> PO-linked GRN draft -> receive
  stock -> vendor bill -> three-way match -> vendor payment. The chain uses
  server-owned stock, AP, GST, match, journal, and tenant rules; no React
  mutation bypasses those services.
- [x] Vendor payment accepts a searchable cash/bank ledger account, server
  payable bills, and one atomic allocation payload. Allocations remain intact
  across paginated bill results and are summed to currency precision before
  submission.
- [ ] Verify stock increases once, input GST is correct, AP is correct, and
  all journals balance through the executable purchase QA cases. This is a
  manual acceptance gate; it has not been claimed from source inspection.

#### Order-to-cash golden chain

- [x] React source wiring: sales order -> delivery challan -> dispatch ->
  linked invoice -> partial and final customer receipt. The sales-order
  conversion endpoint is used for dispatched-order invoices so React never
  invokes the direct-invoice stock path for the same goods.
- [ ] Verify stock decreases once, output GST is correct, AR is correct, and
  all journals balance.

**Exit gate:** every P0 case in `01_SALES_test_cases.md`,
`02_PURCHASE_test_cases.md`, `03_INVENTORY_test_cases.md`, and the accounting
verification cases succeeds in Playwright and manual QA. React and Flutter show
the same backend document state during parallel testing.

The focused execution order and evidence table are in
`docs/testing/REACT_WAVE_2_MANUAL_ACCEPTANCE.md`.

**Manual-acceptance decision (2026-09-04):** Product testing is deferred. This
does not mark Wave 2 passed: the item, purchase-to-pay, and order-to-cash
evidence remains required before React replaces Flutter for those workflows.
React source implementation may continue in later waves, provided the deferred
acceptance status is preserved in this tracker.

### Wave 3 - Core accounting, inventory, commercial operations, and reports

**Goal:** complete the daily office ERP used by an owner, accountant, and
operator.

- [ ] Accounting: the Chart of Accounts directory, immutable account-ledger review,
  verified read-only Bank Accounts directory review (with balance cards, masked
  account numbers, IFSC, and GL bindings), and verified read-only Fiscal Periods &
  Financial Years review (with period timeline, year selector, and governance status
  chips) are complete with unit test suites. Manual journal creation now supports
  searchable posting accounts, draft, immediate-post confirmation, and post-dated
  server scheduling. Typed, read-only Trial Balance, Profit & Loss, Balance Sheet,
  and General Ledger views use the existing server-calculated accounting responses;
  their runtime reconciliation acceptance remains pending. Account writes, bank reconciliation mutations, period close/lock
  mutations, guided transactions, vouchers, audit trail, fixed assets, and amortisation
  remain Flutter-only. Manual-journal runtime and accounting acceptance are pending.
- [ ] Inventory: stock views, warehouse/rack management, batch/serial/expiry,
  stock count, transfer orders, picklists, putaway, valuation, reorder, and
  consignment where approved.
- [x] Stock Count source workflow: a warehouse and physical-count line list
  create an immutable DRAFT count; the detail view presents server-calculated
  system quantity and variance, then confirms the existing post or cancel
  actions. Operators can create, but only OWNER/ADMIN/ACCOUNTANT can post/cancel.
  The frozen count request has no batch field and the stock ledger requires one
  for batch-tracked variances; React therefore blocks adding such items rather
  than creating an unpostable draft. Serial reconciliation is not implemented.
  Runtime inventory-ledger acceptance remains pending.
- [x] Transfer Order source workflow: active warehouses and catalogue items
  create a DRAFT transfer; the detail view confirms dispatch, receipt, or
  cancellation against the existing DRAFT -> IN_TRANSIT -> RECEIVED/CANCELLED
  lifecycle. The frozen API receives every dispatched line in full, so partial
  receipt is intentionally not presented as an available action. Batch-tracked
  items now require a source-warehouse batch UUID; separate lines can split an
  item across batches. Changing the source clears prior batch selections.
  Operators cannot cancel transfers. Stock actions invalidate dependent
  balances, item, batch, trace, and shortbook caches.
- [x] Batch and expiry source review: server-calculated expiry buckets and
  near-expiry stock provide a dense read-only watch register with search,
  horizon, and urgency filters. Batch genealogy and recall-impact views use
  only the existing immutable trace endpoints; batch creation, quarantine, and
  returns remain in their controlled receipt and inventory workflows. The
  aggregate watch response cannot safely drive the existing single-warehouse
  expiry-return mutation or supplier credit/debit documentation, so React does
  not expose that stock-changing action from this register. Trace now supports
  item/batch selection including inactive or exhausted historical batches;
  viewer roles do not issue restricted expiry or trace requests.
- [x] Replenishment source correction: Shortbook consumes its raw JSON array
  and actual currentStock/backordered/suggestOrderQty fields. Draft POs use
  selected supplier/warehouse UUIDs and item-master rates/tax groups, not fake
  identifiers or invented shortbook prices. Missing rates block submission.
- [x] Warehouse/zone source maintenance: create/edit facilities and defaults,
  role-aware removal, and zone create/edit/remove through existing endpoints.
  ACCOUNTANT/VIEWER cannot query the restricted zones API. Zone code is immutable;
  clearing an existing capacity is not supported and is not simulated.
- [x] Rack/putaway source workflow: shared warehouse-scoped rack directory and
  create form serve Inventory and the Pharmacy tab. Putaway tasks can be created
  standalone or from a RECEIVED goods receipt, with actual item/rack IDs and
  receipt batch references. Confirm pending lines and cancel open tasks through
  the existing endpoints. These are placement records, not a bin-quantity ledger
  or stock transfer. Lifecycle concurrency and cumulative receipt allocation are
  backend limitations, not solved by React action-state checks.
- [x] UoM metadata source workflow: create, edit, activate/deactivate, and confirm
  removal using the actual COUNT/WEIGHT/VOLUME/LENGTH/PACKAGING categories.
  Conversion ratios are not exposed because no conversion-rule controller exists.
- [x] Serial/stock audit source workflow: server-paged serial history, optional
  warehouse-filtered availability, and paged item stock movements with full
  source/batch/reversal references. Serial writes and generic stock reversals are
  intentionally absent pending safe document/stock integration; batch adjustments
  cannot identify a batch in the frozen DTO.
- [x] Bulk item import source workflow: backend CSV template download, unchanged
  multipart CSV/XLSX upload, preview and explicit commit confirmation, bounded
  row-result tables, active-default-warehouse prerequisite, role gates, cache
  refresh, and no automatic write retry after uncertain results. Per-row commits
  can partially succeed; preview is not a reservation or complete data audit.
- [x] Tax-group shared-master review: active-only directory, bounded paging,
  component-rate details, retryable API errors, and OWNER/ADMIN/ACCOUNTANT/VIEWER
  access match TaxGroupController. OPERATOR does not issue forbidden reads.
  No tax-group write endpoint exists; React does not invent one or recalculate
  transaction taxes. A component sum is labelled reference information only.
- [x] Barcode source correction: exact label request and ZPL/EPL response fields,
  real generated-code download, EAN13 check-digit and printer-text validation.
  The simulated barcode and browser print of the entire page are removed. No
  A4 layout, visual barcode rendering, or hardware certification is claimed.
- [x] Consignment source correction: actual remaining quantity, real master
  selectors, sale recording, supplier-scoped draft settlement retrieval, and
  confirmed settlement-ID actions. These APIs maintain a separate register;
  they do not create warehouse movements, bills, invoices, payments, or journals.
- [x] Price-list maintenance source workflow: create lists (including replacing
  the organisation default), add/remove quantity tiers, assign/unassign customers,
  and retire lists. Writes are exposed to OWNER/ADMIN/ACCOUNTANT; other permitted
  roles retain read access. The frozen controller has no price-list metadata or
  tier UPDATE endpoint, so React does not simulate an edit with delete/recreate.
- [x] Trade scheme source workflow: searchable register, create/edit/delete,
  all four scheme types, half-scheme settings, funding supplier, funding split,
  dates, and active state. Preview first loads applicable schemes, then presents
  the existing evaluation response without reproducing pricing arithmetic.
- [x] FEFO review source workflow: a shared batch picker reads availability for
  the actual issuing warehouse in challans and the default warehouse in direct
  invoices/POS. The picker preserves server expiry order and disables selecting
  a single batch with insufficient quantity. Direct invoices/POS can request
  their existing automatic selection; challans explicitly select their batch.
- [x] Inventory valuation source review: separates purchase-price reference
  balances from `/reports/stock-summary` (organisation costing by warehouse)
  and `/reports/fifo-valuation` (remaining cost lots). The accounting views use
  server currency/number/date column formats and server metrics, and are visible
  to OWNER/ADMIN/ACCOUNTANT. Empty/error responses never imply reconciliation.
- [ ] R-06 runtime acceptance: tests, build, responsive visual checks, and
  stock/GL reconciliation are deferred to the user. See
  `docs/testing/REACT_INVENTORY_PRICING_ACCEPTANCE.md` and the 2026-09-05 review
  addendum `docs/testing/REACT_INVENTORY_REVIEW_ACCEPTANCE.md`. Regression test
  sources were added but not executed in this review. Java and Flutter remain unchanged.
- [ ] Sales/AP/AR: estimates, recurring documents, credit/debit notes, customer
  receipts/advances, vendor payments/credits, dunning, and document PDF/share.
- [ ] Pricing and trade controls: price lists, customer pricing, schemes, rate
  contracts, credit warnings, and approval workflow states.
- [ ] Reports & Dashboards: the Executive ERP Overview Dashboard is fully migrated
  and connected to 10 live backend telemetry endpoints (today's sales with POS/Invoice
  split, receivables, payables, monthly gross profit, SO distribution alerts, top selling
  products, revenue trend intervals 7d/30d/90d, cash flow, near-expiry batch watch, and
  recent activity) with resilient query isolation and component tests. Financial statements
  and report exports remain pending. Trial balance, P&L, balance sheet,
  general-ledger, and AR/AP ageing source views are built but require runtime
  reconciliation acceptance.
- [ ] GST, TDS/TCS, e-invoice/e-way bill, GSTR flows, and country-specific VAT
  screens according to capability/country gates.

**Exit gate:** P0/P1 cases in Sales, Purchase, Inventory, Accounting, GST, and
Settings packs pass. High-risk report totals are cross-checked against backend
responses and source documents, not merely visual snapshots.

### Wave 4 - Workforce, field execution, and vertical packs

**Goal:** migrate high-value operational web administration while retaining
native execution where browser capabilities are not equivalent.

- [ ] HR and Payroll: employee records, attendance/admin, leave, shifts,
  timesheets, payroll lifecycle, salary structures, statutory outputs, and
  payment controls.
- [ ] Field Sales/MR administration: beats, customers-on-beats, routes,
  route-beat ordering, vans, team assignments, targets, live tracking views,
  tour plans, DCR review, samples, TA/DA review, coverage, and approvals.
- [ ] Pharma: drug/HSN/rack masters, near-expiry, statutory registers, and
  report/admin workflows.
- [ ] Manufacturing: BOM, routings, work orders, job cards, QC/NCR, job work,
  MRP, maintenance, shop-floor oversight, BMR, CAPA, and analytics.

**Exit gate:** the admin/reporting workflows in QA packs 05, 06, 09, and 10
pass. GPS check-in, barcode capture, thermal printing, and offline queue
behaviour remain Flutter-owned until their own native/PWA certification plan is
approved.

### Wave 5 - Ecosystem, platform, portals, and regional extensions

**Goal:** finish the web surfaces that extend the core ERP without weakening
the proven operational flows.

- [ ] Partner Network: partners, catalog publication, supplier search,
  incoming/outgoing orders, order traceability, and linked PO/SO state.
- [ ] Supply chain, courier, transport, franchise, loyalty, integrations,
  WhatsApp, and notifications.
- [ ] Platform admin, CA console, onboarding, organisation settings, module
  visibility, navigation customisation, API keys, audit, and support flows.
- [ ] Portal web app: customer/vendor authentication, statement, catalog,
  reordering, and order tracking.
- [ ] International/country profiles: currency precision, language/RTL, VAT,
  Kenya-specific payroll/payment only after the upstream provider contract is
  verified as operational.

**Exit gate:** P0/P1 cases in Partner Network, AI, Settings, and applicable
country/vertical packs pass. Every visible React action has a real endpoint and
an observable completion state.

### Wave 6 - Cutover, hardening, and Flutter web retirement

**Goal:** make React the default web client only after behaviour, performance,
and support readiness are proven.

- [ ] Run React and Flutter against the same staging tenant with identical
  test data and compare outcomes for every golden chain.
- [ ] Pilot with internal users and a small, reversible organisation cohort.
- [ ] Fix parity, accessibility, performance, and observability gaps found in
  pilot; do not hide them behind feature flags indefinitely.
- [ ] Make React the default web application; retain a time-limited legacy
  Flutter web link for rollback.
- [ ] Remove Flutter web only after all tracked web modules are accepted;
  keep Flutter native projects where still required.

**Exit gate:** no critical workflow requires Flutter web, all release gates
pass, monitoring is in place, and rollback has been rehearsed.

## 7. Feature Coverage Tracker

### Parallel Ownership - 2026-09-05

User-assigned work split: Antigravity owns the following enterprise-extension
implementation sections. Codex owns the independent bug review after Antigravity
finishes and the user explicitly confirms completion. This records ownership,
not dispatch, completion, or test acceptance. Do not duplicate or overwrite the
other agent's implementation while it is in progress.

| Section | Owner | Scope | Tracker mapping |
|---|---|---|---|
| 5A Transport and Logistics | Antigravity | Courier shipments/tracking, COD remittances/reconciliation, lorry receipts, freight rate cards, vehicle trip and maintenance logs under `/transport/*`. | R-13 transport subset |
| 5B Franchise and Loyalty | Antigravity | Franchise hierarchy/node details, supported royalty/inter-company workflows, loyalty programs, tiers and earn/redeem rules under `/franchise` and `/loyalty`. | R-13 franchise/loyalty subset |
| 5C Financial Depth and Assets | Antigravity | Fixed assets and depreciation, amortization, budgets and cost-center variance under `/fixed-assets`, `/amortization`, `/budgets` and their related screens. | R-07 asset/budget subset; assignment label does not move the original roadmap wave |
| 5D CA, AI and Platform Tools | Antigravity | CA workbench/alerts/dispatch review, AI suggestions/model registry/configuration, organization settings, UDFs and supported print-template configuration under `/ca/*`, `/ai/*`, `/settings/*`. | R-14 listed subsets; external portal/onboarding parity is not automatically included |
| Inventory and item-domain shared masters | Codex | Remaining R-06 inventory action parity plus item/pricing/UoM review outside the reserved settings, transport, franchise, asset, CA and AI areas. | R-03/R-06 scoped continuation |
| Sales estimates and quotations | Codex | Existing `/estimates` directory, create/detail/edit, role-aware document lifecycle, PDF/share handling and activity review. No shared shell or Antigravity-owned feature edits. | R-05 commercial pre-sales extension; source work started 2026-09-05 |

Both workstreams must preserve Java, migrations, backend tests and Flutter.
Use only existing APIs and inspect existing React code before adding screens.
Missing or unsafe contracts, including unavailable royalty/billing operations,
are documented blockers; do not simulate posting, settlement or calculations.

"Zero raw UUID" means user-facing relationships use searchable name/code
pickers; real IDs remain in API payloads, routes and audit references where
needed. Use the shared dense design-system components and handle long lists,
roles, tenant switching, pending actions and API errors consistently.

"100% test coverage" is a requested target, not a current result. Record the
measured line/branch/function/statement scope, executed commands and results
before claiming it; test-source creation alone is not coverage evidence.
Previously deferred automated/runtime acceptance remains pending until run.

Router, navigation, API client, design-system primitives and this tracker are
shared integration files. Coordinate changes before editing them concurrently;
make additive, narrowly scoped patches and preserve the other workstream's
changes. Antigravity ownership is not a blanket assignment of all R-07/R-13/R-14
features, and all affected rows retain their current acceptance status.

### Antigravity Handoff and Codex Bug Review

**Current review status (2026-09-05):** The user confirmed Antigravity's handoff
and authorised fixing the reviewed issues. The delivered React diff was checked
against existing Spring contracts. The nine reported issues now have scoped
React corrections and regression tests. This is not full 5A-5D acceptance:
live testing and the backend-dependent workflows below remain open.

| Section | Implementation owner | Follow-up reviewer | Review state |
|---|---|---|---|
| 5A Transport and Logistics | Antigravity | Codex | Reported contact-picker/fixture issues corrected; live lifecycle acceptance pending |
| 5B Franchise and Loyalty | Antigravity | Codex | Node/policy/wallet contracts corrected; unavailable integration actions explicitly blocked |
| 5C Financial Depth and Assets | Antigravity | Codex | Budget preservation, recognition accounts and monthly posting corrected; ledger acceptance pending |
| 5D CA, AI and Platform Tools | Antigravity | Codex | Reported PDF-setting and AI-export issues corrected; broader CA/UDF/platform acceptance not claimed |

Review and acceptance checklist (source review is distinct from live acceptance):

- [x] Inspect the actual implementation commits and local diff, preserving
  unrelated work; do not accept an agent summary as proof of correctness.
- [ ] Review API paths, payloads, response parsing, lifecycle transitions,
  permissions, tenant isolation, cache refresh, and repeat/failed submissions.
- [ ] Check money, stock, reconciliation and posting behaviour against existing
  backend contracts without changing Java or Flutter. Flag unsupported operations
  and simulated results rather than treating them as completed parity.
- [ ] Review searchable entity pickers, raw-UUID inputs, long-list pagination,
  dense shared layouts, validation, loading/error/empty states and accessibility.
- [ ] Inspect regression tests and any claimed coverage; distinguish source
  inspection, executed automated checks and live acceptance. Existing execution
  restrictions remain in force unless the user changes them.
- [x] Report actionable bugs by severity with file/line references and missing
  tests, then update each section's findings and acceptance status in this tracker.
  Implementation completion alone must not mark a section accepted or COMPLETE.

#### Review Corrections - 2026-09-05

- Budget GET/PUT uses `accountCode`, `annualAmount` and `notes`. Replacement
  saves preserve existing lines, including zero and no-longer-selectable accounts.
  Actuals come from the fiscal-year variance report, never hard-coded zero.
- Amortization requires explicit, distinct recognition accounts. The form no
  longer substitutes Cash/TDS codes. Both depreciation and amortization use
  the real organisation-wide monthly run endpoints with scope confirmation.
- Fixed assets collect the WDV rate, distinguish registration from acquisition
  accounting, parse actual preview/entry fields, and send the real disposal
  proceeds/account fields. Financial forms reset on organisation/role changes.
- Franchise node CRUD and policies use actual DTO fields. Store detail no
  longer invokes unavailable branch-price APIs. Royalty processing, invoicing,
  catalog sync and branch overrides remain unavailable because the existing
  backend explicitly rejects them. No replacement posting flow was invented.
- Loyalty supports explicit customer selection, wallet/history and read-only
  redemption eligibility. Arbitrary bonus/standalone redemption actions were
  removed: the existing mutation APIs require a real receipt, and a safe atomic
  sale/wallet workflow is not supplied by this migration. Full loyalty write
  parity remains blocked, not complete.
- Transport customer/vendor selection uses server search instead of a static
  first-page list. Invalid Contact/transport test fixtures match current types.
- PDF settings send only supported fields, preserve false values and cleared
  text, and isolate document/organisation drafts. No rendered-PDF preview is
  claimed. PDF output parity must still be tested with the existing renderer.
- AI training export uses the authenticated raw NDJSON download path and shows
  pending/error states. Training data is Owner/Admin only; unsupported quality
  metrics are not fabricated from missing response fields.

Final automated validation: **357 React tests passed across 90 files** with
two test workers; ESLint and the production build (including TypeScript) pass.
The build retains the large-bundle warning. Default-worker runs encountered
resource-sensitive UI timeouts; no unrelated tests or timeouts were weakened.
No live app, Java tests or Flutter tests were run. These corrections are
included in the 2026-09-05 Git checkpoint described below.

Validation results and manual steps are recorded in
`docs/testing/REACT_WAVE5_REVIEW_ACCEPTANCE.md`. Java, migrations, backend tests,
Flutter, the shared shell and navigation remain unchanged. Existing Estimates
work is preserved. These review fixes are not a 100% coverage or full-migration
completion claim.

#### Git Checkpoint Summary - 2026-09-05

Branch: `codex/contact-roles-field-sales-planning`.
The user requested a summary, tracker update and GitHub publication. This
checkpoint is split into two reviewable commits, not a new migration wave:

| Work package | Included changes | Acceptance status |
|---|---|---|
| Estimates and quotations | Shared create/edit form, correct DTOs and decimal totals, pagination, role-gated lifecycle actions, authenticated documents and paged activity | Automated checks passed; live workflow and documented conversion/PDF blockers remain open |
| Wave 5 review corrections | Budget preservation and actuals, explicit recognition accounts, confirmed organisation-wide monthly posting, fixed-asset contracts, transport search, franchise/loyalty contracts, PDF settings and AI export | Nine reported issues corrected in React; live ledger/UI testing and unsupported backend integrations remain open |

Both work packages include regression tests and their manual acceptance
checklists. Final checks: **357 tests / 90 files passed with two workers**, lint
passed, TypeScript and production build passed. The large-bundle warning and
default-worker resource-sensitive timeouts remain recorded, not suppressed.
No Java, database migration, backend test, Flutter, shared shell or navigation
files are included. No application was started and no real transaction was
posted during validation. Git commit history records the checkpoint revisions;
this checkpoint does not promote the wider migration rows to COMPLETE.

### Reconciliation - 2026-09-05

The table separates implementation from acceptance. `BUILDING` means React
source exists but the full workflow has not been accepted; it does not mean
every action is migrated. Recent implementation commits include `d6dd0d8d`
(Field Sales/MR) and `6fd0a875` (HR/Payroll and pricing). Their commit messages
are not independent proof of parity or test health. Existing React code for
POS, tax, manufacturing, ecosystem, and administration is also not a blank slate.
Review it before adding pages. Older narrative bullets and the Wave 0 ledger
are discovery history where they conflict with this dated reconciliation.

Current slice now has source wiring for rack/putaway, UoM metadata, serial
review, paged stock audit, and CSV/XLSX item import. Packaging maintenance was
also inspected: duplicate/cross-table barcode collisions block exposing its
writes safely. Tax-group maintenance was checked next: no write endpoint exists,
and its read-only React directory was corrected to the active-only/read-role
contract. Codex's next non-overlapping slice is now the existing sales estimates
and quotations workflow (R-05), while remaining item-domain shared masters and
inventory action parity stay open. Unsafe serial/batch/reversal/packaging writes stay
recorded as blockers, not React workarounds.
The 5A-5D handoff has been confirmed and its reported React defects corrected;
remaining acceptance and contract blockers are listed above. Concurrent
manufacturing/work-order changes are left to their current owner. Automated
checks for this checkpoint passed as recorded above; broader and live manual
acceptance remain pending. No Java or Flutter changes are allowed.

### R-05 Estimates Slice - 2026-09-05

**Status: BUILDING, source implemented for the scoped actions; not accepted.**
This is separate from Antigravity's reserved 5A-5D work. Existing React estimate
screens were inspected against the frozen EstimateController/DTOs/EstimateService
and Flutter estimate screens before correction. No Java, Flutter, shared router,
navigation, API-client, or design-system files were changed for this slice.

- [x] Corrected request fields to `discountPct`, `taxRate`, `unit` and optional
  `itemId`; removed unsupported invoice/batch/tax-group fields and the hard-coded
  5% preview. Preview follows per-line two-decimal HALF_UP arithmetic; displayed
  persisted totals remain the backend values. Discount is not subtracted twice.
- [x] Shared dense create/edit form: customer/product server search, free-text
  service lines, decimal quantities, subject/validity/currency/notes/terms.
  Editing is DRAFT/SENT only; update does not send unsupported currency changes
  or pretend that null clears an existing expiry date.
- [x] Server pagination, page-local keyword labelling and mutually exclusive
  customer/status filters; removed misleading first-page pipeline/win metrics.
- [x] Explicit role gates and confirmations for send/resend, acceptance, decline
  and draft deletion; server errors remain visible and no optimistic success is
  fabricated. Query keys are organisation-scoped.
- [x] Authenticated PDF download, server-generated WhatsApp message review
  without fallback messages on error, correct converted-invoice links, and
  independently paged activity/comments read view.
- [x] Regression tests added for requests, decimal rounding, permissions,
  form editing, paging, failures, PDF and currency safety, and executed in the
  final full suite: 357 tests passed across 90 files with two workers.
- [ ] Resolve separately authorised backend conversion defect: String-list
  membership is tested against the ContactType enum. Conversion remains visibly
  unavailable; no alternate create-invoice workaround exists in the UI.
- [ ] Backend document acceptance: PDF prints a negative discount row below an
  already-discounted subtotal. INR is hard-coded in PDF/share output. The React
  screen warns about discounted PDFs and blocks non-INR external document output.
- [ ] Bulk send/delete transaction review, comment create/delete parity, public
  document-link/recipient delivery review, concurrency and all live acceptance
  remain open. Source creation is not a full-parity or coverage claim.
- [x] Run typecheck, lint, tests and production build; all passed in the final
  checkpoint validation. Large-bundle/default-worker limitations are above.
- [ ] Complete desktop/mobile/manual acceptance. The React app was not started.

See `docs/testing/REACT_ESTIMATES_ACCEPTANCE.md` for the contract matrix,
backend blockers and the safe manual acceptance sequence.

### R-13/R-14 Partner, Planning and Portal Administration - 2026-09-05

**Status: BUILDING.** This continuation adds lazy-loaded route entries in
React, using the existing PartnerNetworkController, SupplyChainController and
PortalUserAdminController contracts. Java, database, Flutter and backend tests
remain unchanged. The React app has not been started for manual acceptance.

- [x] Partner directory, incoming request approval/rejection, suspension,
  published catalog metadata create/edit/unpublish, approved-supplier search,
  incoming/outgoing order lists, order lines/events and party-aware tracking.
- [x] Supply planning overview; server-paged requisitions, creation, low-stock
  draft generation and approval lifecycle; tracking-only shipment directory,
  creation/detail/dispatch/delivery/cancellation; alerts scan/resolve; moving,
  seasonal and weighted forecasts; ABC/reorder calculations; named item-supplier
  mappings with preferred supplier actions; read-only returns and scorecards.
- [x] Owner/Admin external portal account list, named contact invites,
  regenerate/suspend/reactivate/remove actions and one-time token handling.
  External customer/vendor login, invite acceptance, documents, statements,
  customer catalog and guarded reorder submission are now separate public routes.
- [x] Shared role/organisation boundary resets drafts on organisation, user or
  role change. Local pagination limits unpaged result rendering to 25 rows;
  paged APIs retain real server pagination. Named pickers replace raw UUID entry.
- [x] Command palette now derives visibility from the same group-aware rules
  as the sidebar. Group permissions and disabled groups are no longer bypassed
  by flattening navigation items before filtering.
- [x] Existing density and visual tokens only: 34px controls, 36px rows,
  shared FormGrid/FormCard/Modal/DataTable/StatusChip/Money/Quantity primitives.
  No feature-local CSS, colour palette, or application server was introduced.
- [x] Focused regression checks: 90 passed across six files (including existing
  navigation tests). These are mocked UI/request tests, not live acceptance.
- [x] Full React suite: 469 tests passed across 104 files with two workers;
  ESLint and production build (including TypeScript) passed. Existing main-bundle
  size warning remains; the new routes are lazy-loaded. Detailed evidence is in
  `testing/REACT_PARTNER_SUPPLY_ACCEPTANCE.md`.
- [ ] New partner discovery, network order placement/confirmation and PO/SO
  linking remain blocked by contract gaps/ownership validation, not implemented
  as raw-ID forms or client-only safety workarounds.
- [ ] Supply return execution and supplier-score recalculation need separately
  authorised backend corrections. Tracking is not stock movement or GL posting.
- [x] Shipment departure/arrival scheduling, agreed-unit line weight and notes,
  plus operational turnover ratios are wired to existing API fields. Turnover
  explicitly reports current average-cost stock value, not FIFO or period-average
  inventory. Document-reference writes remain withheld because ownership is not
  validated by the current service.
- [x] External portal sessions use a dedicated memory-only portal token, never
  the ERP administrator token/cookie/org header. Customer documents, statements,
  order history/detail, frequent items, catalog paging, confirmed reorder and
  password change are wired. Vendor bills are available; vendor PO lookup remains
  withheld because its backend lookup uses a contact id where the repository
  expects a supplier projection id. Portal amounts omit a symbol because the API
  does not provide organisation currency.
- [ ] Complete live tenant/role, responsive, concurrency and accounting/stock
  comparison checks before accepting these workflows or retiring Flutter.

See `docs/testing/REACT_PARTNER_SUPPLY_ACCEPTANCE.md` for the route/role matrix,
verified contract limitations and a page-by-page manual acceptance sequence.
The current continuation is uncommitted until a subsequent requested checkpoint.

### R-10/R-11 Contract Review Corrections - 2026-09-05

**Status: BUILDING, source corrected; live acceptance pending.** Antigravity's
HR/payroll and field-sales source was checked against existing controllers,
entities and lifecycle services. No Java, migration or Flutter file was changed.

- [x] Payroll run detail uses real calculate/approve/post/cancel mutations with
  confirmation, resolves employee identities, and downloads actual bank, PF,
  ESIC and payslip files. GL posting is not presented as salary payment.
- [x] Attendance uses server punch and monthly-summary data, real punch actions,
  actual regularization fields, local-time-to-UTC conversion, named employee
  review and reasoned approval/rejection. Fabricated attendance totals are gone.
- [x] Route executions use organisation users rather than payroll employee ids,
  resolve route/salesperson/van labels without invented fallbacks, and constrain
  Operator route/van selection to effective assignments.
- [x] Visit execution follows actual `PLANNED` -> `IN_PROGRESS` -> `COMPLETED`
  states, requires fresh device location for check-in/out, respects salesperson
  ownership, and labels visit collections as real oldest-invoice-first receipts.
- [x] Assignment create/edit/deactivate uses effective dates, named selectors,
  temporal status and confirmation. Beat selection was removed because the
  assignment service ignores that input; route planning owns beats.
- [x] Day close no longer fabricates an empty directory. It opens from an
  execution or saved close link, submits actual cash values, displays the
  server variance, and confirms approval/rejection.
- [ ] Frozen API limitations remain: no day-close list or lookup-by-execution,
  no rejected-close resubmission, assignment update cannot clear a van, visit
  order references lack contact ownership validation, and payslip JSON omits
  component names. React discloses or withholds affected actions.
- [ ] Full employee-to-payroll/statutory reconciliation, MR/native field runtime,
  responsive review, GPS acceptance, tenant/role testing and manual workflow
  comparison with Flutter remain open.
- [x] Current source validation: 469 tests passed across 104 files, ESLint passed
  with zero warnings, TypeScript and production build passed. The existing main
  bundle size warning remains visible. No application server or browser was run.

Use this table as the live executive tracker. Expand a row into smaller issue
checklists only after the wave starts. Status values are `NOT_STARTED`,
`DISCOVERY`, `BUILDING`, `QA`, `PILOT`, `COMPLETE`, or `NATIVE_RETAINED`.

| ID | Area | Wave | Status | Definition of done |
|---|---|---:|---|---|
| R-00 | OpenAPI contract and route/endpoint ledger | 0 | DISCOVERY | Local backend runs, but `/v3/api-docs` currently returns `500`; snapshot and generated types are blocked pending a separately authorised backend fix. React migration must not repair it. |
| R-01 | Browser auth, tenant, roles, capabilities, shell | 1 | BUILDING | React consumes the existing web-session endpoint, keeps the access token in memory, and sends the tenant header. Navigation registry and command palette are in progress; no backend change is permitted in this stream. |
| R-02 | Design system and shared ERP primitives | 1 | BUILDING | Token CSS plus initial Button, TextField, StatusChip, Money, PageHeader, and DataTable primitives pass lint, tests, and production build. |
| R-03 | Contacts, supplier roles, item and shared masters | 2 | BUILDING | Contacts provide search, paging, role counts, detail, statement, and create flows. Items provide typed create/edit for commercial, GST/HSN, unit, batch-control, preferred-vendor, and opening-stock fields; imports and stock-execution mutations remain pending. |
| R-04 | Purchase -> GRN -> bill -> vendor payment | 2 | BUILDING | Source wiring is complete for eligible-supplier PO/GRN creation, PO-linked GRN/bill hand-offs, stock receipt, bill post/delete/void, 3-way match/override, and atomic allocated vendor payment. React runtime, QA, and accounting acceptance are pending. |
| R-05 | Sales -> challan -> invoice -> receipt | 2 | BUILDING | Source wiring covers searchable sales-order creation, confirmation/cancellation, challan drafting/dispatch/delivery, invoice creation/sending and partial receipts. Estimates extension now has corrected create/edit payloads, totals, server paging, lifecycle controls, PDF/share and activity review. Estimate conversion and document-format blockers plus bulk/comment-write parity remain open; see REACT_ESTIMATES_ACCEPTANCE.md. Runtime, QA, stock/GST/AR and journal acceptance remain pending. |
| R-06 | Inventory and pricing operations | 3 | BUILDING | Reviewed source covers picklists, Shortbook PO drafts, printer contracts, consignment register, warehouses/zones, batch-aware transfers, pricing and valuation. Added rack creation, putaway create/confirm/cancel, UoM metadata CRUD, read-only serial review, paged stock audit, and CSV/XLSX preview/commit import. Batch counts/adjustments, serial mutations, generic reversals and packaging writes have frozen-contract/integration blockers; putaway is not bin stock. Remaining inventory and shared-master parity still needs review. No Java/Flutter changes. Automated, responsive, hardware, and inventory/GL acceptance remain deferred; see the R-06 checklists. |
| R-07 | Accounting, banking, reports, audit | 3 | BUILDING | Manual journal source wiring supports account-code posting, balanced draft/post workflows, post-dated scheduling, and reversal review. Typed Trial Balance, P&L, Balance Sheet, General Ledger, and AR/AP ageing views present server-calculated values through the existing report contracts. Runtime and reconciliation acceptance remain pending. |
| R-08 | GST, statutory, and country tax workflows | 3 | BUILDING | React GST/tax/regional pages exist. Full contract, filing, country/role and compliance-document review and acceptance are pending. |
| R-09 | POS web administration and receipt operations | 3 | BUILDING | React checkout, customer creation, discounts, shifts and receipt source workflows exist. Returns, tax/stock/GL acceptance and native printing/offline certification still require review. |
| R-10 | HR and Payroll | 4 | BUILDING | HR/payroll source was contract-reviewed: real attendance punches/summary/regularization and payroll lifecycle/download corrections are implemented. Employee-to-posted-payroll, payment/statutory reconciliation, role/tenant runtime and manual acceptance remain pending. |
| R-11 | Field Sales/MR administration | 4 | BUILDING | Planning, assignments, execution, GPS visit actions, collections and day-close source were contract-reviewed and corrected. Missing backend lookup/resubmission/clear-van safeguards plus MR/native execution and end-to-end acceptance remain pending. |
| R-12 | Pharma and Manufacturing | 4 | BUILDING | React pharmacy, BOM, work-order, QC, maintenance and related pages exist; manufacturing is under concurrent work. Review complete action loops and real item/batch effects before acceptance. |
| R-13 | Partner, supply chain, courier, franchise, loyalty | 5 | BUILDING | Reviewed transport/franchise/loyalty source plus partner and supply workflows. Shipment scheduling/weights and operational current-stock turnover are wired. Partner discovery/order integrity/linking, document references, supply returns and supplier-score recalculation retain frozen-contract blockers. Live acceptance remains open; see REACT_PARTNER_SUPPLY_ACCEPTANCE.md. |
| R-14 | Platform, CA console, portal, onboarding, AI | 5 | BUILDING | React settings/CA/AI and portal administration exist. A separately authenticated external portal now covers customer documents/statements/catalog/reorders and vendor bills; vendor PO retrieval and currency metadata are frozen API blockers. Platform/onboarding, integration, permission and end-to-end acceptance remain open. |
| R-15 | Cutover and Flutter web retirement | 6 | NOT_STARTED | Pilot accepted, rollback rehearsed, React default enabled. |

## 8. Quality Gates

### Per pull request

- TypeScript type-check, lint, formatting, and production build pass.
- Unit/component tests cover changed formatters, permission gates, field
  validation, calculation presentation, and reusable primitives.
- API client contract generation is current, or the feature is frontend-only
  foundation work explicitly permitted while the separately tracked OpenAPI
  blocker remains unresolved.
- No raw colour/spacing values or direct `fetch` calls appear in feature pages.
- Screens use `Money`, entity pickers, status chips, and error normalisation
  rather than reimplementing them.
- Accessibility review covers focus order, labels, visible focus, escape from
  dialogs, and keyboard table/form operation.

### Per migration wave

- Playwright covers a happy path, validation failure, permission denial, and
  tenant isolation check for each migrated feature.
- Desktop (1440px), laptop (1280px), tablet (1024px), and narrow mobile review
  screenshots are approved for the relevant workflows.
- Document totals are verified from source API values; UI never independently
  becomes the financial calculation authority.
- Loading, error, empty, permission-denied, and long-list states are tested.
- The corresponding manual QA cases are marked pass with real data.
- The current Flutter path remains operational until the React wave is accepted.

### Before production cutover

- Full backend test suite, React unit suite, and Playwright regression suite
  pass from a clean environment.
- P0 manual smoke cases pass in a fresh tenant and a long-lived test tenant.
- Role matrix tested: OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER.
- Tenant switch isolation tested in the browser, including cached data removal.
- Security review verifies cookie/session rules, no token leakage in browser
  storage or logs, CSP, and production API proxy/CORS configuration.
- Performance budget met for initial shell, table navigation, large search
  results, and document-line entry.

## 9. Deployment and Rollout Plan

### Development

- Vite development server proxies `/api` to `http://localhost:8080`.
- One `VITE_API_BASE_URL` environment variable is allowed; no production URL
  or secret is hard-coded in a React component.
- React development uses the same local Spring Boot, PostgreSQL, and Redis
  stack as Flutter. Test data is reset only through approved test scripts.

### Production

- Build React assets in a separate Node build stage.
- Serve hashed static assets from Nginx, CDN, or the selected platform.
- Proxy `/api/` to Spring Boot at the same public origin; configure SPA fallback
  only for client routes, never for `/api` or static assets.
- Set cache headers for immutable hashed assets; never cache authenticated API
  responses at a shared proxy.
- Publish an immutable release version in the UI and attach it to browser error
  telemetry.

### Rollout

1. Internal staff: React available behind an organisation/user allow-list.
2. QA cohort: run paired React/Flutter acceptance scenarios against the same
   staging organisation.
3. Pilot cohort: selected low-risk production organisations; Flutter web stays
   available as a visible rollback path.
4. Default-on: React becomes default for all web users only after pilot exit
   criteria pass.
5. Legacy removal: remove Flutter web after a measured support period; preserve
   Flutter native where required.

## 10. Realistic Effort and Capacity

The earlier high-level estimate was suitable for a small usable core. The code
inventory shows that **full production web coverage is materially larger**.

| Milestone | Focused AI-agent work estimate | What it delivers |
|---|---:|---|
| Foundations and contract baseline | 3-5 working days | A secure, typed, testable React shell and design system. |
| Golden master/purchase/sales chains | 7-12 working days | A credible daily ERP core with verified money and stock flows. |
| Accounting, inventory, reports, and compliance | 8-14 working days | Core office operations and financial confidence. |
| Workforce, vertical packs, ecosystem, platform, portal | 15-25 working days | Full React web coverage of the current product scope. |
| Parallel-run, pilot fixes, and cutover | 5-10 working days | Release confidence, not just finished screens. |

**Planning range:** roughly **38-66 focused AI-agent working days** for safe
full web coverage. Some tasks can run in parallel after foundations are stable,
but shared API, design-system, and golden-flow work must remain sequential to
avoid conflicting architecture. Human product acceptance/UAT determines the
calendar duration and cannot responsibly be compressed into code generation.

## 11. Risks and Controls

| Risk | Control |
|---|---|
| Copying Flutter bugs or omissions | Use backend contracts and QA packs as source of truth; reconcile the UI gap audit before each wave. |
| React screen is visually complete but business-incomplete | Feature definition of done includes happy, validation, role, tenant, and accounting/stock assertions. |
| API contract drift causes late failures | OpenAPI generation and typed client are mandatory before feature implementation. |
| Browser token exposure | Implement the HttpOnly refresh-cookie model before shipping browser authentication. |
| Full rewrite blocks current product progress | Parallel-run and module-by-module cutover; Flutter remains usable until each gate passes. |
| Native hardware/offline regression | Explicitly mark native-only flows and retain Flutter until browser/PWA equivalence is proved. |
| Inconsistent UI from rapid AI generation | Build/review the design system once; reject raw screen-local styles in code review. |
| Duplicate business logic in React | React presents backend-calculated money, tax, stock, and lifecycle state; it does not reimplement ledgers or posting rules. |
| Huge, untestable pull requests | One feature slice per PR with coverage update, tests, screenshots, and a rollback note. |

## 12. Implementation Rules for Future Tasks

- Do not start a React feature page until its route, API contract, QA cases,
  role rules, empty/error states, and source document are identified.
- Do not migrate an incomplete Flutter page without first deciding the desired
  ERP workflow from the backend and BRD.
- Do not add temporary mock data, fake totals, invisible actions, raw IDs, or
  dummy success states to make a screen look complete.
- Do not broaden backend business changes inside a React UI PR. Contract fixes
  must be isolated, reviewed, tested, and documented.
- Keep one migration checklist item and one API coverage record updated for
  every feature PR.
- Treat mobile/native parity as a separate decision; a responsive React page is
  not evidence of safe offline or hardware integration.

## 13. First Approved Next Step

Implementation started on 2026-09-03 after the source inventory, migration
plan, and visual-system brief were completed. The current Wave 1 task is the
React-only navigation registry, command palette, and accessibility foundation.
The `/v3/api-docs` failure is a separately authorised backend blocker; React
must not repair it. Contact create/edit and every document workflow remain
blocked until a contract snapshot can be produced from the unchanged backend.
