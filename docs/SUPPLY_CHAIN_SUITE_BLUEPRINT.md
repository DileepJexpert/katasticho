# KATIXO Supply Chain Suite: A Complete Functional Module Map & Event-Driven Build Blueprint

Source: research brief shared 2026-06-22. Live tracker of progress against this
blueprint: see `SUPPLY_CHAIN_BUILD_TRACKER.md`.

## TL;DR
- **Replace the thin 7-item "Inventory" submenu with a 10-pillar supply chain suite** (Planning, Procurement, Supplier Management, Inventory/Warehouse, Order Management, Logistics, Manufacturing, Reverse Logistics, Traceability/Compliance, Control Tower), but **build it in three sequenced phases** — Phase 1 ships the pharma/FMCG distributor MVP (batch/expiry/FEFO, GST e-invoice + e-way bill, P2P with GRN/3-way match, order-to-cash with scheme + credit engine), Phase 2 adds differentiators (WMS scanning, multi-warehouse, supplier scorecards, control-tower KPIs, AI photo-to-GRN), Phase 3 adds manufacturing/MRP and advanced AI.
- **Technically, model each pillar as a bounded context that owns its data and emits domain events to Kafka** (PurchaseOrderApproved, GoodsReceived, StockAdjusted, SalesOrderPlaced, StockReserved, ShipmentDispatched, DeliveryConfirmed, ReturnInitiated). Every inventory movement event is consumed by a Ledger service that posts double-entry journals (perpetual inventory), reusing your existing transactional-outbox/Kafka pattern so the DB write and event publish are atomic.
- **For the distributor-first wedge, batch+expiry+FEFO, a declarative scheme engine, credit-limit control, and one-click e-way bill/e-invoice are the highest-value must-haves** — they are what Marg, C-Square and FMCG DMS players win on; defer enterprise overkill (S&OP optimization, full TMS route-optimization, deep MRP) until you have distribution traction.

## Key Findings

**The whole supply chain reduces to six canonical processes.** The ASCM/APICS SCOR Digital Standard organizes every supply chain into **Plan, Source, Make, Deliver, Return, and Enable** — the universally accepted, open-access reference model.

**Leading ERPs converge on the same module set.** NetSuite's SCM suite is built from Procurement, Inventory Management, Warehouse Management (WMS), Demand Planning, Order Management, Supply Chain Control Tower, Quality Management, and Work-in-Process/Routings. SAP S/4HANA structures it as MM, SD, PP, EWM, TM, QM, and IBP.

**India pharma/FMCG distributors have non-negotiable, regulator-driven requirements** — Forms 20B / 21B / 20G; Rule 65 (batch on memo, 3-year retention); Schedule H1 separate register (G.S.R. 588(E), Rule 65(11)(h)); Schedule X separate license + Form 20G + invoice copies to LA; Schedule N for biologicals (refrigeration); Rule 64(2) competent person; G.S.R. 823(E) top-300 QR mandate (eff. 1 Aug 2023) with GS1 DataMatrix carrying GTIN/batch/expiry/mfg/serial.

**GST movement compliance is a hard dependency.** E-way bill required for consignments > ₹50,000 inter-state. Since 1 Jan 2025, only documents within 180 days. From 1 Apr 2025, AATO ≥ ₹10 cr must IRP-upload within 30 days. MFA mandatory.

**Distributor wedge = secondary sales, schemes, beats, credit.** FMCG/pharma DMS players (BeatRoute, FieldAssist, Marg, SpireStock) win on these. Scheme leakage alone erodes 2–3% gross margin.

**Event-driven pattern fits perfectly.** Bounded contexts (Order, Inventory, Payment, Shipping) communicate via domain events with idempotent consumers + transactional outbox. The double-entry ledger is just another consumer.

## A. Complete Functional Module Map (proposed navigation tree)

Each leaf has a one-line description. Items tagged **[P1]/[P2]/[P3]** for build phase.

### 1. Planning & Forecasting *(SCOR: Plan)*
- Demand Forecasting [P2] — statistical + ML per SKU/location
- Demand Sensing [P3] — short-horizon adjustment from secondary sales
- Replenishment Planning [P1] — min/max, ROP, EOQ
- Safety Stock & Service Levels [P2] — Z-score × demand/lead-time variability
- S&OP / Supply Planning [P3]
- Seasonal/Promo Planning [P2]

