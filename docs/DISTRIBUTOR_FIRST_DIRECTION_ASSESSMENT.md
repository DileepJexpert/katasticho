# Katasticho: Distributor-First Direction Assessment

This note is based on:

- [Indian Distributor, Pharma, and FMCG ERP Market Gaps.pdf](C:\dileepkm\Learning\erp-system\katasticho\docs\Indian Distributor, Pharma, and FMCG ERP Market Gaps.pdf)
- [Indian Distributor, Pharma, and FMCG ERP Market Gaps.txt](C:\dileepkm\Learning\erp-system\katasticho\docs\Indian Distributor, Pharma, and FMCG ERP Market Gaps.txt)
- current Katasticho codebase state as of 2026-05-31

## Core conclusion

Yes, Katasticho can shift in this direction without a rewrite.

The report's strongest recommendation is:

1. Distributor Core first
2. Pharma Trade Pack next
3. FMCG secondary-sales / van-sales pack next
4. Manufacturing-lite later

That direction matches the current codebase better than a manufacturing-first strategy.

## Why this fits the current codebase

Katasticho already has a strong base in the exact areas the report calls "table stakes plus operational trust":

- accounting backbone
- GST foundations
- inventory
- sales orders
- delivery challans
- purchase orders
- stock receipts / GRN
- price lists
- schemes
- low stock / reorder
- batch / expiry / FEFO-oriented pharmacy flows
- role/auth/module gating

This means the product is already closer to:

- distributor operational spine

than to:

- full manufacturing ERP
- deep FMCG route/beat/van execution

## What already aligns well

### 1. Distributor core

Already present or largely present:

- sales order workflow
- delivery challan workflow
- purchase order workflow
- stock receipt / GRN workflow
- stock and warehouse model
- price list support
- scheme support
- credit/outstanding reporting foundations
- inventory reporting
- audit trail / role controls

This is the biggest reason the report's recommendation is viable now.

### 2. Pharma trade pack

Already present or meaningfully underway:

- batch tracking
- expiry tracking
- near-expiry workflows
- FEFO-oriented POS/batch selection
- rack locations
- prescription-related extensions
- pharma item metadata

Pharma is not the best first wedge by itself, but it is a very strong domain pack on top of distributor core.

### 3. Migration-friendly product shape

Already useful:

- CSV import surfaces
- item import
- sample medical import templates
- seeded rack layout
- business-type / capability model

Still incomplete, but directionally correct for a switching market.

## What does not yet align

These are the main gaps against the report.

### 1. Single-screen operational speed

The report strongly emphasizes:

- fewer screen flips
- faster order entry
- inline warnings
- operator-speed execution

Katasticho is improving here, but today many workflows are still screen-by-screen and form-heavy.

Gap severity: High

### 2. Distributor-native execution surfaces

The report repeatedly calls out:

- loading sheets
- van statements
- route-wise reporting
- collections execution
- party-specific schemes
- branch/godown control in one operating flow

Katasticho currently has the backbone objects, but not the distributor control tower UX.

Gap severity: High

### 3. FMCG route / beat / van workflows

Mostly missing today:

- beat plans
- route plans
- van loading
- van unloading
- day-close wizard
- salesman incentive workflows
- route collections workflow
- secondary-sales dashboards

Gap severity: Very High

### 4. Migration wizard and cutover workflow

The report is right here: migration is not a side task.

Current repo has import tools, but not a serious migration operating layer:

- source mapping
- dry-run validation
- opening balance checks
- duplicate detection across ledgers/masters
- cutover checklist
- hypercare queue

Gap severity: High

### 5. Offline-first mobile execution

The report treats this as a major wedge.

Current Flutter app is multi-platform and capability-aware, but it is not yet a true:

- Android offline distributor execution app

with:

- sync queue
- conflict handling
- offline collections
- offline van stock
- offline route order capture

Gap severity: Very High

### 6. Manufacturing depth

Current manufacturing is still not a real production engine.

What exists is closer to:

- BOM/composite support

What is missing:

- work orders
- issue to production
- finished goods completion
- WIP
- production costing

This is exactly why the report says manufacturing should be later.

Gap severity: High, but strategically deferrable

## Recommended product position

The report's recommendation is sound for this codebase:

### Recommended top-level positioning

Katasticho should move toward:

`India-first distributor ERP with pharma and FMCG packs`

Not:

- generic ERP for everyone
- manufacturing-first ERP
- accounting-only SaaS

## Recommended sequencing for this repo

### Phase 1: Commit to Distributor Core

Strengthen what already exists:

- sales orders
- challans
- stock receipts
- purchase orders
- collections visibility
- party pricing / schemes
- branch / warehouse execution
- credit control

Concrete repo implication:

- prioritize distributor workspace and order-to-cash flow
- do not spend the next major phase on manufacturing

### Phase 2: Make Pharma a domain pack, not the base identity

Pharma should sit on top of distributor/retail inventory spine:

- batch
- expiry
- FEFO
- rack
- prescription extras
- returns / expiry settlement

Concrete repo implication:

- keep pharma-specific flows capability-gated
- avoid building parallel order domains where sales order already fits

### Phase 3: Build FMCG field execution pack

This is the largest new capability area:

- route / beat planning
- van stock
- van loading / unloading
- collection posting
- salesman workflows
- secondary-sales dashboards

Concrete repo implication:

- likely new modules, not just UI polish
- but still on top of the existing sales / inventory / accounting core

### Phase 4: Manufacturing-lite only after distributor spine is strong

Manufacturing can come later as:

- limited finished-goods / BOM extension first

not full MRP from the start.

## Practical fit score

### Good fit now

- Distributor Core: 8/10
- Pharma Trade Pack: 7.5/10

### Partial fit now

- Migration-led switching motion: 5/10
- Usability / operator-speed wedge: 5.5/10

### Weak fit now

- FMCG route / van / beat pack: 2.5/10
- Manufacturing-lite with real execution: 3/10
- Offline mobile distributor app: 2/10

## Decision

If the goal is to choose one market direction based on the current repo, the best decision is:

### Yes, switch toward this direction

but do it as:

1. Distributor-first
2. Pharma as a pack
3. FMCG field execution after distributor core
4. Manufacturing later

### Do not switch by doing these things

- do not make manufacturing the next major bet
- do not create duplicate backend domains when sales order / stock receipt already cover the same operational path
- do not present the app as all-verticals-equal right now

## Recommended next internal doc

The next useful project document should be:

`DISTRIBUTOR_CORE_EXECUTION_PLAN.md`

with:

- scope to keep
- scope to defer
- exact current modules to reuse
- exact new distributor UX surfaces to build
- exact FMCG pack boundaries

