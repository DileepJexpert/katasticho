# React Inventory and Pricing Acceptance

Status: source implementation ready for review; automated execution, browser
acceptance, and accounting reconciliation have NOT been performed in this pass.
Scope: React only. Existing Java, database, security, and Flutter are unchanged.

Inventory review follow-up (2026-09-05): see
`REACT_INVENTORY_REVIEW_ACCEPTANCE.md` for corrected operational contracts,
warehouse/zone writes, stock-count limitations, shared-control changes, and
the additional acceptance cases. R-06 is still BUILDING.

## Price lists

Path: Inventory -> Price Lists (`/price-lists`).

- [ ] As ADMIN, create `Wholesale Test`, currency `INR`, default unchecked.
- [ ] Add an item tier: minimum quantity 10, unit price 40; confirm it reloads.
- [ ] Add another tier at quantity 25, price 38; confirm both remain visible.
- [ ] Repeat quantity 10 for the same item; confirm the server duplicate error
  keeps the form open and does not create a second tier.
- [ ] Assign an existing CUSTOMER/BOTH contact; confirm it appears under
  Assigned customers. Confirm vendor-only contacts are excluded from the picker.
- [ ] Move that customer to a different list and verify both lists after refresh.
- [ ] Remove an assignment and verify fallback pricing on a new document.
- [ ] Remove a tier only after confirmation; verify other tiers survive.
- [ ] Create a new default list; verify the previous default is cleared.
- [ ] Retire a test list; verify it leaves the directory and previously posted
  documents retain their amounts.
- [ ] As OPERATOR/VIEWER, verify read access and absence of mutation controls.
- [ ] With many items/customers, search a record outside the first page and
  verify the picker remains bounded and scrollable on desktop and mobile.

Contract limits: lists support creation and retirement; tiers support adding and
removing. There is no UPDATE endpoint for list metadata or tier rows. Customer
unassignment clears the current pin by contact ID; the backend does not compare
the list ID in the URL. Concurrent reassignment/unassignment remains a server
contract limitation and is not made atomic by this UI.

## Trade schemes

Path: Inventory -> Trade Schemes (`/schemes`).

- [ ] Create/edit percentage discount, buy-X-get-Y, half/full, and special net
  rate schemes. Confirm item, supplier, dates, funding percentage, free quantity
  cap, half-scheme threshold, and active state survive reload.
- [ ] Reject inverted date ranges, missing required terms, negative values,
  and percentages above 100 before sending the request.
- [ ] Preview an active 10+1 scheme at quantity 10, then quantity 5 with half
  scheme enabled. Compare every displayed result with `/schemes/evaluate`.
- [ ] Change quantity/item/rate after preview; ensure the old result disappears.
- [ ] Confirm inactive, future, expired, or below-minimum schemes are absent
  from the applicable-scheme selector for the selected item and quantity.
- [ ] Preview automatic selection with no applicable scheme; display the
  returned no-scheme explanation without creating an order or stock movement.
- [ ] Delete a scheme after confirmation; verify it disappears on refresh.

## Batch issue review

Paths: a confirmed sales order -> Create delivery challan; New direct invoice;
POS counter. Use a batch-tracked test item with two batches in two warehouses.

- [ ] Open batch allocation and verify the order warehouse ID is used for
  challans; direct invoices and POS use the default-warehouse API behaviour.
- [ ] Verify returned expiry order, actual warehouse quantity, and batch UUID
  submission. A short batch cannot be explicitly selected for the whole line.
- [ ] Check no available stock and API permission/network failures are shown
  explicitly; neither is presented as a successful allocation.
- [ ] For direct invoices, switch between an explicit batch and automatic
  FEFO, save, send, and reconcile the resulting stock movements.
- [ ] For challans, select an explicit batch, dispatch, and verify that batch's
  movement and balance. The existing challan path does not split one line across
  multiple batches or auto-allocate when no batch is supplied.
- [ ] Clear an explicit challan batch and verify the selection is removed;
  clearing must not be labelled as automatic allocation.
- [ ] For POS, review/change the batch and compare the receipt and movement.
  Its existing automatic path selects the first available batch; it is not the
  direct invoice's multi-batch allocation algorithm.
- [ ] Check expired-stock behaviour against the existing server controls. The
  available-batches endpoint includes active expired batches; FEFO order alone
  does not establish that a batch is safe to sell.

## Inventory valuation

Path: Inventory -> Stock Summary (`/inventory/stock-summary`).

- [ ] Stock balances show the existing purchase-price reference values without
  describing them as weighted-average or FIFO accounting valuation.
- [ ] As ADMIN/OWNER/ACCOUNTANT, Warehouse valuation matches
  `/api/v1/reports/stock-summary`, including warehouse and server totals.
- [ ] FIFO cost lots matches `/api/v1/reports/fifo-valuation`, including
  currency, receipt dates, numeric columns, open-lot count, and lot values.
- [ ] Search filters rows without relabelling the full-report totals as filtered
  totals. Switching views does not change the organisation costing setting.
- [ ] An empty response shows no rows/lots; a failed request shows a retryable
  error. Neither reports the inventory as reconciled.
- [ ] OPERATOR/VIEWER receive no inventory-report controls or requests,
  including stock-summary and low-stock-alert (both are also restricted by the
  existing controller). Item-level stock quantities remain in Items.
- [ ] Reconcile known receipt/dispatch/transfer transactions and GL inventory
  balances using the existing Flutter reports as the comparison client.

## Checks deferred to the tester

Run from `react_app`: `npm run lint`, `npm run test`, and `npm run build`.
Relevant test sources: price-list writes/detail, pricing contracts, scheme
workflow, batch allocation, stock summary, and modal focus. Check all new dialogs
at laptop and mobile widths, keyboard navigation, pending/error states, and
repeat submissions before marking R-06 accepted.
