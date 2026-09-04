# React Wave 0 Coverage Ledger

**Status:** Wave 1 implementation opened; OpenAPI contract export blocked
**Purpose:** A source-backed migration index for the React web ERP. This is not
a claim that a Flutter page should be copied or that an API is ready for React.
It records what exists, which workflow owns it, and what evidence is required
before a React feature may be marked complete.

## 1. Evidence Rules

Use sources in this order:

1. Spring controller, DTO, service, permission, and tenant behaviour.
2. Approved BRD and accounting/inventory invariants.
3. Manual QA pack case IDs in `docs/testing/`.
4. Current Flutter route and navigation implementation.
5. Historical roadmap or completion documents only after code verification.

React must not migrate a raw UUID field, dead action, placeholder chart, fake
total, or incomplete Flutter flow just because it is visible today.

## 2. Live Source Inventory

The following was measured from the working tree on 2026-09-03:

| Source | Measured surface | Migration implication |
|---|---:|---|
| Spring controllers | 195 controller classes | API coverage is much larger than the current UI and must be contract-led. |
| Spring method mappings | 1,383 `Get/Post/Put/Patch/DeleteMapping` annotations | Endpoint coverage must be generated from OpenAPI, not maintained by hand. |
| Flutter router | 294 `GoRoute` declarations and 1 shell route | Existing routes are a discovery input, not the React route design. |
| Sidebar registry | 13 major operational groups plus standalone dashboard, POS, contacts, settings, AI, and platform areas | React needs one typed navigation registry with the same role, industry, country, and capability gates. |
| UAT suite | 12 module packs under `docs/testing/` | Each migrated workflow needs its existing case IDs attached to its React acceptance tests. |
| OpenAPI support | `springdoc-openapi-starter-webmvc-ui` is installed; `/v3/api-docs/**` is permitted in `SecurityConfig` | Export a real snapshot only from a running backend; do not hand-write an API contract. |

The local server now starts, but `/v3/api-docs` returns a generic `500`. This
document therefore still does **not** contain a generated OpenAPI snapshot.
That defect is a separately scoped backend task: the React migration must not
change Java, database, API, or Flutter code to repair it. Generated TypeScript
types and write-capable React workflows remain blocked until the unchanged
backend can export its contract.

## 3. Product-Surface Coverage

`React classification` means the desired end state, not current readiness.
`Flutter fallback` means temporary only unless the row explicitly says
`Native retained`.

