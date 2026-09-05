# React Partner, Supply Planning and Portal Administration

Date: 2026-09-05. Status: BUILDING, source implemented for the scope below.
This document is not a claim of full migration, full coverage or live acceptance.
Java, migrations, backend tests and Flutter are frozen and unchanged.

## Implemented Routes and Roles

| Menu / Route | Existing controller roles | Implemented scope |
|---|---|---|
| Partner Network / `/partner-network/partners` | OWNER, ADMIN, OPERATOR | Relationship list/detail, incoming approval, reject, suspend |
| Partner Network / `/partner-network/catalog` | OWNER, ADMIN, OPERATOR | Catalog metadata publish/edit/unpublish; hidden drug reference retained |
| Partner Network / `/partner-network/supplier-search` | OWNER, ADMIN, OPERATOR | Server search of approved seller catalogs; supplier names |
| Partner Network / `/partner-network/incoming`, `/partner-network/outgoing`, `/partner-network/orders/:orderId` | OWNER, ADMIN, OPERATOR | Order history/lines/events, buyer cancel/delivery, seller reject/dispatch; own-party document links |
| Supply Planning / `/supply-chain` | OWNER, ADMIN, ACCOUNTANT, OPERATOR | Actual planning counts; no misleading FIFO valuation claim |
| Supply Planning / `/supply-chain/requisitions`, `/:requisitionId` | OWNER, ADMIN, ACCOUNTANT; approve/reject OWNER/ADMIN only | Server paging/status, named multi-line draft, low-stock draft, submit/approve/reject |
| Supply Planning / `/supply-chain/shipments`, `/:shipmentId` | Read: OWNER, ADMIN, ACCOUNTANT, OPERATOR; write: first three only | Tracking directory/create/detail/dispatch/deliver/cancel |
| Supply Planning / `/supply-chain/alerts` | OWNER, ADMIN, ACCOUNTANT | Server paging/status, explicit scan/resolve confirmation |
| Supply Planning / `/supply-chain/forecasts` | OWNER, ADMIN, ACCOUNTANT | Date-range read and organisation-wide moving/seasonal/weighted generation |
| Supply Planning / `/supply-chain/reorder-policies` | OWNER, ADMIN, ACCOUNTANT | ABC classification and named item/warehouse reorder calculation |
| Supply Planning / `/supply-chain/item-suppliers` | OWNER, ADMIN, ACCOUNTANT | Selectable supplier projection mapping, numeric validation, preferred/remove actions |
| Supply Planning / `/supply-chain/returns`, `/supply-chain/supplier-performance` | OWNER, ADMIN, ACCOUNTANT | Read-only request register and persisted score history |
| Settings / `/settings/portal-users` | OWNER, ADMIN | List/invite/regenerate/suspend/reactivate/remove external accounts |

These role guards reflect the existing controllers. A platform role's general
navigation bypass does not grant it access to endpoints which omit that role.
Module enforcement remains server-side. No entitlement bypass was introduced.

## Contract Boundaries

1. **Partner discovery:** new relationship requests need a target organisation
   UUID, but PartnerNetworkController has no authorised organisation-discovery
   endpoint. React does not substitute arbitrary UUID entry or platform access.
2. **Network order integrity:** PartnerNetworkService.placeOrder accepts catalog
   and item references without verifying their seller/buyer ownership. Confirmation
   does not bound confirmed quantities to ordered quantities or validate item
   ownership. Placement/confirmation are not exposed in this continuation.
3. **Document linking:** linkBuyerPo/linkSellerSo check participation but do not
   validate the referenced document's tenant or the correct buyer/seller side.
   No linking mutation is offered. Existing links render only for the matching
   current party; target documents still rely on their normal backend enforcement.
4. **Tracking versus execution:** network and supply shipment dispatch/delivery
   change statuses only. ShipmentService has no inventory or journal integration.
   Screens and confirmations explicitly say they do not move stock or post GL.
5. **Returns:** SupplyChainService.processReturn sets PROCESSED without stock,
   credit note or payment integration. The read-only register does not offer a
   fake process/refund action. Recorded refund figures are not receipts/payments.
6. **Supplier scores:** calculateSupplierPerformance queries
   `purchase_order_line`, while the purchase entity uses `purchase_order_lines`.
   Its GRN query references `stock_receipt_id`, `received_qty` and `unit_cost`,
   while StockReceiptLine maps `receipt_id`, `quantity`, `unit_price` and
   `landed_unit_cost`. It also sets overallScore from qualityRate only, not
   delivery timeliness. Recalculation is withheld; persisted scores remain readable.
7. **Planning numbers:** lowStockCount counts warehouse balance rows, not unique
   items. Supply dashboard valuation uses averageCost and is not a FIFO valuation;
   React omits that financial metric and directs users to inventory valuation.
8. **Requisitions:** approve does not create a PO, and no conversion action is
   available on this controller. Auto creation can return null; React reports no
   eligible items instead of claiming creation. Repeat scans are not idempotent.
9. **Portal:** invitations return a one-time token, not verified email delivery.
   Tokens stay only in mounted component state, masked by default, and are not
   returned as mutation-cache data or stored in browser storage. Close/tenant/user
   change clears the dialog; late old-organisation results are ignored. The
   existing API tracing redacts token fields. Clipboard copying is explicit.
