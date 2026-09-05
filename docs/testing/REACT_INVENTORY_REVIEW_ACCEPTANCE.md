# React Inventory Review and Acceptance Addendum

Reviewed: 2026-09-05. Tracker: R-06 remains BUILDING.

This is source review and React implementation, not runtime acceptance. Java,
backend tests, resources/migrations, and Flutter were not changed. The app was
not started. Type-check, lint, tests, build, browser checks, and stock/GL
reconciliation remain deferred to the tester. `git diff --check` is only a
whitespace check, not evidence of application correctness.

## Corrected Findings

| Area | Confirmed mismatch | React correction |
|---|---|---|
| Picklists | Create omitted required lines; update sent a raw array/batch number; start assumed DRAFT. | Eligible SO selection, order-line UUIDs, `{lines: [...]}` updates using batchId, PENDING lifecycle, partial-completion warning. |
| Shortbook | ApiResponse parsing on a raw array; invented stock/price fields and free-text UUID inputs. | Raw JSON reader, actual suggestions, real supplier/warehouse selection, item-master rates and tax groups. |
| Barcodes | Wrong request/response fields and a decorative barcode unrelated to server output. | Exact generator contract and actual ZPL/EPL downloads; no simulated print preview. |
| Consignment | Invented quantity fields; settle used the stock ID and implied bill/payment posting. | Actual quantity and supplier draft settlements; settle uses settlement ID with status-only explanation. |
| Warehouses/zones | Read-only React despite write APIs; zone tab exposed forbidden reads. | Warehouse and zone maintenance with exact endpoint roles and immutable/default-field rules. |
| Transfers/counts | Missing batch payloads and action role gates; stale stock projections after posting. | Batch-aware transfer lines, controller-matched permissions, shared dependent-cache invalidation. |
| Stock reports | Operators could still request restricted stock-summary and low-stock reports. | All inventory-report requests restricted to OWNER/ADMIN/ACCOUNTANT, including deep-link rendering. |
| Shared controls | Search failures looked like no matching records; nested Escape could close both dialogs. | Retryable picker errors, cancelled stale searches, topmost-dialog keyboard handling and shared scroll locking. |
| Racks/putaway | Inventory rack/putaway routes were absent; pharmacy contained its own rack form. | One shared rack workspace; create placement tasks standalone/from a received GRN, select actual racks, confirm pending lines and cancel open tasks. |
| UoM | Read-only directory included AREA/TIME categories the API does not accept. | Actual PACKAGING category and role-gated metadata create/edit/deactivate/remove. No invented conversion-rule API. |
| Serial register | No serial review path despite read endpoints. | Server-paged per-item history and warehouse-filtered availability, without unsafe status mutations. |
| Item ledger | Only first 50 movements visible; failed child queries looked like empty lists. | Page navigation, movement audit details, real source/reversal references, errors and retry for every item-review section. |
| Item import | Existing preview, import, and CSV-template endpoints had no React workflow. | Same-file multipart preview/commit, explicit confirmation, bounded row results, partial-success reporting and no blind write retry. |
| Tax-group shared master | UI advertised inactive groups and Flutter maintenance despite active-only GET endpoints; OPERATOR could request forbidden reads. | Active-only, paginated review, exact read roles, error retry, and no invented maintenance operation. |

Evidence: existing PicklistController/DTOs/PicklistService, StockController and
ShortbookItemResponse, BarcodeLabelController/DTOs, ConsignmentController/Service,
WarehouseController/Service, WarehouseZoneController/Service, TransferOrderService,
StockCountController/Service, InventoryService, BatchController/BatchTraceController,
and InventoryReportController. React adapters preserve these contracts.
Additional sources: PharmacyMasterController/Service, WarehousePutawayController/Service,
UomController/Service, SerialNumberController/Service, ItemController,
ItemImportService and its DTOs, ItemPackagingBarcodeService and V57. Only React
and tracker/test-source files were edited.

## Permissions To Verify

