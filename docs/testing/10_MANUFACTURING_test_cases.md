# 10 — Manufacturing

Manual UAT for the manufacturing module: BOM + routing masters, the work-order
lifecycle (issue → produce → receive → complete), WIP accounting, job cards /
shop floor, job work (subcontracting), QC, scrap, MRP, maintenance, the advanced
BOM tools, production reports, and the pharma (BMR) / quality (CAPA) packs.
Format matches the rest of the pack — see `README.md` §3.

> **Module gate:** Manufacturing is a **strict** capability (`MANUFACTURING` /
> `canUseManufacturing`). A manufacturer org gets it by default; otherwise enable
> it on the **Modules** screen (doc 07). All screens are under **`/manufacturing/*`**.
> Roles: OWNER/ADMIN for masters + lifecycle; OPERATOR for shop-floor actions.

> **Standard manufacturing data (create once, reuse):**
> | Item | Type | Role in test |
> |---|---|---|
> | Paracetamol 500mg Strip | GOODS (batch) | raw material |
> | Cough Syrup 100ml | GOODS (batch) | raw material |
> | **Wellness Combo Pack** | **COMPOSITE** | finished good (FG) |
>
> **BOM for Wellness Combo Pack:** 2 × Paracetamol + 1 × Cough Syrup per unit.
> Ensure both RMs have on-hand stock (Purchase pack 02 / opening stock) before issuing.

---

## A. Masters — workstation, operation, routing, BOM

### TC-MFG-001 — Create a BOM for the composite FG
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/manufacturing/masters` (item BOM) · **Role:** OWNER/ADMIN |
| **Preconditions** | Wellness Combo Pack exists as a COMPOSITE item |

**Test data:** Add components 2 × Paracetamol, 1 × Cough Syrup.

**Expected result:** BOM saved (version 1). A composite item never holds its own
stock — its buildable qty is derived from component availability. Duplicate child
without a variant filter is rejected.

**Actual / Status / Notes:**

---

### TC-MFG-002 — Workstation + operation + routing
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/masters`, `/manufacturing/routings` (`POST /workstations`, `/operations`, `/routings`) · **Role:** OWNER/ADMIN |

**Test data:** Workstation **Packing-1** (capacity 8 h/day, hourly rate ₹250).
Operation **Pack** (setup 10 min, run 2 min/unit). Routing for Wellness Combo
Pack → op Pack on Packing-1, sequence 1.

**Expected result:** Workstation, operation, and routing created; the routing
lists the operation in sequence with its workstation.

**Actual / Status / Notes:**

---

## B. Work-order lifecycle

### TC-MFG-010 — Create a work order (BOM explosion)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/manufacturing/work-orders/create` (`POST /work-orders`) · **Role:** OWNER/ADMIN |

**Test data:** FG **Wellness Combo Pack**, qty **10**.

**Expected result:** WO created **DRAFT** with a WO number; BOM exploded into
lines — **20 Paracetamol + 10 Cough Syrup** planned. Job cards created from the
routing (op Pack). No stock has moved yet.

**Actual / Status / Notes:**

---

### TC-MFG-011 — Issue materials to production (stock deducts + WIP journal)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | WO detail → Issue (`POST /work-orders/{id}/issue`) · **Role:** OWNER/ADMIN |
| **Preconditions** | RM on-hand ≥ 20 Paracetamol + 10 Cough Syrup |

**Expected result:** WO → **IN_PROGRESS**. RM stock **deducts** (20 Para + 10
Cough) — batch-tracked RM consumed **FEFO** (earliest expiry first), one movement
per batch slice. **WIP journal:** DR **WIP (1210)** / CR **Inventory (1200)** +
**Direct Labor (5040)** + **Mfg Overhead (5030)**. Short batch stock →
`MFG_INSUFFICIENT_BATCH_STOCK` (no partial issue).

**Actual / Status / Notes:**

---

### TC-MFG-012 — Receive finished goods (with batch)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | WO detail → Receive FG (`POST /work-orders/{id}/receive`) · **Role:** OWNER/ADMIN |

**Test data:** Receive 10 units, batch **WCP-2607**, expiry +2 years.