### 2. Procurement (Procure-to-Pay) *(SCOR: Source)*
- Purchase Requisitions [P1]
- RFQ / Quotation Management [P2]
- Purchase Orders [P1] — standard, blanket, scheduled
- Approval Workflows [P1]
- Goods Receipt (GRN) [P1] — batch/expiry capture, partial receipts
- 3-Way Matching [P1] — PO ↔ GRN ↔ invoice with tolerance + exception queue
- Purchase Returns / Debit Notes [P1]
- Landed Cost [P2] — freight/duty/insurance allocation
- Import/Customs [P3]
- AP Integration [P1]

### 3. Supplier / Vendor Lifecycle (SRM) *(SCOR: Enable/Source)*
- Supplier Master & Onboarding [P1] — KYC, drug license, GST
- Price Lists / Rate Contracts [P1]
- Supplier Scorecards / Rankings [P2] — OTIF, quality, lead-time, price
- Contract Management [P3]
- Supplier Risk & Multi-sourcing [P3]
- Supplier Portal [P3]

### 4. Inventory & Warehouse (WMS) *(SCOR: Source/Deliver)*
- Item/Product Master [P1]
- Multi-warehouse / Multi-location [P2]
- Bin/Location Hierarchy [P2]
- Batch/Lot Tracking [P1]
- Expiry & Shelf-life / FEFO-FIFO [P1]
- Serial Number Tracking [P3]
- Inbound/ASN & Putaway [P2]
- Picking / Packing [P2]
- Cross-docking [P3]
- Stock Transfers [P2]
- Cycle Counts & Physical Inventory [P2]
- Stock Adjustments [P1]
- Inventory Valuation [P1] — FIFO/WA/MA
- ABC/XYZ, Dead/Slow-moving, Ageing [P2]
- Available-to-Promise (ATP) [P2]
- Barcode/QR/RFID & Mobile Scanning [P2] — GS1 DataMatrix

### 5. Order Management (Order-to-Cash) *(SCOR: Deliver)*
- Multi-channel Order Capture [P1] — web, mobile, WhatsApp, van
- Beat / Route Planning [P2]
- Pricing / Discount / Scheme Engine [P1] — slab/qty/value + claim
- Credit Limit & Outstanding Control [P1]
- Allocation / Reservation / Backorder [P2]
- Pick-Pack-Ship / Dispatch [P1]
- Proof of Delivery [P2] — ePOD
- Secondary Sales Tracking [P2]
- Returns from Customer [P1]

### 6. Logistics / Transportation (TMS) *(SCOR: Deliver)*
- Shipment Planning [P2]
- E-way Bill Generation [P1]
- Carrier / Transporter Management [P2]
- Route Optimization [P3]
- Last-mile Delivery Tracking & ePOD [P2]
- 3PL / Courier Aggregator Integration [P3]
- Freight Cost & Reconciliation [P3]

### 7. Manufacturing / Production *(SCOR: Make)* — all [P3]
- BOM, Routing, Work Orders, MRP, WIP, Subcontracting/Job Work, BMR

### 8. Reverse Logistics / Returns *(SCOR: Return)*
- Sales Returns / RMA [P1]
- Purchase Returns to Vendor [P1]
- Expiry / Damaged Goods Returns & Claims [P1]
- Recall Management [P2] — batch-genealogy-driven

### 9. Traceability, Compliance & Quality *(SCOR: Enable)*
- Batch Genealogy / Track & Trace [P1]
- Schedule H1 / X / Narcotics Registers [P1] — statutory separate registers
- GST e-Invoice (IRN/QR) [P1]
- E-way Bill [P1]
- Drug License & Expiry Tracking [P1]
- Quality Inspection / COA [P2]
- Cold Chain / Temperature Monitoring [P3]
- Serialization / GS1 QR (top-300) [P2]
- Audit Trail [P1]

### 10. Control Tower / Analytics / AI *(SCOR: Enable/Plan)*
- KPI Dashboards [P1] — fill rate, OTIF, inventory turns, DSO, GMROI
- Inventory Analytics [P1]
- Alerts & Exceptions [P1]
- Demand/Stockout Prediction [P2]
- Anomaly / Fraud Detection [P3]
- Agentic Replenishment & Exception Handling [P3]

**KPI definitions:** Fill rate = % demand met from on-hand (target ~95%, excellence 98%+); OTIF = % delivered on-time AND in-full; GMROI = gross margin ÷ avg inventory cost; DSO = days to collect after sale.

## B. Proposed Information Architecture

```
KATIXO
├── Planning
├── Procurement
├── Suppliers
├── Inventory & Warehouse
├── Orders (Sales)
├── Logistics
├── Manufacturing            (Phase 3)
├── Returns & Recalls
├── Compliance & Quality
└── Control Tower
```

## C. Technical Build Blueprint

