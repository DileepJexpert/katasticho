# Workflow Context Hints Execution Plan

## Purpose

Katixo should teach users at the point of action without becoming a tutorial-heavy product. Workflow pages should include short contextual hints that explain what the current document means, what the next step is, and when stock or accounting actually changes.

## Design Principle

Hints must be vertical-aware. The same page can mean different things for a pharma distributor, kirana retailer, FMCG distributor, manufacturer, or service business.

Do not hardcode long help text directly inside screens. Use one resolver so the page remains reusable.

## Suggested Implementation

Create a small frontend resolver first:

- Input:
  - `businessType`
  - `industryCode`
  - `pageKey`
  - optional `status`
- Output:
  - `title`
  - `body`
  - `variant`
  - optional action route

Suggested page keys:

- `purchase_order.detail`
- `stock_receipt.create`
- `stock_receipt.detail`
- `sales_order.detail`
- `delivery_challan.create`
- `delivery_challan.detail`
- `payment.record`
- `approval.inbox`

## Example Hints

### Sales Order Detail

Default:
`Sales Order records customer demand. Stock moves only when a Delivery Challan is dispatched.`

Pharma distributor:
`Record chemist or dealer demand. Stock decreases only after Delivery Challan dispatch.`

Kirana retailer:
`Use Sales Order for advance or delivery orders. Use POS for counter sales.`

FMCG distributor:
`Record retailer order booking. Dispatch happens through Delivery Challan.`

Manufacturer:
`Record buyer demand. Production and dispatch planning starts from confirmed orders.`

### Purchase Order Detail

Default:
`Purchase Order records supplier commitment. Stock increases only after Goods Receipt is received.`

Pharma distributor:
`Order medicines from supplier or company. Verify batch and expiry in Goods Receipt before receiving stock.`

Kirana retailer:
`Order goods from supplier. Create Goods Receipt when goods physically arrive.`

Manufacturer:
`Order raw materials or bought-out goods. Inventory increases only after Goods Receipt is posted.`

### Goods Receipt Detail

Default:
`Verify received quantity, batch, expiry, rack, and cost before posting stock.`

Posting hint:
`Receive Stock updates inventory and batch records. Use this only after verification.`

### Delivery Challan Detail

Default:
`Prepare dispatch against a Sales Order. Stock decreases when this challan is dispatched.`

Posting hint:
`Dispatch deducts inventory and marks the order as shipped or partially shipped.`

## UI Pattern

Add a reusable component later:

`KContextHint`

Variants:

- `info`
- `workflow`
- `warning`
- `success`

Keep hints compact:

- one title
- one sentence body
- optional action link

Avoid large permanent education blocks. Use short hints at the top of workflow pages and clear confirmation text for posting actions.

## Future Backend Option

Start with frontend static mappings. Later, move hint text to backend/org settings only if customers need editable language per organisation.

## Execution Order

1. Create `WorkflowHintResolver` in frontend.
2. Create reusable `KContextHint` widget.
3. Add hints to purchase and sales operational pages first.
4. Add posting-specific confirmation text to `Receive Stock` and `Dispatch` dialogs.
5. Extend to payment approval and credit-control screens.
