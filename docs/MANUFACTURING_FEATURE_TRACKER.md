# Manufacturing Module — Feature Tracker

Gap analysis based on Zoho, ERPNext, Odoo, SAP B1, NetSuite, Katana, MRPeasy, Cin7, Fishbowl, InFlow.
Current coverage: **30 / 114 features (26%)**. Target: Tier 1 + Tier 2 = competitive for Indian SMBs.

---

## Status Legend
- `DONE` — Implemented, tested, merged
- `IN_PROGRESS` — Currently being built
- `TODO` — Planned, not started
- `DEFERRED` — Low priority, future phase
- `N/A` — Not applicable to our target market

---

## Tier 1 — Must Have (blocks real usage for Indian SMBs)

### 1.1 Subcontracting / Job Work (India-critical)
Most Indian SMB manufacturing is outsourced via job work (pharma tablet pressing/coating, garment stitching/embroidery, food co-packing, electronics PCB assembly). GST compliance (ITC-04) is regulatory.

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Subcontracting order entity (send RM to vendor for processing) | DONE | `JobWorkOrder` + `JobWorkOrderLine` entities, `JobWorkService` |
| 2 | Job work challan (DC for materials sent to job worker) | DONE | `sendMaterials()` records JOB_WORK_OUT movements, auto-generates challan number |
| 3 | Job work receipt (receive processed goods back) | DONE | `receiveGoods()` with wastage tracking, partial/full receipt, JOB_WORK_IN movements |
| 4 | Job work stock tracking (materials at each subcontractor) | DONE | Via stock_movement ledger with JOB_WORK_OUT/IN types and JOB_WORK_ORDER reference |
| 5 | Job work costing (processing charges in FG cost) | DONE | processingCharges + totalMaterialCost = totalCost on JobWorkOrder |
| 6 | GST ITC-04 data generation (goods sent/received from job workers) | DONE | gstReturnDeadline (sendDate + 1yr), deadline alert query endpoint |
| 7 | Job work reason codes and wastage recording | DONE | wastageQty on lines, cancel reverses unreceived stock via ADJUSTMENT |

### 1.2 Routing, Operations & Workstations
Without this, no operation-level tracking is possible. Every competitor has it.

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 8 | Operation/routing definition (ordered steps: Cut→Mix→Pack) | DONE | `Operation`, `Routing`, `RoutingOperation` entities, `RoutingService` CRUD |
| 9 | Workstation/work center (machine + capacity + hourly rate) | DONE | `Workstation` entity with hourlyRate, capacityHoursPerDay, `RoutingService` CRUD |
| 10 | Job cards per operation (assigned worker, start/stop, qty) | DONE | `JobCard` entity, `createJobCardsForWorkOrder()` from routing |
| 11 | Operation time tracking (planned vs actual) | DONE | actualStart/actualEnd on JobCard, timeLoggedMinutes on complete |
| 12 | Labor time logging per operation (worker + hours + cost) | DONE | timeLoggedMinutes + assignedTo on JobCard |
| 13 | Work instructions / attachments per operation | TODO | |
| 14 | BOM with operations/routing attached | DONE | routingId on WorkOrder, `createJobCardsForWorkOrder()` |
| 15 | Alternative work centers (fallback if primary at capacity) | TODO | |
| 16 | Operation dependencies (predecessor/successor) | TODO | |

### 1.3 Quality Control
Regulatory requirement for pharma (GMP Schedule M), food (FSSAI). Non-negotiable for these verticals.

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 17 | Quality inspection templates (parameters + acceptable ranges) | DONE | `QcTemplate`, `QcParameter` entities, `QualityControlService` CRUD |
| 18 | IQC — Incoming quality control (inspect raw materials at receipt) | DONE | `createInspection()` with inspectionType=INCOMING, referenceType/Id for GRN |
| 19 | IPQC — In-process quality control (checkpoints between operations) | DONE | inspectionType=IN_PROCESS, referenceType=WORK_ORDER |
| 20 | OQC — Outgoing quality control (final inspection before shipment) | DONE | inspectionType=OUTGOING |
| 21 | Inspection results recording (measured values, pass/fail, inspector) | DONE | `QcInspection`, `QcInspectionResult`, `recordResults()` + `finalizeInspection()` |
| 22 | Accept/reject/hold decision workflow | TODO | Quarantine stock on hold |
| 23 | Non-conformance reports (NCR) with reason codes | TODO | |
| 24 | Certificate of Analysis (CoA) generation per batch | TODO | Critical for pharma |
| 25 | Batch-wise QC (track QC per production batch) | DONE | batchId field on QcInspection for per-batch tracking |