**Expected result:** FG stock **increases** by 10 into batch WCP-2607
(`PRODUCTION_RECEIVE` movement carries the batchId; repeated receipts into the
same batch accumulate). **Guards:** batch-tracked FG with no batch number →
`MFG_BATCH_REQUIRED`; batch number on a non-batch item → `MFG_ITEM_NOT_BATCH_TRACKED`.

**Actual / Status / Notes:**

---

### TC-MFG-013 — Complete the work order (WIP clears + cost summary)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | WO detail → Complete (`POST /work-orders/{id}/complete`) · **Role:** OWNER/ADMIN |

**Expected result:** WO → **COMPLETED**. Completion journal: DR **Inventory
(1200)** / CR **WIP (1210)**; any RM/labour/overhead variance → **Material
Variance (5050)**. A **production cost summary** is built (planned vs actual RM /
labour / overhead, **yield %**). WIP account nets to ~zero for the WO.

**Actual / Status / Notes:**

---

### TC-MFG-014 — Cancel a work order (reversal)
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | WO detail → Cancel (`POST /work-orders/{id}/cancel`) · **Role:** OWNER/ADMIN |

**Expected result:** Cancelling an IN_PROGRESS WO **reverses** the WIP journal
(`journalService.reverseEntry`) and restores issued RM stock. A WO with an
unfinished **child** sub-assembly can't start (`MFG_CHILD_WO_PENDING`).

**Actual / Status / Notes:**

---

### TC-MFG-015 — SO → WO automation
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `POST /work-orders/from-sales-order` · **Role:** OWNER/ADMIN |
| **Preconditions** | A confirmed SO containing the composite FG |

**Expected result:** A DRAFT WO is created per composite item on the SO, linked to
the SO line. An SO with **no** composite item → `MFG_SO_NO_COMPOSITE_ITEMS`.
(MTO items build only via this path; MTS only via the reorder sweep — see TC-MFG-016.)

**Actual / Status / Notes:**

---

### TC-MFG-016 — Auto-WO from reorder / production mode
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `POST /work-orders/from-reorder`; `PATCH /items/{id}/production-mode` · **Role:** OWNER/ADMIN |

**Expected result:** The reorder sweep drafts one WO per **low-stock composite**
(qty = reorder − on-hand), idempotent (skips items with an open WO). `production-mode`
= **MTO** (only SO→WO fires) / **MTS** (only reorder fires) / null (both);
invalid value → `MFG_INVALID_PRODUCTION_MODE`.

**Actual / Status / Notes:**

---

## C. Backflush

### TC-MFG-020 — Backflush mode issues RM on FG receipt
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | WO create (backflush toggle) → receive · **Role:** OWNER/ADMIN |

**Expected result:** With **backflush ON**, `issue` does **not** consume RM;
instead each **FG receipt** auto-issues RM proportionally (ratio = received /
to-produce). Receiving 5 of 10 issues half the BOM. The non-backflush path is
unchanged.

**Actual / Status / Notes:**

---

## D. Job cards & shop floor

### TC-MFG-030 — Job card start / complete (time tracking)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/work-orders/:id/job-cards` (`POST /job-cards/{id}/start|complete`) · **Role:** OPERATOR |

**Expected result:** A job card goes PENDING → **IN_PROGRESS** (start stamps
`actualStart`) → **COMPLETED** (complete captures qty + time logged). Logged time
feeds actual-labour costing (TC-MFG-092).

**Actual / Status / Notes:**

---

### TC-MFG-031 — Shop-floor scan
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/manufacturing/shop-floor` (`GET /work-orders/by-number/{number}`) · **Role:** OPERATOR |

**Expected result:** Scanning/typing a WO number resolves the same WO + job
cards; big Start / Complete / Log-scrap buttons act inline; "scan next" refocuses.
Unknown number → not-found.

**Actual / Status / Notes:**

---

## E. Job work (subcontracting)

### TC-MFG-040 — Send + receive job work
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/job-work` (`POST /job-work`, `.../{id}/send|receive|cancel`) · **Role:** OWNER/ADMIN |

**Expected result:** Job work DRAFT → **SENT** posts **JOB_WORK_OUT** (stock to
the job-worker) → **receive** posts **JOB_WORK_IN** with wastage → COMPLETED.
Cancel reverses movements. **ITC-04** GST deadline alerts appear
(`/job-work/gst-alerts`).

