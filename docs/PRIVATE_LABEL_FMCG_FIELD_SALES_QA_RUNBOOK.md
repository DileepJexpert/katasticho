# Private-Label FMCG Distributor and Field Sales QA Runbook

**Product scope:** Moong/Urad Dal Badi, Five-Dal Family Mix, Maize Dalia/Makka Atta, Sugarcane/Jamun Vinegar, Plain Sattu, and Besan

**Purpose:** Repeatable manual regression test for a private-label FMCG brand that buys finished goods from different manufacturers, stores them, distributes them to retailers/wholesalers, and uses field salespeople for daily market visits.

**Run policy:** Execute this runbook after every backend or Flutter bug fix. Record the date, build/branch, tester, and result. Do not mark a section passed until the expected stock, accounting, permissions, and audit results are verified.

## 1. Business Model Under Test

The organisation is a **Distributor + FMCG Distributor**. It owns the brand and customer relationships but does not operate its own manufacturing plant.

The primary supported flow is:

`External manufacturer -> Purchase Order -> Goods Receipt -> Supplier Bill -> Warehouse -> Field/Sales Order -> Dispatch -> Sales Invoice -> Collection`

Each manufacturer is maintained as a supplier contact. Retailers and wholesalers are customer contacts. They do not need ERP or field-app logins for this test.

Do not use Manufacturing -> Job Work for the primary test. The current job-work flow sends and receives material lines; it does not yet model conversion of raw materials into a different finished product. That limitation is recorded in Section 15.

## 2. Required Test Logins

All demo users use password `Demo@1234`.

| User | Phone | Role | Application | Responsibility |
|---|---:|---|---|---|
| Demo Owner | 9000000001 | OWNER | ERP | Organisation, settings, approvals, audit |
| Demo Admin | 9000000002 | ADMIN | ERP | Suppliers, products, routes, sales supervision |
| Demo Accountant | 9000000003 | ACCOUNTANT | ERP | Bills, vendor payments, customer receipts, reports |
| Demo Salesman 1 | 9000000005 | OPERATOR | Field app | Primary daily route and customer visits |
| Demo Salesman 2 | 9000000008 | OPERATOR | Field app | Second territory and ownership/security tests |
| Demo Viewer | 9000000007 | VIEWER | ERP | Read-only reporting check |

The field app does not use a separate salesperson role. A user becomes a salesperson because an ADMIN assigns that OPERATOR to a route and effective date. A warehouse/storekeeper role is not separate in the current role model; do not treat that as a completed permission boundary.

## 3. Product and Supplier Test Data

Create the following products as finished branded goods:

| Product | Test classification | Suggested source | Required checks |
|---|---|---|---|
| Moong/Urad Dal Badi | Hero | Badi Manufacturer | Batch, expiry, pack and selling price |
| Five-Dal Family Mix | Hero | Dal Mix Manufacturer | Batch, pack conversion, margin |
| Maize Dalia/Makka Atta | Second-stage | Grain Manufacturer | Weight unit, partial receipt |
| Sugarcane/Jamun Vinegar | Niche, outsource only | Vinegar Manufacturer | Bottle unit, batch/expiry, GST |
| Plain Sattu | Supporting | Grain Manufacturer | KG/GM selling unit |
| Besan | Supporting | Besan Manufacturer | KG/GM selling unit, landed cost |

Create at least three suppliers: `Badi Foods`, `Grain Foods`, and `Vinegar Foods`. Use different GSTIN/state/payment terms where possible so tax and payable behaviour is meaningful.

For every item verify SKU, barcode if available, HSN, GST rate, brand, description, inventory tracking, purchase unit, selling unit, conversion factor, purchase price, sale price, reorder level, preferred supplier, and batch/expiry settings.

Recommended unit examples:

- Badi: purchase `BOX` or `PACK`, sell `PCS` or `PACK`.
- Dal mix: purchase `BAG`, sell `KG` or sealed `PACK`.
- Besan and Sattu: purchase `BAG`, sell `KG` and `GM` through conversion.
- Vinegar: purchase `CASE`, sell `BOTTLE`.

## 4. Customer, Route, and Field Data

Create at least six customer contacts:

| Customer | Payment test | Route |
|---|---|---|
| Shree Kirana Store | Cash | Main Market |
| Maa General Store | Credit, 15 days | Main Market |
| Om Wholesale Mart | Credit, 30 days | Wholesale Market |
| New Bharat Retail | Prepaid/advance test | Main Market |
| Radha Provision Store | Partial collection | Wholesale Market |
| Unassigned Test Shop | Must not be visible to assigned seller | No route |

Store valid latitude/longitude for at least two shops. Keep one shop without coordinates to verify the non-blocking GPS behaviour.

Create:

1. Beat `MAIN-MARKET` with three retailers in visit sequence.
2. Beat `WHOLESALE-MARKET` with two retailers in visit sequence.
3. Route `MONDAY-MARKET` containing Main Market.
4. Route `TUESDAY-WHOLESALE` containing Wholesale Market.
5. Assign Salesman 1 to Monday-Market.
6. Assign Salesman 2 to Tuesday-Wholesale.
7. Optionally create a van and assign one van per seller for van stock tests.

## 5. Test Environment Readiness

Before every run:

1. Start the backend from `C:\dileepkm\Learning\katasticho`.
2. Confirm the application connects to the intended PostgreSQL database.
3. Confirm the organisation is `Demo Distributor` with business type `DISTRIBUTOR` and industry code `FMCG_DISTRIBUTOR`.
4. Start the ERP Flutter app and confirm login works.
5. Start the field app separately and confirm it points to the same backend.
6. Allow browser location permission for the field app.
7. Confirm one default branch, warehouse, and chart of accounts exist.
8. Record current stock, supplier outstanding, customer outstanding, and cash/bank balances before testing.
9. Clear only test data that is explicitly part of the reset plan. Do not reset production-like data casually.

## 6. Organisation and Permission Smoke Test

### Owner/Admin

1. Login as Owner and open Settings -> Business Configuration.
2. Verify Distributor and FMCG Distributor values.
3. Verify modules for Inventory, Distribution, Field Sales, Accounting, Purchases, Sales, and Reports.
4. Login as Admin and verify supplier, item, beat, route, assignment, and sales screens are available.

### Accountant

1. Login as Accountant.
2. Verify bills, vendor payments, customer receipts, accounting, and reports are available.
3. Verify organisation configuration and field assignment administration are not available unless explicitly granted.

### Viewer

1. Login as Viewer.
2. Verify read-only pages open.
3. Attempt to create, edit, post, approve, receive stock, dispatch, and record payment.
4. Expected: every write action is blocked by UI and backend authorization.

## 7. Procurement and Inventory Test

### 7.1 Supplier and purchase order

1. Login as Admin.
2. Open Purchases -> Suppliers and verify the three manufacturers.
3. Create one purchase order per manufacturer.
4. Put different products and quantities on each PO.
5. Use one full receipt, one partial receipt, and one purchase with a different actual cost.
6. Confirm or send each PO.

Expected: PO status and pending quantities are correct, supplier is retained, and no stock is added merely by creating or confirming a PO.

### 7.2 Goods receipt

1. Open the PO and create a Goods Receipt.
2. Enter actual quantities, warehouse, batch, expiry, manufacturing date, rack/bin, and landed charges where applicable.
3. Save the receipt as draft.
4. Verify draft receipt does not increase stock.
5. Receive stock once.
6. Reopen the receipt and try to receive it again.

Expected:

- First receipt increases stock by actual quantity only.
- Second receive attempt does not duplicate stock.
- Partial receipt leaves the remaining PO quantity open.
- Batch and expiry are visible on item detail and stock summary.
- Received/landed cost is used for valuation.
- Supplier is attached to the batch where batch tracking is enabled.

### 7.3 Supplier bill and payment

1. Login as Accountant.
2. Create a supplier bill linked to the PO/receipt.
3. Run 3-way match where available.
4. Post the bill.
5. Verify inventory is not double-counted when a received GRN is linked.
6. Record full payment for one supplier.
7. Record partial payment for another supplier.

Expected accounting:

- Purchase bill: debit inventory/input GST and credit supplier payable.
- Vendor payment: debit supplier payable and credit bank/cash.
- Supplier ageing reflects the unpaid balance.
- Voiding a bill reverses the correct journal and stock movement where allowed.