| Action | OWNER/ADMIN | ACCOUNTANT | OPERATOR | VIEWER |
|---|---|---|---|---|
| Picklist create/start/update/complete | Yes | Yes | Yes | No |
| Picklist cancel | Yes | Yes | No | No |
| Transfer create/dispatch/receive | Yes | Yes | Yes | No |
| Transfer cancel | Yes | Yes | No | No |
| Count create | Yes | Yes | Yes | No |
| Count post/cancel | Yes | Yes | No | No |
| Warehouse create/edit | Yes | Yes | No | No |
| Warehouse removal | Yes | No | No | No |
| Zone read | Yes | No | Yes | No |
| Zone writes | Yes | No | No | No |
| Shortbook draft PO | Yes | Yes | No | No |
| Consignment receive/sale | Yes | Yes | Yes | No |
| Consignment mark settled | Yes | Yes | No | No |
| Barcode generation | Yes | Yes | Yes | No |
| Expiry/trace reports | Yes | Yes | Yes | No |
| Stock summary/low-stock/valuation reports | Yes | Yes | No | No |
| Rack list/create | Yes | Yes | Yes | No |
| Putaway list/create/confirm/cancel | Yes | Yes | Yes | No |
| UoM read | Yes | Yes | Yes | Yes |
| UoM create/edit/remove | Yes | Yes | No | No |
| Serial and stock-ledger review | Yes | Yes | Yes | Yes |
| Item create/edit/import/template | Yes | Yes | Yes | No |
| Tax-group review | Yes | Yes | No | Yes |

Other inventory directories retain their endpoint read rules. UI permissions
are convenience controls, not an authorization boundary. Verify direct API
enforcement separately; React does not bypass server module/role policies.

## Manual Checklist

Use a disposable test organisation and unique test references. Do not reconcile
real inventory by experimenting with count, transfer, or consignment actions.

- [ ] Picklists: choose an eligible order beyond page one, confirm the real
  warehouse and shippable lines, exclude shipped/backordered quantities, then
  create. Check order/order-line UUIDs and requiredQuantity in the payload.
- [ ] Start a PENDING picklist. Record zero and partial quantities, choose an
  actual batch, and verify `{lines: [{lineId, pickedQuantity, batchId, notes}]}`.
  Close a nested batch dialog with Escape; the quantity form must remain open.
- [ ] Complete a partially picked list only after the shortage warning. Verify
  COMPLETED does not falsely show dispatch or change stock. Check cancellation
  permissions and failed action messages.
- [ ] Shortbook: compare currentStock, backordered, and suggestOrderQty against
  the response. Select several suggestions, real supplier/warehouse, and draft
  a PO. Verify quantities, purchase rates, and taxGroupId after reload.
- [ ] Missing rates, inactive items, zero/negative quantities, and query errors
  must prevent invalid PO submission. Search failure must not say stock is healthy.
- [ ] Warehouses: create, edit addresses, change the default, and reload. A
  default must stay active. Check default/stock-bearing removal errors and roles.
- [ ] Zones: create/edit/remove with confirmation; code stays immutable and
  current utilisation is read-only. Clearing a saved capacity explains the API
  limitation instead of silently keeping the old value.
- [ ] Transfers: select two active warehouses, batch-tracked and plain items;
  require actual source batches and use separate lines for separate batches.
  Changing source must clear batch selections. Dispatch/receive/cancel must
  reconcile item balances, batch balances, source cost, and stock movements.
- [ ] Counts: plain inventory items accept zero physical quantity. Batch-tracked
  items are blocked with the exact contract limitation. Post/cancel require
  OWNER/ADMIN/ACCOUNTANT. Do not aggregate quantities from different units.
- [ ] After a stock action, revisit stock summary, item balances/movements,
  batch watch, trace and Shortbook; data must refetch rather than remain stale.
- [ ] Trace: select an item and batch by name, including inactive/exhausted
  historical batches. Verify the actual UUID is used; direct UUID links still work.
- [ ] Consignment: receive supplier-owned goods into the separate register,
  record a partial sale, and compare quantity and DRAFT settlement. Confirm the
  settlement UUID is posted when marking settled, never the stock UUID.