**Actual / Status / Notes:**

---

## F. Quality Control

### TC-MFG-050 — QC template + inspection + finalize
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/qc/inspections` (`POST /qc/templates`, `/qc/inspections`, `.../results`, `.../finalize`) · **Role:** OWNER/ADMIN |

**Expected result:** Create a QC template with parameters; open an inspection
(INCOMING/IN_PROCESS/OUTGOING), record per-parameter results, **finalize** →
PASSED / FAILED / PARTIAL. **CoA** JSON available (`.../{id}/coa`).

**Actual / Status / Notes:**

---

### TC-MFG-051 — QC disposition (ACCEPT/REJECT/HOLD) + NCR
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | inspection → disposition (`POST /qc-inspections/{id}/disposition`) · **Role:** OWNER/ADMIN |

**Expected result:** On a finalized inspection, split the inspected qty across
ACCEPT/REJECT/HOLD (must sum to inspected qty, once only). **REJECT** posts a
negative `ADJUSTMENT` movement + auto-raises an **OPEN/MAJOR NCR**
(`/qc/ncrs`). **HOLD** requires a **QUARANTINE** zone. NCR closes via
`/qc/ncrs/{id}/close`.

**Actual / Status / Notes:**

---

## G. Scrap

### TC-MFG-060 — Record production scrap
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/manufacturing/scrap` (`POST /scrap/reason-codes`, scrap on WO) · **Role:** OWNER/ADMIN/OPERATOR |

**Expected result:** Create a reason code; record scrap on a WO/job card → a
`PRODUCTION_SCRAP` movement; the WO's scrap total updates. Scrap feeds the
scrap-rate dashboard (TC-MFG-091).

**Actual / Status / Notes:**

---

## H. MRP

### TC-MFG-070 — Run MRP + convert planned orders
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/mrp-runs` (`POST /mrp/run`, `.../planned-orders/{id}/convert-po|convert-wo`) · **Role:** OWNER/ADMIN |

**Expected result:** MRP aggregates demand (SO + forecasts), matches supply
(on-hand + open PO + WO), computes net requirement + safety stock, explodes BOMs,
and generates **planned orders** (PURCHASE for RM / PRODUCTION for composites).
Convert a planned order to a **PO** or **WO**.

**Actual / Status / Notes:**

---

## I. Maintenance

### TC-MFG-080 — Maintenance schedule → generate-due → complete
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/maintenance` (`POST /schedules`, `/schedules/generate-due`, `.../{id}/complete`) · **Role:** OWNER/ADMIN/OPERATOR |

**Expected result:** Create a preventive schedule (workstation + frequency days).
**Generate-due** creates a DRAFT maintenance WO per due schedule (idempotent —
skips one already open). Start → Complete computes **downtime** and rolls the
schedule's next-due forward. Guards: duplicate code `MAINTENANCE_DUPLICATE_CODE`;
bad frequency `MAINTENANCE_BAD_FREQUENCY`.

**Actual / Status / Notes:**

---

### TC-MFG-081 — Downtime + reliability (MTBF/MTTR)
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/manufacturing/reliability` + downtime (`GET /reports/downtime`, `/reports/reliability`) |

**Expected result:** Downtime aggregates completed maintenance WOs per workstation
(worst-first). Reliability computes **MTTR** (breakdown downtime / breakdowns),
**MTBF** (uptime / breakdowns), **availability %** — only BREAKDOWN feeds
MTBF/MTTR; a machine with no breakdowns shows 100% availability + null MTBF/MTTR.

**Actual / Status / Notes:**

---

## J. Advanced BOM

### TC-MFG-090 — BOM versioning + diff + alternates + co-products
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/manufacturing/bom-diff`, `/manufacturing/parameterized-bom` (`/bom/{id}/version`, `/diff`, `/bom-alternates`, `/bom-co-products`, `/cost-rollup`) · **Role:** OWNER/ADMIN |