**Bounded contexts → modular monolith now, microservices later.** Strict module
boundaries + schema-per-tenant DB. Every cross-module interaction modelled as a
Kafka event from day one so modules can be peeled into services later without
rework.

**Bounded contexts:**
| Context | Owns |
|---|---|
| Catalog | Master data |
| Procurement | P2P |
| Supplier | SRM |
| Inventory | Stock truth + valuation |
| Order | O2C |
| Logistics | Transport |
| Manufacturing | Make (P3) |
| Returns | Return |
| Compliance | Statutory + audit |
| Ledger | Double-entry GL |
| Planning/AI | Plan |

**Core domain events:**
- Procurement: `PurchaseRequisitionRaised`, `PurchaseOrderApproved`, `GoodsReceived`, `PurchaseInvoiceMatched`, `ThreeWayMatchFailed`, `PurchaseReturnIssued`
- Inventory: `StockReceived`, `StockReserved`, `StockReleased`, `StockAdjusted`, `StockTransferred`, `BatchNearExpiry`, `ReorderPointBreached`, `LandedCostApplied`
- Order: `SalesOrderPlaced`, `CreditCheckPassed/Failed`, `SchemeApplied`, `OrderAllocated`, `OrderPartiallyFulfilled`, `OrderInvoiced`
- Logistics: `ShipmentPlanned`, `EwayBillGenerated`, `ShipmentDispatched`, `DeliveryConfirmed`, `PODCaptured`
- Returns: `ReturnInitiated`, `ReturnGradedToStock` / `ReturnScrapped`, `RecallTriggered`
- Compliance: `IRNGenerated`, `StatutoryRegisterEntryRecorded`, `AuditEntryLogged`
- Ledger: consumes movement events, posts journals

**Double-entry / ledger integration (perpetual inventory):**
- GoodsReceived → DR Inventory, CR GRN/AP-accrual; on invoice match → CR AP, clear accrual
- LandedCostApplied → DR Inventory, CR freight/duty accrual (15–40% over FOB typical)
- OrderInvoiced → DR COGS, CR Inventory (FEFO batch cost) + DR AR/Cash, CR Sales, CR GST payable
- StockAdjusted (write-off/expiry) → DR Shrinkage/Expiry-Loss, CR Inventory
- SalesReturn to stock → DR Inventory, CR COGS (reverse)

**Outbox + idempotency.** Transactional outbox in same DB tx; relay (poll or Debezium) publishes to Kafka. Consumers maintain `consumed_events(event_id)` table. Key every topic by aggregateId for per-entity ordering.

**Schema-per-tenant.** Each tenant = own schema; tenantId in event header.

## D. Prioritized Roadmap

**Phase 1 — Pharma/FMCG Distributor MVP.** A distributor can run their whole primary business: buy, store w/ batch/expiry, sell on credit w/ schemes, dispatch w/ e-way bill, file GST, handle returns, survive a drug inspection.

**Phase 2 — Differentiators.** WMS scanning + GS1 DataMatrix, replenishment intelligence, supplier scorecards, beat planning, photo-to-GRN, predictive stockouts, control-tower v2.

**Phase 3 — Advanced / enterprise.** Manufacturing depth, full TMS, S&OP, serialization automation, agentic replenishment.

**Explicitly NOT early:** full S&OP optimization, finite-capacity production scheduling, deep TMS optimization, supplier-portal EDI, multi-echelon inventory.

## E. AI / Agentic Opportunities

**Realistic near-term (P1–P2):**
- Photo-to-GRN / invoice extraction (Marg has it — proves demand)
- Demand forecasting & auto-replenishment suggestions (Walmart "Eden" $86M waste prevented; General Mills $20M+ savings)
- Predictive stockouts & near-expiry alerts
- Credit/fraud anomaly detection
- Supplier risk score

**Aspirational (P3):**
- Autonomous replenishment agents (Gartner: 50% of SCM solutions use intelligent agents by 2030; market $2B→$53B)
- Agentic exception handling for 3-way-match
- Dynamic safety-stock
- **Caveat:** Gartner predicts 40%+ of agentic AI projects cancelled by 2027; 60% of AI projects abandoned without AI-ready data. Define KPI + clean data first.

## Caveats from the source brief
- Drug licensing is state-administered; register formats vary by state
- G.S.R. 823(E) data elements mandated; GS1 DataMatrix is *recommended* not strictly required — scanners must parse both GS1 and proprietary QR
- e-Way bill / e-invoice thresholds change frequently — treat as config, not constants
- Agentic-AI ROI figures are large-enterprise; validate direction not scale