## 8. Sales Order, Dispatch, and Customer Accounting Test

### 8.1 Cash sale

1. Login as Admin.
2. Create a Sales Order for Shree Kirana Store.
3. Add Badi and Besan.
4. Confirm the order.
5. Create a Delivery Challan.
6. Dispatch the actual quantity.
7. Create/post the sales invoice.
8. Record customer receipt for the full amount.

Expected: stock decreases once, sales invoice posts GST and revenue, COGS is recorded, and customer outstanding returns to zero.

### 8.2 Credit sale

1. Create and dispatch an order for Maa General Store.
2. Post the invoice without collecting money.
3. Verify customer outstanding and ageing.
4. Record a partial collection.
5. Verify remaining balance.
6. Record the final collection.

Expected: AR follows invoice amount, partial collection reduces balance correctly, and final collection closes the invoice.

### 8.3 Wholesale and mixed-manufacturer order

1. Create an order for Om Wholesale Mart containing products supplied by all three manufacturers.
2. Verify customer pricing, discount, GST, and quantity.
3. Dispatch partially.
4. Invoice only the dispatched quantity if the flow supports partial invoicing.
5. Verify remaining backorder quantity.

### 8.4 Credit controls

1. Set a low credit limit for a customer.
2. Test credit policy WARN.
3. Test credit policy BLOCK.
4. Test overdue customer behaviour.
5. If approval is enabled, verify `PENDING_APPROVAL`, approve, reject, and audit history.

## 9. Field App Daily Seller Trip

### 9.1 Route preparation in ERP

1. Login as Admin.
2. Create or select today’s route execution for Salesman 1.
3. Confirm route date, route, salesperson, and optional van.
4. Start the execution only when ready for the field trip.

### 9.2 Seller login and route start

1. Login to the field app as `9000000005` / `Demo@1234`.
2. Confirm header shows `Demo Salesman · OPERATOR`.
3. Open Today and refresh.
4. Confirm only the assigned route and visits are visible.
5. Start the route.
6. Confirm the execution becomes `IN_PROGRESS`.

### 9.3 Customer visit

For each assigned retailer:

1. Open Visits.
2. Open the retailer visit.
3. Check in and allow location access.
4. Verify GPS status and distance when coordinates exist.
5. Record an order for one or more products.
6. Record cash, credit, or collection information as applicable.
7. Add visit notes.
8. Check out.

Expected: visit status, timestamps, salesperson ownership, GPS verification, order value, and collection value are saved against the correct route execution and customer.

### 9.4 Tracking the seller

While the route is `IN_PROGRESS`, the field app sends foreground location pings approximately every few minutes. In ERP:

1. Login as Admin in another browser session.
2. Open Field Sales -> Live Tracking.
3. Verify Salesman 1 appears with latest ping time.
4. Open the route trail.
5. Verify ping count and travelled distance.
6. Wait long enough to verify stale-location highlighting.
7. Check in at a customer with coordinates and verify geo distance.
8. Check in at the customer without coordinates and verify the visit is not incorrectly blocked.

Expected: location tracking is tied to the logged-in salesperson and current execution. It must not show Salesman 1 as Salesman 2 or attach pings to another organisation.

### 9.5 Expenses, collection, and day close

1. In the field app open Expense and add travel/fuel/food expense.
2. Open Collect and record money collected from a credit customer.
3. Complete all planned visits.
4. Complete the route.
5. Open Day Close.
6. Enter opening cash, collections, expenses, closing cash, deposited cash, and note.
7. Submit day close.
8. Login as Admin and approve or reject it according to the workflow.
9. Open Daily Report/DCR and submit the field-work report.

Expected: cash reconciliation equals opening cash plus collections minus expenses; day close status follows the approval lifecycle; expenses and collections appear in ERP reports.

## 10. Two-Salesperson Ownership Test

1. Assign Salesman 1 to Monday-Market.
2. Assign Salesman 2 to Tuesday-Wholesale.
3. Start both executions on separate dates or controlled test executions.
4. Login to the field app as Salesman 1.
5. Try to open, check in, order, collect, or close Salesman 2’s visit.
6. Repeat from Salesman 2’s login.
7. In ERP, verify Admin can see both routes and trails.