**Expected result:** Create a new BOM version (snapshots + closes old dates).
**Diff** two versions → ADDED/REMOVED/CHANGED (same version → `BOM_DIFF_SAME_VERSION`).
**Alternate** substitute materials swap on a DRAFT WO line. **Co-products** are
also received on FG receipt (allocation Σ ≤ 100%). **Cost-rollup** returns the
recursive component-cost tree. **Parameterized** BOM resolves lines by variant
attributes.

**Actual / Status / Notes:**

---

## K. Reports

### TC-MFG-091 — Production reports
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/analytics` + reports (`/reports/production-summary|trends|cost-variance|wip-valuation|consumption|work-order-profitability|scrap-rate`) |

**Expected result:** Production summary (status counts, completion/on-time %, avg
yield). Trends (daily started/completed/produced/scrap). Cost variance (planned vs
actual, yield). WIP valuation (Σ IN_PROGRESS WO cost). Consumption (RM per item).
**Profitability** (revenue via SO link − cost, worst-margin first; no SO link →
revenue 0, source NONE). **Scrap-rate** (by reason + item). All read cleanly.

**Actual / Status / Notes:**

---

### TC-MFG-092 — Bottleneck + actual-cost preview
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/manufacturing/workstation-load`, `/manufacturing/actual-cost-preview` (`/reports/workstation-load|bottlenecks`, `/work-orders/{id}/actual-cost-preview`) |

**Expected result:** Workstation load sums open job-card hours per workstation →
BOTTLENECK/BUSY/OK/IDLE (worst-first). Actual-cost preview sums logged time ×
workstation rate for labour + org overhead rate; falls back to the WO's planned
estimate when no workstation rate is configured (amber warning).

**Actual / Status / Notes:**

---

## L. Industry packs — Pharma BMR & CAPA

### TC-MFG-100 — Batch Manufacturing Record (BMR)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/manufacturing/bmr` (`POST /bmr/step-records|signoffs|deviations`, `GET .../work-orders/{id}/snapshot|pdf`) · **Role:** OWNER/ADMIN/OPERATOR |

**Expected result:** Record in-process **parameters** (jc-to-wo membership checked
→ `BMR_JC_WO_MISMATCH`), **sign-offs** (OPERATOR/SUPERVISOR/QA/QC; unauthenticated
→ `BMR_SIGNOFF_NO_USER`), and **deviations** (OPEN→INVESTIGATING→RESOLVED/ACCEPTED).
**Yield reconciliation** = planned vs produced, ±2% tolerance → WITHIN/OUT. The
**snapshot** bundles all sections; the **PDF** renders a Schedule-M/WHO-GMP layout.

**Actual / Status / Notes:**

---

### TC-MFG-101 — CAPA lifecycle (self-verify blocked)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/manufacturing/capa` (`POST /capa`, `.../{id}/start|complete|verify|cancel`) · **Role:** OWNER/ADMIN/OPERATOR |

**Expected result:** Raise a CAPA (auto-number `CAPA-YYYY-NNNNN`, CORRECTIVE/
PREVENTIVE) → Start → Complete (stamps completer) → **Verify** by a **different**
user (self-verify → `CAPA_SELF_VERIFY_FORBIDDEN`) → VERIFIED. Cancelling a VERIFIED
CAPA → `CAPA_FINAL_STATE`. A CAPA against a CLOSED NCR is refused.

**Actual / Status / Notes:**

---

## M. Role / module gate

### TC-MFG-110 — OPERATOR limited to shop-floor
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | API various · **Role:** OPERATOR |

**Expected result:** OPERATOR can start/complete job cards, record scrap, and use
the shop-floor screen, but is **403** on masters + WO create/issue/complete/cancel,
routing, MRP, and maintenance-schedule CRUD (OWNER/ADMIN). (403 = pass.)

**Actual / Status / Notes:**

---

### TC-MFG-111 — Module gate hides Manufacturing for non-manufacturers
| | |
|---|---|
| **Priority / Type** | P2 / Role |
| **Route** | sidebar · **Role:** OWNER of a **retailer/distributor** org (no override) |

**Expected result:** The **Manufacturing** group is **not** in the sidebar unless
the org is a manufacturer or `MANUFACTURING` is enabled on the Modules screen
(doc 07). Manufacturing is a *strict* module — even the API is gated for
non-OWNER roles when the flag is off.

**Actual / Status / Notes:**