### 1.4 Scrap & Waste Management

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 26 | Scrap recording during production (qty + reason code) | DONE | `ScrapService.recordScrap()` with PRODUCTION_SCRAP movement + WO totals |
| 27 | Scrap reason codes (material defect, machine error, operator, tooling) | DONE | `ScrapReasonCode` entity, CRUD in `ScrapService` |
| 28 | Scrap stock location / scrap accounting | DONE | PRODUCTION_SCRAP stock movement type, scrapQty/scrapCost on WorkOrder |
| 29 | Yield tracking (input vs output ratio, actual vs expected) | TODO | |
| 30 | BOM scrap/yield percentage (e.g., issue 105% for 5% expected waste) | TODO | Field on `bom_component` |
| 31 | Material variance reporting (planned vs actual consumption) | TODO | |

### 1.5 Production Plan from Sales Orders

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 32 | Auto-create work orders from sales orders (MTO) | DONE | `createWorkOrdersFromSalesOrder()` finds composite items, creates WOs |
| 33 | SO → WO linkage and traceability | DONE | `salesOrderId` on WorkOrder, auto-set by SO→WO flow |
| 34 | Make-to-Order vs Make-to-Stock modes | TODO | Item-level or org-level setting |

---

## Tier 2 — Required for Feature Parity