| ID | Business surface | Representative backend contracts | Existing client/navigation evidence | Acceptance evidence | React classification | Wave | Status |
|---|---|---|---|---|---|---:|---|
| W0-01 | Authentication, organisation, onboarding, roles | `/api/v1/auth`, `/api/v1/organisations`, `/api/v1/onboarding`, `/api/v1/org/users`, `/api/v1/settings` | Login, onboarding, settings, team routes | Settings pack + role checks in all packs | React web | 0-1 | BUILDING: browser-only cookie session is source-tested; live restart verification pending |
| W0-02 | App shell, search, capability navigation, notifications | Organisation/settings, notifications, dashboard APIs | Stable sidebar IDs in `shell_screen.dart`; command/search shell | Cross-module role UAT | React web | 1 | BUILDING: the shell applies role/industry gates and the organisation's `nav.disabled` setting; country/capability context and notifications remain contract-pending. |
| W0-03 | Dashboard and work queues | Dashboard, AR/AP reports, stock, workflow, field-sales dashboard APIs | Dashboard and accounting dashboard routes | Sales, Purchase, Inventory, Accounting P0 cases | React web | 1-3 | BUILDING: live dashboard queries implemented; acceptance test pending |
| W0-04 | Contacts, parties, supplier eligibility, statements | `/api/v1/contacts`, `/api/v1/suppliers`, `/api/v1/customer-receipts` | Standalone Contacts nav and create/detail/statement routes | `TC-SAL-001...`; `TC-PUR-001...004` | React web | 2 | BUILDING: the read-only directory, detail view, and bounded statement ledger use the source contracts; create, edit, and import mutations remain pending. |
| W0-05 | Items, prices, tax, units, warehouses, stock masters | `/api/v1/items`, `/api/v1/uoms`, `/api/v1/warehouses`, `/api/v1/tax-groups`, `/api/v1/stock` | Inventory group and item/detail/import routes | Inventory pack P0/P1 | React web | 2-3 | BUILDING: read-only Item directory uses the existing paged list and negative-stock count contracts; mutations, detail, units, pricing, tax, and stock execution remain pending. |
| W0-06 | Purchase to pay | `/api/v1/purchase-orders`, `/api/v1/stock-receipts`, `/api/v1/bills`, `/api/v1/ap/three-way-match`, `/api/v1/vendor-payments` | Purchases group: PO, GRN, bills, matching, payment paths | `TC-PUR-010...071` | React web | 2 | DISCOVERY: the current Purchase Order list is an unbounded array with no supported page, search, or status query; React intentionally does not duplicate that scaling limitation. |
| W0-07 | Order to cash | `/api/v1/sales-orders`, `/api/v1/delivery-challans`, `/api/v1/invoices`, `/api/v1/payments`, `/api/v1/customer-receipts` | Sales group: SO, challan, invoices, receipts, credit notes | Sales pack P0/P1 | React web | 2 | BUILDING: read-only, status-filtered Sales Order and Invoice directories plus document review use the current paginated list/detail contracts; all workflow mutations remain Flutter-only. |
| W0-08 | POS and cash register | `/api/v1/items` search, `/api/v1/sales-receipts`, `/api/v1/pos/cash-register` | Standalone POS, receipt, cash-register, printer routes | `TC-SAL-070` and POS cases | React web; Flutter temporary hardware/offline fallback | 3 | DISCOVERY |
| W0-09 | Inventory execution and costing | `/api/v1/stock-counts`, `/api/v1/transfer-orders`, `/api/v1/picklists`, `/api/v1/batches`, `/api/v1/serial-numbers`, `/api/v1/inventory/*` | Inventory group: counts, transfers, picklists, putaway, barcode, consignment | Inventory pack P0/P1 | React web; scan/print certification required | 3 | BUILDING: Picklists has a server-paginated read-only directory and line review. Creating, starting, quantity entry, completion, and cancellation remain Flutter-only. |
| W0-10 | Accounting, banking, audit, financial reports | `/api/v1/accounts`, `/api/v1/journal-entries`, `/api/v1/accounting/*`, `/api/v1/bank-*`, `/api/v1/reports` | Accounting, banking, reports groups | `TC-ACC-*` | React web | 3 | DISCOVERY |
| W0-11 | GST, TDS/TCS, e-invoice, statutory compliance | `/api/v1/gst/*`, `/api/v1/tds`, `/api/v1/tcs`, tax-group/settings APIs | Tax & Compliance group | `TC-GST-*` | React web | 3 | DISCOVERY |
| W0-12 | HR and payroll | `/api/v1/hr/*`, `/api/v1/payroll/*` | HR & Payroll group | `TC-HR-*`, `TC-PAY-*` | React web | 4 | DISCOVERY |
| W0-13 | Field sales and MR administration | `/api/v1/field-sales`, `/api/v1/mr`, `/api/v1/field-sales/hierarchy` | Field Sales group, including beats, routes, assignments, DCR, tracking | `TC-FS-*` | React admin web; mobile/GPS execution separately certified | 4 | DISCOVERY |
| W0-14 | Pharma operations | Drug master, pharmacy master, prescriptions, FSSAI, statutory-register APIs | Pharmacy/rack/near-expiry/prescription routes | Applicable Inventory, GST, Field Sales cases | React admin web | 4 | DISCOVERY |
| W0-15 | Manufacturing and job work | `/api/v1/manufacturing`, `/api/v1/inventory/job-work`, BMR, CAPA, maintenance APIs | Manufacturing group plus inventory job work | `TC-MFG-*` | React web | 4 | DISCOVERY |
| W0-16 | Partner network, supply chain, courier, transport | `/api/v1/partner-network`, `/api/v1/supply-chain`, `/api/v1/courier/*` | Partner Network, Supply Chain, Courier groups | `TC-PN-*` plus relevant trade flows | React web | 5 | DISCOVERY |
| W0-17 | Portal, platform, CA, administration, integrations | `/api/v1/portal*`, `/api/platform-admin/v1/*`, API key, settings, notification APIs | Portal, platform admin, CA console, settings routes | Settings, Partner, role cases | React web, with portal as separate external journey | 5 | DISCOVERY |
| W0-18 | AI-assisted workflow | `/api/v1/ai*`, bill/GRN draft, conversational entry, replenishment drafts | AI command centre and inbox routes | `TC-AI-*` | React web, review-first | 5 | DISCOVERY |

## 4. Golden Workflow Map

These are the first React workflows because they prove both operational and
financial correctness. A visually finished page is insufficient: every stated
stock, tax, outstanding, and journal effect must be asserted from backend data.

| ID | Flow | Required document relationship | Required acceptance evidence |
|---|---|---|---|
| G-01 | Master data to purchase payment | Eligible vendor/supplier -> PO -> GRN -> received stock -> vendor bill -> three-way match -> vendor payment | `TC-PUR-001`, `010`, `012`, `020`, `030`, `040`, `043`, `050`, `051`, `070`; accounting balance check |
| G-02 | Master data to customer receipt | Customer -> sales order -> delivery challan -> dispatch -> invoice -> partial receipt -> final receipt | Sales P0 chain, including stock decreases once, GST is correct, AR clears only by payment, and journals balance |
| G-03 | POS to ledger | POS search -> sale -> receipt/return -> cash-register close -> stock, revenue, tax, and journal evidence | `TC-SAL-070` plus applicable return/role cases |
| G-04 | Accounting source traceability | Source document -> posted journal -> ledger -> trial balance -> financial statement | `TC-ACC-010...030` and source-document drill-down |
| G-05 | Controlled exception | Three-way, credit, stock, or GST exception -> required reason -> authorised resolution -> activity evidence | Purchase, Sales, Inventory, GST role and negative cases |

