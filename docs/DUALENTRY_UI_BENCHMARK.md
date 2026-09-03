# Katasticho UI Benchmark: Lessons from DualEntry

**Status:** Active discovery - design direction before React implementation  
**Decision:** Build a calmer, faster, operations-first ERP. Learn from
DualEntry's financial-workspace patterns, but do not copy its product or turn
Katasticho into a finance-only system.

## 1. Research Scope

This benchmark reviews publicly available DualEntry product material, not its
private application source or an assumed implementation. Its product pages
emphasise real-time, role-based finance dashboards; invoice-to-payment context;
AP matching and exception review; auditability; and report drill-down. Those
are useful workflow patterns, not requirements to copy every claimed feature.

- [DualEntry general ledger](https://www.dualentry.com/core-financials/general-ledger-software)
- [DualEntry accounts payable](https://www.dualentry.com/core-financials/accounts-payable-automation)
- [DualEntry accounts receivable](https://www.dualentry.com/core-financials/accounts-receivable-automation)

## 2. Product Direction

Katasticho's final web product is **one role-aware React application**:

- A cashier sees a focused POS workspace.
- An operator sees orders, dispatch, collections, and stock work.
- An accountant sees reconciliation, approvals, payables, receivables, and
  financial reports.
- An owner/admin can move between all authorised areas without logging into a
  different product.

The menu is permission-aware, but the data, document links, activity history,
and search belong to the same ERP. POS is not an isolated island: a completed
sale must lead naturally to the invoice or receipt, stock movement, customer
balance, journal, and report.

## 3. What to Adopt

| Pattern | DualEntry lesson | Katasticho implementation rule |
|---|---|---|
| Role-based dashboards | People need the few facts and tasks relevant to their work, not every metric. | Start each role home with a real action queue and a small set of drillable operational facts. |
| Document 360 view | A document is understood through its lines, payments, linked records, and audit history together. | Every purchase, sales, payment, stock, and journal detail page has a consistent header, lifecycle state, linked documents, values, and activity timeline. |
| Exception-first review | Mismatches should be surfaced with the reason and the permitted resolution, rather than buried in lists. | Three-way match, credit limits, overdue balances, stock shortages, and GST errors get an explicit exception panel with a safe next action. |
| Searchable financial operations | Dense, filterable lists are faster than card galleries for finance work. | Use server-backed tables with persistent URL filters, saved views, counts, pagination, column controls, and keyboard navigation. |
| Drill-down reporting | A report total should lead to the underlying transaction. | Financial and operational reports always link to source journals, invoices, bills, movements, or visits. |
| Controlled automation | Automation is useful only when the result and audit reason remain visible. | Suggestions can prepare, match, flag, or prioritise; only approved lifecycle actions post money, stock, or journals. |

## 4. Where Katasticho Must Be Better

DualEntry's public positioning is centred on finance teams. Katasticho is an
Indian MSME and distributor ERP, so the interface must combine finance control
with daily operational control.

| Katasticho advantage | Required experience |
|---|---|
| Operations and finance in one flow | A sales order shows fulfilment, dispatch, invoice, receipt, stock impact, and customer exposure without forcing users to hunt across modules. |
| Distributor command centre | The owner dashboard prioritises today's collections, overdue credit, dispatch backlog, stock risk, low stock, near expiry, supplier dues, and cash position. Each item opens a filtered work list. |
| Indian compliance at the point of work | GST, HSN, e-invoice/e-way-bill state, TDS/TCS, and place of supply are visible where they affect a document, not hidden in a separate compliance maze. |
| Fast counter-to-ledger path | POS has barcode/keyboard speed and a focused cashier layout, but authorised users can open the same sale's accounting and inventory evidence immediately. |
| Field and distribution context | Beat, route, visit, van, collection, DCR, and salesperson context should appear in relevant customer, order, collection, and dashboard views. |
| Clear master data roles | Contact pickers show Customer, Vendor, and Supplier eligibility, plus GSTIN, phone, company, and location. Same-name records are never distinguished by a raw UUID. |

## 5. Mandatory Screen Patterns

### 5.1 Role home: action queue before charts

Each role home starts with one compact **Needs attention** queue. It contains
only actionable records, for example: approval waiting, stock below reorder,
delivery awaiting dispatch, invoice overdue, three-way mismatch, or day close
variance. A row contains the reason, amount/quantity where relevant, age, owner,
and one controlled action. The count links to the complete filtered work list.

Below it, show no more than four context-specific facts. Examples for a
distributor owner are collections due today, dispatches waiting, inventory at
risk, and supplier payables due. Do not fill the first screen with decorative
charts or values without a source document.

### 5.2 Lists: workbench, not a long page

Every ERP list uses this structure:

1. Page title, visible result count, and one primary action.
2. Search by business identifier or name, followed by compact filter chips.
3. Saved views such as `All`, `Needs attention`, `Draft`, and user-defined
   views when supported.
4. A dense, server-paginated table with sticky header and a deliberate action
   column.
5. URL-persisted search, filters, sorting, tab, and pagination so a refresh,
   shared link, or back navigation does not lose the operator's place.

No unbounded supplier, customer, or item list may expand the page or escape a
dialog. Entity results use a bounded virtualised scroll area and progressive
search.

### 5.3 Document detail: one truth, visible next action

The header always contains: document number, lifecycle status, party, date,
total, and the one or two permitted primary actions. A document page has
consistent tabs:

- `Overview`: commercial and tax facts, balance, and linked records.
- `Lines`: quantities, rate, tax, discount, fulfilment or receipt state.
- `Payments` or `Stock`: whichever operational evidence applies.
- `Journal`: source accounting entry when the document is posted.
- `Activity`: append-only timeline of creation, approval, changes, posting,
  notification, payment, override reason, and actor.

The screen says why an action is unavailable. For example, a bill with a
matching variance explains the mismatch and offers `Review match` rather than
leaving a disabled payment button without context.

### 5.4 Pickers: choose safely at scale

Customer, vendor, supplier, item, warehouse, account, and employee pickers
must provide debounced server search and a fixed-height results area. Each row
shows enough stable information to distinguish near-duplicates:

- contact: name, role chips, company, GSTIN, phone, city;
- item: name, SKU/barcode, unit, available stock, tax;
- supplier: purchase eligibility, GSTIN, primary contact, outstanding AP;
- customer: credit status, outstanding AR, phone, primary route/beat when
  relevant.

The visible role determines eligibility. Procurement can select Vendor or
Supplier according to the approved business rule; customers never leak into
the list simply because the contact has a similar name.

### 5.5 Exception centre: resolve, do not merely alert

For a mismatch or blocked state, render source values side by side, the
calculated variance, policy/permission, resolution choices, and required
reason. Overrides require a clear business reason and write an audit event.
This applies to three-way match, price/quantity variance, credit override,
stock shortage/backorder, failed payment match, and tax validation.

## 6. Visual Direction

The implementation must follow [the existing design system](design-system.md):
warm-neutral background, deep teal primary action, borders before shadows,
compact 36px controls and 40px rows, tabular money, and mono document codes.

The intended quality is not "more modern cards." It is **calm, dense, and
decisive**:

- one strong primary action per page;
- restrained status colour that conveys lifecycle or risk only;
- data tables and entry forms receive the visual focus;
- no gradients, oversized rounded cards, dashboard-card clutter, or decorative
  animation;
- transitions only clarify state change, respect reduced-motion settings, and
  never delay data entry.

## 7. React Foundation Acceptance Criteria

Before any business screen is migrated, the React foundation must prove these
patterns with real backend data:

- role-aware sidebar and command palette from the current stable menu IDs;
- a desktop workbench table with URL-persisted filters and long-list behaviour;
- an accessible bounded entity picker with duplicate-name disambiguation;
- a document-detail shell with lifecycle actions and activity timeline;
- `Money`, quantity, tax, status, and document-code primitives from the existing
  design tokens;
- a real owner action queue with click-through to a filtered document list;
- a React POS route in the same application shell, gated to the appropriate
  roles, even while Flutter remains the temporary hardware/offline fallback.

## 8. Build Decision for the First React Slice

The first design-and-build slice after Wave 0 is not a cosmetic dashboard. It
is the reusable shell and workflow foundation needed by every module:

1. App shell, role/capability navigation, organisation switcher, command
   palette, secure session, and error states.
2. Data-table workbench, entity picker, money/status/code primitives, and
   activity timeline.
3. Owner action queue and one real list-to-document journey.
4. Contacts and items, then the purchase-to-pay and order-to-cash golden
   chains.

React source code remains intentionally unstarted until Wave 0 completes its
route/endpoint ledger, OpenAPI contract snapshot, browser session decision, and
foundation backlog review.