- [ ] Confirm consignment actions do not claim to create warehouse stock,
  supplier bills, sales invoices, payments, or journals. Manage those separately.
- [ ] Barcodes: load an item, choose dimensions/DPI/copies, generate, and inspect
  actual ZPL/EPL. Editing input must hide old output. Test invalid EAN13 check
  digits and printer-command text. Certify a real printer and scanner separately.
- [ ] All dialogs: keyboard-only use, search beyond the first result set,
  bounded scrolling, laptop/mobile widths, pending controls, API failures,
  stale searches, repeat submissions, role switching, and tenant isolation.

## Storage, Audit and Import Acceptance

Implemented source is not a passing test result. Use fresh disposable records.

- [ ] Inventory > Rack locations (`/inventory/rack-locations`): explicitly
  choose the warehouse, create a unique code and optional location labels,
  reload, search and page through more than 25 records. The Pharmacy > Racks
  tab must show the same shared workflow. No edit/delete action should appear.
- [ ] Change warehouses in a rack picker: only active racks from the selected
  warehouse appear. Fetch failures must show Retry, not an empty successful list.
- [ ] Inventory > Putaway tasks (`/inventory/putaway-tasks`): create standalone
  placement lines with positive quantities and optional suggested rack IDs.
  Changing warehouse clears previous rack selections.
- [ ] Open a RECEIVED GRN and choose Create putaway task. Confirm the actual
  receipt ID, warehouse, item IDs, quantities and batch numbers are preserved;
  unreceived receipts must not create placement tasks. The copied warehouse and
  batch reference are locked; quantities cannot exceed that source line.
- [ ] Confirm a pending putaway line with a same-warehouse active rack, reload,
  and check actual status. Complete all lines and verify COMPLETED. Cancel an
  open task only after confirming that earlier placements are not undone.
- [ ] Confirming a rack does not move stock or assign quantities to a bin.
  The backend only fills the item's default rack if it was empty; an existing
  default is not overwritten. Repeated GRN task creation has no cumulative
  quantity guarantee. Test with awareness of this limit, not as a receipt lock.
- [ ] UoM: create a PACKAGING unit, edit metadata, persist false base/active
  values, then confirm removal on a disposable unreferenced unit. Check all
  five actual categories and the read-only OPERATOR/VIEWER path.
- [ ] Inventory > Serial numbers (`/inventory/serial-numbers`): choose an item,
  review more than 25 serials, switch to availability and filter warehouse.
  Browser back/item changes reset paging. Preserve receipt/invoice *line* IDs
  as references rather than inventing document links. No mutation action exists.
- [ ] Item > Stock ledger: review more than 50 movements; inspect recorded
  date/time, quantity direction, cost, warehouse, batch, source and reversal IDs
  in Details. Page-local search must be labelled and cannot imply global totals.
  Failed ledger/balance/batch/packaging requests must not say no records exist.
- [ ] Items > Import items (`/items/import`): download the server CSV template,
  replace its sample row, and preview CSV and XLSX files with unique/duplicate
  SKUs and invalid cells. Preview alone must create no item or stock movement.
- [ ] Select a different file after preview; commit must become unavailable
  until the new file is previewed. Check the actual multipart field is `file`
  with browser-generated boundary and the original file bytes.
- [ ] Confirm import only after reviewing the file, default warehouse and
  stock/accounting effects. Check created/skipped counts and row messages;
  some rows can succeed while others fail. No IDs are invented for success rows.
- [ ] Test missing default warehouse, missing opening-stock default accounts,
  invalid rack code, duplicate SKU, server failure and network interruption.
  After an unconfirmed response, inspect the item directory and preview again;
  the UI must not automatically replay the write.
- [ ] Reconcile imported positive opening quantities and values against the
  warehouse stock ledger and existing opening-stock journals. Review item,
  batch, valuation and accounting screens after cache invalidation.
- [ ] Tax Groups (`/tax-groups`): only active groups are advertised; search and
  page through large results, open component details, and retry failures.
  OPERATOR must not query the endpoint; VIEWER can review but cannot maintain it.
  Component sums are reference information, not transaction tax calculations.