## 5. Endpoint-Ledger Contract

The detailed ledger is generated from the committed OpenAPI snapshot. It must
have one row for every public operation, with these mandatory columns:

| Field | Rule |
|---|---|
| `operationId` / API ID | Taken from OpenAPI; add one where Springdoc cannot derive a stable ID. |
| `controller.method` | Java source reference for design and debugging. |
| HTTP method and path | Exact generated contract, including query parameters. |
| domain and business action | Human-readable action, not merely controller name. |
| permission and tenant rule | Derived from `@PreAuthorize`, module/capability guards, and tenant behaviour. |
| React route and feature | A planned route only after UX review; no copied Flutter route strings by default. |
| lifecycle impact | Read, draft, command, post, reverse, approval, export, or external integration. |
| QA evidence | Existing `TC-*` IDs plus new Playwright test ID. |
| migration state | `DISCOVERY`, `CONTRACT_READY`, `BUILDING`, `QA`, `PILOT`, `COMPLETE`, or `NATIVE_RETAINED`. |

### Snapshot procedure

When the backend is running, capture the source contract without editing it:

```powershell
Invoke-WebRequest http://localhost:8080/v3/api-docs -UseBasicParsing `
  -OutFile docs/contracts/openapi.json
```

Then validate the JSON, record its SHA-256 and operation count, and generate
TypeScript types only from that committed snapshot. The snapshot must be
regenerated and reviewed whenever a backend API changes.

## 6. Browser Session Decision Record

### Current verified state

- Spring Security is stateless and globally disables CSRF.
- `AuthResponse` returns both access and refresh tokens in JSON.
- `/api/v1/auth/refresh` accepts the refresh token in a JSON request body.
- Flutter stores credentials through its native auth storage and attaches a
  bearer token plus `X-Org-Id` through `AuthInterceptor`.

This is appropriate for the current native Flutter client. It is not the React
browser design: a long-lived refresh token must never be placed in
`localStorage`, `sessionStorage`, Redux/Zustand state, or application logs.

### Recommended implementation direction for React

Keep the mobile endpoints unchanged. Add a deliberately separate, same-origin
web session contract before React login is released:

1. Web login returns a short-lived access token and user context in JSON, but
   places the rotated refresh token only in a `Secure`, `HttpOnly`,
   `SameSite=Lax` cookie restricted to the web-session refresh/logout path.
2. Web refresh reads the cookie, validates and rotates the existing persisted
   refresh token, returns only a new access token/user context, and resets the
   cookie.
3. Web logout revokes the stored token and clears the cookie.
4. Production serves React and `/api` from the same public origin. Local React
   development reaches `/api` through the Vite proxy with credentials included.
5. Cookie-bearing web-session endpoints enforce an explicit trusted-Origin
   guard without imposing browser-cookie requirements on existing bearer-token
   mobile APIs. Production requires `WEB_SESSION_ALLOWED_ORIGINS`; blank fails closed.
6. React keeps the access token in memory only, sends `X-Org-Id` on every
   organisation-scoped request, and clears cached tenant data before/after an
   organisation switch.

**Status:** CONTRACT_FROZEN, RUNTIME_VERIFICATION_PENDING. React may consume
only the currently available web-session endpoints. Any correction to those
endpoints is a separately authorised backend task; Flutter's auth contract is
not part of this migration stream.

## 7. Wave 0 Remaining Checklist

- [x] Inventory Flutter routes, sidebar groups, controllers, and QA packs.
- [x] Create source-backed surface and golden-flow ledger.
- [x] Review current auth/session behaviour and record the browser-safe target.
- [x] Produce DualEntry-informed React UX benchmark and foundation criteria.
- [x] Establish the React shell, design tokens, initial primitives, and browser-safe auth contract.
- [x] Build a read-only Contacts pilot against the source-backed role filters.
- [x] Freeze Java backend, database, API, and Flutter code during React migration.
- [ ] Start the backend, export, validate, and commit the OpenAPI snapshot.
- [ ] Produce the generated detailed endpoint ledger from that snapshot.
- [ ] Review the ledger with product owner and mark intentionally retired,
  native-retained, and first-wave capabilities.
- [ ] Add generated endpoint types and Playwright acceptance checks after a
  separately authorised backend task repairs the OpenAPI endpoint.
