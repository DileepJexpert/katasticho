# Supply Chain Build Tracker

**Last updated:** 2026-06-22
**Branch:** `claude/inspiring-ritchie-ygolsn`

## North star (from `SUPPLY_CHAIN_SUITE_BLUEPRINT.md`)
Replace the thin 7-item "Inventory" submenu with a 10-pillar supply chain suite.
**~85% of Phase-1 is already built.** The real gaps are statutory registers,
3-way match, photo-to-GRN, and information architecture (nav restructure).

---

## Recently shipped (this session)

- [x] **AI local/remote toggle** (Ollama vs Claude) — commit `cf16715`, merged to main. `app.ai.use-local` flag.
- [x] **Bill-freely UX**: negative-stock items surfaced on items list — commit `aee6055`. Red −1 styling + filter chip.
- [x] **Provisional COGS + GRN true-up** (Option B) — commit `2c00301`. New `Stock-Out Suspense (2042)`, `CostResolverService`, `ProvisionalCostReconciler`, V5 migration, 14 new tests. Books self-heal at GRN time. **1273/1273 backend tests pass.**

---

## In flight / queued

### 1. [ ] Statutory registers (Schedule H1 / X / Narcotics) — NEXT
**Why:** Pharma regulatory must-have. Rule 65(11)(h) requires a separate H1 register
(prescriber, patient, drug, qty) with 3-year retention. Form 20G + Schedule X needs
Form 19C tracking + 2-year retention. NDPS Forms 3D/3E/3H for narcotics.
Without these, a drug-inspector visit will fail.
**Scope:**
- Backend V6 migration: `statutory_register_entry` (type, sale_receipt_id, drug, batch, qty, prescriber, patient, retention_until)
- `StatutoryRegisterService` — auto-record on POS sale of H1/X items; CRUD; export
- `StatutoryRegisterController` — list/get/export (CSV for inspector)
- Flutter screen under Compliance pillar (when nav restructure lands)
- Tests: auto-recording on sale, retention computation, separate registers per type

### 2. [ ] 3-way match (PO ↔ GRN ↔ vendor bill)
**Why:** Finishes the P2P flow. AP teams can't trust the system without it.
Today GRN + bill exist independently — no automatic match, no tolerance, no
exception queue.
**Scope:**
- Backend: `ThreeWayMatchService` — compare PO line × GRN line × Bill line on qty + unit price + amount with org-configurable tolerances (default ₹1 + 0.5%)
- AP inbox entries for mismatches (use existing AiSuggestion infra)
- Auto-mark bill as MATCHED / EXCEPTION on creation
- Endpoint: `POST /api/v1/ap/three-way-match/{billId}` (manual re-run)
- Tests: exact match, qty over-receipt, price mismatch, missing GRN

### 3. [ ] 10-pillar nav restructure (Flutter sidebar)
**Why:** Doc's #1 recommendation. Surfaces ~85% of supply-chain features that
exist but are buried under "Inventory > 7 items". Pure UX, no backend.
**Scope:**
- Reorganize `flutter_app/lib/core/widgets/sidebar.dart` (or equivalent) into:
  Planning · Procurement · Suppliers · Inventory & Warehouse · Orders ·
  Logistics · Manufacturing · Returns · Compliance · Control Tower
- Existing routes re-grouped, no new screens needed (every route already exists)
- Verify command palette still works
- Add `(coming soon)` stubs ONLY for what doesn't exist yet (avoid)

### 4. [ ] Photo-to-GRN (AI invoice → draft GRN)
**Why:** Highest-ROI AI feature for distributors per the blueprint. Marg has
this. We already have `BillScanService` (photo → draft bill) so 80% is built.
**Scope:**
- Extend `BillScanService` → `GrnScanService.draftGrnFromPhoto(image, poId)`:
  matches PO lines by item name fuzzy, fills batch/expiry/qty/cost from photo
- New `DRAFT_GRN` AiSuggestion type — approve posts via `StockReceiptService.receive`
- Endpoint: `POST /api/v1/ai/grn-drafts`
- Tests: line-match by name, missing PO → standalone GRN draft

---

## Parked (Phase 2/3 — defer until distributor traction)

- ATP (Available-to-Promise) real-time order capture
- RFQ / quotation compare
- Rate contracts (price lists exist; supplier-negotiated rates don't)
- Supplier portal (self-service PO/ASN/invoice)
- GS1 DataMatrix scanning (top-300 QR mandate — G.S.R. 823(E))
- Cross-docking, ASN/putaway strategies
- Route optimization (courier *tracking* exists, optimization doesn't)
- Cold-chain / temperature monitoring (IoT loggers, WHO GDP 2–8 °C)
- Full S&OP / demand sensing
- Agentic replenishment (autonomous PO placement)
- Full Schedule H register (46 H1 substances flagged today; Sch H 500+ later)

---

## Verification debt
- `flutter analyze` + `flutter test` on both apps (cloud env has no Flutter SDK)
- Local boot smoke with V5 migration applied

---

## Conventions
- New migration = **V6** (V5 is the provisional COGS one shipped today)
- Branch: `claude/inspiring-ritchie-ygolsn` until merged to main
- Commits: conventional (`feat(...)`, `fix(...)`)
- Tests required for every service method that touches the database
