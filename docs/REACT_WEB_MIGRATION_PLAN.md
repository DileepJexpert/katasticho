# Katasticho React Web Migration Plan

**Status:** Active implementation - Wave 1 foundation and a read-only Contacts pilot are built
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
- [x] Items: server-paginated directory, detail review, and typed create/edit
  workflow for catalog identity, pricing, GST/HSN, primary and transaction
  units, batch controls, preferred vendor, and create-only opening stock. Stock
  adjustments, reversals, imports, and barcode/serial mutations remain
  Flutter-only. Item writes use the existing ItemController request contracts
  and preserve its opening-stock audit rule.
- [x] Sales Orders pilot: server-paginated, status-filtered directory and
  read-only document review using the existing Sales Order list/detail
  contracts. Creation, confirmation, cancellation, dispatch, invoicing, and
  document download remain pending in React.
- [x] Invoices pilot: server-paginated, searchable receivables directory and
  read-only invoice/payment review using the existing Invoice contracts.
  Sending, cancellation, payment recording, sharing, and exports remain
  pending in React.
- [x] Picklists pilot: server-paginated warehouse picklist directory and
  read-only line review using the existing Picklist contracts. Creating,
  starting, changing picked quantities, completing, and cancelling remain
  Flutter-only.
- [ ] Items: imports, serial operations, stock adjustments/reversals, and other
  stock-execution actions. Item master create/edit and create-only opening stock
  are complete; read-only pricing, tax/HSN, units, batch/expiry, packaging,
  warehouse, and ledger review remain available.
- [x] Shared masters: warehouse, price-list, Units of Measure (UoM), and tax-group
  read-only directories and detail reviews are complete. Warehouse/zone/putaway,
  price-list/customer-tier, and UoM/tax-group writes, branches, and users remain
  pending. Payment Terms and the Chart of Accounts have read-only reviews; their
  writes remain Flutter-only.

#### Purchase-to-pay golden chain

- [ ] Supplier/customer selection uses the approved procurement eligibility
  rules, not name-only filtering.
- [ ] Purchase order -> GRN -> receive stock -> vendor bill -> three-way match
  -> vendor payment.
- [ ] Verify stock increases once, input GST is correct, AP is correct, and
  all journals balance.

#### Order-to-cash golden chain

- [ ] Sales order -> delivery challan -> dispatch -> invoice -> partial and
  final customer receipt.
- [ ] Verify stock decreases once, output GST is correct, AR is correct, and
  all journals balance.

**Exit gate:** every P0 case in `01_SALES_test_cases.md`,
`02_PURCHASE_test_cases.md`, `03_INVENTORY_test_cases.md`, and the accounting
verification cases succeeds in Playwright and manual QA. React and Flutter show
the same backend document state during parallel testing.

### Wave 3 - Core accounting, inventory, commercial operations, and reports

**Goal:** complete the daily office ERP used by an owner, accountant, and
operator.

- [ ] Accounting: the Chart of Accounts directory and immutable account-ledger
  review are complete. Account writes, journals, guided transactions, vouchers,
  fiscal periods, audit trail, fixed assets, amortisation, bank accounts, and
  reconciliation remain pending.
- [ ] Inventory: stock views, warehouse/rack management, batch/serial/expiry,
  stock count, transfer orders, picklists, putaway, valuation, reorder, and
  consignment where approved.
- [ ] Sales/AP/AR: estimates, recurring documents, credit/debit notes, customer
  receipts/advances, vendor payments/credits, dunning, and document PDF/share.
- [ ] Pricing and trade controls: price lists, customer pricing, schemes, rate
  contracts, credit warnings, and approval workflow states.
- [ ] Reports: dashboards, trial balance, P&L, balance sheet, ledgers, ageing,
  operational reports, saved reports, exports, and cash/runway only where the
  backend represents real facts.
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

Use this table as the live executive tracker. Expand a row into smaller issue
checklists only after the wave starts. Status values are `NOT_STARTED`,
`DISCOVERY`, `BUILDING`, `QA`, `PILOT`, `COMPLETE`, or `NATIVE_RETAINED`.

| ID | Area | Wave | Status | Definition of done |
|---|---|---:|---|---|
| R-00 | OpenAPI contract and route/endpoint ledger | 0 | DISCOVERY | Local backend runs, but `/v3/api-docs` currently returns `500`; snapshot and generated types are blocked pending a separately authorised backend fix. React migration must not repair it. |
| R-01 | Browser auth, tenant, roles, capabilities, shell | 1 | BUILDING | React consumes the existing web-session endpoint, keeps the access token in memory, and sends the tenant header. Navigation registry and command palette are in progress; no backend change is permitted in this stream. |
| R-02 | Design system and shared ERP primitives | 1 | BUILDING | Token CSS plus initial Button, TextField, StatusChip, Money, PageHeader, and DataTable primitives pass lint, tests, and production build. |
| R-03 | Contacts, supplier roles, item and shared masters | 2 | BUILDING | Contacts provide search, paging, role counts, detail, statement, and create flows. Items provide typed create/edit for commercial, GST/HSN, unit, batch-control, preferred-vendor, and opening-stock fields; imports and stock-execution mutations remain pending. |
| R-04 | Purchase -> GRN -> bill -> vendor payment | 2 | NOT_STARTED | Stock/AP/GST/journal golden path passes. |
| R-05 | Sales -> challan -> invoice -> receipt | 2 | NOT_STARTED | Stock/AR/GST/journal golden path passes, including partial payment. |
| R-06 | Inventory and pricing operations | 3 | NOT_STARTED | Counts, transfers, batches, FEFO, valuation, and prices pass QA. |
| R-07 | Accounting, banking, reports, audit | 3 | NOT_STARTED | Statements reconcile to source documents and journals. |
| R-08 | GST, statutory, and country tax workflows | 3 | NOT_STARTED | Country/role gates and compliance documents pass validation. |
| R-09 | POS web administration and receipt operations | 3 | NOT_STARTED | React POS billing, returns, shifts, and receipt operations pass; Flutter hardware/offline fallback has an explicit certification and retirement path. |
| R-10 | HR and Payroll | 4 | NOT_STARTED | Employee-to-posted-payroll lifecycle and statutory reports pass. |
| R-11 | Field Sales/MR administration | 4 | NOT_STARTED | Planning, assignments, approvals, and reports pass; native execution assessed separately. |
| R-12 | Pharma and Manufacturing | 4 | NOT_STARTED | Vertical QA pack workflows pass with real item/batch data. |
| R-13 | Partner, supply chain, courier, franchise, loyalty | 5 | NOT_STARTED | Full create/detail/action loops are usable, not list-only shells. |
| R-14 | Platform, CA console, portal, onboarding, AI | 5 | NOT_STARTED | Admin and external user journeys have permission and E2E coverage. |
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
