# Distributor Manual QA Checklist

Use this checklist before adding new distributor features. The goal is to prove that stock, batch, invoice, and accounting movements are correct through the existing Purchase Order, Goods Receipt, Sales Order, Delivery Challan, Sales Invoice, Payment, and Approval flows.

## Test Setup

1. Start backend with the `dev` profile.
2. Start Flutter web with:
   ```powershell
   flutter run -d chrome --dart-define=ENV=dev
   ```
3. Sign up or log in as a pharma distributor organisation.
4. Confirm Settings shows:
   - Primary business: Distributor or Pharma Distributor.
   - Modules include Sales, Purchases, Inventory, Accounting, Reports, Batch & Expiry, and Pharma.
5. Create or confirm one warehouse exists.
6. Create or confirm one rack exists, for example:
   - Zone: `A`
   - Rack: `A1`
   - Shelf: `S1`
   - Bin: `B1`
   - Display code: `A1-S1-B1`
7. Create one supplier and one customer.
8. Create or use one batch-tracked pharma item with:
   - SKU
   - HSN
   - GST rate
   - Track inventory enabled
   - Track batches enabled
   - Reorder level greater than zero

## 1. Item Master And Opening Stock

### Normal Case

1. Open Inventory -> Items.
2. Create a new stockable item with opening stock greater than zero.
3. Open item detail.
4. Verify:
   - Item is visible in item list.
   - On-hand stock reflects opening stock.
   - Batch section appears if batch tracking is enabled.
   - Rack is visible if assigned.
5. Open Inventory -> Stock Summary.
6. Verify:
   - Item appears even if stock is zero.
   - On-hand quantity matches item detail.
   - Reorder level and shortage status are correct.

### Corner Cases

1. Create item with opening stock `0`.
   - Expected: item is created, no stock movement is created, item still appears in stock summary as zero stock.
2. Create item with batch tracking enabled but no batch stock.
   - Expected: item is valid, but sale/dispatch should require stock batch later.
3. Create non-inventory service item.
   - Expected: it should not appear as stock shortage and should not create stock movement.

## 2. Shortage To Purchase Order

### Normal Case

1. Open Inventory -> Shortage.
2. Select one low-stock item.
3. Click create Purchase Order from shortage.
4. Verify Purchase Order draft opens with:
   - Supplier selected or selectable.
   - Item prefilled.
   - Quantity based on shortage/reorder quantity.
   - Price editable.
5. Save Purchase Order.
6. Send or confirm Purchase Order if the screen supports it.

### Corner Cases

1. Item has no preferred supplier.
   - Expected: user can select supplier manually before saving.
2. Purchase price is blank.
   - Expected: PO can be created only if business validation allows it, but GRN must still allow actual received cost entry.
3. Shortage item already has an open PO.
   - Expected: verify system does not create confusing duplicate demand without user intent.

## 3. Purchase Order To Goods Receipt

### Normal Case

1. Open the Purchase Order detail.
2. Verify the button says `Create Goods Receipt`, not `Receive Stock`.
3. Click `Create Goods Receipt`.
4. Verify Goods Receipt create screen opens with:
   - Supplier copied from PO.
   - PO items copied.
   - Pending quantity copied.
   - Expected unit price copied if present.
5. Change actual received quantity if needed.
6. Enter:
   - Batch number
   - Expiry date
   - Manufacturing date if available
   - Rack/bin
   - Actual purchase cost
7. Save as draft.
8. Verify no stock is added yet.

### Corner Cases

1. Supplier delivers less than ordered.
   - Example: ordered `100`, received `80`.
   - Expected: GRN receives `80`; PO remains pending for `20`.
2. Supplier delivers more than ordered.
   - Expected: system should either block or clearly allow over-receipt according to current validation. Record observed behavior.
3. Batch number missing for batch-tracked item.
   - Expected: Receive Stock must fail with batch-required validation.
4. Expiry date missing for pharma batch item.
   - Expected: Receive Stock should block if expiry is mandatory.
5. Received cost differs from PO price.
   - Expected: stock valuation should use received cost, not silently keep zero price.

## 4. Goods Receipt Receive Stock

### Normal Case

1. Open draft Goods Receipt detail.
2. Click `Receive Stock`.
3. Verify:
   - GRN status changes to received/posted.
   - Stock on hand increases by received quantity.
   - Batch is created or updated.
   - Rack is visible on item/POS/search surfaces.
   - Purchase cost is reflected where stock valuation or item cost is shown.
   - PO received quantity updates.
4. Open item detail.
5. Verify batch quantity, expiry, and rack.
6. Open Stock Summary.
7. Verify on-hand quantity and low-stock status.

### Accounting Checks

1. Open accounting ledger or reports.
2. Verify GRN/purchase flow accounting behavior matches current design:
   - If GRN accrues inventory: inventory account increases.
   - If bill-only accounting is used: no unexpected journal should be posted at GRN.
3. Confirm no duplicate journal is created when refreshing or reopening the GRN.

### Corner Cases

1. Click `Receive Stock` twice.
   - Expected: second click should not duplicate stock.
