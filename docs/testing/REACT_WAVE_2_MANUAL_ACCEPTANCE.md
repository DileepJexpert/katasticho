# React Wave 2 Manual Acceptance

**Status:** Pending manual execution

This runbook accepts the React item-master, purchase-to-pay, and order-to-cash
workflows against the existing Spring API. It does not replace the complete
module packs in this directory; it is the smallest connected evidence set for
React parity.

## Rules

- Use an OWNER or ADMIN account with the required modules enabled.
- Test against an isolated organisation or add a unique suffix such as
  `RW2-20260904` to every new master and document reference.
- Record stock before and after every stock-affecting action. Do not rely only
  on dashboard totals.
- Use the React application for every listed action. If a required master is
  unavailable in React, stop and record the blocker; do not silently create it
  elsewhere and mark the React flow passed.
- Record document numbers, amounts, status, stock result, and journal result in
  the evidence table at the end.

## A. Item Master And Opening Stock

1. Open **Items** and create a stock item with this unique data:

| Field | Value |
|---|---|
| Name | Turmeric Masala RW2 100g |
| SKU | RW2-TURMERIC-100G |
| HSN | 2106 |
| GST | 18% |
| Purchase price | ₹30.00 |
| Sale price | ₹45.00 |
| Unit | PCS |
| Track inventory | Yes |
| Track batches | No |
| Opening stock | 100 PCS in the main warehouse |

2. Open the saved item and its stock/movement review.

**Pass criteria:** the item is active, selling price is ₹45.00, on-hand is 100,
and exactly one `OPENING` movement exists for 100. No purchase, sale, or journal
should be created by the item save itself.

## B. Purchase To Pay

**Precondition:** an existing contact is both a `VENDOR` and `SUPPLIER`, for
example `Annapurna Raw Materials Supplier`.

1. Create a purchase order for the supplier:

| Field | Value |
|---|---|
| Item | Turmeric Masala RW2 100g |
| Quantity | 100 PCS |
| Rate | ₹30.00 |
| GST | 18% |
| Supplier reference | RW2-PO-001 |

2. Save the PO and send it. Confirm its status is `SENT`.
3. From that PO, use **Create GRN**. Confirm a `DRAFT` receipt is created and
   on-hand stock remains 100.
4. Open the GRN and choose **Receive Stock**. Use receipt reference
   `RW2-GRN-001`, quantity 100, and unit cost ₹30.00.
5. Verify GRN status is `RECEIVED`, item on-hand is now 200, and one purchase
   movement for 100 exists. There must be no purchase-accounting journal yet.
6. From the PO, use **Create Bill**. Confirm the bill has the supplier vendor
   contact, the PO-linked line, and total **₹3,540.00**.
7. Open **3-Way Match**. Confirm all lines are `MATCHED`, then post/send the
   bill.
8. Verify the bill is payable, AP is ₹3,540.00, and the bill journal balances:
   debit purchase/inventory and input GST ₹540.00; credit AP ₹3,540.00.
9. Record a vendor payment of **₹1,500.00** through a valid cash or bank GL
   account. The bill must become `PARTIALLY_PAID`, with ₹2,040.00 due.
10. Record the final ₹2,040.00 payment. The bill must be `PAID`, its balance
    must be zero, and the two payments together must debit AP and credit the
    selected cash/bank accounts by ₹3,540.00.

**Required negative check:** attempt to allocate more than the outstanding bill
balance. The page or server must reject it and no extra payment may be posted.

## C. Order To Cash

**Precondition:** an existing `CUSTOMER` contact, for example `Shree Ganesh
Kirana Test`, and the item has on-hand quantity 200 after section B.

1. Create a sales order:

| Field | Value |
|---|---|
| Customer | Shree Ganesh Kirana Test |
| Item | Turmeric Masala RW2 100g |
| Quantity | 10 PCS |
| Rate | ₹45.00 |
| Discount | 0% |
| GST | 18% |
| Reference | RW2-SO-001 |
| Allow backorder | Off |

2. Save the order and choose **Confirm**. It must become `CONFIRMED`; on-hand
   must remain 200 because confirmation reserves stock but never deducts it.
3. From the order, choose **Create delivery challan**. Save the default 10 PCS
   line. The challan must be `DRAFT`; on-hand must still be 200.
4. Open the challan and choose **Dispatch**. It must become `DISPATCHED`; item
   on-hand must change exactly once from 200 to 190. Confirm no accounting
   journal was created by dispatch.
5. Return to the sales order and choose **Create linked invoice**. Invoice only
   the 10 dispatched PCS, create the draft, then choose **Send invoice**.
6. Verify the invoice total is **₹531.00**: ₹450.00 taxable value plus ₹81.00
   GST. Stock must still be 190 after invoice creation and sending.
7. Verify the sent invoice creates a balanced journal: debit AR ₹531.00,
   credit sales revenue ₹450.00, and credit the GST liability ₹81.00. COGS and
   inventory entries should also balance at the item cost.
8. On the invoice, choose **Record payment** and record ₹200.00 by bank
   transfer. The invoice must become `PARTIALLY_PAID` with ₹331.00 due.
9. Record the final ₹331.00. The invoice must become `PAID`, balance zero, and
   the two receipts together must debit bank and credit AR by ₹531.00.

**Required negative check:** try to record more than the remaining invoice
balance. It must be rejected with no payment and no balance change.

## D. Direct Invoice Guardrail

Use a separate item or a remaining one-unit quantity so this check does not
confuse the linked-order stock evidence.

1. Open **New direct sales invoice**.
2. Confirm that the configured `SALES_REVENUE` account is selected, or choose
   an active revenue account. Do not continue if the account control is empty.
3. Add one catalog item, create a DRAFT, and send it.
4. Confirm stock changes only once when the direct invoice is sent.
5. Confirm a direct invoice was not used for the dispatched sales-order lines.

## Evidence Record

| Check | Document number | Expected result | Actual result | Pass/Fail | Notes or error code |
|---|---|---|---|---|---|
| Item opening stock |  | On-hand 100; one OPENING movement |  |  |  |
| PO and draft GRN |  | No stock change before receive |  |  |  |
| GRN receipt |  | On-hand 200; one purchase movement |  |  |  |
| Bill and 3-way match |  | ₹3,540; MATCHED; AP correct |  |  |  |
| Vendor partial/final payment |  | ₹2,040 then ₹0 AP due |  |  |  |
| SO confirmation |  | On-hand remains 200 |  |  |  |
| Challan dispatch |  | On-hand 200 to 190 once |  |  |  |
| Linked invoice |  | ₹531; no second stock movement |  |  |  |
| Customer partial/final receipt |  | ₹331 then ₹0 AR due |  |  |  |
| Direct invoice guardrail |  | Configured revenue account and one stock move |  |  |  |

## Acceptance Decision

Wave 2 passes only when every required check passes, the negative checks do
not create a document or movement, and the resulting stock, AP, AR, GST, and
journal balances reconcile to the source documents. Attach screenshots or API
responses to failures and record the business error code before changing code.
