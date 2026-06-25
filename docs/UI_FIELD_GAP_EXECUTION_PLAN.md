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

## Sprint B — Reusable primitives (multiply value of everything after)  ← ACTIVE
- [x] **B1. EntityPicker (primitive built + 1 proof wiring)** — `core/widgets/k_entity_picker.dart`: `showEntityPicker()` modal + `KEntityPickerField` form field + `EntityOption`/`EntitySearchFn`. Riverpod-free (caller supplies the search fn) so it drops into any screen. Exported via the widgets barrel. **Proof wiring:** manufacturing Scrap → Reason Code now uses it instead of a paste-UUID field. **Rollout TODO** (mechanical, do as each screen is touched + analyzed locally): operations/workstations/WO ids in Manufacturing (scrap WO/Item/JobCard, QC, routing, job-card create); route/salesperson/van/SO in Field Sales; GL accounts in Payroll settings + Amortization; bill/account/item in Vendor Credit; van/POD ids in MR app.
- [ ] **B2. Name resolution helper** — resolve ids→names for list/detail cards (WO BOM-lines, job cards, QC params, supplier rankings ['Supplier'], ABC list item UUIDs). Some are backend DTO name-joins (compile-verifiable), some client-side bulk lookups.
- [x] **B3. Sidebar un-orphan pass** — added 7 NavItems: Manufacturing (CAPA, Workstation Load, Equipment Reliability, Production Analytics) + Inventory (Warehouse Zones, Batch Trace, Batch Recall). FSSAI was already food-gated in nav (stale audit claim). Per-entity "paste-an-id" tool screens intentionally deferred to detail-screen wiring (needs B1 rollout).

## Sprint C — India-core flows
- [ ] **C1. POS returns / refund / void** (backend endpoint + receipt-detail action).
- [ ] **C2. POS credit / khata** (CREDIT payment mode → AR; show running balance).
- [ ] **C3. AR multi-invoice allocation + customer advance receipt** (allocation table + Receive-Payment screen).
- [ ] **C4. Supplier master CRUD** (list + create/edit).
- [ ] **C5. Multi bank-account master** + reconcile account picker.

## Sprint D — Statutory / compliance
- [ ] **D1. e-invoice signed-QR rendering** (image on e-invoice card + invoice PDF).
- [ ] **D2. Fiscal-year setup + year-end closing entry** (P&L→Retained Earnings).
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