2. Receive two batches for same item.
   - Expected: stock total is sum of batches; batch rows stay separate.
3. Receive expired batch.
   - Expected: system should block or clearly mark as expired according to current validation. Record observed behavior.
4. Receive item into different rack.
   - Expected: selected rack appears in item detail and POS search result.

## 5. POS Search And Rack Visibility

### Normal Case

1. Open POS.
2. Search the received item by name, SKU, or barcode.
3. Verify result shows:
   - Name
   - SKU
   - Price/MRP if configured
   - Available quantity
   - Batch/expiry if applicable
   - Rack/bin code
4. Add item to cart.
5. Verify FEFO batch selection if multiple batches exist.

### Corner Cases

1. Search item with zero stock.
   - Expected: item may appear but should clearly show no available stock or should not be selectable, based on current POS design.
2. Search expired batch item.
   - Expected: expired stock should not be silently sold.
3. Search item with no rack.
   - Expected: UI should not crash; rack field can be blank.

## 6. Sales Order Creation

### Normal Case

1. Open Sales -> Sales Orders.
2. Create Sales Order for a customer.
3. Select stocked item.
4. Verify customer/default price list is applied.
5. Save order.
6. Confirm order.
7. Verify:
   - Sales Order status changes as expected.
   - Stock is not deducted at Sales Order confirmation.
   - Accounting is not posted at Sales Order confirmation.

### Corner Cases

1. Order quantity greater than available stock.
   - Expected: Sales Order can create backorder if current configuration allows it; stock must not go negative at SO creation.
2. Customer inactive.
   - Expected: Sales Order creation fails with inactive customer validation.
3. Customer on active sales hold.
   - Expected: Sales Order creation fails with sales-hold validation.
4. Price list changes after Sales Order is saved.
   - Expected: SO-to-invoice conversion preserves booked Sales Order rate.

## 7. Sales Order Credit And Overdue Controls

### Credit WARN

1. Set `sales.credit_policy = WARN`.
2. Create customer with credit limit.
3. Create Sales Order above limit.
4. Expected:
   - Order is allowed.
   - System warning/comment is added.

### Credit BLOCK

1. Set `sales.credit_policy = BLOCK`.
2. Create Sales Order above limit.
3. Expected:
   - Order is rejected with credit-limit error.
   - No stock or accounting movement happens.

### Credit Approval

1. Open Settings -> Workflows.
2. Enable Sales Order Credit Approval.
3. Create Sales Order above limit.
4. Expected:
   - Order moves to `PENDING_APPROVAL`.
   - Approval Inbox shows request.
   - Approve returns order to usable state.
   - Reject prevents confirmation/dispatch.

### Overdue Controls

1. Create or use a customer with one overdue invoice.
2. Test `sales.overdue_policy = WARN`.
   - Expected: SO is created with warning.
3. Test overdue approval workflow.
   - Expected: SO goes to `PENDING_APPROVAL`.
4. Test `sales.overdue_policy = BLOCK`.
   - Expected: SO creation is rejected.

## 8. Sales Order Schemes

### Percent Discount

1. Configure a percent discount scheme.
2. Create Sales Order line that qualifies.
3. Apply scheme manually or set auto mode.
4. Expected:
   - Existing line discount percent is updated.
   - Invoice preserves same discount.
   - Accounting posts net value correctly.

### Buy X Get Y

1. Configure buy/get scheme.
2. Create qualifying Sales Order.
3. Apply scheme.
4. Expected:
   - Explicit zero-rate free line is added.
   - Free line is visible before dispatch/invoice.
   - Delivery Challan deducts stock for paid and free items.
   - Invoice allows zero-rate free line only through SO invoice path.
   - Invoice posting does not post duplicate stock movement.
   - Free goods cost posts to COGS/inventory if current accounting design supports it.

### Corner Cases

1. Reduce paid quantity below scheme threshold.
   - Expected: stale free line is removed or scheme no longer applies.
2. Scheme mode `DISABLED`.
   - Expected: scheme lookup/apply actions are hidden.
3. Multiple applicable schemes.
   - Expected: current policy applies first applicable scheme; record if UI needs clearer selection later.

## 9. Sales Order To Delivery Challan

### Normal Case

1. Open confirmed Sales Order.
2. Verify button says `Create Delivery Challan`.
3. Click it.
4. Verify Delivery Challan create screen opens with:
   - Customer copied.
   - Sales Order lines copied.
   - Dispatch quantities editable.
5. Save as draft.
6. Verify no stock is deducted yet.

### Corner Cases

1. Partial dispatch.
   - Example: order `100`, dispatch `60`.
   - Expected: SO becomes partially shipped; remaining `40` stays pending.
2. Dispatch more than ordered.
   - Expected: system blocks or clearly validates over-dispatch.
3. Dispatch item with no stock.
   - Expected: system blocks or creates controlled backorder, but must not silently make stock wrong.

## 10. Delivery Challan Dispatch

### Normal Case