## Remaining Parity and Contract Limits

- [ ] Rack edit/delete has no existing controller contract. Putaway has no
  rack-quantity ledger, task edit/reassign/skip, or cumulative GRN allocation.
  The backend confirm path does not reject terminal task status and cancel is
  unconditional. React checks open status and re-reads before actions, but this
  is NOT a concurrency or authorization fix. Separate backend work is required.
- [ ] Serial writes remain blocked for independent integration review. Item
  read DTOs do not expose the serial-tracking flag; register receive/sale/damage/
  return actions do not reconcile inventory or GL. Sale assignment does not
  enforce the supplied warehouse; returned serials become RETURNED, not IN_STOCK.
- [ ] Manual batch adjustments have no batchId in StockAdjustmentRequest.
  ADJUSTMENT bypasses the batch-required guard, so a batch item can change only
  aggregate stock. No such action is exposed in React. The generic reversal
  endpoint also cannot safely replace reversal of a business document and GL;
  double-reversal concurrency remains a backend review item.
- [ ] Packaging barcode writes remain read-only after source review: update
  has no duplicate check, V57 has only non-unique indexes, and hierarchy resolution
  precedes the base-item barcode without cross-table collision validation.
  The current API can therefore map an ambiguous scan to the wrong item. No
  frontend delete/recreate or check-before-write workaround is implemented.
- [ ] Controlled warehouse-scoped expiry returns remain separate work; a
  multi-line controller loop does not provide an all-lines transaction guarantee.
- [ ] UoM conversion ratios have no controller contract. Removing metadata does
  not remap existing item references or rewrite historical units/quantities.
- [ ] TaxGroupController only exposes active-list and detail GET operations.
  Create/update/delete and inactive-list browsing need a separately authorized
  API change. The React directory does not claim these remain available in Flutter.
- [ ] Item import preview is not complete validation or a reservation. It omits
  batch/rack/brand and other source columns from the response, and some validations
  occur only while committing. It does not apply the full ItemService write path;
  negative numeric values and allowed item-type validation need a separate backend
  review. React rejects invalid numeric values visible in the preview, unsupported
  types and service opening stock even if marked OK; this is not a substitute for
  server validation of hidden columns. Inline editing/rebuilding failed rows is intentionally not implemented,
  because the result DTO omits source columns needed to recreate the original file.
- [ ] Batch-aware stock counts need a separately authorized contract change:
  StockCountService posts STOCK_COUNT without batchId, but InventoryService
  rejects a batch-tracked STOCK_COUNT movement without it. No Java fix is made here.
- [ ] Consignment is not an integrated procure-to-pay/VMI workflow. The existing
  service uses its own register and status records, not inventory or GL services.
  Concurrency and cross-master validation require a separate backend audit.
- [ ] Zone capacity cannot be cleared through UPDATE. Zone deletion does not
  perform stock relocation or dependent putaway reconciliation.
- [ ] Transfers receive all shipped lines; no partial-receipt contract exists.
- [ ] Label API supplies printer code only. EPL uses a fixed barcode format;
  it does not mirror every ZPL option. A4 and printer/scanner acceptance are not done.
- [ ] Price-list/tier UPDATE limitations and prior pricing/FEFO acceptance remain
  documented in `REACT_INVENTORY_PRICING_ACCEPTANCE.md`.

## Deferred Automated Checks

From `react_app`, run the existing type-check, lint, test, and build scripts before
merging. Newly added/updated regression sources cover API payloads, permissions,
picklist lifecycle, Shortbook drafting/errors, warehouse/zone defaults and limits,
transfer batches, stock-count restrictions/zero counts, consignment settlement IDs,
label output, historical batch selection, shared picker failures, nested dialogs,
and inventory cache invalidation. Further source covers rack scoping, putaway
receipt/confirmation/cancellation, UoM metadata, serial paging, stock-ledger audit,
multipart import preview/commit/partial outcomes, CSV downloads, and API errors.
They have NOT been executed in this review.