### 2.1 BOM Enhancements

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 35 | Multi-level BOM (nested sub-assemblies) | DONE | BomService already supports explosion |
| 36 | BOM versioning / revision control (Rev A, B, C with effectivity dates) | TODO | |
| 37 | Alternate/substitute materials in BOM | TODO | |
| 38 | Phantom/kit BOM (explode but don't create sub-WOs) | TODO | |
| 39 | Co-products / by-products in BOM | TODO | Multiple outputs from one production run |
| 40 | BOM cost roll-up through all levels | TODO | Recursive cost calculation |
| 41 | BOM comparison (diff between versions) | TODO | |
| 42 | Configurable/parameterized BOMs (size, color variants) | TODO | |

### 2.2 Batch Traceability in Production

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 43 | Batch assignment to finished goods at production receipt | TODO | Assign batch/lot number on receive |
| 44 | Input batch tracking (which RM batches consumed per WO) | TODO | Link stock_movement batches to WO |
| 45 | FEFO in production material consumption | TODO | Extend existing FEFO to production issue |
| 46 | Forward/backward traceability report (FG batch → RM batches → suppliers) | TODO | |
| 47 | Batch recall support | TODO | Given defective RM batch, find all affected FG batches |

### 2.3 Production Reporting & Analytics

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 48 | Production summary report (WOs by status, completion rate, on-time %) | TODO | |
| 49 | Cost variance report (planned vs actual: material + labor + overhead) | TODO | |
| 50 | Material consumption report (planned vs actual per WO) | TODO | |
| 51 | WIP valuation report (value of in-progress production) | TODO | |
| 52 | Production analytics dashboard (throughput, efficiency, trends) | TODO | |
| 53 | Work order profitability (revenue - production cost per WO) | TODO | |
| 54 | Scrap rate dashboard (by product, operation, reason, trend) | TODO | |

### 2.4 Module Integration

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 55 | WIP journal entries (DR WIP / CR Raw Materials on issue; DR FG / CR WIP on receipt) | TODO | Use existing JournalService |
| 56 | Production → Purchase Order link (MRP generates POs for shortages) | TODO | |
| 57 | Production → Payroll integration (labor hours → piece-rate/hourly pay) | TODO | Bridge to existing payroll module |
| 58 | Backflush materials (auto-issue when FG received instead of manual issue) | TODO | Alternative to current issue-to-production |

### 2.5 Work Order Enhancements

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 59 | Work order priority and sequencing (urgent/high/normal/low) | TODO | |
| 60 | Linked/dependent work orders (auto-create child WOs for sub-assemblies) | TODO | |
| 61 | Work order approval workflow | TODO | Reuse existing ApprovalWorkflowService |
| 62 | Work order cloning / templates | TODO | |
| 63 | Disassembly / unbuild orders (reverse FG back to components) | TODO | |
| 64 | Split / merge work orders | TODO | |
| 65 | Batch/lot assignment on production receipt | TODO | |
| 66 | Auto-create WOs from reorder points (auto-assembly) | TODO | |

---

## Tier 3 — Competitive Differentiators (later phases)

### 3.1 MRP Engine & Scheduling

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 67 | MRP run (analyze demand, check stock, generate planned WOs + POs) | DEFERRED | Core MRP engine — complex, do after Tier 1-2 |
| 68 | Master Production Schedule (MPS) | DEFERRED | |
| 69 | Forward/backward scheduling | DEFERRED | |
| 70 | Finite capacity scheduling | DEFERRED | Requires workstations (Tier 1) |
| 71 | Gantt chart / visual scheduler | DEFERRED | |
| 72 | Production planning board (material readiness view) | DEFERRED | |
| 73 | Demand forecasting from historical sales | DEFERRED | |
| 74 | Lead time estimation from routing + procurement | DEFERRED | |

### 3.2 Shop Floor Control

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 75 | Shop floor tablet/kiosk interface | DEFERRED | Flutter mobile app extension |
| 76 | Barcode scanning on shop floor | DEFERRED | |
| 77 | Real-time production dashboard (for factory TV monitors) | DEFERRED | |
| 78 | Material requisition from shop floor | DEFERRED | |
| 79 | Production alerts / push notifications | DEFERRED | |

### 3.3 Advanced Costing

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 80 | Actual costing from time tracking (labor hours × rate) | DEFERRED | Requires job cards (Tier 1) |
| 81 | Standard costing with variance analysis | DEFERRED | |
| 82 | Landed cost allocation to production | DEFERRED | |
| 83 | Cost roll-up from sub-assemblies | DEFERRED | |

### 3.4 Maintenance Management

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 84 | Preventive maintenance scheduling (time or usage-based) | DEFERRED | |
| 85 | Corrective maintenance requests from shop floor | DEFERRED | |
| 86 | Maintenance history per equipment (MTBF/MTTR) | DEFERRED | |
| 87 | Maintenance-production integration (block scheduling during maintenance) | DEFERRED | |

### 3.5 Advanced Quality

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 88 | CAPA (Corrective & Preventive Action tracking) | DEFERRED | |
| 89 | Statistical Process Control (SPC) with control charts | DEFERRED | |
| 90 | Sampling plans (AQL-based: inspect N of M) | DEFERRED | |

### 3.6 Capacity Planning

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 91 | Capacity requirements planning (required vs available per workstation) | DEFERRED | |
| 92 | Bottleneck identification | DEFERRED | |
| 93 | What-if simulation (add shifts, machines, outsource) | DEFERRED | |
| 94 | Resource leveling | DEFERRED | |

### 3.7 Industry-Specific (India)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 95 | Pharma: Batch Manufacturing Record (BMR) | DEFERRED | GMP Schedule M compliance |
| 96 | Pharma: Stability testing tracking | DEFERRED | |
| 97 | Food: Recipe/formula management (percentage-based BOMs) | DEFERRED | |
| 98 | Food: FSSAI compliance (license, labels, traceability) | DEFERRED | |
| 99 | Garment: Size-color matrix production | DEFERRED | |
| 100 | Garment: Cut plan optimization | DEFERRED | |
| 101 | Electronics: Component obsolescence tracking | DEFERRED | |

---

## Progress Log

| Date | Items Completed | Total Done | Notes |
|------|----------------|------------|-------|
| 2026-06-06 | Phase 9 base: WO lifecycle, BOM explosion, issue/receive, costing, cancel | 13 | Initial Manufacturing-Lite |
| 2026-06-07 | Tier 1: Job work (7), routing/ops/job cards (5), QC (5), scrap (3), SO→WO (2) | 30 | V46 migration, 4 services, 41 new tests (417 total) |

---

## Implementation Notes

### Database Migrations
- V45: `work_order`, `work_order_line` (DONE)
- V46: 15 new tables (workstation, operation, routing, routing_operation, job_card, job_work_order, job_work_order_line, qc_template, qc_parameter, qc_inspection, qc_inspection_result, scrap_reason_code, production_scrap) + 5 ALTER TABLE on work_order + 20 indexes (DONE)

### Key Architecture Decisions
- Job work reuses DC pattern for material transfer, PO pattern for processing charges
- Operations/routing are separate from BOM — one BOM can have multiple routings
- QC templates are item-scoped, inspections are instance-scoped (per batch/receipt/WO)
- Scrap is a stock movement type (PRODUCTION_SCRAP), not a separate entity
- WIP accounting uses existing JournalService — no new accounting module needed
- Backflush is an alternative mode to issue-to-production, configurable per org/item

### Existing Infrastructure We Can Reuse
- `InventoryService.recordMovement()` — for all stock changes (scrap, job work transfers)
- `JournalService.postJournal()` — for WIP accounting entries
- `ApprovalWorkflowService` — for WO approval workflows
- Batch tracking (`stock_batch_balance`) — extend to production
- FEFO (`InventoryServiceFefoTest`) — extend to production material consumption
- `DeliveryChallanService` pattern — for job work challans
- `PurchaseOrderService` pattern — for subcontracting orders
