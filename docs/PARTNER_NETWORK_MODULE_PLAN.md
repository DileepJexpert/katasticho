# Partner Network Module Plan

## Purpose

Katixo should eventually support a connected B2B trade network where manufacturers, distributors, and retailers can transact with each other inside the same product subscription.

This is a future module. Distributor ERP stability remains the current priority.

## Product Direction

One Katixo subscription should cover:

- ERP
- POS
- distributor operations
- manufacturer/distributor/retailer partner ordering
- inventory availability visibility
- field-sales ordering
- accounting document linkage

The goal is to avoid customers needing separate third-party B2B ordering portals or commerce subscriptions.

## Architecture Decision

Build this as a module inside the existing monolith first.

Do not create a microservice now.

Recommended shape:

```text
same backend app
same frontend app
same database
same login
same subscription

backend package: com.katasticho.erp.partnernetwork
frontend feature: flutter_app/lib/features/partner_network
routes: /partner-network/...
```

This keeps development, testing, authentication, document posting, and accounting simpler while the product is still evolving.

## Core Principle

Do not expose raw cross-organisation inventory.

Bad:

```text
Retailer directly queries distributor stock_balance
```

Good:

```text
Distributor stock -> published availability snapshot -> retailer supplier search
```

Each organisation keeps private:

- stock
- accounting
- ledgers
- customers/vendors
- pricing
- users

Only explicitly published catalog, availability, prices, schemes, and order status are shared.

## Main User Flow

Retailer shortage flow:

```text
Retailer Shortage
  -> Find Supplier
  -> Search connected distributors' published catalog
  -> Select distributor, quantity, price/scheme
  -> Create Purchase Order in retailer org
  -> Create Incoming B2B Order in distributor org
```

Distributor fulfilment flow:

```text
Incoming B2B Order
  -> Accept
  -> Sales Order created in distributor org
  -> Delivery Challan dispatch
  -> Sales Invoice
```

Retailer receiving flow:

```text
Distributor invoice/challan
  -> Retailer draft GRN / Bill reference
  -> Retailer verifies quantity, batch, expiry, rack, cost
  -> Receive Stock
```

## Future Data Model

Possible tables:

```text
trading_partner
- id
- seller_org_id
- buyer_org_id
- status
- price_list_id
- credit_terms
- delivery_terms
- created_at

published_catalog_item
- id
- seller_org_id
- item_id
- global_product_id / drug_master_id
- display_name
- published_sku
- availability_mode
- available_qty_band
- min_order_qty
- price
- active
- updated_at

network_order
- id
- buyer_org_id
- seller_org_id
- buyer_po_id
- seller_so_id
- status
- requested_at
- confirmed_at

network_order_line
- id
- network_order_id
- buyer_item_id
- seller_item_id
- global_product_id / drug_master_id
- quantity
- rate
- scheme_snapshot

network_order_event
- id
- network_order_id
- event_type
- payload
- created_at
```

## Product Matching Requirement

This module needs strong product mapping.

For pharma:

- drug master
- brand name
- salt composition
- strength
- dosage form
- pack size
- manufacturer
- HSN
- GST

For FMCG:

- barcode
- brand
- pack size
- UOM
- category

Retailer item and distributor item should map to the same `global_product_id` or `drug_master_id` before reliable shortage matching is attempted.

## Suggested Route Structure

```text
/partner-network/partners
/partner-network/catalog
/partner-network/incoming-orders
/partner-network/outgoing-orders
/partner-network/supplier-search
```

Entry points inside existing modules:

```text
Shortage screen -> Find Supplier
Purchase Order -> Source from Partner
Sales Order -> Created from B2B Order
```

## Integration With Existing Services

The partner network module should not post stock or accounting directly.

It should call existing services:

```text
Retailer creates partner order
  -> PurchaseOrderService.create(...)

Distributor accepts partner order
  -> SalesOrderService.create(...)

Distributor dispatches
  -> existing DeliveryChallanService

Distributor invoices
  -> existing InvoiceService / AccountingPostingEngine

Retailer receives stock
  -> existing StockReceiptService
```

## Implementation Phases

1. Stabilize distributor ERP core first.
2. Finish product/drug master mapping.
3. Add trading partner request and approval.
4. Add distributor published catalog.
5. Add retailer supplier search from Shortage.
6. Add linked buyer PO and seller incoming B2B order.
7. Add distributor accept/reject and Sales Order creation.
8. Add status sync between seller and buyer.
9. Add invoice-to-GRN assistance for buyer.
10. Add salesman/field-sales ordering on top of the same network.

## Explicit Deferrals

Do not build now:

- separate microservice
- separate database
- public marketplace where every org can browse every seller
- direct cross-org stock balance query
- automatic accounting sync between organisations

## Current Decision

Hold this module for later.

Current active priority remains:

```text
Distributor-first ERP stability:
SO -> DC -> Invoice
PO -> GRN -> Receive Stock
batch / expiry / rack / schemes / credit / payment workflows
```
