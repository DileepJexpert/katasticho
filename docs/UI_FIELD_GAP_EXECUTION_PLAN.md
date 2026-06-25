# UI / Field Gap — Execution Plan (living tracker)

Derived from `docs/UI_FIELD_GAP_AUDIT.md` (2026-06-24). This is the **work tracker**: sprints run in sequence, each item a checkbox. Tick items as they ship; keep the audit doc as the reference detail.

**Status key:** `[ ]` todo · `[~]` in progress · `[x]` done.
**Note:** the cloud env has **no Flutter SDK** (`flutter analyze`/`test` must run locally/CI) and backend tests need Postgres; backend changes are validated with `./mvnw -q compile`.

---

## Sprint A — "Stop the bleeding" (broken now: bugs / 404s / phantom endpoints)  ✅ COMPLETE

- [x] **A1. Change-password** — added `POST /api/v1/auth/change-password` (`AuthService.changePassword` verifies current pw, blocks unchanged, keeps the session valid) + `ChangePasswordRequest` DTO; new `ChangePasswordScreen` routed at `/settings/change-password`, wired from both the profile-card pencil (was a no-op) and a new "Change Password" settings tile; Flutter repo verb aligned POST. **Backend compiles clean.**
- [x] **A2. Platform-admin Users tab 404** — added `GET /api/platform-admin/v1/users?search=&page=&size=` (new `AppUserRepository.searchAllForPlatformAdmin` JPQL) + `POST /users/{id}/deactivate` (bumps tokenVersion to kill sessions) + `/reactivate`, mirroring the suspend/reset patterns + PLATFORM_ADMIN protection. **Backend compiles clean.**
- [x] **A3. Integration screen non-functional** — repo realigned to real endpoints (`PUT /{id}` isActive toggle, `/sync?syncType=&direction=`) + real field names (`integrationType`/`isActive`/`lastSyncAt`), error-swallowing removed, **+ a "New connector" create FAB/dialog added**. Dead `integrationEnable/Disable` ApiConfig paths removed.
- [x] **A4. Field-sales payload-key mismatch** — repo now sends `skipReason` / `collectionAmount` (collection had been NPE'ing to a 500).
- [x] **A5. Target achievement GET-on-PUT** — converted the broken GET into `updateTargetAchievement(id, achievedValue)` PUT (matches `@PutMapping`; lays the correct method for E4).
- [x] **A6. 3-way-match Override** — gate widened to `OWNER || ADMIN` (`isOwner`→`canOverrideRole`).
- [x] **A7. Currency `isBase`** — removed the non-existent-field read; now shows `decimalPlaces` + an Inactive chip from `isActive`.
- [x] **A8. Courier chevron** — misleading `chevron_right` removed.
- [x] **A9. 3 dead PDF screens** — RESOLVED BY REMOVAL: invoice/bill/estimate detail already have working "Download PDF" via the shared server-rendered `KPdfPreviewScreen`; the three client-side `*PdfScreen` classes were redundant dead code (0 external refs) and were deleted.

## Sprint B — Reusable primitives (multiply value of everything after)  ✅ PRIMITIVES DELIVERED (broad rollout tracked)
- [x] **B1. EntityPicker (primitive built + 1 proof wiring)** — `core/widgets/k_entity_picker.dart`: `showEntityPicker()` modal + `KEntityPickerField` form field + `EntityOption`/`EntitySearchFn`. Riverpod-free (caller supplies the search fn) so it drops into any screen. Exported via the widgets barrel. **Wired into Scrap:** Reason Code → `KEntityPickerField` (backed by `scrapReasonCodesProvider`); Item → the proven `showItemPicker` modal. (WO + Job Card fields still paste-UUID — need a WO-list search source; tracked.) **Rollout TODO** (mechanical, do as each screen is touched + analyzed locally): operations/workstations/WO ids in Manufacturing (scrap WO/Item/JobCard, QC, routing, job-card create); route/salesperson/van/SO in Field Sales; GL accounts in Payroll settings + Amortization; bill/account/item in Vendor Credit; van/POD ids in MR app.
- [x] **B2. Name resolution — pattern + SCM + Manufacturing done.** `@Transient` name field + cached resolve helper pattern (no migration — Hibernate ignores transient fields).
  - **SCM:** `SupplierPerformance.supplierName` (rankings/scorecard) + `ReorderPolicy.itemName` (ABC/reorder) → rankings show the real supplier (was literal `'Supplier'`); ABC list shows item names (was a UUID prefix).
  - **Manufacturing:** `WorkOrder.finishedGoodName` + `WorkOrderLine.itemName` resolved in `getWorkOrder`/`getWorkOrderByNumber`/`listWorkOrders` (list refactored to a thin name-resolving wrapper over `queryWorkOrders`); `JobCard.operationName`/`workstationName`/`assigneeName` resolved in `getJobCardsForWorkOrder` (RoutingService gained `AppUserRepository`). WO detail title now shows "WO-00042 · «FG name»", BOM lines show item names, WO list cards show the FG name, job-card title/sheet show operation/workstation names.
  - **QC:** `QcInspection.itemName`/`inspectorName`/`batchNumber`/`referenceLabel` + `QcInspectionResult.parameterName` resolved in `getInspection` + `listInspections` (QualityControlService gained `AppUserRepository`). QC detail now names the item/inspector/batch/reference-WO and each result's parameter (was "Param: «uuid»").
  - **Verified:** `mvn compile` + `mvn test-compile` clean; the three affected unit-test classes (QualityControl/Routing/SupplyChain) **pass**; their manual-constructor / `@InjectMocks` fixtures updated for the new repo deps.
  - **B2 name-resolution surface from the audit is now complete.**
- [x] **B3. Sidebar un-orphan pass** — added 7 NavItems: Manufacturing (CAPA, Workstation Load, Equipment Reliability, Production Analytics) + Inventory (Warehouse Zones, Batch Trace, Batch Recall). FSSAI was already food-gated in nav (stale audit claim). Per-entity "paste-an-id" tool screens intentionally deferred to detail-screen wiring (needs B1 rollout).

## Sprint C — India-core flows
- [~] **C1. POS returns / refund / void** — **backend DONE + tested.** V9 migration adds `sales_receipt.status` (COMPLETED|RETURNED CHECK) + `reversal_journal_entry_id` / `returned_at` / `return_reason` / `returned_by` + a partial index. `SalesReceiptService.voidReceipt(id, reason)` reverses the Cash/Revenue+COGS journal (`journalService.reverseEntry`) and restocks every SALE movement (`inventoryService.reverseMovement` — restores qty + FIFO lots), flips the row to RETURNED, idempotent (`SR_ALREADY_RETURNED`). Endpoint `POST /api/v1/sales-receipts/{id}/return` (OWNER/ADMIN/ACCOUNTANT — OPERATOR excluded; cash-sale reversal is sensitive). `status` surfaced on `SalesReceiptResponse`. Tests: `SalesReceiptReturnTest` (3 — reverse journal+restock+flip, double-return throws, no-journal-still-restocks) **pass**. **Flutter DONE:** `SalesReceiptDetailScreen` shows a "Return / void" app-bar action (only when status==COMPLETED) → confirm dialog w/ optional reason → `PosRepository.returnReceipt` (`POST .../return`) → invalidates the detail provider; a red "returned/voided" banner renders when status==RETURNED. `ApiConfig.salesReceiptReturn` added. (List-row RETURNED badge optional follow-up.) **flutter analyze pending locally.**
- [ ] **C2. POS credit / khata** (CREDIT payment mode → AR; show running balance).
- [ ] **C3. AR multi-invoice allocation + customer advance receipt** (allocation table + Receive-Payment screen).
- [x] **C4. Supplier master CRUD** — backend CRUD (`/api/v1/suppliers`) + `SupplierRepository` already existed (only a picker sheet shipped). Added `SupplierListScreen` (`/suppliers`, sidebar Purchases ▸ Suppliers) — searchable list + FAB → `SupplierFormSheet` (create/edit: name/GSTIN/PAN/phone/email/address/city/state/postal/payment-terms-days/notes/active). Reuses the existing `supplierListProvider`/`supplierRepositoryProvider` + the picker's proven K-widget idioms. **flutter analyze pending locally** (one API bug caught + fixed pre-commit: `KButton.isLoading`, not `loading`).
- [ ] **C5. Multi bank-account master** + reconcile account picker.

## Sprint D — Statutory / compliance
- [ ] **D1. e-invoice signed-QR rendering** (image on e-invoice card + invoice PDF).
- [~] **D2. Year-end closing entry** — **backend DONE + tested.** `YearEndCloseService.closeYear(fiscalYear)` posts the closing journal that zeroes every REVENUE/EXPENSE account for the FY into **Retained Earnings (3020)** — profit credits RE, loss debits it; balanced by construction (Σdebit=Σcredit). FY range derived from `org.fiscalYearStart`; per-account nets from the existing `computeAccountTotalsForPeriod`. Idempotent per (org, FY) via a deterministic `sourceId` marker (`YEAR_END_ALREADY_CLOSED` on re-close; a reversal re-opens). New `DefaultAccountPurpose.RETAINED_EARNINGS` (3020 already seeded for all industries). Endpoint `POST /api/v1/accounting/periods/year-end-close/{fiscalYear}` (OWNER/ADMIN/ACCOUNTANT). Tests: `YearEndCloseServiceTest` (4 — profit→CR RE, loss→DR RE + balance assertion, idempotent re-close throws, no-activity posts nothing) **pass**. **Flutter close screen + period-lock-on-close still TODO.**
- [ ] **D3. TDS register + TCS register screens** + Form 16 PDF / 24Q CSV / FVU download buttons.
- [ ] **D4. GST IMS Accept/Reject/Pending** tab.
- [ ] **D5. VAT201 (UAE) + Oman VAT return screens** (Gulf launch).

## Sprint E — Close the backend-complete / UI-absent set
- [ ] **E1. Payroll:** salary-structure builder, Form 12BB tax declaration, PF-ECR/ESI/bank-salary file downloads.
- [ ] **E2. Inventory:** serial-number UI, consignment/VMI, warehouse management (+ backend PUT/DELETE), customer↔price-list assignment.
- [ ] **E3. Manufacturing:** QC disposition/NCR/CoA, QC templates, Operations master, BOM editor.
- [ ] **E4. Field Sales:** target create/update, assignment screen, van-load UI, add-customer-to-beat (+geo).
- [ ] **E5. Trade Ops:** partner place-order + catalog publish; SCM PR/return/shipment/item-supplier create+detail; courier book+track; integration create form.
- [ ] **E6. MR app:** RCPA, field customer onboarding, FCM token registration, collection payment-mode/UTR, offline-first bootstrap.

## Continuous — form-field completeness (pattern #10)
- [ ] Contact form (~26 missing fields), Invoice create (due-date/POS/RCM/notes/terms + edit screen), SO create (bill/ship addr, order discount, freight), GRN (warehouse/mfg-date/landed-cost), Org profile (logo/FY/currency/bank).

---

### Progress log
- 2026-06-24 — Plan created from the audit. Sprint A started.
- 2026-06-24 — **Sprint A COMPLETE** (A1–A9). Backend (A1 change-password, A2 platform-admin users) verified with `mvn compile` (clean). Flutter changes pattern-matched to existing screens; `flutter analyze` still pending locally (no SDK in this container). Next: Sprint B (EntityPicker / name-resolution / sidebar un-orphan).
- 2026-06-24 — **Sprint B primitives delivered.** B3 sidebar un-orphan (7 NavItems). B1 `KEntityPicker` widget built + exported + proof-wired into Scrap. B2 name-resolution pattern established (`@Transient` name + cached resolver) + SCM supplier-rankings + ABC done — `mvn compile` clean. Remaining: broad EntityPicker rollout + manufacturing UUID→name resolution (tracked on B1/B2). **Recommend a local `flutter analyze` pass now** before more unverified Flutter accumulates.