Expected: field users can operate only their assigned execution and visits. Admin/Owner can supervise both. No user can change the salesperson owner from the field app.

## 11. Van Stock Test, If Van Selling Is Used

1. Create a van in ERP.
2. Load Badi, Besan, and Sattu from warehouse to Salesman 1’s van.
3. Verify warehouse stock decreases and van stock increases.
4. Sell from the van during a field visit.
5. Verify van stock decreases and the sale is linked to the visit.
6. Return unsold stock at day close.
7. Verify van stock returns to zero or the expected balance.

Expected: warehouse, van, field sale, and return quantities reconcile without negative stock or duplicate movements.

## 12. Required Negative and Recovery Tests

Run these after the happy path:

1. Login with an invalid password.
2. Stop and restart the backend during a field-app request.
3. Disable network temporarily and sync the field app later.
4. Submit the same visit/order/collection twice.
5. Refresh the browser during a draft form.
6. Dispatch more stock than available.
7. Receive more than ordered.
8. Sell an expired or unavailable batch.
9. Post the same bill twice.
10. Attempt to void a bill with payments.
11. Complete a route with missing visits.
12. Submit day close with a cash variance.
13. Change a route assignment after an execution has started.
14. Use a customer from another organisation ID.

Expected: the system rejects invalid operations with a clear message, does not partially post stock or accounting, and does not create duplicate rows after retry.

## 13. Reconciliation Checklist

At the end of every complete run, compare:

- Opening stock + receipts + adjustments - dispatches - sales = closing stock.
- Supplier bills - vendor payments = supplier outstanding.
- Sales invoices - customer receipts = customer outstanding.
- Route opening cash + collections - expenses = expected closing cash.
- Warehouse stock + van stock = total owned stock.
- Sales quantity by product = item movement quantity by product.
- GST in purchase bills and sales invoices = tax report totals.
- Revenue - COGS - approved expenses = expected gross contribution before other overheads.
- Every posted journal has one business reference and no duplicate reference posting.

## 14. Regression Result Sheet

Copy this block for every release or bug-fix cycle.

| Field | Value |
|---|---|
| Test date | |
| Backend branch/commit | |
| Flutter branch/commit | |
| Database reset or reused | |
| Backend startup profile | |
| ERP tester | |
| Field-app tester | |
| Sections passed | |
| Sections failed | |
| Defect IDs | |
| Retest date | |
| Final sign-off | |

For every failed case record: precondition, exact steps, expected result, actual result, API status/error, screenshot/log, user/org, and whether stock or accounting was affected.

## 15. Known Boundary: Outsourced Production

This runbook intentionally tests manufacturers supplying finished goods. If the business supplies raw dal, spices, bottles, labels, or packaging to an external processor, the ERP needs a dedicated outsourced-production flow before that process can be accepted.

The future flow should support:

1. Product recipe/BOM and version.
2. Sourcing mode per item: BUY, MAKE, OUTSOURCE, or MIXED.
3. External manufacturer and contract/rate.
4. Material issue to vendor or vendor-supplied components.
5. Finished-goods receipt with batch, expiry, yield, wastage, and QC.
6. Processing charges and landed cost roll-up.
7. Vendor bill and 3-way match.
8. Stock at vendor, stock in transit, and owned stock reconciliation.
9. Traceability from finished batch to raw-material and vendor records.

Until that feature exists, do not represent outsourced conversion by manually adjusting stock; use a normal purchase of the finished product and record the manufacturer as the supplier.

## 16. Exit Criteria

The private-label FMCG flow is ready for broader pilot testing only when:

- All six products can be received, valued, sold, and reported.
- At least three suppliers and six customers are reconciled correctly.
- Cash, credit, prepaid/advance, partial collection, and overdue cases are understood.
- Two field sellers can complete separate routes without cross-access.
- Live tracking, GPS visit data, expenses, collections, DCR, and day close are visible in ERP.
- No duplicate stock or journal is created after refresh, retry, or repeated clicks.
- Viewer and field-user permissions are enforced by the backend, not only hidden in Flutter.
- All failures have a defect ID and a repeatable retest result.