1. Open draft Delivery Challan detail.
2. Select/confirm batch if required.
3. Click `Dispatch`.
4. Verify:
   - DC status changes to dispatched.
   - Stock decreases once.
   - Batch quantity decreases.
   - SO shipped status updates.
   - No accounting journal is posted at dispatch.

### Corner Cases

1. Click Dispatch twice.
   - Expected: stock is not deducted twice.
2. Multiple batches available.
   - Expected: FEFO/default selection is correct, or manual selected batch is respected.
3. Partial dispatch followed by second challan.
   - Expected: final SO shipped status becomes fully shipped only after remaining quantity is dispatched.

## 11. Delivery Challan To Sales Invoice

### Normal Case

1. Open dispatched Delivery Challan.
2. Click create invoice from challan/Sales Order path.
3. Verify invoice is created with:
   - Same customer.
   - Same Sales Order line rates.
   - Only dispatched/challan quantities.
   - Scheme/free lines preserved.
4. Post invoice if posting is separate.
5. Verify:
   - AR/customer outstanding increases.
   - Sales/revenue and tax accounting posts correctly.
   - Inventory is not deducted again.
   - SO invoiced status updates.

### Corner Cases

1. Partial invoice after full shipment.
   - Expected: status remains partially invoiced until all shipped quantity is billed.
2. Create invoice twice for same challan.
   - Expected: duplicate billing is blocked or quantities remaining are controlled.
3. Invoice with zero-rate free line.
   - Expected: allowed only for linked SO scheme path; normal invoice entry should still reject invalid zero-value lines.

## 12. Payment And Collection

### Normal Payment

1. Open invoice.
2. Record payment.
3. Verify:
   - Invoice balance reduces.
   - Customer outstanding reduces.
   - Payment status is posted if no workflow applies.
   - Journal is posted once.

### Payment Approval

1. Enable Payment approval workflow.
2. Record payment that matches workflow trigger.
3. Expected:
   - Payment moves to `PENDING_APPROVAL`.
   - Invoice balance does not reduce yet if design gates posting until approval.
   - No journal is posted before approval.
4. Approve payment.
   - Expected: payment posts, invoice balance reduces, journal posts once.
5. Reject payment.
   - Expected: payment is rejected/voided, no invoice or accounting side effect.

### Dealer Collection Follow-Up

1. Open Credit Ledger.
2. Add follow-up status, promise date, and note.
3. Verify:
   - Follow-up is visible.
   - No invoice balance changes.
   - No payment is created.
   - No journal is posted.

## 13. Credit Note Approval

### Normal Case

1. Enable Credit Note approval workflow.
2. Create credit note above workflow threshold.
3. Click issue/post.
4. Expected:
   - Credit note moves to `PENDING_APPROVAL`.
   - No AR/accounting effect before approval.
5. Approve from Approval Inbox.
6. Verify:
   - Credit note becomes issued/applied.
   - AR reduces only after approval.
   - Journal posts once.

### Corner Cases

1. Reject credit note.
   - Expected: no AR or journal effect.
2. Credit note below threshold.
   - Expected: follows normal issue path.
3. Credit note linked to invoice.
   - Expected: invoice/customer balance updates only after issue/approval.

## 14. Distributor Dashboard And Reports

### Dashboard

1. Log in as pharma distributor.
2. Open top Dashboard.
3. Verify it shows distributor layout, not Kirana/retail layout.
4. Verify KPIs reflect current data:
   - Dispatch flow
   - Dealer collections
   - Supplier dues
   - Expiry risk
   - Low stock

### Reports

1. Open Reports.
2. Open `Pending Dispatch`.
3. Verify confirmed/backorder/partially shipped SOs appear until fully shipped.
4. Open `Challan Not Invoiced`.
5. Verify dispatched/delivered challans appear until linked SO quantities are invoiced.
6. Confirm reports are read-only and do not mutate stock, invoice, payment, or journal state.

## 15. Browser And Session Switching

1. Log in as one org, then log out.
2. Log in as another org with different business type.
3. Verify:
   - Dashboard changes to correct business type.
   - Sidebar modules are correct.
   - Settings profile is correct.
   - Old org capabilities are not reused from cache.
4. Refresh browser.
5. Verify same route loads without redirect loop.

## 16. Final Regression Pass

Run this compact smoke pass after every distributor hardening change:

1. Create item with zero stock.
2. Confirm item appears in stock summary.
3. Create PO from shortage.
4. Create draft GRN from PO.
5. Receive stock with batch, expiry, rack, and cost.
6. Confirm POS search shows rack and stock.
7. Create Sales Order.
8. Create Delivery Challan.
9. Dispatch stock once.
10. Create Sales Invoice.
11. Confirm accounting and customer outstanding.
12. Record payment.
13. Confirm invoice balance and journal.
14. Open dashboard and reports.

## Defect Logging Format

Use this format when reporting a bug:

```text
Area:
Route/Page:
Org type:
Steps:
Expected:
Actual:
Stock impact:
Accounting impact:
Backend error/request id:
Screenshot/log:
```

Any bug with wrong stock quantity, duplicate stock movement, wrong invoice balance, or duplicate/missing journal should block new feature development until fixed.
