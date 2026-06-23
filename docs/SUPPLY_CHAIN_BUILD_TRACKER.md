# Supply Chain Build Tracker

**Last updated:** 2026-06-22
**Branch:** `claude/inspiring-ritchie-ygolsn`

## North star (from `SUPPLY_CHAIN_SUITE_BLUEPRINT.md`)
Replace the thin 7-item "Inventory" submenu with a 10-pillar supply chain suite.
**~85% of Phase-1 is already built.** The real gaps are statutory registers,
3-way match, photo-to-GRN, and information architecture (nav restructure).

---

## Recently shipped (this session)

- [x] **GS1 DataMatrix parser + drug_master GTIN lookup** — V12 migration adds `drug_master.gtin VARCHAR(14)` + partial index (most rows NULL until orgs populate). `GsOneDataMatrixParser` (pure utility, NOT a Spring bean) handles the CDSCO G.S.R. 823(E) top-300 pharma QR code mandate: AI (01) GTIN / (17) expiry / (10) batch / (21) serial / (11) MFG / (240) additional id, FNC1 (0x1D) separator + structure-aware no-FNC1 greedy fallback (boundary candidates validated against the next AI's expected fixed-length shape so "01" inside a serial "SN001" can't be misread as a new GTIN), GS1 sliding-year window (YY<50→2000+YY, else 1900+YY), expiry DD=00→last-of-month convention, `]d2` symbology-identifier prefix stripped. All failure modes throw `BusinessException("GS1_PARSE_FAILED", BAD_REQUEST)`. `BarcodeScanController @ GET /api/v1/inventory/barcode/scan?code=...` (OWNER/ADMIN/OPERATOR) returns `{parsed, drugMaster, item}` — drugMaster filled when the GTIN hits `DrugMasterRepository.findByGtinIgnoreCase`, item filled when the org has an `Item` whose name matches the drug's brandName (same heuristic as `PosCatalogService` catalog quick-add). 7 new tests (happy path w/ FNC1; scanner-stripped FNC1 keeps GTIN+expiry+batch — serial absorption is documented spec limitation; `]d2` strip; missing GTIN throws; expiry DD=00→last-of-month incl. Feb-non-leap edge; explicit DD=15; sliding year window). Flutter: `inventoryBarcodeScan` endpoint constant in `api_config.dart`; no new screen — camera-scan UX for DataMatrix needs the existing barcode stack extended (deferred follow-up). **1334/1334 backend tests pass.** Commit: `d77b89b`.
- [x] **Supplier rate contracts** (parked item, now built) — V11 migration adds `supplier_rate_contract` + `supplier_rate_contract_line` for negotiated unit prices per (supplier × item), mirroring `PriceListService` on the sell side. `SupplierRateContractService` (Clock-injected): DRAFT→ACTIVE→EXPIRED/CANCELLED lifecycle, `activate` walks lines + refuses `SRC_OVERLAPPING_ACTIVE` collisions with existing ACTIVE rows for the same (org, supplier, item), `findActiveRate(supplierContactId, itemId)` and `findActiveRateForSupplier(supplierId, itemId)` (resolves procurement Supplier→Contact by displayName). `PurchaseOrderService.buildLines` hooked: `PurchaseOrderRequest.LineRequest.unitPrice` is now nullable — when omitted, the rate-contract fallback fills it; when neither caller nor contract has a price, line throws `PO_LINE_NO_PRICE`. Explicit caller price wins (rate service not consulted). `SupplierRateContractExpiryJob` nightly sweep (cron `app.automation.rate-contract-expiry.cron`) flips contracts past `valid_until` to EXPIRED. `SupplierRateContractController @ /api/v1/procurement/rate-contracts`. Flutter `RateContractsScreen` (`/procurement/rate-contracts`) — list + status chip + per-row activate/expire/cancel menu + "New contract" dialog (supplier + validity + first line), sidebar entry + command palette "Rate contracts" (keywords supplier rates / negotiated / price contract / procurement). 7 new tests (create+auto-number, activate happy/conflict, sweep w/ fixed Clock, findActiveRate hit/miss, PO falls back to contract on null price, PO explicit price overrides contract). **1327/1327 backend tests pass.** Commit: `90251b3`.
- [x] **RFQ + quotation compare + award→PO** (parked item, now built) — V10 migration adds 5 tables (`rfq`, `rfq_line`, `rfq_supplier`, `supplier_quote`, `supplier_quote_line`) to model the shop-around step the existing PO flow short-circuits. `RfqService` (`@Lazy` PurchaseOrderService dep) full lifecycle: createRfq validates every supplier contact is VENDOR/BOTH (`RFQ_NOT_VENDOR`) + auto-numbers `RFQ-YYYY-NNNNN` like CAPA/MWO; send DRAFT→SENT; recordQuote creates RECEIVED `SupplierQuote` w/ supplied lines, auto-numbers `SQ-YYYY-NNNNN`, computes totalAmount from qty×unitPrice; compareQuotes returns per-supplier summaries (avg lead time) + per-line lowest price (grouped by itemId, free-text by description) + overall `lowestTotalQuoteId`; award flips winner→AWARDED, siblings→REJECTED, RFQ→AWARDED, then drafts a real PO via `PurchaseOrderService.create` w/ winning lines' itemId+unitPrice (auto-resolves a procurement Supplier from the winning vendor Contact via displayName match, creates one if absent — preserves PO's Supplier-id contract). `RfqController @ /api/v1/procurement/rfq` (`@RequiresModule SUPPLY_CHAIN`). Flutter `RfqScreen` (`/procurement/rfq`) — list w/ status chip, "New RFQ" FAB dialog (title + dueDate + first line + supplier contact UUIDs), bottom-sheet detail w/ per-quote KMoney totals + per-row Award gated by status, "Record quote" sub-dialog. Sidebar entry under Procurement + command palette "RFQ" (keywords quotation/compare/supplier quote/sourcing/bid). 7 new tests (create + auto-number + vendor validation, non-VENDOR rejected, send DRAFT→SENT, recordQuote w/ auto-number + total calc, compareQuotes lowest-per-line + lowest-total, award lifecycle + PO drafted w/ winning supplier+prices verified via ArgumentCaptor, cancel from DRAFT+SENT but RFQ_TERMINAL from AWARDED/CANCELLED). **1320/1320 backend tests pass.** Commit: `10184c6`.
- [x] **Schedule H prescription-required overlay** — V9 migration widens the `prescription_required=true` flag from H1 (46 substances, already flagged in V2) to ~110 well-known Schedule H generics across 14 therapeutic classes (anti-infectives, antifungals/antivirals, antidiabetics incl. insulin, cardiac, anticoagulants, gastric PPIs, thyroid/steroids, psychiatry SSRIs/antipsychotics, antiepileptics, respiratory, oncology/immunosuppressants, urology, neurology, migraine). Idempotent: `WHERE drug_schedule IS NULL OR drug_schedule = 'GENERAL'` guards rerun, H1/X/NARCOTICS rows never overwritten. POS impact: Flutter `pos_screen.dart` (~L233) already reads `item['prescriptionRequired']` for pharmacy orgs and triggers the prescription-number dialog before cart-add — so the V9 flag wiring takes effect immediately, no Flutter change required. Backend `StatutoryRegisterService.classify()` only treats H1 / SCHEDULE_X / NARCOTICS as register-trackable (Sch H is Rx-only, not bound to the 3-year retention sheet) — that's by design, no register-table writes from these new H rows. No integration test added — project has no `@SpringBootTest` Flyway-applied DB tests, only Mockito unit tests; verifying migration row counts would require booting Flyway+Postgres outside the existing pattern. List is curated, not exhaustive — extend by category as new substances enter the catalogue. Commit: `(commit pending)`.
- [x] **Photo-to-GRN (tracker task #4)** — `GrnScanService` (vision OCR tailored to goods-receipt fields: batch / expiry / received-qty / unit-cost, distinct from `BillScanService`'s tax-block prompt), `GrnDraftingService` (PO-line fuzzy match by item name with longest-match-wins + exact-beats-contains + no-double-binding, stamps `itemId` + `purchaseOrderLineId` end-to-end so the P2P FKs survive; standalone-no-PO path uses caller-supplied warehouse + supplier with item-master name lookup; unmatched lines drop from the draft + raise the suggestion priority + carry an `unmatchedCount` warning), DTOs (`GrnScanResponse` / `GrnDraftFromScanRequest` / `GrnDraftResult`), new `DRAFT_GRN` AiSuggestion type, `GrnDraftingController` @ `/api/v1/ai/grn-drafts` (OWNER/ADMIN/OPERATOR — operators record receipts). Approve calls `StockReceiptService.receive` (fires inventory + provisional-COGS reconciliation paths); reject calls `StockReceiptService.cancel` so the audit trail keeps the failed attempt instead of hard-deleting. Flutter: `aiGrnDrafts` / `aiGrnDraftScan` / approve / reject endpoints in `api_config.dart`, repo methods on `AiRepository`, PO detail screen overflow-menu "Scan invoice → draft GRN" entry (camera→gallery fallback for desktop, base64 + media-type plumbing, navigates to drafted GRN), AI Inbox accept/reject routing for `DRAFT_GRN` (mirrors `DRAFT_BILL`). 8 new tests (`GrnDraftingServiceTest` — PO match + FK stamping w/ MEDIUM priority, unmatched-line HIGH priority + skip, standalone-no-PO w/ warehouse + supplierId, no-PO + no-warehouse throws `GRN_DRAFT_WAREHOUSE_REQUIRED`, two scan lines mapping to same PO line first-wins + second-unmatched, approve calls `receive` + ACCEPT, reject calls `cancel` + REJECT, non-DRAFT_GRN suggestion throws `AI_NOT_DRAFT_GRN`). **1313/1313 backend tests pass.** Flutter analyze/test require local SDK (no Flutter SDK on PATH in cloud env). Commit: `95c379a`.
- [x] **AI local/remote toggle** (Ollama vs Claude) — commit `cf16715`, merged to main. `app.ai.use-local` flag.
- [x] **Bill-freely UX**: negative-stock items surfaced on items list — commit `aee6055`. Red −1 styling + filter chip.
- [x] **Provisional COGS + GRN true-up** (Option B) — commit `2c00301`. New `Stock-Out Suspense (2042)`, `CostResolverService`, `ProvisionalCostReconciler`, V5 migration, 14 new tests. Books self-heal at GRN time. **1273/1273 backend tests pass.**
- [x] **Statutory registers (Schedule H1 / X / Narcotics)** — V6 migration `statutory_register_entry`, `StatutoryRegisterService` (auto-record on POS sale, schedule normalisation, h1_strict gate, CSV export), India-only `StatutoryRegisterController` @ `/api/v1/pharma/statutory-registers`, Flutter `StatutoryRegistersScreen` with 3 tabs + CSV download + regulatory banner. 11 new tests. **1284/1284 backend tests pass.** See `CLAUDE.md` § "Statutory pharma registers (H1 / Schedule X / Narcotics) (2026-06-22)" for full design.
- [x] **3-way match (PO ↔ GRN ↔ Vendor Bill)** — backend commits `24a9643` (P2P FK plumbing — `purchase_order_id` / `purchase_order_line_id` linkage on bills + GRNs, `createGrnFromPo` / `createBillFromPo`, `receive` now updates `receivedQuantity` on the source PO line) + `bb597a7` (`ThreeWayMatchService` per-line classification — MATCHED / QTY_OVER / PRICE_HIKE / NO_PO / NO_GRN / BYPASSED, org-configurable tolerances `ap.three_way_match.*`, EXCEPTION rolls up to a `THREE_WAY_MATCH_EXCEPTION` AI Inbox suggestion, OWNER-only override w/ audit reason). **`recordStockForBill` decision: option a (intentional fallback)** — purchase bill posts a PURCHASE movement only when there's no PO + active GRN behind it; the P2P loop's GRN is the authoritative stock-posting step, so direct vendor bills keep working but the double-counting hole closes. Flutter UI: new `ThreeWayMatchInboxScreen` (`/ap/three-way-match`, Exceptions + Settings tabs, OWNER override dialog, shared `ThreeWayMatchDetailSheet` w/ per-line variance drill-in), sidebar entry under Purchases, command palette "3-Way Match" (keywords ap inbox / vendor bill / po grn / variance / audit / control / match / exception / three way / p2p / tolerance), bill detail banner (PO link + match status + "View match" entry point), PO detail "Create GRN from this PO" / "Create Bill from this PO" actions on SENT/PARTIAL POs. **1304/1304 backend tests pass.** See `CLAUDE.md` § "3-way match (PO ↔ GRN ↔ Vendor Bill) (2026-06-22)" + "P2P workflow integration (2026-06-22)" for full design.

---

## In flight / queued

### 2. [x] 3-way match (PO ↔ GRN ↔ vendor bill) — shipped 2026-06-22, see Recently shipped above
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

### 4. [x] Photo-to-GRN (AI invoice → draft GRN) — shipped 2026-06-22, see Recently shipped above

---

## Parked (Phase 2/3 — defer until distributor traction)

- ATP (Available-to-Promise) real-time order capture
- ~~RFQ / quotation compare~~ — shipped 2026-06-23, commit `10184c6`
- ~~Rate contracts (price lists exist; supplier-negotiated rates don't)~~ — shipped 2026-06-23, commit `90251b3`
- Supplier portal (self-service PO/ASN/invoice)
- ~~GS1 DataMatrix scanning (top-300 QR mandate — G.S.R. 823(E))~~ — parser + drug_master GTIN lookup shipped 2026-06-23, commit `d77b89b`; camera-scan Flutter UX deferred
- Cross-docking, ASN/putaway strategies
- Route optimization (courier *tracking* exists, optimization doesn't)
- Cold-chain / temperature monitoring (IoT loggers, WHO GDP 2–8 °C)
- Full S&OP / demand sensing
- Agentic replenishment (autonomous PO placement)

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