10. **Portal authentication remains separate:** external users use a dedicated
    memory-only portal token and no ERP cookie, access token or organisation
    header. Invite acceptance, login, customer documents/statements/catalog/order
    history and vendor bills are implemented. Vendor purchase orders are withheld:
    the service passes a contact id to a repository lookup that expects a Supplier
    projection id. The API also omits organisation currency, so portal amounts do
    not invent an INR symbol. Suspended accounts without accepted invites cannot
    reactivate; the server error stays visible.

Backend fixes require a separate authorised task. Existing backend validation
gaps are not repaired by React-only input checks. Catalog/item-supplier/shipment
writes select references through named current-organisation pickers, but this
does not certify server-side ownership or concurrent-write safety.

## Validation

- Focused suite: **90 tests passed across six files** including navigation.
- ESLint: passed, zero warnings.
- Full React suite: **469 tests passed across 104 files**, zero failures, exit 0,
  with `node node_modules/vitest/vitest.mjs run --maxWorkers=2` (160.90 seconds).
  This includes the earlier 357-test baseline and 82 additional regression tests.
- `npm run build`: passed, including `tsc --noEmit`. Vite emitted separate lazy
  chunks for the new workspaces. The existing main bundle remains about 2.16 MB
  minified and still produces the 500 kB chunk warning; it is not hidden.
- `git diff --check`: passed. Protected-path diff for `src`, `flutter_app` and
  `pom.xml` is empty. Current changes remain React and documentation only.
- The first sandboxed test launch failed to start Vite workers (EPERM/native
  dependency load). Validation was rerun successfully with worker permissions;
  no dependency versions, global timeouts or test assertions were weakened.
- No dev server, browser application, real transaction, Java test or Flutter test
  was run. Responsive appearance and business acceptance remain manual.
- Shared density tokens: `--control-h: 34px`, `--row-h: 36px`, compact 32px.
  Shared primitives only; no feature-specific CSS or new visual token palette.
- API request tests use the actual apiFetch encoder/envelope and mocked fetch.
  UI tests cover permissions, paging, errors, invalid quantities, duplicate items,
  role-specific actions, confirmation, organisation switches and token lifecycle.
- No 100% code-coverage claim is made.

## Manual Acceptance Sequence

Use disposable development organisations and known records. Compare with Flutter
and the backend response. Do not infer stock/GL execution from tracking badges.

| Page / Scenario | Expected result | State |
|---|---|---|
| Navigation and command search | Both honour disabled groups and group role gates; direct restricted routes do not fetch records | Pending |
| All new directories with 60+ records | Unpaged API results render 25 rows at a time; search/paging remain bounded; paged APIs fetch the correct server page | Pending |
| Partnership requested by current organisation | No self-approval action; incoming request can be reviewed and confirmed by the other party | Pending |
| Published catalog edit | Preserve SKU/HSN/manufacturer/drug reference/availability; invalid numeric values block publish; inactive edit clearly republishes | Pending |
| Supplier catalog search | Find a product beyond the initially returned list through server search; no unsafe Place Order action | Pending |
| Incoming/outgoing order detail | Correct quantities/events/party names; buyer cannot execute seller actions; foreign-side PO/SO links absent | Pending |
| Network tracking | Confirm action, refresh state/activity; verify stock and GL unchanged, as disclosed | Pending |
| New requisition | Named item/supplier/warehouse selection; multiple unique lines; blank/zero quantity blocked; server total after save | Pending |
| Requisition approval | Accountant can submit but cannot approve/reject; Owner/Admin sees eligible actions only | Pending |
| Automatic requisition | Cancel causes no request; no eligible stock produces notice; existing draft warning shown before repeated scan | Pending |
| Shipment creation/tracking | Transfer needs distinct warehouses; correct quantities/packages; Operator read-only; delivered/cancelled terminal controls absent | Pending |
| Alerts | Status paging correct; scan confirmation warns about duplicate signals; resolution refetches list | Pending |
| Forecasts | Invalid date range blocked; method-specific generation values; whole-organisation scope disclosed before confirmation | Pending |
| ABC/reorder | Classification is org-wide; item/warehouse selection names visible; results are planning values, not POs | Pending |
| Supplier mappings | Search/select actual supplier projections; integer lead days/positive MOQ; preferred/remove require confirmation | Pending |
| Returns/scores | Existing records visible; no fake refund, stock processing or live delivery score | Pending |
| Portal invite | Named contact/email; no email-sent claim; securely deliver token to intended test contact via existing portal flow | Pending |
| Portal actions | Confirm suspend/remove; existing external sessions are invalidated by backend; unaccepted reactivation errors remain visible | Pending |
| Portal token lifecycle | Reveal/copy only on request; close and organisation/user switch clear token; no local/session storage or query-cache token | Pending |
| Tenant switch during slow create | Draft disappears; late previous-organisation result cannot navigate to an old-tenant record or display invite token | Pending |
| Responsive/keyboard | Shared modals scroll; labels and focus work; table overflow contained; no large checkbox list runs off screen | Pending |

## Still Open

Shipment ETA/weight and operational turnover source plus the external portal
journeys are implemented. Shipment document references, vendor portal POs,
currency metadata, broader platform/onboarding, full role/tenant runtime testing
and all frozen-contract blockers above remain open. This is not completion of
the complete ERP migration. Current source is uncommitted until the user requests
the next Git checkpoint.
