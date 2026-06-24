# Katasticho ERP — UI / Field Gap Audit (low-level, module-by-module)

**Date:** 2026-06-24 · **Branch:** `claude/tender-faraday-wskqch`
**Scope:** Both repos — `katasticho` (Spring Boot backend + `flutter_app` web/admin) and `katasticho-mr-salesman-app` (Flutter field app).
**Method:** 11 parallel deep-review passes. For every domain we read the JPA entities, the request/response DTOs, the controllers (endpoints + roles), then the actual Flutter screens (create / edit / detail / list) and `api_config.dart`, and compared four surfaces: **DB/entity fields ↔ DTO fields ↔ what the UI captures/shows ↔ what a real Indian-SMB ERP needs.** Findings were verified against actual code — **not** the CLAUDE.md "DONE" claims (several of which are stale; corrections are noted inline).

> This document is the synthesis. The full per-domain detail (coverage maps + every gap with file paths + suggested fix) is in **Part 2** below.

---

## 1. Headline

The **backend is far more complete than the UI**. Across the codebase there are **159 REST controllers / 1,166 endpoints / ~150 API groups**, but the Flutter app references only **~604 distinct `/api/v1` paths** — **roughly half the backend is never reachable from the UI**. Dozens of services that CLAUDE.md marks "DONE" are backend-only, have a screen that isn't in the sidebar, or have a screen that omits most of the fields the backend accepts.

**Aggregate gap counts (≈316 findings; some cross-domain overlap, e.g. FCM push appears twice):**

| # | Domain | P1 | P2 | P3 | Headline gap |
|---|--------|----|----|----|--------------|
| 1 | Sales & AR | 11 | 11 | 7 | Invoice can't show IRN/QR/e-way; no advance/multi-invoice receipt; no invoice edit |
| 2 | Procurement & AP | 7 | 12 | 8 | No Supplier master CRUD; no standalone vendor-payment; TDS uncapturable |
| 3 | Inventory & Pricing | 8 | 11 | 8 | Serial tracking, consignment, warehouse mgmt = zero UI; no customer↔price-list |
| 4 | Accounting / Tax / GST / VAT | 9 | 18 | 8 | Whole VAT module, GST IMS, year-end close, journal-reverse = no UI |
| 5 | Manufacturing | 13 | 12 | 6 | QC disposition/NCR/CoA no UI; ~12 screens orphaned; paste-a-UUID everywhere |
| 6 | Field Sales / MR (ERP) | 7 | 10 | 5 | Can't set targets, create assignments, load vans, assign beat customers |
| 7 | HR & Payroll | 6 | 8 | 10 | Salary-structure builder unreachable; Form 12BB dark; statutory files undownloadable |
| 8 | Pharma / POS / Loyalty / Contacts | 6 | 9 | 4 | No POS returns; no POS credit/khata; contact form missing ~26 fields; no loyalty config |
| 9 | Trade & Finance Ops | 12 | 17 | 8 | Partner buy-loop dead; SCM/courier list-only shells; integrations non-functional |
| 10 | Platform & Shared | 6 | 15 | 12 | Change-password phantom; platform-admin 404s; push dead; org logo/FY/bank unsettable |
| 11 | MR Salesman App | 5 | 11 | 13 | No RCPA, no field customer onboarding, no FCM, collections amount-only, offline partial |
| 0 | Cross-cut (routing) | – | 3 | – | 3 PDF screens (invoice/bill/estimate) defined but unreachable |
| | **TOTAL** | **~90** | **~137** | **~89** | |

---

## 2. Systemic patterns (fix the pattern, not just the instance)

These ten patterns explain the great majority of the 316 findings. Each is cheaper to fix as a convention than one screen at a time.

1. **Backend-complete, UI-absent.** Entire feature-complete services have no screen: UAE/Oman **VAT returns**, GST **IMS Accept/Reject/Pending** (8 endpoints), **serial-number** tracking, **consignment/VMI**, **warehouse management**, **salary-structure builder**, **Form 12BB tax declaration**, PF-ECR/ESI/bank-salary file downloads, SCM **multi-supplier sourcing**, **WhatsApp inbound-order** inbox, org **audit-log** viewer, AI **transaction categorization**. → Treat "endpoint exists" ≠ "feature shipped"; every controller needs a screen-coverage check.

2. **"Paste-a-UUID" data entry.** Real users are asked to hand-type entity UUIDs because there's no picker: all of Manufacturing (item/operation/workstation/template/reason-code/WO ids), Vendor Credit (bill + account), Payroll GL-account mapping, Amortization accounts, Field-Sales route/salesperson/van/SO ids, route-execution warehouse, MR-app van-load + POD ids. → A reusable searchable-picker is the single highest-leverage fix; the pattern already exists in `work_order_create_screen.dart` item search.

3. **Orphaned screens (built, routed, but not in the sidebar).** ~12 Manufacturing screens (Production Analytics, CAPA, BMR, Reliability, Bottleneck, BOM Diff, etc.), 5 Inventory screens (**Batch Recall** — a safety feature!, Batch Trace, Warehouse Zones, FSSAI, FIFO Valuation). Reachable only by command palette/URL = invisible to most users. → Add NavItems or hang them off the relevant detail screen.

4. **List-only shells with dead repo methods.** SCM, Partner Network, Courier and Integration repositories carry full `create*/detail*/sub-flow` methods **that no screen ever calls**: `placeOrder`, `publishCatalogItem`, `createRequisition`, `createReturnOrder`, `addItemSupplier`, `getForecasts`, `calculateSupplierPerformance`, `convertAmount`, courier book/track. Gives a false "done" impression while the core action is unreachable. → Wire the dead methods to create/detail screens.

5. **No edit screen / no draft correction.** Invoice, Purchase Bill, Credit Note, Scheme, Price-list header, Freight rate card all lack an edit path (several have a working backend `PUT` that's never called) — a typo means cancel + recreate. → Add edit-for-DRAFT screens reusing the create form.

6. **UUIDs shown instead of names.** Detail/list cards render raw ids: Work-order BOM lines + job cards, QC inspection params, SCM supplier rankings (literally the string `'Supplier'`), ABC list (item UUID), notification deep-links. → Resolve names in the DTO (join) or client-side bulk lookup.

7. **Statutory / compliance holes (India + Gulf).** e-invoice **signed QR is stored as text, never rendered** as a scannable image (legally must print on B2B invoices); no **year-end closing** entry (P&L→Retained Earnings) or fiscal-year setup; no dedicated **TDS/TCS registers**; **Form 16 PDF / 24Q CSV / FVU** generators exist but have no download button; whole **VAT201/Oman/PINT-AE** suite has no UI; **GST 2.0 rate-remap** + **CMP-08** + **month-end close** screens missing.

8. **India-core retail/trade flows missing.** **No POS returns/refund/void** (sale can never be reversed → stock + cash overstated); **no POS credit/khata** (sale-on-account to AR — a core kirana flow); **no customer advance / on-account receipt**; **no multi-invoice allocation on AR** (AP already has it — asymmetric); **no Supplier master CRUD**; **single hardcoded bank account** (no multi-bank reconciliation).

9. **Push notifications dead end-to-end (both apps).** Backend FCM v1 sender + register endpoint are real, but neither the ERP Flutter client nor the MR app ever registers a device token (`push_notification_service.dart` is an all-TODO stub; MR app has no `firebase_messaging` at all). Every server push — daily-report reminder, low-stock, collections, approvals — reaches **zero phones**.

10. **Form omits backend-supported fields.** Forms routinely send a fraction of the DTO: Contact create (~26 of 40+ fields — shipping address, opening balance, bank/UPI, TDS, MSME), Invoice create (due-date/place-of-supply/RCM/notes/terms), SO create (bill/ship addresses, order discount, freight), GRN (warehouse, mfg-date, landed cost), Org profile (logo/fiscal-year/currency/bank), Workstation (rate/capacity), Expense (customer/project/receipt).

---

## 3. Broken **right now** (bugs, 404s, phantom endpoints) — fix first, cheap

These are not "missing features" — they are wired to fail or silently corrupt data:

- **Change-password is a phantom** — Flutter `auth_repository.changePassword` → `POST /api/v1/auth/change-password` which **has no backend mapping**; the Settings edit pencil is `onPressed: () {}`. A logged-in user cannot rotate their password. _(Platform §)_
- **Platform-admin Users tab is 404** — screen calls `GET /api/platform-admin/v1/users` (no mapping) and deactivate/reactivate endpoints that don't exist → whole tab dead. _(Platform §)_
- **Integration screen is non-functional** — reads DTO fields that don't exist (`status`/`enabled`/`type` vs real `integrationType`/`isActive`/`lastSyncAt`), toggle/sync call non-existent `/enable`//`/sync`-no-params endpoints, and `catch(_) → []` swallows errors so any failure shows "nothing configured." _(Trade §)_
- **Field-sales payload-key mismatch** — repo sends `{amount}` / `{reason}` but the controller reads `collectionAmount` / `skipReason` → visit **collection & skip silently post nulls** on a strict backend. _(Field-Sales §)_
- **`getTargetAchievement` GETs a PUT-only endpoint** — 404/405s if ever called. _(Field-Sales §)_
- **3-way-match Override hidden from ADMINs** — button gated `role=='OWNER'` but backend allows OWNER+ADMIN. _(Procurement §)_
- **Currency catalogue reads non-existent `isBase`** — no currency is ever flagged base. _(Trade §)_
- **Courier shipment tile shows a chevron with no `onTap`** — implies a detail screen that doesn't exist. _(Trade §)_
- **3 PDF screens unreachable** — `InvoicePdfScreen` / `BillPdfScreen` / `EstimatePdfScreen` defined, navigated to from nowhere → print/preview is dead code. _(Cross-cut §)_

---

## 4. The P1 list (must-fix to be a credible ERP), by domain

Concise; full context + fixes for each in Part 2.

**Sales & AR** — (1) invoice e-invoice IRN/QR + e-way panel; (2) AR multi-invoice allocation + customer advance receipt; (3) invoice create header (due-date/place-of-supply/RCM/notes/terms) + an invoice **edit** screen; (4) invoice detail show TCS/RCM/place-of-supply/currency; (5) SO bill-to/ship-to capture; (6) SO credit-limit/overdue **warnings** rendered on detail.

**Procurement & AP** — (7) standalone Vendor-Payment screen (multi-bill allocation + TDS + reference); (8) vendor advance / on-account payment; (9) TDS capturable on bill/payment + shown on bill detail; (10) **Supplier master CRUD**.

**Inventory & Pricing** — (11) Serial-number UI (lookup + capture + `trackSerialNumbers` toggle); (12) Consignment/VMI UI; (13) Warehouse management screen (+ backend PUT/DELETE); (14) customer↔price-list assignment; (15) surface the 5 sidebar-orphaned screens (Batch Recall first); (16) item form `preferredVendorId` + `trackSerialNumbers`.

**Accounting / Tax / GST / VAT** — (17) VAT201-UAE screen; (18) Oman VAT screen; (19) GST **IMS** Accept/Reject/Pending; (20) TDS register; (21) TCS register; (22) journal **Reverse** action; (23) **fiscal-year setup + year-end close** (P&L→Retained Earnings).

**Manufacturing** — (24) QC disposition + NCR + CoA UI; (25) QC template management; (26) **Operations master** screen; (27) WO create: priority/routing/BOM-version/SO-link; (28) WO list/detail show FG **name**/priority/approval; (29) resolve item/operation/workstation **names** on WO BOM-lines + job cards; (30) merge/clone/disassembly WO UI; (31) job-work ITC-04 deadline + challan surfacing; (32) un-orphan the ~12 palette-only screens; (33) Job-Cards entry point from WO detail.

**Field Sales / MR (ERP)** — (34) salesman-target create/update-achievement; (35) field-sales **assignment** screen; (36) **van load / stock-transfer** UI; (37) add-customer-to-beat (sequence/frequency/**geo-coords**).

**HR & Payroll** — (38) **salary-structure builder**; (39) employee **tax-declaration / Form 12BB**; (40) statutory file downloads (**PF ECR / ESI / bank-salary**).

**Pharma / POS / Loyalty / Contacts** — (41) **POS returns/refund/void**; (42) **loyalty program/tier/enrolment** config; (43) **contact form** ~26 missing fields; (44) add-contact-**person** UI; (45) **POS credit/khata** mode.

**Trade & Finance Ops** — (46) partner **place-order** loop; (47) partner **catalog publish** form; (48) SCM **multi-supplier sourcing** UI; (49) SCM purchase-requisition create + detail; (50) SCM return-order create + detail; (51) SCM shipment create + detail; (52) integration **add/create** form; (53) courier shipment **book + detail + tracking**; (54) transport **lorry-receipt detail**; (55) integration toggle/sync wired to **real** endpoints; (56) **multi bank-account** master + reconcile picker.

**Platform & Shared** — (57) change-password screen + endpoint; (58) platform-admin global-users list + deactivate (fix 404s); (59) **FCM push** registration on the ERP client; (60) org profile logo/fiscal-year/currency/**bank** (+ DTO/entity); (61) warehouse-management screen; (62) audit-log viewer (+ controller).

**MR Salesman App** — (63) **RCPA** screen; (64) field **customer onboarding**; (65) **FCM** token registration; (66) collection **payment-mode/UTR/receipt** (backend + app); (67) push (same FCM gap).

---

## 5. Suggested sequencing

- **Sprint A — "stop the bleeding" (days):** §3 broken-now list (change-password, platform-admin 404s, integration endpoints, field-sales payload keys, 3-way-match role, PDF-screen wiring, currency isBase). Small, high-trust wins.
- **Sprint B — reusable primitives:** one searchable **EntityPicker** (kills pattern #2 across Manufacturing/Field-Sales/Payroll/Vendor-Credit/MR-app), a **name-resolution** helper for list/detail cards (pattern #6), and a sidebar pass to un-orphan built screens (pattern #3). These multiply the value of everything after.
- **Sprint C — India-core flows (pattern #8):** POS returns + POS credit/khata, AR advance + multi-invoice allocation, Supplier master CRUD, multi bank-account.
- **Sprint D — statutory (pattern #7):** e-invoice QR render, year-end close, TDS/TCS registers + Form 16 PDF/24Q CSV, GST IMS, then VAT201/Oman for Gulf.
- **Sprint E — close the backend-complete/UI-absent set (pattern #1, #4):** salary-structure builder + Form 12BB + payroll file downloads, serial/consignment/warehouse, SCM/partner/courier/integration create+detail, MR-app RCPA + onboarding + FCM + offline-first.
- **Continuous:** form-field completeness pass (pattern #10) — Contact, Invoice, SO, GRN, Org-profile each have a backlog of DTO-supported fields the form drops.

---

## 6. Stale CLAUDE.md claims found during the audit (worth correcting in the doc)

- **3-way-match Flutter UI exists** (`three_way_match_inbox_screen.dart` + detail sheet + bill banner) — CLAUDE.md implies backend-only.
- **Field org-chart / SSS / RCPA ERP screens exist** (`field_org_chart_screen.dart`, `secondary_sales_screen.dart` 923 lines, `rcpa_screen.dart` 920 lines) — CLAUDE.md marks all three "ERP Flutter UI TODO".
- **e-invoice & e-way-bill actions are wired** (generate-gsp / cancel / portal-json / record / check-vehicle in `gst_compliance_tabs.dart`) — the real e-invoice gap is **QR image rendering**, not the actions.
- **Push notifications are NOT "DONE" on the client** — backend yes, both Flutter clients never register a token.

---

# Part 2 — Detailed per-domain findings

Each section below is the verbatim deep-audit for that domain (coverage map + every gap with severity, backend path, Flutter path, ERP rationale, and a suggested fix). Cross-cutting routing analysis first, then the 11 domains.



---

# Cross-cutting: Routing, Navigation & API-surface coverage

## Headline metrics (whole codebase)
- Backend: **159 `@RestController`** classes, **1,166 endpoint mappings**, **150** top-level `/api/v1/*` groups.
- Main Flutter app: **474 dart files**, **240 `*_screen.dart`** files, **245 GoRoute paths**, **141 NavItems** across **29 NavGroups**.
- Flutter references **~604 distinct `/api/v1` paths** → roughly **half** the backend endpoint surface is never called by the UI (reports, sub-actions, admin, many "DONE-in-backend" services).
- MR app: 30 dart files, 13 screens.

## Orphaned screens (defined but never navigated to)
- **[P2] Invoice PDF preview not reachable** — `InvoicePdfScreen` defined, referenced nowhere. _Flutter:_ `lib/features/invoices/presentation/invoice_pdf_screen.dart`. Users cannot preview/print the invoice PDF from the detail screen. _Fix:_ wire a Print/PDF action from invoice detail.
- **[P2] Bill PDF preview not reachable** — `BillPdfScreen` defined, referenced nowhere. _Flutter:_ `lib/features/bills/presentation/bill_pdf_screen.dart`. _Fix:_ wire from bill detail.
- **[P2] Estimate PDF preview not reachable** — `EstimatePdfScreen` defined, referenced nowhere. _Flutter:_ `lib/features/estimates/presentation/estimate_pdf_screen.dart`. _Fix:_ wire from estimate detail.
- (AddPrescriptionScreen IS wired — pushed from prescription_history_screen; not an orphan.)

## Note for synthesis
Per-domain agents report wiring within their domain; this file captures the global picture: route coverage is high (245 routes/240 screens) but **navigation discoverability** and **endpoint utilization** are the systemic gaps — many backend capabilities are reachable only via command palette/deep-link or not at all.


---

# Sales & AR — UI/Field Gap Audit

Scope: backend `sales` (SalesOrder, DeliveryChallan, ProofOfDelivery), `ar` (Invoice, Payment, CreditNote), `estimate`, `recurring`; Flutter `sales_orders, delivery_challans, invoices, payments, credit_notes, estimates, recurring_invoices, sales` (+ POD).
Method: read JPA entity + Create/Response/Update DTOs + controllers, then matched Flutter create/edit/detail screens + repositories + `api_config.dart`. All paths cited were opened.

## Coverage map

| Sub-domain | Backend key fields (entity) | Flutter screens present? | Wired? |
|---|---|---|---|
| Sales Order | branchId, referenceNumber, estimateId, orderDate, expectedShipmentDate, status, shipped/invoicedStatus, discountType(ITEM/ENTITY), discountAmount, subtotal, taxAmount, **shippingCharge**, **adjustment**+desc, total, **billingAddress(json)**, **shippingAddress(json)**, **paymentMode**, deliveryMethod, **currency**, placeOfSupply, notes, terms, allowBackorder; line: itemId, qty, rate, unit, discountPct, taxGroupId, hsnCode (+ shipped/invoiced/backordered qty) | list/create+edit/detail | Partial — create omits ref#, addresses, paymentMode, entity-discount, shippingCharge, adjustment, currency; detail omits warnings/links/reservations |
| Delivery Challan | branchId, challanNumber, salesOrderId, contactId, **challanDate**, status, dispatchDate, **warehouseId**, deliveryMethod, vehicleNumber, trackingNumber, notes, **shippingAddress(json)**; line: soLineId, qty, **batchId** | list/create/detail | Partial — create omits challanDate, warehouse, shippingAddress, **per-line batch picker** |
| Proof of Delivery | deliveryChallanId/invoiceId, contactId, recipientName/phone/relation, deliveredAt, geoLat/Lng, notes, recordedBy; attachments(POD) | list + create dialog (`sales/.../proof_of_delivery_screen.dart`) | Yes — IDs typed as free text (no DC/invoice picker) |
| Invoice | branchId, contactId, invoiceDate, **dueDate**, status, subtotal, taxAmount, **tcsAmount**, totalAmount, amountPaid, balanceDue, **currency/exchangeRate + base amounts**, **placeOfSupply**, **reverseCharge**, journalEntryId, salesOrderId, notes, termsAndConditions, cancel fields; line: itemId, batchId, taxGroupId, desc, hsn, qty, unitPrice, discountPct, gstRate, accountCode, mrp | list/create/detail/pdf | Partial — create omits SO link/currency/branch; **no edit screen**; detail omits TCS, reverseCharge, placeOfSupply, currency, **e-invoice IRN/QR, e-way bill** |
| Payment (AR) | **invoiceId NOT NULL (1 invoice/payment)**, contactId, paymentDate, amount, currency/exchangeRate/baseAmount, paymentMethod, referenceNumber, bankAccount, notes, status, void fields | list/record/repo (no detail) | Partial — single-invoice only; omits paidThrough/bankAccount; **no allocation / advance / TDS** |
| Credit Note | contactId, invoiceId, creditNoteDate, **reason(free text)**, status, subtotal/tax/total, currency+base, placeOfSupply, journalEntryId; line: desc, hsn, qty, unitPrice, gstRate, accountCode (**no itemId/batchId**) | list/create/detail | Partial — no edit; reason free-text; no CDNR/e-invoice |
| Estimate | estimateNumber, contactId, estimateDate, expiryDate, status, subtotal, **discountAmount**, taxAmount, total, **currency**, referenceNumber, subject, notes, terms, convertedToInvoiceId, sent/accepted/declinedAt; line: itemId, desc, unit, hsn, qty, rate, discountPct, taxRate | list/create+edit/detail | Mostly — create omits currency selector & entity discount; detail lacks convert-to-SO |
| Recurring Invoice | profileName, contactId, frequency, start/end/nextInvoiceDate, **lineItems(jsonb)**, paymentTermsDays, autoSend, status, currency, notes, terms, totalGenerated | list/create+edit/detail | Good — currency hardcoded INR; nextInvoiceDate not exposed |

## Gaps

### Missing screens
- **[P1] Invoice edit screen entirely absent** — backend has NO update method (`InvoiceService` has create/send/cancel only; verified no `updateInvoice`), and there is no Flutter edit screen/`PUT`. A DRAFT invoice with a typo can only be cancelled and re-created. · _Backend:_ `ar/service/InvoiceService.java`, `ar/controller/InvoiceController.java` · _Flutter:_ `features/invoices/presentation/` (create/detail/list/pdf only) · _Why (ERP):_ every accounting tool lets you correct a draft invoice before posting. · _Fix:_ add `PUT /api/v1/invoices/{id}` for DRAFT + an edit screen reusing the create form.
- **[P2] Payment has no detail screen** — only list + record. A recorded payment cannot be opened to view/void from its own screen; void lives only behind the invoice's Payments tab. · _Backend:_ `PaymentController` GET `/{id}`, POST `/{id}/void` exist · _Flutter:_ `features/payments/` has only `payment_list_screen.dart` + `record_payment_screen.dart` · _Why (ERP):_ users audit/void a specific receipt by drilling into it. · _Fix:_ add a payment detail screen with void action.
- **[P3] Credit Note has no edit screen** — create/issue/detail only; a DRAFT CN can't be edited. · _Backend:_ no CN update endpoint in `CreditNoteController` · _Flutter:_ `features/credit_notes/presentation/` · _Why:_ parity with estimate/SO which do allow draft edit. · _Fix:_ add CN update for DRAFT + edit screen.

### Missing form/detail fields
- **[P1] Invoice create form omits due-date, place-of-supply, reverse-charge, notes, terms** — the 3-step create wizard (`invoice_create_screen.dart`, Customer→Items→Review) captures none of `dueDate`, `placeOfSupply`, `reverseCharge`, `notes`, `termsAndConditions` even though `CreateInvoiceRequest` accepts all five. So a directly-created invoice always gets a defaulted due date (breaks ageing), can never be marked reverse-charge (RCM purchase invoices wrong), and has no T&C text. · _Backend:_ `ar/dto/CreateInvoiceRequest.java` · _Flutter:_ `features/invoices/presentation/invoice_create_screen.dart` · _Why (ERP):_ due date drives AR ageing; RCM + place-of-supply drive GST; T&C is standard. · _Fix:_ add a header step (date/due/net-terms, POS, RCM toggle) + notes/terms inputs.
- **[P1] Invoice: no e-invoice IRN / signed QR display** — `EInvoice` entity stores `irn`, `ackNumber`, `signedQr`, `status`, but the invoice feature has ZERO references to einvoice/irn/qr (grep of `features/invoices/` is empty), AND `EInvoiceController` exposes only list/by-status — there is **no GET-by-invoiceId endpoint** to fetch an invoice's own IRN. Printing the signed QR on a B2B invoice is legally required in India. · _Backend:_ `gst/entity/EInvoice.java`, `gst/controller/EInvoiceController.java` · _Flutter:_ none in `features/invoices/` · _Why (ERP):_ B2B invoice is invalid without IRN+QR; users must see/print it. · _Fix:_ add `GET /einvoices/by-invoice/{invoiceId}` + an e-invoice card (IRN, ack, QR image, Generate button) on invoice detail.
- **[P1] Invoice: no e-way bill panel** — `eway_bill` table + `EwayBillService` flag invoices ≥₹50k, but invoice detail shows no EWB number/status/Generate. grep of `features/invoices/` for "eway" is empty. · _Backend:_ `gst/service/EwayBillService.java`, `gst/entity` eway · _Flutter:_ none on invoice detail · _Why (ERP):_ goods can't move without the EWB; the invoice is where users expect to generate/see it. · _Fix:_ EWB status chip + "Generate e-way bill" action on invoice detail.
- **[P1] AR Payment: no multi-invoice allocation / advance receipt** — `Payment.invoiceId` is `NOT NULL` (1 invoice per payment); `RecordPaymentScreen` takes a single `invoiceId`. The AP side HAS `vendor_payment_allocation` + allocation UI, so this is an asymmetric AR gap. Cannot "receive ₹X from customer and split across 3 invoices", and cannot book an advance/on-account receipt (no invoice). · _Backend:_ `ar/entity/Payment.java` (invoice_id NOT NULL), `ar/service/PaymentService.java`; cf. `ap/entity/VendorPaymentAllocation.java` · _Flutter:_ `features/payments/presentation/record_payment_screen.dart` (single invoice) · _Why (ERP):_ lump-sum customer receipts and customer advances are everyday flows. · _Fix:_ add an AR payment_allocation table + a "Receive Payment" screen that lists open invoices with allocate amounts + an unapplied/advance bucket.
- **[P1] Invoice detail: TCS, reverse-charge, place-of-supply, currency not shown** — `InvoiceResponse` carries `tcsAmount`, `reverseCharge`, `placeOfSupply`, `currency`, but the detail screen renders only dueDate/subtotal/tax/total/amountPaid/balanceDue (verified in `invoice_detail_screen.dart`). TCS silently inflates total with no line explaining it; reverse-charge invoices look identical to normal. · _Backend:_ `ar/dto/InvoiceResponse.java` · _Flutter:_ `features/invoices/presentation/invoice_detail_screen.dart` · _Why (ERP):_ GST correctness — buyer/auditor must see RCM flag, place of supply, and the TCS amount. · _Fix:_ add these rows to the totals/header block (TCS line, RCM badge, POS, currency).
- **[P1] Sales Order create: billing & shipping address not capturable** — entity has `billingAddress`/`shippingAddress` jsonb; create form captures neither (per `sales_order_create_screen.dart`). For a distributor shipping to multiple sites this is core. · _Backend:_ `sales/entity/SalesOrder.java`, `CreateSalesOrderRequest` (both fields present) · _Flutter:_ `features/sales_orders/presentation/sales_order_create_screen.dart` · _Why (ERP):_ ship-to ≠ bill-to is normal in B2B; flows down to DC/invoice. · _Fix:_ add bill-to/ship-to address blocks (or "same as contact" + override).
- **[P1] Sales Order detail: credit-limit/overdue warnings not surfaced** — service returns `SalesOrderResponse.warnings` (credit limit + overdue, `SalesOrderService.java:206-240`) and writes system comments, but the detail screen does not render `warnings`. The whole credit-control feature is invisible post-create. · _Backend:_ `sales/service/SalesOrderService.java` (warnings, evaluateCreditLimit/overdue) · _Flutter:_ `features/sales_orders/presentation/sales_order_detail_screen.dart` · _Why (ERP):_ credit risk must be visible on the order, not just a transient create-time toast. · _Fix:_ render a warnings banner on detail (and on confirm).
- **[P2] Delivery Challan create: no per-line batch picker** — line DTO accepts `batchId` and dispatch validates batch stock, but the create form has no batch column (per agent read of `delivery_challan_create_screen.dart`). For pharma/FEFO the operator can't choose which batch ships. · _Backend:_ `CreateDeliveryChallanRequest.ChallanLineRequest.batchId`, `DeliveryChallanService.dispatch` · _Flutter:_ `features/delivery_challans/presentation/delivery_challan_create_screen.dart` · _Why (ERP):_ batch/expiry traceability on outbound goods. · _Fix:_ add a batch dropdown per DC line (FEFO-suggested).
- **[P2] Sales Order create: entity-level discount, shipping charge, adjustment/round-off not capturable** — entity + DTO support `discountType=ENTITY_LEVEL`, `discountAmount`, `shippingCharge`, `adjustment`. Create form captures none (only per-line discount %); detail DOES display them, so they can never be non-zero from the UI. · _Backend:_ `CreateSalesOrderRequest` · _Flutter:_ `sales_order_create_screen.dart` · _Why (ERP):_ freight + order-level discount + round-off are standard on a sales order. · _Fix:_ add order-level discount/shipping/adjustment inputs to the totals block.
- **[P2] Sales Order create: reference number & payment mode not capturable** — both on entity/DTO; not in the form (paymentMode isn't even in the create DTO — entity-only). · _Backend:_ `SalesOrder.referenceNumber/paymentMode`, `CreateSalesOrderRequest.referenceNumber` · _Flutter:_ `sales_order_create_screen.dart` · _Why (ERP):_ buyer PO reference is routinely entered; payment mode informs collection. · _Fix:_ add ref# field (and surface paymentMode via DTO+form).
- **[P2] Payment: paid-through account & bank account not capturable** — `RecordPaymentForInvoiceRequest.paidThroughId` and `Payment.bankAccount` exist but the form never sends them. Every receipt lands in the default cash/bank account with no choice. · _Backend:_ `ar/dto/RecordPaymentForInvoiceRequest.java`, `ar/entity/Payment.java` · _Flutter:_ `record_payment_screen.dart` (sends amount/method/date/ref/notes only) · _Why (ERP):_ orgs with multiple bank accounts must deposit to the right one. · _Fix:_ add a "deposit to" account dropdown → `paidThroughId`.
- **[P2] Invoice detail: no SO-link nor "convert from SO" provenance** — `Invoice.salesOrderId`/`InvoiceResponse` has no `salesOrderId`/`salesOrderNumber` field at all, so an invoice can't show which SO it came from. · _Backend:_ `ar/dto/InvoiceResponse.java` (missing salesOrderId) · _Flutter:_ `invoice_detail_screen.dart` · _Why (ERP):_ traceability SO→Invoice in the distributor flow. · _Fix:_ add `salesOrderId/Number` to `InvoiceResponse` + a link row.
- **[P2] Sales Order detail: linked invoices / challans / reservations not shown** — endpoints (`/{id}/invoices`, `/by-sales-order/{soId}`, `/{id}/reservations`) and repo methods `getLinkedInvoices()/getReservations()` exist and are in `api_config.dart`, but the detail screen never calls them. · _Backend:_ `SalesOrderController` (3 GETs) · _Flutter:_ `sales_order_detail_screen.dart` (not wired) · _Why (ERP):_ users track fulfilment (what shipped, what's invoiced, what's reserved) from the order. · _Fix:_ add Invoices/Challans/Reservations tabs on SO detail.
- **[P3] Estimate: convert-to-SO action missing** — `salesOrderFromEstimate(estimateId)` is defined in `api_config.dart` and `POST /api/v1/sales-orders/from-estimate/{id}` exists, but the estimate detail offers only convert-to-invoice. · _Backend:_ `SalesOrderController.createFromEstimate` · _Flutter:_ `features/estimates/presentation/estimate_detail_screen.dart` · _Why (ERP):_ quote→order is as common as quote→invoice for distributors. · _Fix:_ add "Convert to Sales Order" on accepted estimates.
- **[P3] Estimate create: currency hardcoded INR (no selector)** — entity/DTO support `currency`; form sends INR. · _Backend:_ `CreateEstimateRequest.currency` · _Flutter:_ `estimate_create_screen.dart` · _Why:_ export quotes. · _Fix:_ currency dropdown (also Recurring Invoice — same hardcode).
- **[P3] Delivery Challan create: challan date, warehouse, shipping address not capturable** — all on entity; form omits them (date auto-set, warehouse defaulted). · _Backend:_ `DeliveryChallan` fields · _Flutter:_ `delivery_challan_create_screen.dart` · _Why:_ back-dated challans + multi-warehouse picking. · _Fix:_ add challan-date picker + warehouse dropdown.

### Missing business capabilities
- **[P1] No customer advance / on-account receipt** — see allocation gap; there is no path to take money before/without an invoice. · _Backend:_ `Payment.invoiceId NOT NULL` · _Flutter:_ none · _Why (ERP):_ advances are routine; needed for GST advance-receipt too. · _Fix:_ allow null invoice + advance ledger handling.
- **[P2] Credit Note carries no item/batch lines** — `CreditNoteResponse.LineResponse` has desc/hsn/qty/price but **no itemId/batchId**, so a sales-return credit note cannot restock a specific item/batch. · _Backend:_ `ar/dto/CreditNoteResponse.java`, `ar/entity/CreditNoteLine` · _Flutter:_ `credit_notes/` · _Why (ERP):_ a return should put stock back by item/batch. · _Fix:_ add itemId/batchId to CN lines + optional restock.
- **[P2] Credit Note: approve/reject only via generic Approval Inbox; reason is free text** — `CreditNoteController` exposes only create + issue (no reject/void on the CN itself); the detail screen's PENDING_APPROVAL state just deep-links to the workflow inbox (no in-context Approve/Reject), and CN `reason` is a free-text field, not a GST-aligned reason code (sales return / post-sale discount / deficiency). · _Backend:_ `ar/controller/CreditNoteController.java` (create/issue/get/list/pdf only) · _Flutter:_ `credit_note_detail_screen.dart` (Issue + "Open Approval Inbox" only) · _Why (ERP):_ approvers want in-context approve/reject; GST CDNR needs a standard reason. · _Fix:_ surface approve/reject on CN detail + a reason-code dropdown.
- **[P3] No payment receipt PDF** — invoices/estimates/SO/DC/CN all have `/{id}/pdf`; payments do not, so a customer can't be sent a receipt voucher. · _Backend:_ no payment PDF service · _Flutter:_ none · _Why (ERP):_ receipt vouchers are expected. · _Fix:_ add payment PDF + share.

### Wiring & UX issues
- **[P2] ProofOfDelivery API takes the raw JPA entity as the request body** — `ProofOfDeliveryController.record(@RequestBody ProofOfDelivery body)` (no DTO), and the Flutter form types DC/invoice IDs as free text (no picker). Leaks persistence shape and invites bad IDs. · _Backend:_ `sales/controller/ProofOfDeliveryController.java` · _Flutter:_ `features/sales/presentation/proof_of_delivery_screen.dart` · _Why:_ API hygiene + usability. · _Fix:_ introduce a CreatePodRequest DTO + DC/invoice pickers.
- **[P3] Invoice create cannot set due date directly only via terms** — `dueDate` is optional in the DTO and the create flow relies on defaults; confirm the form exposes an explicit due-date / payment-term picker (detail shows dueDate). · _Backend:_ `CreateInvoiceRequest.dueDate` · _Flutter:_ `invoice_create_screen.dart` · _Why:_ AR ageing depends on accurate due dates. · _Fix:_ ensure an explicit due-date / net-terms selector in create.

## Stats
P1=11, P2=11, P3=7, screens-missing=3 (invoice edit, payment detail, credit-note edit), fields-missing≈18 (invoice create: due-date/POS/RCM/notes/terms; invoice detail: e-invoice IRN+QR, e-way bill, TCS, reverse-charge, place-of-supply, currency, SO link; SO create: bill/ship address, ref#, paymentMode, entity-discount, shippingCharge, adjustment; DC create: batch/warehouse/date/ship-addr; payment: paidThrough/bankAccount; CN lines: item/batch; estimate: currency)


---

# Procurement & AP — UI/Field Gap Audit

Scope: backend `procurement` (PurchaseOrder, StockReceipt/GRN, Supplier, DebitNote, SupplierRateContract), `ap` (PurchaseBill, VendorPayment, VendorCredit, ThreeWayMatch), `expense`. Flutter `procurement`, `bills`, `ap`, `vendor_payments`, `vendor_credits`, `expenses`.

Headline correction to CLAUDE.md: the **3-way-match exception/override UI DOES exist in Flutter** (`ap/presentation/three_way_match_inbox_screen.dart` + `widgets/three_way_match_detail_sheet.dart`, route `/ap/three-way-match`, plus a banner on the bill detail). CLAUDE.md's "Flutter ... not yet wired" implication is stale. It is well-built (exceptions tab, settings tab, per-line variance, override dialog). One real defect remains (override gated to OWNER only — see W1).

## Coverage map

| Sub-domain | Backend key fields | Flutter screens present? | Wired? |
|---|---|---|---|
| Purchase Order | supplierId, orderDate, expectedDeliveryDate, notes, warehouseId, lines(item/qty/unitPrice/**taxGroupId**), status, receivedQuantity/line | list/create/detail (`procurement/`) | Partial — create omits warehouse + per-line tax/GST; detail omits per-line tax. No PDF. No approval/submit. create-GRN/create-bill/scan-GRN wired. |
| GRN / Stock Receipt | receiptDate, warehouseId, supplierInvoiceNo/Date, freight/duty/insurance/other (landed), purchaseOrderId, line(item/qty/**unitPrice/discountPercent**/gstRate/batchNumber/**manufacturingDate**/expiryDate/**landedUnitCost**) | list/create/detail | Partial — create has no warehouse picker, no mfg date, no per-line discount; detail hides landed cost + PO link + landedUnitCost + mfg/expiry. Receive/cancel work. No PDF. |
| Supplier | name/gstin/pan/phone/email/address/stateCode/**paymentTermsDays**/active/contactId | picker sheet only (`supplier_picker_sheet.dart`) | **No supplier CRUD screen** — only a read/search picker. SupplierController has full CRUD. |
| Purchase Bill | contactId, vendorBillNumber, billDate, dueDate, placeOfSupply, **reverseCharge(RCM)**, **tdsAmount/tdsSection**, branchId, termsAndConditions, purchaseOrderId, threeWayMatchStatus+override fields, currency/exchangeRate, line(item/qty/price/**discountPercent**/gst/uom) | list/create/detail/pdf/scan | Mostly — create omits discount, branch, T&C; detail omits TDS, discount, branch, balance(in body). **No edit screen** (PUT unreachable). |
| 3-Way Match | status, per-line variance, override(reason), settings(5 tolerances) | inbox (exceptions+settings) + detail sheet + bill banner | Yes — well-built. Defect: override role gate OWNER-only (backend = OWNER+ADMIN). |
| Vendor Payment | contactId, amount, paymentMode, paidThroughId, referenceNumber, **tdsAmount/tdsSection**, multi-bill **allocations[]**, currency/exchangeRate/baseAmount | list + detail only; create = per-bill record-payment sheet | **No standalone create screen.** Sheet does single-bill alloc only, no TDS, no reference#, no advance/on-account, no forex. |
| Vendor Credit | contactId, creditDate, purchaseBillId, reason, placeOfSupply, balance, line(item/account/qty/price/gst), apply-to-bill | list/create/detail + apply sheet | Yes — but create uses raw text fields for billId & per-line accountId (no pickers); no item picker. |
| Debit Note (procurement) | supplierId, returnReason, referenceBillId, lines | list/create/detail (`debit_notes_screen.dart`) | Yes. **Overlaps VendorCredit** — two supplier-return systems exist. |
| Expense | expenseDate, accountId, category, amount, gstRate(**ITC**), contactId, paymentMode, paidThroughId, **billable**, **projectId**, **customerContactId**, **receiptUrl** | list/create/detail | Partial — create/detail omit project, customer-contact (billable target), receipt/attachment. |
| Supplier Rate Contract | per-item supplier price contracts | `rate_contracts_screen.dart` | Present. |
| AP Ageing report | /api/v1/ap/reports/ageing | `reports/ap_ageing_screen.dart` | Present. |

## Gaps

### Missing screens

- **[P1] No standalone Vendor Payment create screen** — payments can only be made from a single bill's "Record Payment" sheet, which forces a 1:1 bill allocation. `POST /api/v1/vendor-payments` supports a multi-bill `allocations[]` array, TDS, and reference#, none reachable. · _Backend:_ `ap/controller/VendorPaymentController.java` (recordPayment), `ap/dto/VendorPaymentRequest.java` · _Flutter:_ none (only `bills/.../record_payment_bottom_sheet.dart`) · _Why (ERP):_ paying one cheque against five vendor bills, or making an on-account advance, is a daily AP action. · _Fix:_ add a `/vendor-payments/create` screen with vendor pick → list open bills → multi-row allocation + TDS + reference + unallocated/advance amount.

- **[P1] No Supplier master CRUD screen** — `SupplierController` exposes create/update/list/get but Flutter only has a read-only `supplier_picker_sheet`. Suppliers (name/GSTIN/PAN/paymentTermsDays/address) can't be created or edited in the app; users must rely on the Contact entity instead, leaving the `supplier` table unmanaged. · _Backend:_ `procurement/controller/SupplierController.java`, `procurement/dto/SupplierRequest.java` · _Flutter:_ none · _Why (ERP):_ GRN/PO/rate-contract all FK to `supplier`; you can't set a supplier's payment terms or GSTIN anywhere. · _Fix:_ supplier list + create/edit form, or document that Contacts are the canonical vendor and back-fill supplier rows.

- **[P2] No Purchase Bill edit screen** — `PUT /api/v1/bills/{id}` (`UpdatePurchaseBillRequest`) exists but the bill detail overflow menu offers only Post/Void/Delete/PDF/Share. A DRAFT bill with a wrong line can't be edited — only deleted and re-created. · _Backend:_ `PurchaseBillController.updateBill` · _Flutter:_ `bills/presentation/bill_detail_screen.dart` (no edit action) · _Why (ERP):_ fixing a typo on a draft vendor bill is routine. · _Fix:_ add Edit action for DRAFT bills routing to a pre-filled create screen.

### Missing form/detail fields

- **[P1] Vendor payment: TDS not capturable** — `VendorPaymentRequest.tdsAmount/tdsSection` exist and `VendorPaymentDetail` *displays* TDS if present, but the only create path (`record_payment_bottom_sheet.dart`) never sends it. TDS-at-payment (194C/194J/194I etc.) can't be deducted from the UI even though forex posting logic explicitly branches on TDS=0. · _Backend:_ `ap/dto/VendorPaymentRequest.java`, `tax/service/TdsService.java` · _Flutter:_ `bills/presentation/widgets/record_payment_bottom_sheet.dart` · _Why (ERP):_ Indian SMBs deduct TDS at payment for contractors/professionals. · _Fix:_ add TDS section dropdown + amount to the payment create UI.

- **[P1] Bill detail hides TDS** — `PurchaseBill.tdsAmount/tdsSection` are auto-computed (TdsService) and `balanceDue = total − TDS`, but the bill detail "Details" tab shows only Subtotal/Tax/Total/AmountPaid. The user sees a balance due that silently excludes TDS with no line explaining it. · _Backend:_ `PurchaseBillResponse.tdsAmount` (surfaced), entity `tdsSection` (not surfaced in response) · _Flutter:_ `bill_detail_screen.dart` `_BillDetailBody` · _Why (ERP):_ "why is my balance ₹X less than the total?" — auditors need the TDS line. · _Fix:_ add TDS Deducted + section rows; add `tdsSection` to `PurchaseBillResponse`.

- **[P2] GRN create: no warehouse picker** — `CreateStockReceiptRequest.warehouseId` is optional and "defaults to org default", but the create screen never lets the user choose. A multi-warehouse distributor cannot receive stock into a non-default warehouse. · _Backend:_ `CreateStockReceiptRequest.warehouseId` · _Flutter:_ `stock_receipt_create_screen.dart` (body has no warehouseId) · _Why (ERP):_ goods arrive at specific godowns. · _Fix:_ warehouse dropdown on the supplier/receipt step.

- **[P2] GRN detail hides landed cost + PO link + landed unit cost** — entity carries freight/duty/insurance/other + `purchaseOrderId` + per-line `landedUnitCost`, all in `StockReceiptResponse`, but the detail screen shows none of them (only batch on lines, summary is just taxable/GST/total). User can't verify what landed cost was apportioned or trace the source PO. · _Backend:_ `StockReceiptResponse` (freightAmount/dutyAmount/.../purchaseOrderId/lines.landedUnitCost) · _Flutter:_ `stock_receipt_detail_screen.dart` · _Why (ERP):_ landed cost changes inventory valuation; the PO link is the audit trail. · _Fix:_ add a "Charges" card + PO-link row + Landed Unit Cost / Expiry / Mfg columns.

- **[P2] GRN create: no manufacturing date, no per-line discount** — `StockReceiptLineRequest` supports `manufacturingDate` and `discountPercent`; the create line card captures only batch + expiry, and no discount. Pharma GRNs routinely need mfg date for FEFO age, and supplier line discounts are common. · _Backend:_ `StockReceiptLineRequest.manufacturingDate / discountPercent` · _Flutter:_ `stock_receipt_create_screen.dart` `_GrnLineCard` · _Why (ERP):_ mfg date drives shelf-life; line discounts affect landed cost. · _Fix:_ add Mfg Date picker (next to Expiry) and a discount % field.

- **[P2] PO create/detail: no per-line tax/GST** — `PurchaseOrderLine` has `taxGroupId` and the request accepts it (auto-prefilled from item), but neither create nor detail shows any tax — the PO total is taxable-only (no GST line). A PO sent to a supplier shows a number that won't match the bill. · _Backend:_ `PurchaseOrderRequest.LineRequest.taxGroupId`, `PurchaseOrderLine.taxGroupId` · _Flutter:_ `purchase_order_create_screen.dart`, `purchase_order_detail_screen.dart` (`_PoLinesPanel` has no tax column) · _Why (ERP):_ a printed PO must show GST so the supplier bills correctly. · _Fix:_ add a TaxGroupPicker per line + GST/Total rows in the summary and a Tax column in detail.

- **[P2] Expense: billable target (customer) + project not capturable** — `Expense.customerContactId` and `projectId` exist (and a billable expense is meant to be re-invoiced to a customer), but the create screen only has a billable toggle and the detail shows "Billable: Yes" with no customer/project. A billable expense therefore can't actually be tied to the customer it bills to. · _Backend:_ `CreateExpenseRequest.customerContactId / projectId`, `ExpenseResponse.customerContactName` · _Flutter:_ `expense_create_screen.dart`, `expense_detail_screen.dart` · _Why (ERP):_ "billable to customer" is meaningless without naming the customer. · _Fix:_ when billable toggled on, reveal a customer-contact picker (+ optional project).

- **[P2] Expense: no receipt/attachment upload or view** — `Expense.receiptUrl` exists in entity+DTOs but the create screen has no file/photo picker and detail never shows a receipt. Expense receipts (the audit backbone) can't be attached. · _Backend:_ `CreateExpenseRequest.receiptUrl`, `ExpenseResponse.receiptUrl` · _Flutter:_ `expense_create_screen.dart`, `expense_detail_screen.dart` · _Why (ERP):_ every expense needs a bill/receipt image for tax. · _Fix:_ add image/file picker → upload → store URL; show thumbnail on detail. (Note: unlike Bill, Expense has no generic attachment endpoint — only the `receiptUrl` string.)

- **[P3] Bill create/detail: no per-line discount** — `CreatePurchaseBillRequest.BillLineRequest.discountPercent` + `PurchaseBillLine.discountAmount/discountPercent` exist and the response surfaces `discountPercent/discountAmount`, but neither create line card nor the detail Lines tab shows discount. · _Backend:_ `CreatePurchaseBillRequest`, `PurchaseBillResponse.LineResponse.discountPercent` · _Flutter:_ `bill_create_screen.dart`, `bill_detail_screen.dart` `_LinesTab` · _Why (ERP):_ vendor trade/quantity discounts per line are normal. · _Fix:_ add discount % field per line + show on detail.

- **[P3] Bill create: no branch / terms & conditions** — `CreatePurchaseBillRequest.branchId` + `termsAndConditions` exist (T&C also on update); create UI captures neither. · _Backend:_ `CreatePurchaseBillRequest.branchId / termsAndConditions` · _Flutter:_ `bill_create_screen.dart` · _Why (ERP):_ multi-branch orgs need branch attribution. · _Fix:_ branch picker (when org is multi-branch) + a T&C field.

- **[P3] PO create: no warehouse / ship-to** — `PurchaseOrderRequest.warehouseId` exists (deliver-to warehouse) but isn't captured; no ship-to address either. · _Backend:_ `PurchaseOrderRequest.warehouseId`, `PurchaseOrder.warehouseId` · _Flutter:_ `purchase_order_create_screen.dart` · _Why (ERP):_ supplier needs to know which godown to ship to. · _Fix:_ add a delivery-warehouse dropdown.

### Missing business capabilities

- **[P1] Vendor advance / on-account payment impossible** — the record-payment sheet requires `allocations: [{billId, amountApplied}]` against exactly one bill, so a vendor advance (payment before any bill) cannot be recorded. (The backend request itself marks `allocations` `@NotEmpty`, so even the API may not support a true unallocated advance — worth a backend follow-up.) · _Backend:_ `VendorPaymentRequest.allocations @NotEmpty` · _Flutter:_ `record_payment_bottom_sheet.dart` · _Why (ERP):_ advance-to-supplier is standard in Indian trade. · _Fix:_ allow an unallocated/advance bucket (backend + UI).

- **[P2] PO has no approval / submit-for-approval flow** — PO lifecycle in the controller is only create → send → cancel (no PENDING_APPROVAL). For an SMB with PO approval limits this is a gap; SO has approval, PO does not. · _Backend:_ `PurchaseOrderController` (no approval endpoint), `PurchaseOrder.status` · _Flutter:_ `purchase_order_detail_screen.dart` (Send/Cancel only) · _Why (ERP):_ spend control needs PO approval above a threshold. · _Fix:_ if intended, add a workflow handler + approve/reject UI; else document POs as un-approved by design.

- **[P2] No PO PDF / printable document** — bills have `/api/v1/bills/{id}/pdf` + a Flutter PDF preview, but PO has no PDF endpoint and the detail has no Download/Share. You can't send a supplier a PO document (the "Send to Supplier" action only flips status and tells the user to "share the PO document" that doesn't exist). · _Backend:_ no PO PDF service · _Flutter:_ `purchase_order_detail_screen.dart` · _Why (ERP):_ a PO must be emailable/printable to the supplier. · _Fix:_ add PO PDF service + endpoint + preview/share, mirroring BillPdfService.

- **[P3] Two parallel supplier-return systems (DebitNote vs VendorCredit)** — `procurement.DebitNote` (supplierId-keyed, `/debit-notes`) and `ap.VendorCredit` (contactId-keyed, `/vendor-credits`) both model "money the vendor owes us / goods returned". Both have full Flutter screens in the sidebar. Users will be confused which to use; AP balance reconciliation can diverge. · _Backend:_ `procurement/entity/DebitNote.java`, `ap/entity/VendorCredit.java` · _Flutter:_ `procurement/.../debit_notes_screen.dart`, `vendor_credits/...` · _Why (ERP):_ one return concept, two documents → double-entry confusion. · _Fix:_ pick one as canonical (VendorCredit posts to AP + applies to bills; DebitNote is supplier-id only) and hide/redirect the other.

### Wiring & UX issues

- **[W1][P2] 3-way-match Override button gated to OWNER only** — the detail sheet computes `canOverride = isOwner && ...` where `isOwner = role == 'OWNER'`, but `ThreeWayMatchController.override` allows `hasAnyRole('OWNER','ADMIN')`. An ADMIN can override via API but the button is hidden for them. · _Backend:_ `ap/match/ThreeWayMatchController.java` (override = OWNER/ADMIN) · _Flutter:_ `ap/presentation/widgets/three_way_match_detail_sheet.dart` (`isOwner`) · _Fix:_ allow `role == 'OWNER' || role == 'ADMIN'` for the override action.

- **[W2][P2] Vendor Credit create uses raw text fields for Bill ID and per-line Account ID** — "Purchase Bill ID (optional)" and each line's "Account ID" are free-text fields where the user must paste a UUID / type an account code by hand (`accountId: '5000'` style). No bill picker, no account picker, no item picker (itemId never set). · _Backend:_ `CreateVendorCreditRequest` (accountId is `@NotNull UUID`) · _Flutter:_ `vendor_credits/presentation/vendor_credit_create_screen.dart` · _Fix:_ bill picker for the linked bill, account picker for the GL, item picker for lines.

- **[W3][P3] GRN "Receive" has no QC / inspection gate** — GRN goes DRAFT → RECEIVED with no quality-check / accept-reject-quarantine step (QC lives only in `manufacturing`, not procurement). Pharma/food receiving often needs incoming QC before stock posts. · _Backend:_ `StockReceiptService.receive` (no QC) · _Flutter:_ `stock_receipt_detail_screen.dart` · _Why (ERP):_ rejected/damaged goods shouldn't hit sellable stock. · _Fix:_ optional incoming-QC hold before receive (larger feature; flag for backlog).

- **[W4][P3] PO detail "Send to Supplier" promises a document that doesn't exist** — the confirm dialog says "The supplier will be notified once you share the PO document," but there is no PO PDF/share. Misleading copy until P-PO-PDF lands. · _Flutter:_ `purchase_order_detail_screen.dart` `_confirmSend` · _Fix:_ tie to the PO PDF feature, or soften copy.

- **[W5][P3] Bill detail Activity tab vs vendor-payment void path** — bill detail offers comment/attachment (BILL entity) and good 3-way banner, but voiding a posted bill is the only correction path; there's no re-open or partial reversal. Minor; acceptable.

## Stats
P1=7, P2=12, P3=8, screens-missing=3 (Vendor Payment create, Supplier CRUD, Bill edit), fields-missing≈12 (payment TDS, bill TDS, GRN warehouse, GRN landed-cost/PO-link/landedUnitCost, GRN mfg-date, GRN line discount, PO per-line tax, expense customer/project, expense receipt, bill line discount, bill branch/T&C, PO warehouse)


---

# Inventory & Pricing — UI/Field Gap Audit

Scope: `src/main/java/com/katasticho/erp/{inventory,pricing}` (backend) vs `flutter_app/lib/features/{inventory,pricing}` (Flutter). Verified against actual code, not CLAUDE.md "DONE" claims.

## Coverage map

| Sub-domain | Backend key fields / endpoints | Flutter screen(s)? | Wired? |
|---|---|---|---|
| Item master | `Item` (sku, barcode, hsn, gstRate, mrp, sale/purchase price, reorderLevel/Qty, trackInventory/Batches/SerialNumbers, manufacturer, rackLocationId, **preferredVendorId**, **defaultTaxGroupId**, **weightBasedBilling**, **productionMode**, **phantom**, **active**, weight/dims, drug fields, FSSAI fields, group/variant) — `ItemController` @ `/api/v1/items` | `item_create_screen.dart`, `item_detail_screen.dart`, `item_list_screen.dart` | **Partial** — many fields not in form (see gaps) |
| Stock balance / on-hand | `StockBalance` (qtyOnHand, averageCost, lastMovementAt), `/api/v1/stock/items/{id}/balances`, `/low-stock` | item_detail Stock card (single total), Stock Summary report | Partial — no per-warehouse on-hand grid in UI |
| Stock movement / ledger | `StockMovement` (append-only, signed qty, unitCost, totalCost, ref, batchId, reversed), `/api/v1/stock/movements/{id}/reverse`, `/items/{id}/movements` | item_detail "Recent Movements" (read), Stock Movements report | Partial — no reverse button in UI, no global ledger view |
| Stock adjustment | `StockAdjustmentRequest` (itemId, warehouseId, signed qty, unitCost, reason), `/api/v1/stock/adjust` | `stock_adjust_sheet.dart` | Partial — no warehouse picker, no batch picker |
| Batch & expiry | `StockBatch` (batchNumber, mfg/expiryDate, unitCost, supplierId), `BatchController` @ `/api/v1/batches`, near-expiry | item_detail `_BatchesCard`, `near_expiry_screen.dart`, `batch_picker_sheet.dart` | Yes (read); no batch master edit |
| Batch trace | forward/backward, `/api/v1/inventory/batch-trace` | `batch_trace_screen.dart` (routed) | **Routed, NOT in sidebar** |
| Batch recall | `/api/v1/inventory/batch-trace/recall/{rmBatchId}` | `batch_recall_screen.dart` (routed) | **Routed, NOT in sidebar** |
| Serial numbers | `SerialNumber` + `SerialNumberController` @ `/api/v1/serial-numbers` (receive, assign-sale, damage, return, available, by-item) | **NONE** | **No UI at all** |
| UoM & conversions | `Uom`/`UomConversion`/`UomCategory`, `UomController` @ `/api/v1/uoms` (full CRUD) | **NONE** (inline dropdown in item form only) | **No management UI** |
| Item groups / variants | `ItemGroup` (sku_prefix, defaults, attributeDefinitions), variants via `Item.groupId/variantAttributes`, matrix generate | `item_group_{list,create,detail}_screen.dart`, `generate_variants_screen.dart` | **Yes — complete** |
| BOM (composite) | `BomComponent` + alternate/coProduct/phantom/versioning, `/api/v1/items/{id}/bom` | item_detail `_BomEditorCard` | Partial — basic add/remove only |
| Transfer orders | `TransferOrder` (from/to wh, lines), ship/receive/cancel | `transfer_order_{list,create,detail}_screen.dart` | Yes — no batch picker |
| Picklists | `Picklist`/`PicklistLine` + `PicklistController` (generate, start, update-line, complete, cancel) | `picklist_list_screen.dart` (list only) | **Partial — no create/detail screen, no picked-qty editor** |
| Stock count | `StockCount`/`StockCountLine`, create/post/cancel | `stock_count_{list,create,detail}_screen.dart` | Yes — no cycle-count mode, no scanning |
| Warehouse | `Warehouse` (code, name, address), `WarehouseController` (create + read only) | **NONE** (inline dropdowns) | **No management UI; no edit/delete backend** |
| Warehouse zones | `WarehouseZone` (STORAGE/QUARANTINE/...), `/api/v1/inventory/warehouse-zones` | `warehouse_zone_screen.dart` (routed) | **Routed, NOT in sidebar** |
| Consignment / VMI | `ConsignmentStock`/`Settlement` + controller @ `/api/v1/inventory/consignment` | **NONE** | **No UI at all** |
| FIFO / cost lots / valuation | `CostLot`/`CostLotConsumption`, `FifoCostingService`, `/api/v1/reports/fifo-valuation` | FIFO Valuation in reports hub (generic viewer) | Yes (report only); valuation method not configurable in UI |
| Barcode | `/api/v1/items/by-barcode/{barcode}`, GsOne datamatrix parser | `item_scan_sheet.dart` (AI label scan) | **No barcode print/generate; no scan-to-cart confirmed here** |
| Reorder / low-stock | `Item.reorderLevel/Qty`, `/api/v1/stock/low-stock`, ATP `/api/v1/inventory/atp` | `reorder_screen.dart`, `shortbook_screen.dart` | Yes — no bulk reorder-level edit |
| Pharmacy masters | rack/HSN/manufacturer/substitution/interaction | `rack_locations_screen.dart`, `hsn_master_screen.dart`, search widgets | Yes |
| FSSAI / food | `FssaiService` item fields + label PDF, `/api/v1/fssai` | `fssai_screen.dart` (paste-id) | Partial — not in main item form |
| Price lists | `PriceList` (currency, isDefault), `PriceListItem` (minQuantity tiers, price), full CRUD | `price_list_{list,create,detail}_screen.dart` | **Partial — no edit, no customer assignment, abs price only** |
| Schemes | `Scheme` (BUY_X_GET_Y / PERCENT_DISCOUNT, item/supplier scope, valid dates), create/**update**/delete | `scheme_list_screen.dart` | **Partial — no edit in UI, only 2 types, no supplier scope** |

---

## Gaps

### Missing screens

- **[P1] Serial number tracking has zero UI** — full backend (`SerialNumberController`: receive/assign-sale/damage/return/available/by-item) but no screen to look up a serial, see its status/history, or manage serials. · _Backend:_ `/api/v1/serial-numbers/*` · _Flutter:_ none · _Why (ERP):_ electronics/appliance/IMEI distributors must trace a unit by serial (warranty, RMA, theft) — table-stakes for serialized inventory. · _Fix:_ add `serial_lookup_screen.dart` (search by serial → status + linked GRN/invoice) + a serial-capture step in GRN-receive and invoice/DC dispatch for `trackSerialNumbers` items.

- **[P1] Consignment / VMI has zero UI** — `ConsignmentController` (receive, record-sale, settle, stock list, unsettled-by-supplier) is fully built but unreachable. · _Backend:_ `/api/v1/inventory/consignment/*` · _Flutter:_ none · _Why (ERP):_ consignment stock (supplier-owned until sold) is common in pharma/FMCG distribution; without UI the feature is dead. · _Fix:_ add `consignment_screen.dart` (receive form, stock list, record-sale, settle) under Inventory sidebar.

- **[P1] Warehouse management has no UI (and backend can't edit/delete)** — `WarehouseController` only has create + read; no list/create/edit screen exists. Address, default-flag, state-code are set only via... nothing (warehouses appear only as dropdowns). · _Backend:_ `/api/v1/warehouses` (POST + GET only — no PUT/DELETE) · _Flutter:_ none · _Why (ERP):_ multi-location businesses need to add/rename/deactivate godowns and set the default; today a user can't create a 2nd warehouse from the UI. · _Fix:_ add `warehouse_{list,form}_screen.dart` + backend `PUT/DELETE /api/v1/warehouses/{id}`.

- **[P2] UoM management has no UI** — `UomController` full CRUD (create/edit/delete custom units, conversions) but only an inline item dropdown exists. · _Backend:_ `/api/v1/uoms` · _Flutter:_ none · _Why (ERP):_ orgs need to add custom units (Dozen, Carton, Bora) and view/maintain conversion factors; the secondary-unit editor in the item form can't create a base UoM that doesn't already exist. · _Fix:_ add `uom_screen.dart` (list + create/edit with conversion factor).

- **[P2] Picklist has no dedicated create/detail screen and no picked-qty editor** — only `picklist_list_screen.dart` with an inline SO-id dialog + expandable card; the `PicklistController` update-line endpoint (record picked qty per line) is never surfaced. · _Backend:_ `/api/v1/inventory/picklists` (start/update-line/complete) · _Flutter:_ list only · _Why (ERP):_ a picker must enter how many of each line they actually picked (short-picks happen); read-only lines make the workflow useless on the warehouse floor. · _Fix:_ add `picklist_detail_screen.dart` with per-line counted-qty entry + warehouse scoping.

- **[P3] No global stock-ledger / movement-explorer screen** — movements are visible only per-item inside item-detail; there's no org-wide filterable ledger (by date, type, warehouse, reference). · _Backend:_ `StockMovementRepository`, Stock Movements report exists via generic viewer · _Flutter:_ item-detail only · _Why (ERP):_ auditors/ops want "all ADJUSTMENT movements last month across warehouses". · _Fix:_ promote the stock-movement report to a filterable screen (type/warehouse/date facets).

### Missing form / detail fields

- **[P1] Item form omits `preferredVendorId`** — `CreateItemRequest.preferredVendorId` accepted; detail shows `preferredVendorName` read-only; create/edit form has NO vendor picker. · _Backend:_ `Item.preferredVendorId` · _Flutter:_ `item_create_screen.dart` (absent) · _Why (ERP):_ preferred vendor drives reorder→PO autofill; without it the reorder-to-PO flow can't pick a supplier. · _Fix:_ add a vendor picker to the item form's Inventory section.

- **[P1] Item form omits `trackSerialNumbers` toggle** — entity + `Item.trackSerialNumbers` exist; the create form only toggles `trackInventory` and `trackBatches`. Serial tracking can never be turned on from the UI. · _Backend:_ `Item.trackSerialNumbers` · _Flutter:_ `item_create_screen.dart` (absent) · _Why (ERP):_ serialized items are unconfigurable, compounding the missing-serial-UI gap. · _Fix:_ add a "Track serial numbers" switch beside Track batches.

- **[P2] Item form omits `weightBasedBilling`, `defaultTaxGroupId`, `productionMode`, `phantom`, active-toggle** — all are real entity fields with no input. `weightBasedBilling` matters for loose/by-weight kirana sales; `phantom`/`productionMode` are set only via separate paste-an-id manufacturing screens; there's no "deactivate item" toggle (only delete). · _Backend:_ `Item.{weightBasedBilling,defaultTaxGroupId,productionMode,phantom,active}` · _Flutter:_ `item_create_screen.dart` (absent) · _Why (ERP):_ weight-billing and active/inactive are everyday SMB needs. · _Fix:_ surface weightBasedBilling + an Active switch in the item form; expose phantom/productionMode in the composite section.

- **[P2] Item form omits FSSAI fields (veg class, allergens, shelf-life, date-marking, nutrition)** — these live only in a separate `fssai_screen.dart` that requires pasting an item id. A food-org user creating an item can't set them inline. · _Backend:_ `Item.{vegClassification,allergens,nutritionalInfo,dateMarkingType,shelfLifeDays,fssaiLicense}`, `/api/v1/fssai` · _Flutter:_ standalone screen only · _Why (ERP):_ food compliance fields belong on the item, not a disconnected utility. · _Fix:_ add a collapsible "Food / FSSAI" section to the item form for food-industry orgs (mirror the Pharmacy section pattern).

- **[P2] No per-warehouse on-hand breakdown in item detail** — `/api/v1/stock/items/{id}/balances` returns per-warehouse rows, but item-detail shows only a single `totalOnHand`. · _Backend:_ `StockBalance` per warehouse · _Flutter:_ item_detail single total · _Why (ERP):_ multi-godown orgs need "where is my stock" at a glance. · _Fix:_ render the balances list as a per-warehouse table in item detail.

- **[P3] Stock adjustment sheet has no warehouse or batch selector** — `StockAdjustmentRequest` accepts `warehouseId`; the sheet always uses the default. For a batch-tracked item there's no way to adjust a specific batch (no batch field on the request at all). · _Backend:_ `/api/v1/stock/adjust` (warehouse optional; no batch field) · _Flutter:_ `stock_adjust_sheet.dart` · _Why (ERP):_ damage/loss happens to a specific batch in a specific godown. · _Fix:_ add warehouse dropdown to the sheet + add a `batchId` field to the request and a batch picker for batch-tracked items.

- **[P3] No "reverse movement" action in UI** — `/api/v1/stock/movements/{id}/reverse` exists; item-detail movement rows show `reversed` strikethrough but offer no button to reverse. · _Backend:_ `/api/v1/stock/movements/{id}/reverse` · _Flutter:_ none · _Why (ERP):_ correcting a mistaken adjustment requires backend access today. · _Fix:_ add a reverse action (with reason) to non-reversed adjustment rows.

### Missing business capabilities

- **[P1] No customer ↔ price-list assignment UI** — `PriceList.isDefault` and the resolver chain (`customer.defaultPriceListId → org default → item.salePrice`) exist, but no Flutter screen lets you pin a price list to a customer. The contacts feature has zero price-list wiring. · _Backend:_ resolver in `PriceListService.resolvePrice`; `customer.defaultPriceListId` FK · _Flutter:_ none (checked `features/contacts/`) · _Why (ERP):_ tiered/wholesale-vs-retail pricing is pointless if you can't assign a list to a customer — the whole feature degrades to "org default only". · _Fix:_ add a "Price List" dropdown to the contact create/edit form.

- **[P2] Scheme builder is shallow + has no edit** — only `BUY_X_GET_Y` and `PERCENT_DISCOUNT`; `SchemeController` has a working `PUT /{id}` (update) that the Flutter screen never calls (delete + recreate only); `supplierId` scope and item-group scope are not in the UI. No value-based (₹ off), slab, or combo schemes. · _Backend:_ `SchemeController` create/**update**/delete; `Scheme.supplierId` · _Flutter:_ `scheme_list_screen.dart` (no edit, 2 types) · _Why (ERP):_ Indian distributor schemes are richer (10+2, slab qty breaks, value-based, brand/group-wide); editing a typo'd scheme shouldn't require deletion. · _Fix:_ wire the update endpoint into an edit sheet; add value-based + group-scope scheme types.

- **[P2] No price-list edit, clone, or markup-from-cost; tiers are absolute price only** — `PriceListController` has create + delete but no header edit (rename/toggle default/active); the detail screen only adds/removes absolute-price tiers. No "% off MRP/cost" tier, no copy-list, no bulk-set. · _Backend:_ no `PUT /price-lists/{id}` · _Flutter:_ `price_list_detail_screen.dart` (add tier only) · _Why (ERP):_ building a wholesale list as "cost + 8%" or cloning last season's list is standard; entering every absolute price by hand is impractical. · _Fix:_ add `PUT` for the header + a markup-mode tier (percent off salePrice/MRP) + a clone action.

- **[P2] Valuation method (FIFO vs Weighted Average) not configurable in UI** — `inventory.valuation_method` org setting is honored by `FifoCostingService`, but the Business Policy settings screen only exposes a batch *picking* policy (FEFO/FIFO/MANUAL), not the *costing* method. · _Backend:_ org setting `inventory.valuation_method` · _Flutter:_ `business_policy_settings_screen.dart` (absent) · _Why (ERP):_ the costing basis materially changes COGS/valuation; an accountant must be able to choose it. · _Fix:_ add a "Inventory valuation method" dropdown (FIFO / Weighted Average) to business-policy settings.

- **[P2] No barcode label generation / print** — barcode is captured (manual + AI label scan) and looked up (`/api/v1/items/by-barcode`), but there is no screen to generate/print barcode labels for items (shelf/price labels). · _Backend:_ `by-barcode` lookup; GsOne parser · _Flutter:_ `item_scan_sheet.dart` (capture only) · _Why (ERP):_ retail/kirana shops print barcode+price labels for unbarcoded stock; this is a daily task in Marg/Vyapar. · _Fix:_ add a barcode-label print screen (item → label sheet PDF, configurable size).

- **[P3] No bulk reorder-level / min-max editor** — reorder levels are editable only one item at a time via item-edit; `reorder_screen.dart` shows the alert list but can't set/recalculate levels in bulk. · _Backend:_ `Item.reorderLevel/Qty` · _Flutter:_ `reorder_screen.dart` (read + PO draft) · _Why (ERP):_ setting reorder points across hundreds of SKUs one-by-one is impractical. · _Fix:_ add a bulk reorder-level edit (and optional auto-suggest from consumption) on the reorder screen.

### Wiring & UX issues

- **[P1] Batch Trace, Batch Recall, Warehouse Zones, FSSAI, FIFO Valuation are routed but NOT in the Inventory sidebar** — these screens exist and work but are reachable only by direct URL or command palette; the `_inventoryGroup` NavItem list (`shell_screen.dart:303-400`) omits them. · _Backend:_ all endpoints live · _Flutter:_ `shell_screen.dart` (missing NavItems for `batch-trace`, `batch-recall`, `warehouse-zones`, `fssai`, valuation) · _Why (ERP):_ batch recall is a regulatory/safety feature — a pharma user hit by a recall can't find it. · _Fix:_ add NavItems for these under the Inventory group (gate FSSAI to food, zones to multi-warehouse).

- **[P2] BOM editor in item-detail is single-level only and exposes none of the advanced BOM features** — the `_BomEditorCard` adds/removes simple-goods components (rejects nested/batch/composite children), but BOM versioning, alternates, co-products, phantom, scrap%, and the cost-rollup view (all backend-built) have no UI here. · _Backend:_ `bom_alternate`, `bom_co_product`, versioning, `/bom/{id}/cost-rollup` · _Flutter:_ `_BomEditorCard` (basic add/remove) · _Why (ERP):_ manufacturers need substitute materials and versioned BOMs from the item, not only from manufacturing utility screens. · _Fix:_ deepen the BOM editor (qty edit inline, alternates, scrap%, cost-rollup) or link to a full BOM editor screen.

- **[P3] Item list has no category/type/active/low-stock facets** — `ItemListScreen` filters only by search text and a "negative stock" chip; backend `listItems` supports `activeOnly` + `negativeStockOnly` but there's no Active filter, category filter, or low-stock filter in the UI. · _Backend:_ `listItems(search, activeOnly, negativeStockOnly, ...)` · _Flutter:_ `item_list_screen.dart` (search + neg-stock only) · _Why (ERP):_ large catalogs need filter-by-category/brand/type/active. · _Fix:_ add facet chips (Active, Type, Category, Low-stock) to the item-list header.

- **[P3] Transfer order & stock count don't support batch-level selection** — both move/count at item level; for batch-tracked items the UI can't pick which batch is transferred or counted (backend carries batchId on movements). · _Backend:_ batch-aware movements · _Flutter:_ `transfer_order_create_screen.dart`, `stock_count_create_screen.dart` · _Why (ERP):_ FEFO orgs must transfer/count specific batches/expiries. · _Fix:_ add a batch picker per line when the item is batch-tracked.

---

## Stats
P1=8, P2=11, P3=8 (27 findings)
screens-missing=6 (serial lookup+capture, consignment, warehouse mgmt, UoM mgmt, picklist detail/editor, global stock-ledger)
fields-missing=~14 (item: preferredVendorId, trackSerialNumbers, weightBasedBilling, defaultTaxGroupId, productionMode, phantom, active, 6 FSSAI fields; per-warehouse on-hand; adjustment warehouse+batch)


---

# Accounting, Tax & GST — UI/Field Gap Audit

Scope: Chart of accounts, Journal entry, Fiscal periods/year-close, Trial balance/P&L/Balance sheet, TDS, TCS, GST returns (GSTR-1/3B/2B, e-invoice, e-way bill, composition, calendar, GSP), VAT (UAE/Oman/PINT-AE), CA bridge/Tally export, amortization/deferred.

Method: read entities + DTOs + controllers (backend), matching Flutter screens, then compared. Heavy claims from sub-agents were re-verified against the actual Flutter source (esp. `gst_compliance_tabs.dart`) — several agent "not wired" claims for e-invoice/e-way bill were FALSE and are corrected below.

## Coverage map

| Sub-domain | Backend key fields / endpoints | Flutter screen(s)? | Wired? |
|---|---|---|---|
| Chart of Accounts | `Account`: code, name, type, subType, parentId, level, isSystem, **openingBalance**, currency, isActive · `/api/v1/accounts` CRUD + activate/deactivate + transactions + balance(asOfDate) + `/template` seed | `account_list_screen` (tree + collapse), `account_create_screen`, `account_detail_screen` (Details/Balance/Transactions tabs) | Mostly. No GST/tax-tag on account, no batch opening-balance, no ledger drill from balance |
| Journal entry (manual, cost-centre, post-dated) | `JournalEntry`: entryNumber, effectiveDate, sourceModule, sourceId, status, isReversal/isReversed, periodYear/Month, postDated, tags(jsonb), approvalStatus · `JournalLine`: debit, credit, exchangeRate, baseDebit/Credit, taxComponentCode, **costCentre**, projectId · POST/`{id}/post`/`{id}/reverse`/list/delete | `journal_create_screen` (multi-line Dr/Cr balance check, cost-centre, post-dated), `journal_list_screen`, `journal_detail_screen`, `guided_transaction_screen` | Partial. **No reverse action in UI** (backend `/reverse` exists); no draft-post action; no attachments; no FX rate fields; no taxComponentCode |
| Fiscal periods / year-end close | `FiscalPeriod`: year, month, status(OPEN/CLOSED/LOCKED) · `/api/v1/accounting/periods` list + close/reopen/lock(month) · `ContinuousClose`: checklist + guarded close | `period_close_screen` (month close/reopen/lock + readiness checklist) | Partial. **Month-only — no fiscal-year setup, no year-end P&L→Retained-Earnings close** |
| Trial Balance | `/reports/trial-balance?asOfDate` | `trial_balance_screen` (date, balanced badge, table) | Yes. **No export/print, no drill to ledger, no group subtotals, no comparative** |
| P&L | `/reports/profit-loss?startDate&endDate` | `profit_loss_screen` | Yes (assumed parity; no export/comparative noted) |
| Balance Sheet | `/reports/balance-sheet?asOfDate` | `balance_sheet_screen` | Yes |
| General Ledger | `/reports/general-ledger/{accountId}?start&end` | `general_ledger_screen` | Yes |
| TDS (26Q, register, sections, Form 16, 24Q) | `/api/v1/tds`: `/register`, `/26q`, `/24q`, **`/24q/csv`**, **`/24q/fvu`**, `/form16/{id}`, **`/form16/{id}/pdf`**, `/salary-register` | `TdsTab` + `SalaryTdsTab` (inside GST dashboard) | Partial. 26Q/24Q/Form16 are **JSON-share only**. **No CSV/FVU/PDF buttons** (backend ready); **no daily TDS register**, no challan/CIN, no Form 16A (vendor) |
| TCS (27EQ, register) | `/api/v1/tcs`: `/register`, `/27eq`, `/settings` | `TcsTab` (inside GST dashboard) | Partial. 27EQ JSON-share + toggle. **No daily TCS register**, no per-buyer threshold view, no challan/CIN |
| GSTR-1 (B2B/B2CL/B2CS/CDNR/HSN) | `/gst/gstr1` + **`/gstr1/export`** | GST dashboard summary tab | Partial. **No per-section drill-down**, **no export button** wired |
| GSTR-3B | `/gst/gstr3b` + **`/gstr3b/export`** | GST dashboard summary tab | Partial. **No section table drill-down**, no export button |
| GSTR-2B recon | `/gst/gstr2b` upload/fetch/summary | `Gstr2bTab` (upload + fetch + summary) | Yes for upload/summary. **No per-row match drill (MATCHED/MISMATCH/NOT_IN_BOOKS) → matched-bill link** |
| GSTR-2B **IMS** (Accept/Reject/Pending) | `/gst/ims`: summary, no-action, `{id}/action`, bulk-action, recommend, apply-recommendations, reset, bulk-reset (8 endpoints) | **NONE** | **No UI at all** — regulatory (deemed-accept) loop unbuilt |
| e-Invoice (IRN/QR) | `/gst/einvoices`: list, create, portal-json, **generate-gsp**, record, cancel, settings | `EInvoicesTab` (record IRN, share IRP JSON, **generate-gsp**, cancel, toggle) | **Mostly wired** (corrects agent). **Gap: signed QR is captured as text, never RENDERED as scannable image; no print/email of QR** |
| e-Way bill | `/gst/eway-bills`: list, create, record, **generate-gsp**, cancel, portal-json, check-vehicle | `EwayBillsTab` (record, portal-JSON share, cancel, generate-gsp, **check-vehicle**) | **Mostly wired** (corrects agent). Gap: no Part-B/vehicle-update flow; validity/distance display thin |
| Composition (CMP-08) | `/gst/composition/cmp08` + settings | repo methods exist (`cmp08`, `compositionSettings`) but **NO tab/screen** renders them | **No UI** — composition orgs cannot view/file CMP-08 |
| Compliance calendar | `/gst/compliance-calendar` | `GstCalendarTab` | Yes. No section/status filtering |
| GST 2.0 rate remap | `/gst/rate-remap`: candidates, apply, apply-bucket | **NONE** | **No UI** — post-Notification-9/2025 drift cannot be audited in-app |
| Month-end GST close | `/gst/close/checklist[/now]` | **NONE** | **No UI** |
| GSP settings | `/gst/gsp-settings` get/put/test | `gsp_settings_screen` | Yes |
| VAT — UAE VAT201 | `/api/v1/vat/uae/return` + `/export` | **NONE** | **No UI / no route / no api_config** |
| VAT — Oman | `/api/v1/vat/oman/return` + `/export` | **NONE** | **No UI** |
| VAT — Gulf calendar | `/api/v1/vat/compliance-calendar` | **NONE** | **No UI** |
| PINT-AE e-invoice (UBL) | `/gst/einvoices/pint-ae/{id}` | **NONE** | **No UI** |
| Tax account mapping | `/settings/tax-accounts` get/put/reset · output/input GL per rate, recoverable | `tax_account_mapping_screen` | Yes. No account-type validation, no audit trail, no purpose chips |
| Tax groups | `/api/v1/tax-groups` GET-only (no CRUD) | `tax_group_picker` widget only | Partial. **No management screen; backend has no create/update/delete** |
| CA console / Tally bridge | `/api/v1/ca/*` (firm, dashboard, clients, deadlines, alerts, report-dispatch, access-token, staff) · `/migration/tally/*` (preview/import/verify-TB/export/suggest-mapping) | `ca_console_screen` (Clients/Calendar/Alerts/Reports), `tally_import_screen` (masters/vouchers/TB-verify/export) | Mostly. Gaps below |
| Amortization / deferred | `AmortizationSchedule`: scheduleType (PREPAID/DEFERRED_INCOME/ACCRUAL), totalAmount, start, numberOfPeriods, debit/creditAccountCode, recognizedAmount · `/api/v1/amortization` list/get/create/run/cancel | `amortization_screen` (list, create sheet, run, detail) | Partial. Account **code-only** (no picker), no period-by-period schedule table, month-only run |

## Gaps

### Missing screens

- **[P1] VAT201 (UAE) return screen** — entire UAE statutory quarterly filing has no UI. · _Backend:_ `vat/VatReturnController.java` `/api/v1/vat/uae/return[/export]` · _Flutter:_ none (no route, no api_config entry) · _Why (ERP):_ headline feature for Gulf expansion; accountant currently must hit the API/download JSON by hand — product is not Gulf-launch-ready. · _Fix:_ build `features/vat/presentation/vat201_screen.dart` (date range → box1a/1b/9/10/14 form + EmaraTax JSON download), mirror trial_balance_screen pattern.
- **[P1] Oman VAT return screen** — same gap for Oman. · _Backend:_ `vat/OmanVatReturnController.java` · _Flutter:_ none · _Why (ERP):_ statutory quarterly filing for OM orgs. · _Fix:_ reuse the VAT201 screen with an Oman box mapping.
- **[P1] GSTR-2B IMS Accept/Reject/Pending screen** — 8 backend endpoints (`ImsController`), zero UI. · _Backend:_ `gst/controller/ImsController.java` `/api/v1/gst/ims/{id}/action`, `/bulk-action`, `/recommend`, `/apply-recommendations` · _Flutter:_ none · _Why (ERP):_ amended Sec 38 / IMS — unactioned rows are deemed-accepted into 2B at cutoff; buyer must action every row or lose ITC. AI recommendations + reasoning are generated but invisible. · _Fix:_ add "IMS" tab to GST dashboard — list rows with per-row Accept/Reject/Pending + remarks, bulk-action sheet, "apply AI recommendations" with `imsAiReason` shown.
- **[P1] Dedicated TDS register screen** — daily/monthly TDS-deducted register (the challan-feeder) has no UI; only quarterly 26Q tab exists. · _Backend:_ `tax/controller/TdsController.java` `/api/v1/tds/register?from&to` · _Flutter:_ none · _Why (ERP):_ ITNS-281 monthly deposit needs the bill-wise register, not the quarterly rollup. · _Fix:_ `features/tax/presentation/tds_register_screen.dart` — date range + section + vendor filter, table (bill/vendor/base/TDS/section).
- **[P1] Dedicated TCS register screen** — invoice-wise TCS-collected register absent; only 27EQ quarterly tab exists. · _Backend:_ `tax/controller/TcsController.java` `/api/v1/tcs/register` · _Flutter:_ none · _Why (ERP):_ TCS is a daily collection duty; audit + monthly deposit need the register. · _Fix:_ `tcs_register_screen.dart` (date range, buyer filter, invoice/TCS/cumulative-FY-consideration columns).
- **[P2] Composition CMP-08 screen** — repo methods `cmp08()`/`compositionSettings()` exist but no screen/tab renders them. · _Backend:_ `gst/controller/CompositionController.java` `/gst/composition/cmp08` + settings · _Flutter:_ repo only, no widget · _Why (ERP):_ composition-scheme orgs file CMP-08 quarterly (not GSTR-1/3B) and cannot view/verify it. · _Fix:_ add "Composition" tab → quarterly turnover×rate table (CGST/SGST split) + enable/rate settings.
- **[P2] GST 2.0 rate-remap wizard** — candidate detection + dry-run + bulk apply all in backend, no UI. · _Backend:_ `gst/controller/Gst20RemapController.java` `/gst/rate-remap/candidates|apply|apply-bucket` · _Flutter:_ none · _Why (ERP):_ post-Notification-9/2025 (eff 2025-09-22) every org must reconcile item GST rates vs HSN master; no in-app way to find/fix drift. · _Fix:_ wizard: list candidates with old→new rate, bucket/bulk apply with dry-run preview.
- **[P2] Month-end GST close checklist screen** — `MonthEndCloseController` checklist unbuilt in UI. · _Backend:_ `/gst/close/checklist[/now]` · _Flutter:_ none · _Why (ERP):_ traffic-light close readiness (IMS done? 2B reconciled? EWB/e-invoice pending? 26Q?) is the accountant's monthly anchor. · _Fix:_ one-page checklist screen, or fold into the existing continuous-close screen.
- **[P2] PINT-AE e-invoice screen** — UBL-XML generator per invoice, no browse/download UI. · _Backend:_ `gst/einvoice/PintAeEInvoiceController.java` `/gst/einvoices/pint-ae/{id}` · _Flutter:_ none · _Why (ERP):_ mandatory B2B e-invoice in UAE; no visibility into status/regeneration/download. · _Fix:_ list e-invoices (AE/OM-gated) with download-UBL action.
- **[P2] Gulf compliance calendar screen** — VAT deadlines + end-of-service gratuity dates, no UI. · _Backend:_ `vat/GulfComplianceCalendarController.java` · _Flutter:_ none · _Why (ERP):_ deadline visibility is table-stakes for any regional ERP. · _Fix:_ Gulf-gated calendar list reusing the GST calendar widget.
- **[P2] Tax-groups management screen** — only a picker widget; no admin CRUD, and backend `TaxGroupController` is GET-only. · _Backend:_ `tax/controller/TaxGroupController.java` (list/detail) · _Flutter:_ `tax_groups/.../tax_group_picker.dart` only · _Why (ERP):_ bundled-rate groups (e.g. GST+Cess) must be creatable; today they're install-seeded only. · _Fix:_ add POST/PUT/DELETE on the controller + a `tax_group_management_screen.dart` with inline rate rows.

### Missing form/detail fields

- **[P1] Journal "Reverse" action absent from UI** — `JournalController` `/{id}/reverse` exists; journal_detail_screen only offers Delete (MANUAL only). · _Backend:_ `accounting/controller/JournalController.java:48` · _Flutter:_ `journals/.../journal_detail_screen.dart` · _Why (ERP):_ posted entries are immutable — reversal is the ONLY correction path; users can't reverse an auto-posted (SALES/PURCHASE) entry from the app. · _Fix:_ add "Reverse entry" action on POSTED entries → posts reversing JE.
- **[P2] e-Invoice signed QR not rendered as image** — QR is captured/stored as text (`qrCtrl`, line 540) but never drawn; no `Image.memory`/`QrImageView`, no print. · _Backend:_ `EInvoice.signedQr` stored · _Flutter:_ `gst_compliance_tabs.dart` EInvoicesTab · _Why (ERP):_ the signed QR must physically accompany the printed/emailed invoice per e-invoice rules. · _Fix:_ render signedQr as a scannable QR on the e-invoice card + on the invoice PDF; add print/share.
- **[P2] Form 16 PDF / 24Q CSV / 24Q FVU download buttons missing** — SalaryTdsTab only `Share.share`s the JSON (lines 1053/1059); backend has `/form16/{id}/pdf`, `/24q/csv`, `/24q/fvu`. · _Backend:_ `TdsController` + `Form16PdfService` + `Form24QExporter` · _Flutter:_ `gst_compliance_tabs.dart` SalaryTdsTab · _Why (ERP):_ employees expect a printable Form 16; CAs need CSV (Tally) + FVU (NSDL portal). All three backends are ready and unused. · _Fix:_ add PDF/CSV/FVU download buttons (`Printing.sharePdf` / file download).
- **[P2] Account create: no GST/tax tagging or batch opening balances** — `account_create_screen` captures code/name/type/subType/parent/openingBalance only. · _Backend:_ `CreateAccountRequest` (also no tax fields) · _Flutter:_ `accounts/.../account_create_screen.dart` · _Why (ERP):_ ledgers often need a default tax rate (Tally's "GST applicable" on ledger) and migrations need a one-screen opening-balance batch entry, not per-account. · _Fix:_ add optional tax-rate tag on account; add an "Opening Balances" batch screen with a TB-balanced check.
- **[P2] Trial Balance: no export/print, no group subtotals, no drill** — table only. · _Backend:_ `/reports/trial-balance` (flat lines) · _Flutter:_ `reports/.../trial_balance_screen.dart` · _Why (ERP):_ a TB is exported/shared with the CA and drilled account→ledger constantly. · _Fix:_ add PDF/Excel export, tap-row → general ledger, optional group rollup.
- **[P2] Amortization create uses raw account codes** — debit/credit are free-text code inputs, no account picker/search. · _Backend:_ `AmortizationController` create (debitAccountCode/creditAccountCode) · _Flutter:_ `amortization/.../amortization_screen.dart` · _Why (ERP):_ copy-paste code typos → posting failures; every other form uses an account dropdown. · _Fix:_ swap to the existing account-picker; add a period-by-period schedule table on detail.
- **[P3] Journal create: no FX rate / base-currency / taxComponentCode inputs** — `JournalLine` carries exchangeRate/baseDebit/baseCredit/taxComponentCode but the form sends none. · _Backend:_ `JournalLine` entity · _Flutter:_ `journal_create_screen.dart` · _Why (ERP):_ multi-currency manual entries can't be booked at a chosen rate; tax-tagging a manual line is impossible. · _Fix:_ optional currency+rate per line when org is multi-currency.
- **[P3] CA console: trial-balance-mismatch count not drillable** — dashboard shows `unbalancedTrialBalanceCount` but no click-through. · _Backend:_ CA dashboard + `/migration/tally/verify-trial-balance` · _Flutter:_ `ca_console_screen.dart` · _Why (ERP):_ TB diff hunting is the #1 post-migration audit step. · _Fix:_ tap count → mismatch list → drill into GL.

### Missing business capabilities

- **[P1] No fiscal-year setup / year-end closing entry** — period screen only closes/reopens/locks a *month*; there is no FY definition (Apr–Mar) and no year-end close that rolls P&L into Retained Earnings. · _Backend:_ `FiscalPeriodController` (month ops only); no year-close endpoint found · _Flutter:_ `period_close_screen.dart` (month) · _Why (ERP):_ the single most fundamental annual accounting action (closing the books, zeroing income/expense to retained earnings) is absent — opening balances for the new FY can't be struck. · _Fix:_ add FY config + a year-end closing routine (P&L → Retained Earnings JE) + UI.
- **[P2] No TDS/TCS challan / CIN deposit tracking** — after deduction/collection there's nowhere to record the ITNS-281 deposit, CIN, or "unpaid TDS by quarter". · _Backend:_ none · _Flutter:_ none · _Why (ERP):_ deposit-status is a statutory tracking need feeding 26Q/27EQ. · _Fix:_ add tds_deposit/tcs_deposit tables + a Deposits tab (quarter, amount, CIN, date, status).
- **[P2] No vendor TDS certificate (Form 16A)** — only employee Form 16 exists; purchasers can't issue 16A to vendors. · _Backend:_ none (only Form16PdfService) · _Flutter:_ none · _Why (ERP):_ vendors need 16A annually to claim TDS credit. · _Fix:_ add Form 16A generator + "issue 16A" action in the TDS tab.
- **[P2] Tally TB-verification + AI ledger-mapping are read-only** — `verify-trial-balance` shows mismatches with no reconcile/drill; `suggest-mapping` (LLM) has no UI to accept/override unmapped ledgers. · _Backend:_ `/migration/tally/verify-trial-balance`, `/suggest-mapping` · _Flutter:_ `tally_import_screen.dart` · _Why (ERP):_ 5–15% of ledgers stay unmapped post-import; mismatches block sign-off. · _Fix:_ wire suggest-mapping into the preview (accept/override per ledger) + make the TB-mismatch table drillable.

### Wiring & UX issues

- **[P2] TDS/TCS/Salary-TDS are buried as tabs inside the GST dashboard** — no top-level sidebar entry; a non-GST org with only TDS obligations has no obvious place to find them. · _Flutter:_ `gst_dashboard_screen.dart` tabs · _Why (ERP):_ TDS/TCS are income-tax, not GST; Zoho/Tally surface them as their own area. · _Fix:_ add a "TDS/TCS" or "Statutory" sidebar group, or promote the tabs to routed screens.
- **[P2] GSTR-1 / GSTR-3B export buttons not surfaced** — `/gstr1/export` and `/gstr3b/export` (JSON download) exist; the dashboard shows summary numbers but no Export action. · _Backend:_ `GstController` export endpoints · _Flutter:_ GST dashboard · _Why (ERP):_ filers feeding the GST portal / a CA's offline tool need the JSON download. · _Fix:_ add Export buttons to the GSTR-1/3B tabs.
- **[P2] GSTR-1 / GSTR-3B have no per-section drill-down** — only counts/summary; can't inspect the B2B invoice list, CDNR, or the 12+ 3B tables. · _Flutter:_ GST dashboard · _Why (ERP):_ correcting a B2B/CDNR row before filing requires seeing the rows. · _Fix:_ section-detail screens (B2B/B2CL/B2CS/CDNR/HSN; 3B tables).
- **[P3] GSTR-2B summary has no per-row match drill** — shows counts; the per-entry `matchStatus`/`matchedBillId`/note is in the list endpoint but not explored. · _Backend:_ `Gstr2bEntry` fields · _Flutter:_ Gstr2bTab · _Why (ERP):_ resolving a VALUE_MISMATCH/NOT_IN_BOOKS needs the row + matched bill link. · _Fix:_ drill row → match status + open matched bill.
- **[P3] CA delegated-access tokens generated but never shown; CA-staff onboarding has no UI** — `{linkId}/access-token` returns a JWT; `/ca/staff` is read-only. · _Backend:_ CA endpoints · _Flutter:_ `ca_console_screen.dart` · _Why (ERP):_ tokens bridge CA↔client; staff onboard/offboard daily. · _Fix:_ token list/revoke/refresh + staff invite/revoke UI.
- **[P3] Amortization run is month-by-month only** — no "run through end of FY"/quarter batch, no indication which months already ran. · _Flutter:_ `amortization_screen.dart` · _Why (ERP):_ orgs with many schedules need bulk run; easy to skip/double-run a month. · _Fix:_ batch run + per-period "run/pending" markers.

## Stats
P1=9, P2=18, P3=8, screens-missing=12, fields-missing=8

(P1 screens: VAT201-UAE, VAT-Oman, GSTR-2B IMS, TDS register, TCS register. P1 fields/capabilities: journal Reverse action, fiscal-year/year-end close, plus the two VAT screens double as capabilities. P2 missing screens: CMP-08, rate-remap, month-end close, PINT-AE, Gulf calendar, tax-groups mgmt. Verified corrections vs sub-agents: e-invoice generate-gsp/cancel/portal-json ARE wired (EInvoicesTab); e-way bill record/cancel/generate-gsp/portal-json/check-vehicle ARE wired (EwayBillsTab) — the real e-invoice gap is QR *rendering*, not the actions.)


---

# Manufacturing — UI/Field Gap Audit

Scope: backend `src/main/java/com/katasticho/erp/manufacturing` (29 entities, 4 controllers, 11 services) vs Flutter `flutter_app/lib/features/manufacturing` (27 screens). Verified against actual code, not CLAUDE.md claims.

The backend is enormous and feature-complete (~115 endpoints across 4 controllers); the Flutter layer is a thin, UUID-driven shell. The recurring failure mode: **screens capture and display raw UUIDs instead of names** (item/operation/workstation/parameter/reason-code/routing all pasted by hand), and **~12 backend capabilities have a screen that is orphaned** (reachable only via the command palette — not in the sidebar), while several backend features (QC disposition/NCR/CoA, job-work ITC-04, merge/clone/disassembly WO, BMR yield) have **no UI affordance at all**.

## Coverage map

| Sub-domain | Backend key fields / endpoints | Flutter screen(s)? | Wired into routes/sidebar? |
|---|---|---|---|
| **Work order — lifecycle** | `WorkOrder` status, priority, approvalStatus, plannedStart/End, actualStart/End, rm/labor/overhead/total/unitCost, salesOrderId, parentWorkOrderId, routingId, bomVersion, backflushMode `POST/GET /work-orders`, `/issue`, `/receive`, `/cancel` | work_order_list / _create / _detail | **Sidebar** (Work Orders) |
| WO — priority | `priority` URGENT/HIGH/NORMAL/LOW, `?priority=` filter, `POST /work-orders/{id}/priority` | none (not in create/detail) | NO |
| WO — approval | `approvalStatus`, `approvedBy/At`, `WorkOrderWorkflowHandler` PENDING_APPROVAL gate | none | NO |
| WO — clone | `POST /work-orders/{id}/clone` | none | NO |
| WO — split | `POST /work-orders/{id}/split` | detail overflow menu | via WO detail |
| WO — merge | `POST /work-orders/merge` | none (backend-only per CLAUDE) | NO |
| WO — disassembly | `POST /work-orders/disassembly`, `/disassemble` | none | NO |
| WO — sub-assembly / parent-child | `parentWorkOrderId`, `/create-sub-assembly-wos`, `/children` | "Cascade" in detail menu; children list not shown | partial |
| WO — batch on FG receipt | `receiveFinishedGoods(qty, batch, expiry)` | receive dialog (batch+expiry) | via WO detail |
| WO — actual cost preview | `GET /work-orders/{id}/actual-cost-preview` | actual_cost_preview_screen (paste WO id) | **palette only** |
| WO — from-reorder | `POST /work-orders/from-reorder` | WO list header button | via WO list |
| WO — from-sales-order | `POST /work-orders/from-sales-order` | none | NO |
| **BOM — editor** | BomComponent CRUD (inventory pkg), explosion, scrapPercent, isPhantom | none (item_detail + bom_repository only; no tree editor) | NO |
| BOM — versioning | `POST /bom/{id}/version`, `/version/{n}`, `/latest-version` | none | NO |
| BOM — diff | `GET /bom/{id}/diff` | bom_version_diff_screen (paste id+versions) | **palette only** |
| BOM — alternates (substitute) | `GET/POST/DELETE /bom-alternates`, `/lines/{id}/substitute` | none | NO |
| BOM — co-products | `GET/POST/DELETE /bom-co-products` | none | NO |
| BOM — phantom | `item.is_phantom` | none | NO |
| BOM — parameterized/variant | `GET /bom/{id}/diff`, variantFilter, `GET items/{id}/bom/resolve` | parameterized_bom_screen (paste id+attrs) | **palette only** |
| BOM — cost rollup | `GET /bom/{itemId}/cost-rollup` | none | NO |
| **Routing / Operations** | `Routing` name/itemId/isDefault/operations | routing_list (+Workstations tab) / routing_create | **Sidebar** (Routings) |
| Operations master | `POST/GET /operations` (code/name/setup/runTime) | none (must paste opId everywhere) | NO |
| Workstations master | `POST/GET /workstations` (hourlyRate, capacityHoursPerDay) | routing_list Workstations tab (create name only) | via Routings |
| Job cards | `JobCard` seq/op/ws/assignedTo/plannedQty/completedQty/scrapQty/timeLoggedMinutes `GET /work-orders/{id}/job-cards`, `/start`, `/complete` | job_card_list_screen | route exists; **no link from WO detail** |
| Op — alternates (alt work center) | `POST/DELETE /workstation-alternates`, `/available-workstation` | workstation_alternates_screen (paste op id) | **palette only** |
| Op — dependencies | `POST/DELETE /routing-operation-dependencies`, `/predecessors`, `/successors` | operation_dependencies_screen (paste op id) | **palette only** |
| Op — attachments/work-instructions | `POST/GET/DELETE /operations/{id}/attachments` | operation_attachments_screen (paste op id) | **palette only** |
| **Job work (subcontract)** | `JobWorkOrder` vendor/wh/charges/challanNumber/sendDate/returnDate/gstReturnDeadline `POST/GET /job-work`, `/send`, `/receive`, `/cancel`, `/gst-alerts` | job_work_list / _create / _detail | **Sidebar** (Job Work) |
| **Quality control — inspections** | `QcInspection` type/ref/item/batch/inspected/accepted/rejected/inspector + results `POST/GET /qc/inspections`, `/results`, `/finalize` | qc_inspection_list / _detail | **Sidebar** (Quality Control) |
| QC — templates | `POST/GET /qc/templates` (+parameters) | none | NO |
| QC — disposition | `POST /qc-inspections/{id}/disposition` ACCEPT/REJECT/HOLD + quarantine | none | NO |
| QC — NCR | `POST/GET/PUT /qc/ncrs`, `/close` | none | NO |
| QC — CoA | `GET /qc-inspections/{id}/coa` | none | NO |
| **Scrap** | `ScrapReasonCode`, `ProductionScrap` `POST /scrap/reason-codes`, `/work-orders/{id}/scrap` | scrap_screen (2 tabs) | **Sidebar** (Scrap) |
| **MRP** | `MrpRun`, demand/supply/PlannedOrder `POST /mrp/run`, `/runs`, `/convert-po`, `/convert-wo` | mrp_run_screen | **Sidebar** (MRP Runs) |
| **Maintenance** | `MaintenanceSchedule`, `MaintenanceWorkOrder`, downtime `/maintenance/...`, `/reports/downtime` | maintenance_screen (3 tabs) | **Sidebar** (Maintenance) |
| Maintenance — reliability MTBF/MTTR | `GET /maintenance/reports/reliability` | reliability_screen | **palette only** |
| **Pharma BMR** | step-records/signoffs/deviations/yield/snapshot/pdf | bmr_screen (paste WO id) | **palette only** |
| **CAPA** | `CapaController` @ `/manufacturing/capa` raise/start/complete/verify | capa_screen | **palette only** |
| **Bottleneck / workstation-load** | `GET /reports/workstation-load`, `/bottlenecks` | workstation_load_screen | **palette only** |
| **Production analytics / trends** | `/reports/production-trends`, `/work-order-profitability`, `/scrap-rate`, `/production-summary` | production_analytics_screen (3 tabs) | **palette only** |
| WIP valuation / consumption / cost-variance | `/reports/wip-valuation`, `/consumption`, `/cost-variance` | none | NO |
| MTO/MTS production mode | `PATCH /items/{id}/production-mode` | production_mode_screen (paste item id) | **palette only** |
| Shop-floor mobile | `GET /work-orders/by-number/{n}` + reuse JC/scrap | shop_floor_screen (scan WO#) | **Sidebar** (Shop floor) |

## Gaps

### Missing screens

- **[P1] No QC inspection plan/disposition/NCR/CoA UI** — backend supports full disposition (ACCEPT/REJECT/HOLD + quarantine), Non-Conformance Reports (open→close lifecycle), and Certificate of Analysis JSON, but `qc_inspection_detail_screen.dart` exposes ONLY Record-Results + Finalize. There is no NCR list/screen and no CoA print. · _Backend:_ `ManufacturingController.recordDisposition/createNcr/listNcrs/updateNcr/closeNcr/getCertificateOfAnalysis` · _Flutter:_ none (detail stops at finalize) · _Why (ERP):_ disposition + NCR is the whole point of QC for pharma/ISO shops; a failed inspection currently dead-ends. · _Fix:_ add disposition action + NCR tab/list + "Print CoA" button on `qc_inspection_detail_screen.dart`.

- **[P1] No QC Template management screen** — templates with parameters (min/max/acceptable/mandatory) can only be created via raw API; the inspection create dialog asks you to paste a "Template ID (UUID)" you can't look up in-app. · _Backend:_ `POST/GET /qc/templates` · _Flutter:_ none · _Why (ERP):_ inspections without a template have no parameters to record → results entry becomes free-text UUID guessing. · _Fix:_ QC templates list+editor screen; make the inspection dialog pick a template from a dropdown.

- **[P1] No Operations master screen** — `Operation` (code/name/setup-time/run-time/default-workstation) can only be created by API. Every routing-create row and job-card flow forces you to paste an "Operation ID (UUID)". · _Backend:_ `POST/GET /operations` · _Flutter:_ none · _Why (ERP):_ operations are the reusable building block of routings; you literally cannot build a routing in the UI without first creating operations elsewhere. · _Fix:_ Operations list+create screen; routing-create picks operations from a searchable list.

- **[P2] No BOM editor screen anywhere** — the WO depends entirely on a composite item's BOM, but there is no manufacturing BOM tree editor (only `bom_repository.dart` + item_detail in inventory, plus the read-only diff/parameterized screens). Co-products, alternates, phantom, scrap%, versioning, and cost-rollup all have endpoints and **zero** UI. · _Backend:_ `/bom/*`, `/bom-alternates`, `/bom-co-products`, `/bom/{id}/version`, `/cost-rollup` · _Flutter:_ none (editor); diff+parameterized are palette-only viewers · _Why (ERP):_ BOM is the master data manufacturing runs on; editing it via API is not a product. · _Fix:_ BOM editor screen (tree add/remove lines, scrap%, alternates, co-products, version snapshot, cost rollup view).

- **[P2] No WO scheduling / capacity calendar / Gantt** — `plannedStart/End` are two date pickers on a flat form; there is no board, no calendar, no capacity view, and the bottleneck/load data lives in a separate palette-only screen. · _Backend:_ `WorkOrder.plannedStartDate/EndDate`, `BottleneckService.workstationLoadReport`, `RoutingOperationDependency` (DAG) · _Flutter:_ none · _Why (ERP):_ a planner needs to see what's running where and when; this is table-stakes shop scheduling. · _Fix:_ at minimum a WO calendar/board; ideally a Gantt fed by operation dependencies.

- **[P3] No material-shortage / availability view before issue** — `issueToProduction` will fail on insufficient batch stock (`MFG_INSUFFICIENT_BATCH_STOCK`) but the WO detail BOM-lines card shows only required/issued, never on-hand vs required, so the planner learns of a shortage only at issue time. · _Backend:_ stock balances exist; no shortage endpoint surfaced on WO · _Flutter:_ `work_order_detail_screen.dart` lines card · _Why (ERP):_ "can I build this?" is the first question on every WO. · _Fix:_ shortage column (required − on-hand) on the BOM-lines card; block/warn before issue.

### Missing form/detail fields

- **[P1] WO create has no Priority, Routing, BOM version, or SO link** — `work_order_create_screen.dart` captures only item/warehouse/qty/dates/labor/overhead/backflush/notes. The backend accepts `priority` and `bomVersion`, and a routing drives job-card generation. · _Backend:_ `createWorkOrder(... bomVersion, priority)`, `WorkOrder.routingId` · _Flutter:_ `work_order_create_screen.dart` · _Why (ERP):_ priority drives the default URGENT-first queue order; without a routing chosen at creation, job cards must be made later by pasting a routing UUID. · _Fix:_ add Priority dropdown, Routing picker, BOM-version picker to the create form.

- **[P1] WO detail/list never show the finished-good name, priority, or approval status** — list cards show only `workOrderNumber` + qty + cost; detail's Overview shows status/qty/dates/notes but not the FG item, priority, approvalStatus, routing, or backflush flag. · _Backend:_ `WorkOrder.finishedGoodId/priority/approvalStatus/backflushMode/routingId` · _Flutter:_ `work_order_list_screen.dart`, `work_order_detail_screen.dart` · _Why (ERP):_ "WO-00042" tells the user nothing about what is being built. · _Fix:_ resolve + show FG item name everywhere; add priority chip + approval badge to detail/list.

- **[P1] WO BOM-lines show `itemId` UUID, not item name** — `work_order_detail_screen.dart:128` renders `line['itemId']` as the line title. · _Backend:_ line has `itemId` only; needs name resolution · _Flutter:_ `work_order_detail_screen.dart` · _Why (ERP):_ a materials list of UUIDs is unusable on the floor. · _Fix:_ resolve item names for the lines (bulk lookup) and show name + SKU.

- **[P1] Job cards display raw `operationId`/`workstationId`/`assignedTo` UUIDs** — `job_card_list_screen.dart` truncates the operation UUID as the card title and shows workstation UUID in the sheet; no operation name, workstation name, or assignee name. · _Backend:_ JobCard carries IDs only · _Flutter:_ `job_card_list_screen.dart` · _Why (ERP):_ operators need "Cutting @ Saw-1, Ramesh", not "550e8400…". · _Fix:_ resolve operation/workstation/user names; show them on card + sheet.

- **[P2] QC inspection detail shows item/parameter/inspector/batch as truncated UUIDs** — `qc_inspection_detail_screen.dart` `_truncate(...)` on itemId/referenceId/batchId/inspectorId; results rows show "Param: <uuid>". · _Backend:_ ids only · _Flutter:_ `qc_inspection_detail_screen.dart` · _Why (ERP):_ a QC sheet must name the parameter being measured ("pH", "Hardness"), not a UUID. · _Fix:_ resolve names; results dialog should list the template's parameters by name instead of asking for a Parameter UUID.

- **[P2] Job-card complete dialog has no per-operation time-logging affordance beyond a single "Time Logged (minutes)" field; no start/stop timer, no assignee** — time is a manual minutes entry on completion only. · _Backend:_ `JobCard.timeLoggedMinutes`, `actualStart/End`, `assignedTo` · _Flutter:_ `job_card_list_screen.dart` complete dialog · _Why (ERP):_ shop-floor time capture is usually start/stop, and labor cost (tracker #80) depends on accurate `timeLoggedMinutes` × workstation rate. · _Fix:_ add start-timer on Start, auto-compute minutes on Complete; surface assignee.

- **[P2] Routing-create captures no operation setup/run-time overrides, no workstation-alternate, no dependency** — `routing_create_screen.dart` rows are just two UUID fields (operationId, workstationId). The backend `RoutingOperationInput` accepts `setupTimeOverride`/`runTimeOverride`. · _Backend:_ `createRouting(... setupTimeOverride, runTimeOverride)` · _Flutter:_ `routing_create_screen.dart` · _Why (ERP):_ routings need per-op time overrides to be useful for scheduling/costing. · _Fix:_ add override fields + operation/workstation pickers to the row.

- **[P3] Workstation create captures name only — no hourlyRate or capacityHoursPerDay** — `routing_list_screen.dart` workstation create form (`_nameCtl`). These two fields drive actual-cost-from-time-tracking (#80), bottleneck load (#92), and reliability availability. · _Backend:_ `createWorkstation(code, name, desc, hourlyRate, capacityHoursPerDay)` · _Flutter:_ `routing_list_screen.dart` · _Why (ERP):_ without rate+capacity, costing and bottleneck reports are blank. · _Fix:_ add code, hourlyRate, capacityHoursPerDay to the workstation create form.

### Missing business capabilities

- **[P1] Merge WOs, Clone WO, Disassembly orders have no UI** — backend ships `POST /work-orders/merge`, `/clone`, `/disassembly`, `/disassemble`; CLAUDE.md even admits "Merge UI ... not yet wired". · _Backend:_ `ManufacturingController.mergeWorkOrders/cloneWorkOrder/createDisassemblyOrder/executeDisassembly` · _Flutter:_ none · _Why (ERP):_ disassembly (e.g. tablet strips → bulk) and clone (repeat batch) are everyday WO operations. · _Fix:_ wire merge into WO-list multiselect; add Clone to detail menu; add a disassembly create entry point.

- **[P1] Job-work ITC-04 / GST return deadline not surfaced; `challanNumber` not editable** — `job_work_list_screen`/`detail` exist but the GST-alerts endpoint (`/job-work/gst-alerts`) and `gstReturnDeadline`/`challanNumber` (the legal heart of subcontracting in India) need explicit affordances. · _Backend:_ `JobWorkOrder.gstReturnDeadline/challanNumber`, `getGstDeadlineAlerts` · _Flutter:_ job_work screens (need verification of deadline surfacing) · _Why (ERP):_ ITC-04 filing depends on tracking the 180-day return window per challan. · _Fix:_ deadline badge/alert tab on job-work list; capture/show challan number.

- **[P2] BMR yield reconciliation / deviation lifecycle / signoffs reachable only by pasting a WO UUID** — `bmr_screen.dart` is a palette-only, paste-WO-id surface; no link from the WO detail for a pharma WO, and there is no cross-batch open-deviation queue UI (`GET /bmr/deviations/open` exists). · _Backend:_ `BmrController` (snapshot/yield/deviations/open) · _Flutter:_ `bmr_screen.dart` (palette only) · _Why (ERP):_ BMR is mandatory per batch for pharma — it must hang off the WO, not a hidden search box. · _Fix:_ add "Batch Record" action on WO detail when FG is pharma; deviations-open work queue.

- **[P2] MRP planned-order convert-to-PO/WO and demand/supply pegging visibility** — `mrp_run_screen.dart` exists but convert actions + the demand/supply detail per planned order need verification; without them MRP output is read-only. · _Backend:_ `/mrp/planned-orders/{id}/convert-po|convert-wo`, MrpDemand/MrpSupply · _Flutter:_ `mrp_run_screen.dart` · _Why (ERP):_ MRP is worthless if you can't action the planned orders it produces. · _Fix:_ ensure convert buttons + pegging drill-down on each planned order row.

- **[P3] No WIP-valuation / consumption / cost-variance report screens** — three reporting endpoints have no Flutter surface (production_analytics covers trends/profitability/scrap only). · _Backend:_ `/reports/wip-valuation`, `/consumption`, `/cost-variance` · _Flutter:_ none · _Why (ERP):_ WIP valuation is needed for month-end; cost variance closes the planned-vs-actual loop. · _Fix:_ add these as tabs/cards (analytics screen or a finance report).

### Wiring & UX issues

- **[P1] ~12 manufacturing screens are orphaned from the sidebar — palette-only** — Production Analytics, BOM Diff, Parameterized BOM, Actual Cost Preview, Workstation Load, CAPA, Reliability, Production Mode, BMR, Operation Attachments, Operation Dependencies, Workstation Alternates are registered in `command_registry.dart` and `app_router.dart` but NOT in `_manufacturingGroup` (8 items only: Work Orders, Routings, Job Work, QC, Scrap, Maintenance, Shop floor, MRP Runs). A user who doesn't know to hit Ctrl+K will never find them. · _Backend:_ n/a · _Flutter:_ `routing/shell_screen.dart:840`, `core/commands/command_registry.dart` · _Why (ERP):_ features that aren't discoverable don't exist for the user. · _Fix:_ add a "Reports & Tools" sub-section under Manufacturing, or hang these off the relevant detail screens (BMR/analytics/cost on WO; dependencies/attachments/alternates on routing).

- **[P1] Job Cards screen is route-registered but has no entry point from the WO detail** — `/manufacturing/work-orders/:id/job-cards` exists, but `work_order_detail_screen.dart` has no "Job Cards" button (its menu only has costs/sub-assembly/split/cancel). Operators cannot reach job cards from the WO they're looking at. · _Backend:_ `GET /work-orders/{id}/job-cards` · _Flutter:_ `work_order_detail_screen.dart` · _Why (ERP):_ job cards are the per-operation execution of the WO; they must be one tap away. · _Fix:_ add a "Job Cards" button/section to WO detail.

- **[P2] Pervasive "Paste UUID" data entry across create dialogs** — Scrap (WorkOrder/Item/ReasonCode/JobCard all "Paste UUID", despite reason codes being listable in the sibling tab), QC inspection (Item/Template/Reference UUID), Job-card create (Routing UUID), Routing create (Operation/Workstation/Item UUID), BMR/CAPA/AltWS/OpDep/OpAttach/BomDiff/Parameterized/ActualCost/ProductionMode (paste WO/op/item id). No searchable pickers. · _Backend:_ n/a · _Flutter:_ `scrap_screen.dart`, `qc_inspection_list_screen.dart`, `job_card_list_screen.dart`, `routing_create_screen.dart`, + all palette-only screens · _Why (ERP):_ no real user has UUIDs memorised; this makes the whole module unusable outside a developer demo. · _Fix:_ replace every UUID `TextField` with a searchable picker (items, operations, workstations, reason codes, WOs) — the pattern already exists in `work_order_create_screen.dart` item search.

- **[P2] Costs rendered as `₹$value` string concatenation, not `KMoney`** — `work_order_detail_screen.dart:467` `_currency()` returns `'₹$value'` (no grouping, no tabular figures); WO list does the same (`'₹$totalCost'`). Violates the design-system money-cell rule. · _Backend:_ n/a · _Flutter:_ `work_order_detail_screen.dart`, `work_order_list_screen.dart` · _Why (ERP):_ inconsistent, ungrouped currency reads as untrustworthy and breaks the dense-table aesthetic. · _Fix:_ use `KMoney(amount)` for all cost cells.

- **[P3] WO detail has no link to actual-cost-preview, profitability, BOM cost-rollup, or batch-trace/recall for that WO** — all four exist as endpoints/screens but require re-pasting the WO/FG id elsewhere. · _Backend:_ `/work-orders/{id}/actual-cost-preview`, `/reports/work-order-profitability`, `/bom/{itemId}/cost-rollup`, `inventory /batch-trace/recall` · _Flutter:_ separate palette screens · _Why (ERP):_ context is lost; the user is doing manual id-copy plumbing. · _Fix:_ deep-link these from the WO detail with the id pre-filled.

## Stats
- P1 = 13
- P2 = 12
- P3 = 6
- screens-missing = 6 (QC disposition/NCR/CoA, QC templates, Operations master, BOM editor, WO scheduling/Gantt, material-shortage view) + ~12 orphaned-from-sidebar (palette-only)
- fields-missing = 11 (WO create: priority/routing/bomVersion/SO-link; WO list+detail: FG name/priority/approval; WO BOM-lines item name; job-card op/ws/assignee names; QC item/param/inspector names; job-card time-logging; routing op time-overrides; workstation rate/capacity)


---

# Field Sales / MR (ERP admin) — UI/Field Gap Audit

Scope: ERP's own Flutter web/admin screens for field sales/MR/SFA (`flutter_app/lib/features/field_sales`, 16 screens + 1 repository). Backend: `src/main/java/com/katasticho/erp/{fieldsales,attendance}`. Verified against actual code, not CLAUDE.md claims.

**CLAUDE.md "ERP Flutter UI TODO" verdicts (all 3 are now BUILT — notes are stale):**
- Org-chart / manager-assignment UI → **DONE** (`field_org_chart_screen.dart`: indented tree from `/hierarchy/org-chart`, manager picker via `/org/users`, writes `/hierarchy/users/{id}/manager`). Nav + route wired.
- SSS entry/report UI → **DONE** (`secondary_sales_screen.dart`, 923 lines: statement editor with per-product opening/purchase/sales/return/value lines + submit; secondary-sales + stock-on-hand report tabs).
- RCPA entry/report UI → **DONE** (`rcpa_screen.dart`, 920 lines: audit entry with OWN/COMPETITOR lines + competitor name + qty/value; share % + competitor-league report tabs).

## Coverage map

| sub-domain | backend key fields | Flutter screen(s)? | wired? |
|---|---|---|---|
| Beats | code, name, area, city, state, description, isActive | `beat_list_screen.dart` (list + create + read-only customer expand) | partial — **create only**; no edit/delete; **no add-customer UI** |
| Beat customers | contactId, visitSequence, visitFrequency, geoLatitude/Longitude, notes | viewed read-only inside beat card | **read-only** — `addCustomerToBeat`/`removeCustomerFromBeat` endpoints exist, no UI |
| Routes | code, name, dayOfWeek, frequency, warehouseId, estimatedDistanceKm, estimatedDurationMinutes, beatIds[] | `route_list_screen.dart` (list + create w/ beat checkboxes) | partial — create only; **warehouse = free-text paste**; no edit/delete; estimatedDistance/duration not capturable |
| Vans | code, vehicleNumber, name, vehicleType, sourceWarehouseId, capacityWeightKg, capacityVolumeLitre | `van_list_screen.dart` (list + create + view stock sheet) | partial — create omits `sourceWarehouseId`; no edit/delete |
| Van stock / load / transfer | VanStockTransfer LOAD/RETURN, lines, confirm | only `getVanStock` (view) | **MISSING write** — load/return/confirm endpoints + api_config strings exist, zero UI |
| Field-sales assignment | salespersonId, routeId, vanId, territory, effectiveFrom/To | none | **NO SCREEN** — `fieldSalesAssignments` string defined, never used |
| Route execution | routeId, salespersonId, vanId, executionDate, start/endTime, start/endOdometer, planned/completed/skipped, totals | `route_execution_screen.dart` (today's list + create + start/complete) | partial — create uses **free-text IDs**; no odometer |
| Field visit | check-in/out GPS, geoVerified, geoDistanceM, salesOrderId, orderValue, collectionAmount, photoUrl, jointVisitUserId, skipReason | `route_execution_detail_screen.dart` (check-in/out/skip/record-order/record-collection) | partial — **no product-log/detail-aid/joint-visit/photo**; geoVerified not shown; SO id = free-text |
| Day-close | opening/collections/expenses/closing/deposited/variance cash, items loaded/sold/returned/closing, visit summary, approve/reject | `day_close_screen.dart` | OK — cash captured, stock+visit shown read-only, approve/reject; **but only reachable by deep-link, see UX** |
| Salesman targets / incentives | salespersonId, periodType, periodStart/End, **targetType** (REVENUE/VOLUME/VISITS/COLLECTIONS/NEW_CUSTOMERS), targetValue, achievedValue, incentiveRate, incentiveAmount | targets shown read-only in `salesman_dashboard_screen.dart` | **NO CREATE / NO UPDATE-ACHIEVEMENT** — no endpoint string, no repo method, no UI |
| Live GPS tracking | live locations, trail (km + pings) | `live_tracking_screen.dart` | OK |
| Tour plan (MTP) approval | DRAFT→SUBMITTED→APPROVED/REJECTED, entries | `mr_approvals_screen.dart` (Tour Plans tab) | OK (approve/reject + entries sheet) |
| DCR approval | per-day report, work-type, POB, samples | `mr_approvals_screen.dart` (DCRs tab) | OK |
| RCPA | audit + OWN/COMPETITOR lines, share/competitor reports | `rcpa_screen.dart` | OK |
| Stockist SSS | statement + lines + secondary-sales/stock-on-hand reports | `secondary_sales_screen.dart` | OK |
| Field allowance (TA/DA) | computeAllowance, claim, claims/me; rate config | `field_samples_screen.dart` (rate config only) | partial — **rate config + sample issue/return only; no claim review/approve surface** |
| Field samples | issue/return register, balance (issued/returned/distributed) | `field_samples_screen.dart` | OK (issue/return + balance + txns) |
| Detail aids (e-detailing) | CRUD, usage counts, visit log | `detail_aids_screen.dart` | OK (CRUD) — visit-log only from field app |
| Reporting hierarchy / org chart | reportsToUserId tree, assign manager | `field_org_chart_screen.dart` | OK |
| Coverage / deviation / frequency | deviation, frequency-compliance, team-dashboard | `field_coverage_screen.dart` | OK (3 tabs) |
| Attendance & leave admin | team punches by date, leave pending/approve/reject | `attendance_screen.dart` | partial — punches + leave approve/reject; no attendance regularization, no monthly summary |

## Gaps

### Missing screens

- **[P1] No salesman-target creation/update UI** — managers cannot set or adjust any target. Dashboard lists targets read-only; there is no create form and no "update achievement" action. Backend `createTarget` (5 target types) + `updateAchievement` fully implemented, but no api_config string for create and no repo method. · _Backend:_ `fieldsales/controller/FieldSalesController.java:621` (`POST /targets`), `:655` (`PUT /targets/{id}/achievement`) · _Flutter:_ none (only `fieldSalesTargets` read string in `api_config.dart:947`) · _Why (ERP):_ targets/incentives are the core of a sales-force module — unusable without an entry path. · _Fix:_ add target-create FAB + form (salesperson picker, target-type dropdown, period, value, incentive rate) and an update-achievement action on `salesman_dashboard_screen.dart`.

- **[P1] No field-sales assignment screen** — salesperson→route→van→territory mapping (with effective dates) can't be created or viewed in UI. `route_execution` create requires raw IDs because there's no assignment layer to resolve them. · _Backend:_ `FieldSalesController.java:244` (`POST /assignments`), `:263` (list), `:268` (by salesperson) · _Flutter:_ none (`fieldSalesAssignments` string at `api_config.dart:901` never used) · _Why (ERP):_ the assignment is what binds the whole route-execution flow to a person + van; without it route execution is hand-keyed. · _Fix:_ new `AssignmentScreen` (list + create with salesperson/route/van pickers + effective dates), nav entry, repo methods.

- **[P1] No van load / stock-transfer UI** — vans can never be stocked from the ERP. Only `getVanStock` (view) is wired; the LOAD/RETURN/confirm workflow has no screen. · _Backend:_ `FieldSalesController.java:286` (load), `:297` (confirm-load), `:306` (return), `:320` (confirm-return), `:327` (list) · _Flutter:_ none — `fieldSalesVanTransfersLoad/Return/ConfirmLoad/ConfirmReturn` strings exist in `api_config.dart:904-915`, called by zero screens · _Why (ERP):_ van-sales (FMCG) is dead without loading stock onto the van; the balance view shows an always-empty table. · _Fix:_ add a load/return sheet to `van_list_screen.dart` (warehouse + item lines + confirm) or a dedicated van-transfer screen.

### Missing form/detail fields

- **[P1] Beat customer assignment is read-only** — managers can't assign customers to a beat, set visit sequence, or visit frequency from the UI; the beat card only displays existing customers. · _Backend:_ `FieldSalesController.java:87` (`POST /beats/{id}/customers` w/ visitSequence + visitFrequency), `:101` (remove) · _Flutter:_ `beat_list_screen.dart:418` (display only) · _Why (ERP):_ beats are useless without a member list; route auto-visit generation reads `beat_customer`. · _Fix:_ add "Add customer" action in the expanded beat card (contact picker + sequence + frequency dropdown) and per-row remove.

- **[P2] Beat customer geo-coordinates not capturable** — `beat_customer.geoLatitude/geoLongitude` drive the geofenced check-in (`field_sales.geofence_radius_m`), but no UI sets them, so geofence verification silently never fires (entity comment: "null when the beat customer has no stored coordinates"). · _Backend:_ `entity/BeatCustomer.java:39-43`; geofence in `FieldSalesService.applyGeofence` · _Flutter:_ none · _Why (ERP):_ the whole geo-verification feature is inert until coords exist. · _Fix:_ capture lat/long (or "pin current location") in the add-customer-to-beat form above.

- **[P2] Route execution create uses free-text ID paste fields** — Route ID, Salesperson ID, Van ID all hand-typed (`route_execution_screen.dart:80-101`); same for Sales Order ID in record-order (`route_execution_detail_screen.dart:230`) and Warehouse ID in route create (`route_list_screen.dart:127`) and Van create has no warehouse at all. · _Backend:_ pickers available via `/org/users`, `/field-sales/routes`, `/field-sales/vans`, warehouses endpoint · _Flutter:_ those screens · _Why (ERP):_ pasting UUIDs is not a usable admin workflow; guarantees data-entry errors. · _Fix:_ replace the four free-text ID fields with dropdown/typeahead pickers.

- **[P2] Visit detail screen omits product-log, detail-aid log, joint-visit, photo, geo-verification** — the ERP `route_execution_detail_screen` only does check-in/out/skip/order/collection; it never shows or lets a manager edit detailing/sample/gift product logs, detail-aids shown, the joint-visit manager flag, the visit photo, or the geofence `geoVerified`/`geoDistanceM` result. · _Backend:_ `MrReportingController.java:98` (products), `:218` (detail-aids), `:124` (joint-visit); fields on `entity/FieldVisit.java:60-91` · _Flutter:_ `route_execution_detail_screen.dart` (none of these) · _Why (ERP):_ a manager auditing a visit can't see what was detailed/sampled or whether the rep was actually at the customer. · _Fix:_ show product-log + detail-aids + photo + geoVerified badge on each visit row; allow joint-visit mark.

- **[P3] Route `estimatedDistanceKm` / `estimatedDurationMinutes` not capturable** — entity has them, create form has neither; card shows distance if present but it's never settable. · _Backend:_ `entity/Route.java:34-38` · _Flutter:_ `route_list_screen.dart` · _Why (ERP):_ route planning metrics can't be entered. · _Fix:_ add the two optional fields to route create/edit.

- **[P3] Route execution odometer (start/end) not captured** — `start_odometer`/`end_odometer` exist for trip-distance reconciliation but no UI sets them. · _Backend:_ `entity/RouteExecution.java:42-45` · _Flutter:_ `route_execution_screen.dart` / detail · _Why (ERP):_ TA/DA & vehicle reconciliation lose the odometer cross-check. · _Fix:_ capture odometer at start/complete.

### Missing business capabilities

- **[P1] No admin surface to review/approve field allowance (TA/DA) claims** — `field_samples_screen` only edits the org rate config + issues samples. The claim lifecycle (`computeAllowance`/`claim`/`claims/me`) is MR-self-service only; a manager cannot list or audit submitted TA/DA claims or their expense-variance. · _Backend:_ `FieldSalesController.java:497-518` (`/allowance/me`, `/allowance/claim`, `/allowance/claims/me`) · _Flutter:_ none (no allowance read/claim strings in `api_config.dart`) · _Why (ERP):_ TA/DA claims create real expense entries; managers need visibility/control over reimbursements. · _Fix:_ add an allowance-claims admin tab (list claims by salesperson/date with GPS-km vs claimed-km variance).

- **[P2] No edit/delete on Beats, Routes, Vans** — every master is create-only in the UI; `PUT`/`DELETE` endpoints exist for all three but no screen calls them (no row menu, no edit dialog). · _Backend:_ `FieldSalesController.java:54/80` (beat), `:138/164` (route), `:198/228` (van) · _Flutter:_ the three list screens · _Why (ERP):_ a typo'd beat code or decommissioned van can never be fixed/removed. · _Fix:_ add edit + delete row actions to each list.

- **[P2] Attendance admin lacks regularization + monthly summary** — `attendance_screen` shows team punches + leave approve/reject only. No punch-correction (regularization) review and no monthly attendance summary, even though the HR module has `AttendanceManagementService.monthlySummary` and regularization flow. · _Backend:_ field side `attendance/AttendanceController.java`; richer HR `hr.service.AttendanceManagementService` · _Flutter:_ `attendance_screen.dart` · _Why (ERP):_ payroll LOP depends on accurate present-day reconciliation, which needs regularization + summary. · _Fix:_ add regularization-approval + monthly-summary to the field attendance screen (or link to HR).

### Wiring & UX issues

- **[P2] `getTargetAchievement` GETs a PUT endpoint** — repo `getTargetAchievement` does `_api.get(.../targets/{id}/achievement)` but backend only defines `PUT /targets/{id}/achievement` (`:655`); there is no GET, so this call 405/404s if ever invoked. · _Backend:_ `FieldSalesController.java:655` · _Flutter:_ `field_sales_repository.dart:221` · _Why (ERP):_ dead/broken method masking the real missing update-achievement UI. · _Fix:_ remove the GET and implement a PUT-based update-achievement method.

- **[P2] Repository `recordOrder`/`recordCollection`/`skipVisit` payload keys mismatch backend** — repo sends `{'amount': ...}` for collection but controller reads `collectionAmount` (`:451`); repo sends `{'reason': ...}` for skip but controller reads `skipReason` (`:431`). So these field actions silently post nulls (NumberFormatException / null skip reason) on a strict backend. · _Backend:_ `FieldSalesController.java:431,451` · _Flutter:_ `field_sales_repository.dart:160-179` · _Why (ERP):_ visit collection/skip recording is broken or records blanks. · _Fix:_ align payload keys to `collectionAmount` / `skipReason` (record-order already correct with `orderValue`/`salesOrderId`).

- **[P3] Day Close reachable only via deep-link / route-execution flow** — `fieldSalesDayClose` is a static `/field-sales/day-close` route + nav entry but `day_close_screen` needs a `routeExecutionId` to initiate; the standalone nav lands with no execution context. · _Backend:_ `FieldSalesController.java:574` (`/day-close/initiate/{routeExecutionId}`) · _Flutter:_ `day_close_screen.dart`, nav `shell_screen.dart:797` · _Why (ERP):_ clicking "Day Close" in the sidebar gives a dead-end screen. · _Fix:_ make the nav day-close show a list of completed executions to pick from, or remove the top-level nav and drive it from execution detail.

- **[P3] Legacy `FieldSalesRepository` returns untyped `Map` everywhere; newer screens bypass it with their own Dio** — org-chart, samples, coverage, secondary-sales, rcpa, detail-aids each re-implement API access (their own `_dio`/`apiClientProvider` calls) instead of the shared repo, so there's no single field-sales data layer and field-name drift (see payload-key bug above) goes uncaught. · _Flutter:_ `field_sales_repository.dart` vs the 6 self-contained screens · _Why (ERP):_ maintenance hazard; inconsistent error handling/response unwrapping. · _Fix:_ consolidate into the repository (or typed models) over time.

## Stats
P1=7, P2=10, P3=5, screens-missing=3 (target create, assignment, van-load), fields-missing=8 (beat-customer assign, beat-customer geo, free-text ID pickers ×4, visit product/aid/joint/photo/geo, route est-distance/duration, exec odometer, allowance-claim review counted under capabilities)


---

# HR & Payroll — UI/Field Gap Audit

Scope: `src/main/java/com/katasticho/erp/{hr,payroll}` (backend) vs `flutter_app/lib/features/{hr,payroll}` (UI).
Method: read entities + DTOs → fields; controllers → endpoints; Flutter screens → fields captured/shown + endpoints wired; cross-check `api_config.dart` + `app_router.dart`. Verified against actual code, not CLAUDE.md "DONE" claims.

Headline: the **backend is far richer than the UI surfaces.** Five fully-built backend capabilities have **zero Flutter wiring** — they are not even declared in `api_config.dart`: salary-structure builder, employee tax declaration (Form 12BB/regime/80C/HRA), PF ECR file, ESI return CSV, and bank salary disbursement file. Net-salary payment recording and statutory-payment recording have endpoints but no screen. The HR portal is broad (9 modules, all routed) but several admin-config surfaces (leave types, holiday calendar, shift assignment) have no UI despite full backend CRUD.

## Coverage map

| Sub-domain | Backend key fields / endpoints | Flutter screen(s)? | Wired? |
|---|---|---|---|
| **PAYROLL** | | | |
| Payroll settings | `payroll_settings`: pf/esi/pt/lwf/tds enabled + 7 GL account FKs + payFrequency + startMonth · `GET/PUT /payroll/settings` | `payroll_settings_screen.dart` | ✅ but **accounts = raw UUID text fields** (no picker); no statutory-rate config |
| Employee master | `Employee` (208 lines): identity, bank, statutory IDs, V18 personal/address/emergency/work-info, `userId` link · `GET/POST/PUT/DELETE /payroll/employees` | `employee_list_screen.dart`, `employee_form_screen.dart` | ✅ create/edit (deep form). **Detail route reuses the form — no read-only 360 view** |
| Salary structure (components, pay-type) | `EmployeeSalaryStructure` + `EmployeeSalaryComponent` (earning/deduction/employer, calcType, %, base) · `SalaryStructureRequest.ComponentLine` · `GET/POST /payroll/employees/{id}/salary-structure` · `GET/POST/PUT /payroll/salary-components` | **NONE** | ❌ **Endpoints in `api_config` but used by ZERO screens.** No way to define basic/HRA/CTC breakup or per-employee earnings/deductions in the UI |
| Pay-type hourly/piece-rate | `payType`/`hourlyRate`/`pieceRate` on structure | (set only via salary-structure POST — no screen) | ❌ no UI to set; only previewable |
| Labor-pay preview | `GET /payroll/employees/{id}/labor-pay-preview` | `labor_pay_preview_screen.dart` | ✅ |
| Payroll run lifecycle | `PayrollRun` DRAFT→CALCULATED→APPROVED→POSTED/CANCELLED · `GET/POST /payroll/runs[/calculate|/approve|/post|/cancel]` | `payroll_run_list_screen.dart`, `payroll_run_detail_screen.dart` | ✅ |
| Payslip (incl LOP) | `Payslip` (gross/deductions/employerContrib/net/lopDays) + `PayslipLine` · `GET /runs/{id}/payslips`, `/payslips/{id}`, `/payslips/{id}/pdf` | run-detail bottom sheet + PDF download | ✅ list+detail+PDF wired; **LOP days not shown** in sheet |
| Statutory (PF/ESI/PT/LWF/TDS) | `LwfRule`, `PtSlab` seeded; `ProfessionalTaxCalculator`, `LabourWelfareFundCalculator`; settings enable toggles | (computed at calculate; toggles in settings) | ⚠️ toggles only; **no slab/rate viewer or per-state PT/LWF UI** |
| Net-salary payment | `PayrollPayment` · `POST /runs/{id}/payment` | **NONE** | ❌ endpoint exists, no screen |
| Statutory payment | `StatutoryPayment` · `POST /payroll/statutory-payments` | **NONE** | ❌ endpoint exists, no screen |
| Tax declaration / Form 12BB | `EmployeeTaxDeclaration` (regime, HRA, 80C/80D/80E/80G/80TTA, home-loan, LTA) · `TaxDeclarationController` `/payroll/tax-declarations[/me|/{id}/submit|/verify]` | **NONE** | ❌ **Entire module dark — not in `api_config`, no screen** |
| Form 16 / 24Q (salary TDS) | `tax/...` `GET /tds/form16/{emp}`, `/tds/24q` | `gst_compliance_tabs.dart` (Salary TDS tab) | ✅ but JSON-share only, lives under **GST** not payroll |
| PF ECR file | `PfEcrFileGenerator` · `GET /runs/{id}/ecr` | **NONE** | ❌ not in `api_config`, no button |
| ESI return CSV | `EsiReturnFileGenerator` · `GET /runs/{id}/esi-return` | **NONE** | ❌ not in `api_config`, no button |
| Bank salary file | `BankSalaryFileGenerator` (GENERIC/HDFC/ICICI/SBI) · `GET /runs/{id}/bank-file` | **NONE** | ❌ not in `api_config`, no button |
| Reimbursements / loans / advances / bonus | — | — | ❌ **no backend entity at all** (not modelled) |
| **HR** | | | |
| Leave apply / balances / requests | `LeaveController` apply/approve/reject/cancel/me/pending/my-balances | `leave_management_screen.dart` (Apply/My Leave/Approvals) | ✅ |
| Leave-type config | `POST /hr/leave/types` (paid, quota, accrual, carry-forward, requires-approval) | **NONE** | ❌ admin CRUD has no UI (screen only GETs types) |
| Holiday calendar config | `POST/DELETE /hr/leave/holidays` | **NONE** | ❌ no UI to add/remove holidays |
| Employee mgmt (profile depth) | `HrEmployeeService` family/education/experience · subresource endpoints | `my_profile_screen.dart` (self) + admin form sections | ✅ |
| My Profile (self-service) | `/hr/employees/me` + family/education/experience | `my_profile_screen.dart` | ⚠️ personal info only — **no payslip / salary / leave-balance / document view** for the employee |
| Attendance regularization + summary | `AttendanceManagementController` regs + `summary/me` + `summary/{userId}` | `hr_attendance_screen.dart` | ⚠️ summary/me + regs wired; **no calendar/day-grid, no team `summary/{userId}`** |
| Shifts (defs) | `ShiftController` shift CRUD | `shift_management_screen.dart` | ✅ list+create defs |
| Shift assignment | `POST /hr/shifts/assignments`, `shiftOn` | **NONE** | ❌ `hrShiftAssignments` defined in `api_config` but no UI assigns or views |
| Timesheets | `TimesheetController` log/submit/approve/summary | `timesheet_screen.dart` | ✅ |
| HR help desk | `HrHelpDeskController` raise/comment/assign/status | `help_desk_screen.dart` | ✅ |
| Document mgmt + expiry | `EmployeeDocumentController` upload/me/{userId}/expiring/delete | `employee_documents_screen.dart` (My Docs / Expiring) | ⚠️ **`/{userId}` admin upload-for-employee not wired** (only self-upload + expiring) |
| HR analytics | `GET /hr/analytics/dashboard` | `hr_analytics_screen.dart` | ✅ |
| Offboarding + clearance + F&F | `OffboardingController` initiate/tasks/fnf/complete/cancel | `offboarding_screen.dart` | ✅ |

## Gaps

### Missing screens

- **[P1] Salary-structure builder screen** — no UI to define an employee's earnings/deductions/CTC breakup (basic, HRA, special allowance, employer PF, etc.). Backend `EmployeeSalaryStructure`/`EmployeeSalaryComponent` + `SalaryStructureRequest.ComponentLine` (calcType/percentage/baseComponent) and `salaryComponents` CRUD are fully built; `api_config` even declares `payrollEmployeeSalaryStructure`/`salaryComponents`, but **no screen references them**. · _Backend:_ `payroll/controller/PayrollController.java` (`/employees/{id}/salary-structure`, `/salary-components`) · _Flutter:_ none (grep of `lib/features/` returns zero) · _Why (ERP):_ without a structure, the payroll run cannot compute component-wise earnings — this is the heart of payroll and it's unreachable from the UI · _Fix:_ add a salary-structure tab on the employee detail screen + a salary-component master screen.

- **[P1] Employee tax-declaration / Form 12BB screen (regime + 80C/HRA/deductions)** — the whole `EmployeeTaxDeclaration` module (OLD/NEW regime, HRA, 80C/80D/80E/80G/80TTA/80TTB, home-loan interest, LTA, DRAFT→SUBMITTED→VERIFIED) has a controller with `/me` self-service and admin verify, but is **not declared in `api_config.dart`** and has no screen. · _Backend:_ `payroll/controller/TaxDeclarationController.java`, `payroll/service/TaxDeclarationService.java` · _Flutter:_ none · _Why (ERP):_ Indian salaried employees declare investments at FY start so monthly TDS is correct; without it every employee is taxed at the no-declaration max · _Fix:_ employee self-service declaration form (regime toggle + deduction fields) + admin verify list.

- **[P1] Statutory-return file downloads (PF ECR, ESI return, bank salary file)** — three generators (`PfEcrFileGenerator`, `EsiReturnFileGenerator`, `BankSalaryFileGenerator` with GENERIC/HDFC/ICICI/SBI) are wired to `GET /runs/{id}/{ecr|esi-return|bank-file}` but **none of the three endpoints exist in `api_config.dart`** and the payroll-run detail screen has no download buttons. · _Backend:_ `PayrollController.java` lines 308–357 · _Flutter:_ none on `payroll_run_detail_screen.dart` · _Why (ERP):_ these are the files an employer physically uploads to EPFO/ESIC and the bank to remit/disburse — the monthly payroll deliverable · _Fix:_ add a "Downloads" action group on the run-detail screen (ECR / ESI CSV / Bank file with format dropdown / + existing payslip PDF).

- **[P2] Net-salary payment + statutory-payment recording screens** — `POST /runs/{id}/payment` (record net-pay disbursement, posts DR Salary Payable / CR bank) and `POST /payroll/statutory-payments` (record PF/ESI/PT/LWF/TDS remittance, posts the payable clear) both exist with journal posting (BUG-11 fix) but have no UI. · _Backend:_ `PayrollController.java` lines 361–390 · _Flutter:_ none · _Why (ERP):_ POSTED payroll leaves Salary Payable + statutory payables open on the books; without these screens they can never be cleared from the app · _Fix:_ "Record payment" button on POSTED runs + a statutory-payments screen (or tab) listing dues by type with a record-payment dialog.

- **[P2] Read-only employee profile / 360 view** — `Routes.payrollEmployeeDetail` (`/payroll/employees/:id`) renders `EmployeeFormScreen` (the edit form), so there is no read-only employee record that aggregates profile + salary structure + payslip history + leave balance. · _Backend:_ data all available (`/payroll/employees/{id}`, `/salary-structure`, payslips, `/hr/leave/my-balances`) · _Flutter:_ `app_router.dart` line ~1190 maps detail→form · _Why (ERP):_ HR needs a one-screen employee summary; editing-as-viewing is error-prone · _Fix:_ dedicated detail screen with tabs (Profile / Salary / Payslips / Leave / Documents).

- **[P2] Leave-type config + holiday-calendar screen** — `POST /hr/leave/types` (paid/unpaid, quota, accrual, carry-forward) and `POST/DELETE /hr/leave/holidays` are admin CRUD with no UI; the leave screen only *consumes* types/holidays. A fresh org has no way to create a leave policy or holiday list from the app. · _Backend:_ `hr/controller/LeaveController.java` lines 30–66 · _Flutter:_ none · _Why (ERP):_ leave balances/working-day math depend on configured types + holiday calendar — unconfigurable = unusable · _Fix:_ HR-settings screen: leave-type list/create + annual holiday calendar editor.

- **[P3] Shift-assignment screen** — `POST /hr/shifts/assignments` + `shiftOn(user,date)` exist (and `hrShiftAssignments` is in `api_config`) but `shift_management_screen.dart` only lists/creates shift *definitions* — there's no UI to assign a shift to an employee or see who is on which shift. · _Backend:_ `hr/controller/ShiftController.java` · _Flutter:_ none · _Why (ERP):_ a shift definition with no roster is inert · _Fix:_ "Assign shift" action + roster view.

- **[P3] Attendance calendar / team view** — only the per-user monthly *summary* (`summary/me`) is shown as a key-value list; there's no day-grid/calendar of punches, and the admin `summary/{userId}` (team) endpoint is not wired. · _Backend:_ `AttendanceManagementController` `summary/{userId}` · _Flutter:_ `hr_attendance_screen.dart` summary tab is KV only · _Why (ERP):_ HR reviews team attendance and spots gaps via a calendar, not a totals list · _Fix:_ add a month-grid view + team-summary tab (admin).

### Missing form / detail fields

- **[P1] Salary structure absent from the employee form** — `employee_form_screen.dart` (940 lines) captures identity, work-info, personal, address, emergency, bank, statutory IDs and applicability toggles, but **no CTC / gross / component breakup**. So an employee can be created and a payroll run calculated against an empty structure. · _Backend:_ structure is a separate resource · _Flutter:_ `employee_form_screen.dart` · _Why (ERP):_ pay can't be computed without it · _Fix:_ add a salary section (or post-create step) that POSTs the structure.

- **[P2] LOP days not surfaced on the payslip** — `Payslip.lopDays` (loss-of-pay from unpaid leave, the whole attendance→payroll integration) is returned but the payslip bottom sheet in `payroll_run_detail_screen.dart` never displays it; the employee/HR can't see why earnings were prorated. · _Backend:_ `Payslip.lopDays` · _Flutter:_ `payroll_run_detail_screen.dart` `_showPayslipDetail` · _Why (ERP):_ "why is my salary short?" is the #1 payslip query · _Fix:_ render LOP days + prorated note in the sheet (PDF already includes it via `PayslipPdfService`).

- **[P3] My Profile shows no salary / payslip / leave / document** — `my_profile_screen.dart` (1217 lines) explicitly notes salary is "read-only here" but in fact renders **only** personal/address/emergency + family/education/experience; an employee can't view their own payslips, salary breakup, leave balance, or documents in one place. · _Backend:_ all available to the user (`/payslips/{id}/pdf` is OWNER/ADMIN/ACCOUNTANT only though — see below) · _Flutter:_ `my_profile_screen.dart` · _Why (ERP):_ self-service ESS is a core HR expectation · _Fix:_ add My Payslips / My Leave / My Documents cards (and a self-service payslip-PDF endpoint).

- **[P3] Payroll settings has no statutory-rate fields** — `payroll_settings_screen.dart` exposes only enable toggles + 7 GL-account text fields; PF rate/ceiling (12% / ₹15k wage ceiling), ESI rates (0.75%/3.25%) and the ₹21k gross threshold, PT slabs and LWF amounts are hardcoded in calculators/seeds with no viewer or override. · _Backend:_ `ProfessionalTaxCalculator`, `LabourWelfareFundCalculator`, `PtSlab`/`LwfRule` seeds · _Flutter:_ `payroll_settings_screen.dart` · _Why (ERP):_ orgs need to see/confirm the rates being applied and handle the PF voluntary-ceiling option · _Fix:_ read-only statutory-rate summary (per-state PT/LWF) + a PF-ceiling option.

### Missing business capabilities

- **[P2] No reimbursements / advances / loans / bonus** — there is no backend entity or UI for expense reimbursements, salary advances, staff loans (with EMI recovery), or ad-hoc bonus/arrears — all standard Indian SMB payroll inputs that feed a payslip. · _Backend:_ absent in `payroll` package · _Flutter:_ none · _Why (ERP):_ these are routine monthly payslip adjustments; without them payroll only handles fixed structures · _Fix:_ model one-off payslip adjustments (earning/deduction inputs per run) — smallest version is an ad-hoc line input on a payslip.

- **[P3] Payslip-PDF self-service download is admin-gated** — `GET /payslips/{id}/pdf` is guarded `hasAnyRole('OWNER','ADMIN','ACCOUNTANT')` (the code comment itself flags a separate `/payslips/me/{id}` as "added when we wire YTD + Form 16" — never built). An ordinary employee cannot download their own payslip. · _Backend:_ `PayrollController.java` line ~290 · _Flutter:_ n/a · _Why (ERP):_ employees must self-serve their payslip · _Fix:_ add a `/payslips/me/{id}/pdf` ESS endpoint + a My Payslips list.

### Wiring & UX issues

- **[P2] GL-account mapping uses raw UUID text fields** — `payroll_settings_screen.dart` maps salary-expense/payable + 5 statutory-payable accounts via free-text `TextEditingController`s holding account UUIDs; a user must paste UUIDs. Everywhere else uses an account picker. · _Backend:_ accounts available via `/accounts` · _Flutter:_ `payroll_settings_screen.dart` lines 37–43 · _Why (ERP):_ pasting UUIDs is unusable; a wrong id silently mis-posts payroll journals · _Fix:_ replace with the existing account-dropdown widget.

- **[P3] Admin "upload document for employee" not wired** — `EmployeeDocumentController` has `POST /hr/documents/{userId}` (HR uploads a doc on behalf of an employee) but `employee_documents_screen.dart` wires only self-upload (`/me`) + expiring; HR can't attach offer letters/contracts to an employee from the app. · _Backend:_ `EmployeeDocumentController` · _Flutter:_ `employee_documents_screen.dart` · _Why (ERP):_ HR-side document management is half-built in the UI · _Fix:_ add an employee-picker upload path for OWNER/ADMIN.

- **[P3] Labor-pay preview / many HR dialogs require pasting a raw entity id** — `labor_pay_preview_screen.dart` (and several "paste an id" patterns) ask the user to type a payroll-employee UUID with no picker. · _Backend:_ n/a · _Flutter:_ `labor_pay_preview_screen.dart` line ~81 · _Why (ERP):_ no user knows a UUID; this is an internal-tool UX · _Fix:_ employee autocomplete instead of a text field.

## Stats
P1=6, P2=8, P3=10, screens-missing=8, fields-missing=4


---

# Pharma, POS, Loyalty & Contacts — UI/Field Gap Audit

Repo: `/home/user/katasticho` (backend `src/main/java/com/katasticho/erp`, Flutter `flutter_app/lib/features`).
Method: read entities/DTOs → controllers → Flutter screens; verified against code, not CLAUDE.md "DONE" claims.

## Coverage map

| Sub-domain | Backend key fields / endpoints | Flutter screen(s)? | Wired? |
|---|---|---|---|
| **Contacts — master** | `Contact` (gstin, pan, **taxId**, salutation, gstTreatment, billing+**shipping** addr, creditLimit, **openingBalance**, **defaultPriceListId**, salesHold, **tdsApplicable/section/rate**, **bankName/AccountNo/Ifsc/upiId**, **msmeRegistered/No**, portalEnabled, MR profile) `ContactController` CRUD | `contact_create_screen.dart`, `contact_detail_screen.dart` | **Partial** — form captures ~14 of 40+ fields |
| Contacts — persons | `ContactPerson` (salutation/first/last/designation/department/email/phone/mobile/primary); `POST /{id}/persons` | detail "Persons" tab (read-only list) | **Read-only** — no add/edit UI |
| Contacts — ledger/statement | `GET /{id}/ledger` (opening/closing/invoiced/paid/entries) | `contact_statement_screen.dart` | Wired (no export) |
| Contacts — GSTIN→state | `GET /reference/state-codes/by-gstin` | auto-resolve in create form | Wired (billing only) |
| Contacts — import | `POST /import`, `/import/preview`, `/import/template` | `contact_import_screen.dart` | Wired |
| **POS — counter** | `PosSearchService`, cart, batch pick, scheme, Rx, drug-interaction, offline | `pos_screen.dart` (+15 widgets) | Wired (rich) |
| POS — payment | `PaymentMode {CASH,UPI,CARD,MIXED}`; `CreateSalesReceiptRequest` | `pos_payment_sheet.dart` (cash/UPI-QR/card/split) | Wired — **no CREDIT/khata mode** |
| POS — receipt detail | `SalesReceiptController` get/list/print/whatsapp/history | `sales_receipt_detail_screen.dart` | **View-only — no refund/void** |
| POS — returns/refund | **none** (SalesReceipt has no status/reversal; no endpoint) | **none** | **Missing entirely** |
| POS — cash register/day-close | `CashRegisterService` 7 endpoints | `cash_register_screen.dart` | Wired |
| POS — receipt settings/print/SMS/WA/UPI | `OrgSettings` + `ReceiptShareService` | `pos_receipt_settings_screen.dart`, `printer_setup_screen.dart` | Wired |
| POS — hold/recall | client-side `pos_held_carts.dart` | `pos_held_carts_sheet.dart` | Wired (local only, max 5) |
| **Loyalty** | `CustomerWallet` (balance/earned/redeemed ONLY), `WalletService` earn/redeem/redeemable | `wallet_history_screen.dart`, `wallet_balance_chip.dart` | Wired (wallet only) |
| Loyalty — program/tiers/enrol | **none** (earn rate + caps hardcoded in service) | **none** | **Missing entirely** |
| **Pharma — drug master** | `DrugMasterController` search/{id}/salts | `drug_master_search_widget.dart` (autocomplete only) | Wired — **no browse/detail screen** |
| Pharma — manufacturer/HSN masters | `PharmacyMasterController` manufacturers, hsn search/{code}, `POST /hsn` | `manufacturer_search_widget.dart`, `hsn_gst_search_widget.dart`, `hsn_master_screen.dart` | Wired |
| Pharma — rack locations | rack-locations GET/POST/seed-demo | `rack_locations_screen.dart` | Wired |
| Pharma — substitutions/interactions | `/substitutions`, `/interactions/check[-by-composition]` (read-only) | POS interaction dialog only | **No master/CRUD screen** |
| Pharma — statutory registers | `StatutoryRegisterController` list/{id}/export/**dashboard** (GET only) | `statutory_registers_screen.dart` (3 tabs, CSV) | Wired — **read-only, no manual entry, dashboard tile unused** |
| Pharma — near-expiry/settlement | `expiry_repository`, drafts supplier debit note | `near_expiry_screen.dart` | Wired |
| Pharma — drug licenses | `DrugLicenseController`; entity (type/number/issuedBy/dates/notes) | `drug_licenses_screen.dart` | Wired (full) |
| Pharma — prescription records | `PrescriptionController` | `add_prescription_screen.dart`, `prescription_history_screen.dart` | Wired |

## Gaps

### Missing screens

- **[P1] No POS returns / refund / sale-reversal screen** — a completed POS sale cannot be returned, refunded, or voided anywhere. `SalesReceipt` has no `status`/`reversed` field; `SalesReceiptController` exposes only create/get/list/print/whatsapp/history. · _Backend:_ `pos/controller/SalesReceiptController.java`, `pos/entity/SalesReceipt.java` · _Flutter:_ none (`sales_receipt_detail_screen.dart` is view-only) · _Why (ERP):_ every retail/pharmacy counter must handle wrong-item/expired/customer-return same-day; without it stock and cash stay overstated and there's no audit trail. · _Fix:_ add `POST /sales-receipts/{id}/return` (reverse journal + restock + new RETURN receipt) and a "Return/Refund" action + line-selection sheet on the receipt detail screen.

- **[P1] No loyalty program configuration / tier / enrolment UI** — loyalty is a bare ₹-wallet; the earn rate (1pt per ₹100), min ₹10, max 50% are hardcoded in `WalletService` and shown as static text. No screen to set rules, define tiers (Silver/Gold), or enrol/opt-in a customer. · _Backend:_ `loyalty/service/WalletService.java`, `loyalty/entity/CustomerWallet.java` (no program/tier/rule entity) · _Flutter:_ none (`wallet_history_screen.dart` is per-contact history only) · _Why (ERP):_ pharmacies/kirana run configurable loyalty (e.g. 2% on ₹500+, tier multipliers, expiry); a fixed hardcoded rate isn't usable as a product. · _Fix:_ add a `loyalty_program` entity + settings screen (earn %, thresholds, redemption caps, point expiry, tiers) and an enrolment toggle on the contact form.

- **[P2] No drug-interaction / generic-substitution master screen** — both tables are seeded and queryable from POS, but there is no list/CRUD UI to view, add, or correct interaction pairs or substitution mappings. · _Backend:_ `PharmacyMasterController` `/substitutions`, `/interactions/check*` (GET only — no POST) · _Flutter:_ none (only the POS warning dialog consumes them) · _Why (ERP):_ a pharmacist must be able to add a clinic-specific interaction or brand substitution; today they can't see or extend the data. · _Fix:_ add a `PharmacyMastersScreen` with substitution + interaction tabs (list + add/edit) backed by new POST endpoints.

- **[P2] No standalone drug-master browse/detail screen** — the 22,928-row platform drug master is reachable only through an autocomplete widget embedded in the item form. A pharmacist cannot browse, search, or view full drug detail (salt/schedule/HSN/MRP/manufacturer/interactions) as a reference. · _Backend:_ `DrugMasterController` search/{id}/salts (detail endpoint exists) · _Flutter:_ `drug_master_search_widget.dart` only · _Why (ERP):_ Marg/Tally pharmacy modules ship a drug directory the counter uses for lookup independent of item creation. · _Fix:_ add a Drug Master screen (search list → detail) reusing `GET /drug-master/{id}`.

### Missing form / detail fields

- **[P1] Contact create/edit form is missing ~26 fields the backend accepts** — `CreateContactRequest` accepts shipping address (all 7 fields), `openingBalance`, `defaultPriceListId`, `tdsApplicable/tdsSection/tdsRate`, `bankName/bankAccountNo/bankIfsc/upiId`, `salutation`, `website`, `notes`, `msmeRegistered/msmeRegistrationNo`, `taxId`, but `contact_create_screen.dart` captures none of them. · _Backend:_ `contact/dto/CreateContactRequest.java`, `contact/entity/Contact.java` · _Flutter:_ `contacts/presentation/contact_create_screen.dart` · _Why (ERP):_ vendor payouts need bank/UPI + TDS; ship-to differs from bill-to for distributors; opening balance is essential during migration; price-list assignment drives SO pricing. · _Fix:_ add collapsible sections (Shipping Address, Opening Balance + Price List, Bank Details, TDS, MSME) to the form.

- **[P1] No way to add a contact person in the UI** — `ContactPerson` CRUD exists (`POST /{id}/persons`) and the detail "Persons" tab even says "Add a contact person", but there is no Add button, form, or edit/delete control; persons can only be created via raw API. · _Backend:_ `ContactController.addPerson/deletePerson`, `ContactPersonRequest` · _Flutter:_ `contact_detail_screen.dart` `_PersonsTab` (read-only) · _Why (ERP):_ B2B accounts need multiple named contacts (owner, accounts, purchase) with designation/department. · _Fix:_ add a FAB + person form sheet on the Persons tab wired to the existing endpoints.

- **[P2] Contact detail omits shipping address, bank, opening balance, TDS, MSME, sales-hold** — even where backend returns the data, `_DetailsTab` renders only contact/tax/billing-city/credit-limit/payment-terms. · _Backend:_ `ContactResponse` · _Flutter:_ `contact_detail_screen.dart` `_DetailsTab` · _Why (ERP):_ users can't verify a vendor's bank/UPI or a customer's opening balance/hold status. · _Fix:_ render the additional sections (mirror the form once fields are added).

- **[P2] `ContactResponse` itself drops `taxId`, `salutation`, `msmeRegistered`, `msmeRegistrationNo`, `portalEnabled`, `portalUrl`** — these are persisted on the entity but never serialized back, so even a future UI cannot display them without a DTO change. · _Backend:_ `contact/dto/ContactResponse.java` vs `Contact.java` · _Flutter:_ n/a · _Why (ERP):_ UAE/Oman use TRN (`taxId`) not GSTIN; MSME flag drives 45-day payment compliance. · _Fix:_ add the missing fields to `ContactResponse` + `ContactService.toResponse`.

- **[P2] Statutory register screen ignores the `/dashboard` endpoint** — backend serves `totalEntries / entriesThisMonth / retentionDueWithin90Days`, but `statutory_registers_screen.dart` only lists rows + exports CSV; no retention-due alert tile. · _Backend:_ `StatutoryRegisterController.dashboard` · _Flutter:_ `pharma/presentation/statutory_registers_screen.dart` · _Why (ERP):_ inspectors check retention; a "N entries due for disposal in 90 days" cue is the point of the dashboard. · _Fix:_ render a summary header consuming `/dashboard`.

### Missing business capabilities

- **[P1] POS has no credit / khata (sale-on-account) mode** — `PaymentMode` is CASH/UPI/CARD/MIXED only; every POS sale books cash and demands `amountReceived`. A customer cannot buy on credit (added to AR) from the counter. The POS customer-history sheet shows purchase history but not the customer's outstanding balance. · _Backend:_ `pos/entity/PaymentMode.java`, `SalesReceiptService` (Cash/Revenue journal only) · _Flutter:_ `pos_payment_sheet.dart`, `widgets/pos_customer_history_sheet.dart` · _Why (ERP):_ Indian kirana/pharmacy run heavily on khata; "add to account, settle later" is a core counter flow. · _Fix:_ add a CREDIT payment mode that books AR against the linked contact (requires a non-walk-in customer) + show running khata balance in the customer sheet.

- **[P2] Statutory registers are auto-populated only — no manual entry, and prescriber/patient address not captured at POS** — registers are written from POS sales, but POS captures only an Rx number, not prescriber name/reg-no/address or patient address that Rule 65(11)(h) / Form 20G require; there's no screen to add a register row or backfill these fields. · _Backend:_ `StatutoryRegisterService.recordSaleEntries` (no manual create endpoint) · _Flutter:_ `statutory_registers_screen.dart` (no add) · _Why (ERP):_ an inspector audit needs the full prescriber+patient detail; auto-rows have null prescriber in non-strict mode. · _Fix:_ capture prescriber/patient detail in the Rx dialog (or add a manual register-entry/edit form) + a POST endpoint.

- **[P3] Loyalty redemption not applied to the POS bill total** — redemption is "queued" then fired as a separate wallet txn after the sale (`_walletRedeemAmount`); the bill total the customer pays is unchanged, so points act as cashback not an at-counter discount. · _Backend:_ `WalletService.redeemPoints` (post-sale) · _Flutter:_ `pos_screen.dart` `_onWalletRedeem`/`_redeemLoyaltyPoints` · _Why (ERP):_ customers expect "use ₹50 points → pay ₹50 less now". · _Fix:_ deduct queued redemption from the payable total in the payment sheet and reflect it on the receipt.

### Wiring & UX issues

- **[P2] Contact statement screen has no export / PDF / email / share action** — the ledger renders on-screen only; AppBar has no actions. · _Backend:_ ledger endpoint returns JSON only (no PDF) · _Flutter:_ `contact_statement_screen.dart` · _Why (ERP):_ a customer statement is something you send (WhatsApp/email/print) for collections. · _Fix:_ add a share/print action (statement PDF) like invoices have.

- **[P3] GSTIN→state auto-resolve fills billing only, not shipping** — `_resolveBillingStateFromGstin` updates billing state/code; with shipping absent from the form entirely, ship-to state code (needed for place-of-supply on inter-state delivery) is never set. · _Flutter:_ `contact_create_screen.dart` · _Why (ERP):_ inter-state GST split keys off ship-to state. · _Fix:_ resolve/allow shipping state once shipping fields are added.

- **[P3] POS drug-interaction & Rx checks gated on `industryCode`/`businessType` containing "PHARMA"** — a misconfigured pharmacy org (industry not tagged PHARMA) silently disables interaction and Rx enforcement at the counter. · _Flutter:_ `pos_screen.dart` `_checkDrugInteractions`, `_addToCart` · _Why (ERP):_ safety checks shouldn't depend on a free-text industry string match. · _Fix:_ drive off an explicit capability flag (e.g. `canUsePharma`) rather than substring matching.

## Stats
P1=6, P2=9, P3=4, screens-missing=4, fields-missing=~30 (≈26 contact form + 6 ContactResponse, overlapping)


---

# Trade & Finance Ops — UI/Field Gap Audit

Scope: partner network, supply chain, integration connectors, currency, banking, transport, courier, fixed assets. Method: read entities/DTOs/controllers → fields; read Flutter screens + repositories → what is captured/shown + which endpoints are actually called. Many of these domains are marked "COMPLETE" in CLAUDE.md but the Flutter layer is a thin list-only shell — the recurring pattern is **rich backend service + repository with full methods, but the screens never call create/detail/sub-flow methods** (dead repo methods).

## Coverage map

| Sub-domain | Backend key fields / capability | Flutter screen(s)? | Wired? |
|---|---|---|---|
| **Partner: trading partners** | seller/buyer org, status, creditLimit, paymentTerms, deliveryTerms, priceListId, notes (`TradingPartner`) | `partner_list_screen.dart` (list + request dialog + approve/reject) | Partial — request dialog omits creditLimit/paymentTerms/deliveryTerms/priceListId; no detail screen; no suspend action |
| **Partner: published catalog** | item/drug, displayName, SKU, HSN, mfr, packSize, category, MRP, PTR, minOrderQty, availability (`CatalogItemRequest`) | `catalog_list_screen.dart` (list + unpublish) | **No — publish form missing** (`POST /catalog` unwired); list+unpublish only |
| **Partner: supplier search** | search across approved suppliers' catalog | `supplier_search_screen.dart` | Search only — **no "place order" action** |
| **Partner: network orders** | order lifecycle PLACED→CONFIRMED/PARTIAL→DISPATCHED→DELIVERED, lines (orderedQty/confirmedQty/dispatchedQty), events | `outgoing/incoming_orders_screen.dart`, `network_order_detail_screen.dart` | **Place-order is DEAD** (`placeOrder` repo method never called); confirm hardcodes confirmedQty=orderedQty (no partial confirm); SO/PO link unwired |
| **SCM: multi-supplier sourcing** | `ItemSupplier`: leadTime, minOrderQty, unitPrice, preferred, supplierSku; full CRUD endpoints | **none** | **No — zero UI** (`addItemSupplier`/`getItemSuppliers`/`setPreferred` are dead repo methods) |
| **SCM: demand forecast** | moving-avg/weighted/seasonal forecast rows by item | dashboard "Forecast" button only | Trigger only — **generated forecasts never displayed** (`getForecastsByItem`/`getForecasts` dead) |
| **SCM: ABC / reorder policy** | abcClass, safetyStock, reorderPoint, EOQ, maxStock, leadTime, serviceLevel, autoReorder (`ReorderPolicy`) | `turnover_screen.dart` (ABC list) | Partial — shows item UUID not name; maxStock/leadTime/serviceLevel/autoReorder hidden; per-item recalc unwired |
| **SCM: purchase requisition** | header (supplier/warehouse/requiredBy/notes) + lines (item/qty/price); DRAFT→SUBMITTED→APPROVED/REJECTED; PO link | `requisition_list_screen.dart` | **No manual create** (FAB only auto-PR); **no detail** (lines never shown); approve blind; no convert-to-PO |
| **SCM: return orders** | type, contact, warehouse, reason, restockFee, netRefund, origRef, lines (`ReturnOrder`) | `return_order_list_screen.dart` | **No create** (`POST /returns` unwired); **no detail**; approve/process/cancel only |
| **SCM: alerts** | type, severity, title, description, item, recommendedAction | `alert_list_screen.dart` (scan + resolve) | Mostly — no detail, no convert-alert→PR |
| **SCM: supplier scorecard** | totalOrders, onTime/late, qtyOrdered/received/rejected, avgLeadTime, onTimeRate, qualityRate, overallScore (`SupplierPerformance`) | `supplier_rankings_screen.dart` (rankings) | **Broken** — card title hardcoded `'Supplier'` (no name); onTimeRate/leadTime/rejected hidden; per-supplier scorecard + calculate unwired |
| **SCM: shipments** | type, origin/dest WH, carrier, vehicle, ETD/ETA, freight, lines; DRAFT→IN_TRANSIT→DELIVERED | `shipment_list_screen.dart` | **No create** (`POST /shipments` unwired); no detail (lines/carrier/dates hidden); dispatch/deliver/cancel only |
| **Integration connectors** | type (Tally/Zoho/Busy/SAP/Custom), name, baseUrl, apiKey, settings(jsonb), isActive, lastSyncAt; CRUD + test + sync + history | `integration_list_screen.dart` | **Broken & no create** — reads non-existent fields; toggle/sync call non-existent endpoints; errors swallowed; no add form; no sync-log view |
| **Currency: catalogue** | code, name, symbol, decimalPlaces, isActive (`Currency`) | `currency_screen.dart` (Currencies tab) | List only — reads non-existent `isBase`; decimalPlaces hidden; no add/edit |
| **Currency: rates** | from/to/rate/effectiveDate upsert; convert | `currency_screen.dart` (Rates tab + set dialog) | Rates OK; **convert endpoint unwired** (`convertAmount` dead) |
| **Banking: import** | CSV paste + file (csv/xlsx) + AI fallback | `bank_reconciliation_screen.dart` | Yes — paste + file both wired |
| **Banking: reconcile** | credit→invoice / debit→bill match suggestions, accept, summary | `bank_reconciliation_screen.dart` | Partial — auto-match accept only; no manual match; no bank-account picker; no categorize-as-expense |
| **Banking: bank accounts** | (no BankAccount entity — hardcoded to GL 1020) | none | **No — single hardcoded BANK account** |
| **Transport: lorry receipt** | ~20 fields (consignor/ee, route, goods, freight, GST, eway, driver, DC/invoice link); ISSUE/DELIVER/CANCEL/bill-freight | `lorry_receipt_list_screen.dart` (list + create) | Partial — create captures ~10/20; **no detail screen**; cancel action absent in UI |
| **Transport: freight rate card** | transporter/route/mode/weight-slab/rateType/rate/minCharge/validity/active | `freight_rate_card_screen.dart` (list + create + delete) | Partial — **no edit**; validity dates + active toggle missing |
| **Transport: vehicle log** | type, date, odometer, qty, amount, vendor, refNo, notes + TCO summary | `vehicle_log_screen.dart` (list + create + summary) | Partial — vendor/refNo/notes not captured; no spend-by-type breakdown shown |
| **Courier: shipment** | AWB, partner, addresses, weight, COD, declaredValue, freight, events; book/cancel/event | `courier_shipment_list_screen.dart` (list + sync) | **No — read-only list** (no create, no detail, no tracking timeline, no AWB search) |
| **Courier: COD remittance** | courier/bank/UTR + lines (matchStatus MATCHED/MISMATCH/ORPHAN, paymentId) | `cod_remittance_list_screen.dart` (list + create + reconcile) | Partial — **no detail / reconciliation audit** (per-line match buckets invisible) |
| **Courier: settings/tracking** | provider config (baseUrl/paths/token), track-by-AWB, sync | `courier_settings_screen.dart` | Settings OK; tracking timeline + track-by-AWB missing |
| **Fixed assets** | code, name, category, cost, residual, method(SLM/WDV), life/rate, accumDep, IT block/rate, GL accounts, disposal | `fixed_assets_screen.dart` (list + create + detail sheet + run dep + dispose + IT schedule) | **Best in scope** — full flows; minor field-visibility gaps only |

## Gaps

### Missing screens

- **[P1] Partner network — no order placement UI (buy-side loop is dead)** — `SupplierSearchScreen` is search-only with no "add to cart / place order" button; no order-create form exists anywhere; the `placeOrder` repo method is never called. The outgoing-orders empty state even instructs "Place a B2B order from the supplier search" — a dead-end. · _Backend:_ `POST /api/v1/partner-network/orders` (`PartnerNetworkController.java:97`) · _Flutter:_ `supplier_search_screen.dart` (no order action), `partner_network_repository.dart:135` (`placeOrder` dead) · _Why (ERP):_ the entire B2B buyer journey (the point of the module) cannot be completed from the UI. · _Fix:_ add a quantity/price sheet on supplier-search cards that builds a `PlaceNetworkOrderRequest` and an order-cart screen.

- **[P1] Partner network — no catalog publish form** — `CatalogListScreen` only lists + unpublishes; the seller cannot publish an item (set MRP/PTR/availability/packSize/minOrderQty) from the UI. · _Backend:_ `POST /api/v1/partner-network/catalog` (`PartnerNetworkController.java:71`) · _Flutter:_ `catalog_list_screen.dart` (no FAB/form) · _Why (ERP):_ a seller with nothing published has no in-app way to populate the catalog buyers search. · _Fix:_ add a publish FAB → item picker + MRP/PTR/availability form.

- **[P1] SCM — multi-supplier sourcing has zero UI** — the entire `ItemSupplier` capability (map item→suppliers with lead time, MOQ, unit price, preferred flag, supplier SKU) has no screen; CRUD endpoints + repo methods exist but are never wired. This is the foundation MRP/auto-PR/EOQ rely on. · _Backend:_ `POST/GET/DELETE /api/v1/supply-chain/item-suppliers...` (`SupplyChainController.java:31-63`) · _Flutter:_ none (`supply_chain_repository.dart:15-36` dead) · _Why (ERP):_ "multi-supplier sourcing" is the marquee SCM feature yet the user can never enter supplier-item data. · _Fix:_ add an item-supplier management screen (per-item supplier list, add/edit/set-preferred).

- **[P1] SCM — no manual purchase-requisition create + no detail** — `RequisitionListScreen` FAB only triggers low-stock auto-PR; the `POST /requisitions` path with supplier/warehouse/requiredBy + manual lines is unwired, and there is no detail screen so lines/requestedBy/approvedBy are invisible (approve/reject is blind). · _Backend:_ `POST /api/v1/supply-chain/requisitions`, `GET /requisitions/{id}` (`SupplyChainController.java:127,161`) · _Flutter:_ `requisition_list_screen.dart`, `supply_chain_repository.dart:78` (`createRequisition` dead) · _Why (ERP):_ requisitions can't be raised manually and approvers can't see what they're approving. · _Fix:_ add PR create form (supplier/warehouse/date + line editor) and a detail screen with line table + convert-to-PO.

- **[P1] SCM — no return-order create + no detail** — `ReturnOrderListScreen` can only approve/process/cancel; `POST /returns` (type/contact/warehouse/reason/lines, restockFee/netRefund) is unwired and no detail screen shows lines or refund math. So returns can be actioned but never created in-app. · _Backend:_ `POST /api/v1/supply-chain/returns`, `GET /returns/{id}` (`SupplyChainController.java:185,218`) · _Flutter:_ `return_order_list_screen.dart`, `supply_chain_repository.dart:114` (`createReturnOrder` dead) · _Why (ERP):_ purchase/sales returns have lifecycle buttons but no origination path. · _Fix:_ add return-order create form + detail (lines, reason, restock fee, net refund).

- **[P1] SCM — no shipment create + no detail** — `ShipmentListScreen` has dispatch/deliver/cancel but no create FAB; `POST /shipments` (type/origin-dest WH/carrier/vehicle/ETD/ETA/freight/lines) is unwired and no detail shows carrier/dates/lines. · _Backend:_ `POST /api/v1/supply-chain/shipments`, `GET /shipments/{id}` (`SupplyChainController.java:295,326`) · _Flutter:_ `shipment_list_screen.dart` · _Why (ERP):_ inbound/outbound shipments can't be created from the UI. · _Fix:_ add shipment create form + detail with line + tracking fields.

- **[P1] Integration connectors — no add/create form** — `IntegrationListScreen` has no FAB/add button; `POST /integrations` (type/name/baseUrl/apiKey/settings) is unwired. A user cannot connect Tally/Zoho/Busy/SAP at all; the empty state offers no action. · _Backend:_ `POST /api/v1/integrations` (`IntegrationController.java:25`) · _Flutter:_ `integration_list_screen.dart` (no add path) · _Why (ERP):_ the connector module is unreachable — nothing can be configured. · _Fix:_ add a "New connector" FAB → type dropdown + name/baseUrl/apiKey + settings form.

- **[P1] Courier — no shipment create / book + no detail / tracking timeline** — `CourierShipmentListScreen` is a read-only list (no FAB, tile not tappable); booking (`POST /shipments` + `/book`), the detail view, and the tracking-event timeline (`courierShipmentEvents`) are all absent. Empty state says "Create one from a delivery challan or invoice" but no such path exists. · _Backend:_ `POST /api/v1/courier/shipments`, `/{id}/book`, `GET /shipments/{id}` (returns events), `/{id}/events` (`CourierShipmentController`) · _Flutter:_ `courier_shipment_list_screen.dart` · _Why (ERP):_ parcels can't be booked or tracked in-app; customer-service has no journey view. · _Fix:_ add shipment create (DC/invoice + partner + addresses + COD) and a detail screen rendering the event timeline.

- **[P1] Transport — no lorry-receipt detail screen** — only list + create; once issued, the full LR (consignee, route, goods, freight basis, GST, eway, driver, DC/invoice link, freight-bill status) can't be reviewed. Cancel action also has no UI. · _Backend:_ `GET /api/v1/transport/lorry-receipts/{id}`, `/{id}/cancel` (`LorryReceiptController`) · _Flutter:_ none (detail) · _Why (ERP):_ operators can't open a consignment to verify or cancel it. · _Fix:_ add an LR detail screen with all fields + lifecycle buttons (issue/deliver/cancel/bill-freight).

- **[P2] Courier — no COD-remittance detail / reconciliation audit** — list + create + reconcile exist, but per-line `matchStatus` (MATCHED/AMOUNT_MISMATCH/ORPHAN) and `paymentId` are never shown; reconcile only returns counts in a snackbar. For a 500-line remittance, mismatches are invisible. · _Backend:_ `GET /api/v1/courier/cod-remittances/{id}` (lines carry matchStatus) (`CodRemittanceController.java:41`) · _Flutter:_ `cod_remittance_list_screen.dart` · _Why (ERP):_ COD reconciliation can't be audited; month-close is blind. · _Fix:_ add a remittance detail screen with a per-line match table + variance.

- **[P2] SCM — no demand-forecast viewer** — `generateForecast`/weighted/seasonal can be triggered (fire-and-forget snackbar) but the produced forecast rows are never displayed; `getForecastsByItem`/`getForecasts` are dead repo methods. · _Backend:_ `GET /api/v1/supply-chain/forecasts`, `/forecasts/by-item/{id}` (`SupplyChainController.java:87,92`) · _Flutter:_ `supply_chain_repository.dart:47-55` (dead) · _Why (ERP):_ forecasting output is invisible, so it can't inform purchasing. · _Fix:_ add a forecast tab/screen (per-item projected demand + confidence).

- **[P2] SCM — no per-supplier scorecard detail / calculate action** — only the rankings list exists; `getSupplierScorecard` (historical scorecards) and `calculateSupplierPerformance(from,to)` are dead repo methods, so a supplier's detailed period-by-period performance and on-demand recalc are unreachable. · _Backend:_ `GET /supplier-performance/{id}`, `POST /supplier-performance/{id}/calculate` (`SupplyChainController.java:261,271`) · _Flutter:_ `supply_chain_repository.dart:164,174` (dead) · _Why (ERP):_ procurement can't drill into supplier reliability or refresh scores. · _Fix:_ add a supplier scorecard detail (period table + calculate-for-range button).

- **[P3] Currency — no converter UI** — the rate set/list works, but `convertAmount` (`/currencies/convert`) is a dead repo method — no on-screen converter despite CLAUDE.md claiming "conversion." · _Backend:_ `GET /api/v1/currencies/convert` (`CurrencyController.java:52`) · _Flutter:_ `currency_repository.dart:68` (dead) · _Why (ERP):_ users can't ad-hoc convert amounts. · _Fix:_ add a small converter card (amount + from/to → result).

- **[P3] Banking — no book-vs-bank reconciliation statement / opening balance** — only counts summary; no view proving every txn is in the ledger, and no opening-balance/cutoff for first-time reconcile. · _Backend:_ none (would need a reconciliation-proof endpoint) · _Flutter:_ none · _Why (ERP):_ auditors/CFO can't verify the bank account ties out. · _Fix:_ add a reconciliation-proof view (bank balance vs GL balance vs unmatched).

### Missing form/detail fields

- **[P2] Partner — trading-partner request omits commercial terms** — the request dialog captures only targetOrgId/role/notes; `TradingPartnerRequest` also carries creditLimit, paymentTerms, deliveryTerms (and the entity has priceListId), none captured, and there is no partner detail screen to view/edit them later. · _Backend:_ `TradingPartnerRequest.java`, `TradingPartner.java` · _Flutter:_ `partner_list_screen.dart:59` · _Why (ERP):_ B2B credit/payment terms are core to the relationship but unsettable. · _Fix:_ add term fields to the request dialog + a partner detail screen.

- **[P2] Partner — order confirm has no partial-confirm UI** — `network_order_detail_screen.dart:194` hardcodes `confirmedQty = orderedQty` for every line; the backend supports PARTIALLY_CONFIRMED with per-line confirmed quantities, but the seller can't short-confirm. · _Backend:_ `POST /orders/{id}/confirm` with `ConfirmNetworkOrderRequest` lines · _Flutter:_ `network_order_detail_screen.dart` · _Why (ERP):_ seller can't accept "8 of 10" — must reject or over-commit. · _Fix:_ add an editable per-line confirmed-qty step in the confirm action.

- **[P2] Partner — SO/PO linkage unwired** — `link-po`/`link-so` endpoints (the bridge from network order into the buyer's PO / seller's SO for downstream DC→Invoice) have no UI. · _Backend:_ `POST /orders/{id}/link-po`, `/link-so` (`PartnerNetworkController.java:163,170`) · _Flutter:_ none · _Why (ERP):_ network orders stay islanded — never flow into normal procurement/sales. · _Fix:_ add link-to-PO/SO actions on the order detail.

- **[P2] SCM — supplier rankings & ABC list show UUIDs not names** — `supplier_rankings_screen.dart:57` renders the literal string `'Supplier'` as every card title; `turnover_screen.dart:133` shows `Item: <uuid-prefix>...`. Names are never resolved. · _Backend:_ responses return `supplierId`/`itemId` only (no name join) · _Flutter:_ `supplier_rankings_screen.dart`, `turnover_screen.dart` · _Why (ERP):_ the user literally cannot tell which supplier/item a row refers to. · _Fix:_ resolve supplier/item names (join in DTO or client-side lookup).

- **[P2] SCM — reorder-policy fields hidden + no per-item recalc** — ABC cards show only safety/ROP/EOQ; maxStock, leadTimeDays, serviceLevelPct, autoReorder are not displayed, and `calculateReorderParams(itemId)` (per-item safety-stock/EOQ recompute) is a dead repo method. · _Backend:_ `POST /reorder-params/{itemId}` (`SupplyChainController.java:118`), `ReorderPolicy.java` · _Flutter:_ `turnover_screen.dart`, `supply_chain_repository.dart:69` (dead) · _Why (ERP):_ planners can't see full policy or recompute when lead time changes. · _Fix:_ surface all policy fields + a per-item recalc action.

- **[P2] Transport — LR create captures ~10 of ~20 fields** — missing consignee (`contactId`), DC link (`deliveryChallanId`), invoice link, e-way bill no, packages (`numPackages`), declared value, driver name/phone, notes. · _Backend:_ `TransportDtos.java`, `LorryReceipt.java` · _Flutter:_ `lorry_receipt_list_screen.dart` (`_CreateLorryReceiptScreen`) · _Why (ERP):_ a goods consignment note legally needs consignee + packages + eway + driver. · _Fix:_ expand the LR create form to the full consignment.

- **[P2] Transport — freight rate card has no edit; validity/active not captured** — only create + delete; `effectiveFrom`/`effectiveTo` (rate validity) and the `active` toggle are never set/shown, so updating a transporter's rate means delete+recreate and stale rates pile up. · _Backend:_ `FreightRateCard.java`, `FreightRateCardController` (no PATCH endpoint) · _Flutter:_ `freight_rate_card_screen.dart` · _Why (ERP):_ rate management without dates/edit is unworkable for a transporter desk. · _Fix:_ add an update endpoint + edit sheet with validity dates + active toggle.

- **[P2] Transport — vehicle log omits vendor/reference/notes** — create captures only type/date/amount/odometer/qty; `vendorContactId` (fuel station/garage), `referenceNo` (bill no), `notes` not captured; summary doesn't show the `spendByType` breakdown the DTO carries. · _Backend:_ `VehicleLog.java`, `FleetDtos.VehicleTcoSummary` · _Flutter:_ `vehicle_log_screen.dart` · _Why (ERP):_ vehicle-expense audit trail is thin and TCO can't be split by category. · _Fix:_ add vendor/ref/notes fields + a spend-by-type chart in the summary.

- **[P2] Banking — match cards lack invoice/bill date** — match review shows confidence/amount/counterparty/doc-number but not the matched invoice/bill date, so date mismatches (premature/stale payments) can't be spotted. · _Backend:_ `PaymentMatchResponse` could carry invoiceDate/billDate · _Flutter:_ `bank_reconciliation_screen.dart` (match card) · _Why (ERP):_ raises false-accept rate on auto-suggestions. · _Fix:_ add the document date to the response + card.

- **[P2] Fixed assets — GL accounts not captured/shown; SLM life & WDV rate not shown in detail** — create form silently applies default GL codes (asset 1600 / accum-dep 1690 / dep-exp 5270) with no override and no display; `bookUsefulLifeMonths`/`bookRatePct` are entered but not echoed in the detail sheet; disposal date/proceeds and the depreciation `journalEntryId` link are not shown. · _Backend:_ `FixedAsset.java`, `FixedAssetDepreciation.java` · _Flutter:_ `fixed_assets_screen.dart` (`_AssetForm`, `_AssetDetailSheet`) · _Why (ERP):_ accountants can't verify/override which accounts post or trace dep entries to the GL. · _Fix:_ add GL-account fields (with defaults visible) to create + show method params, disposal details, and the journal link in detail.

### Missing business capabilities

- **[P1] Banking — single hardcoded bank account (no multi-account)** — there is no `BankAccount` entity; `BankReconciliationService.acceptMatch()` always posts to the org's single `DefaultAccountPurpose.BANK` (GL 1020), and the reconciliation screen offers no account picker. An org with HDFC + ICICI + a forex account cannot reconcile each separately. · _Backend:_ `BankReconciliationService.java` (hardcoded BANK) · _Flutter:_ `bank_reconciliation_screen.dart` (no picker) · _Why (ERP):_ multi-bank is the norm for any scaling SMB; every statement collapses onto one GL account. · _Fix:_ introduce a bank-account master (GL-linked) + an account selector on import/reconcile.

- **[P2] Banking — no manual match and no categorize-as-expense** — users can only accept/reject the auto-suggestion; there is no way to manually match a txn to an arbitrary invoice/bill, nor to book an unmatched txn straight to an expense/GL account. Low-confidence txns (<0.45) silently get no suggestion and strand. · _Backend:_ no manual-match or categorize endpoint · _Flutter:_ `bank_reconciliation_screen.dart` · _Why (ERP):_ a large share of real bank lines (fees, one-offs, missed matches) can't be cleared in the reconcile screen. · _Fix:_ add manual-match (pick invoice/bill) + categorize-to-account actions.

- **[P1] Integration — list/toggle/sync are wired to non-existent endpoints (whole screen non-functional)** — `integration_list_screen.dart` reads fields the DTO never returns (`status`, `lastSyncStatus`, `enabled`, `type` vs actual `integrationType`/`isActive`/`lastSyncAt`); `toggleIntegration` calls `/enable`//`/disable` and `syncIntegration` calls `/sync` with no params, but the backend only has `PUT /{id}` (isActive) and `/sync?syncType=&direction=` (required params). `listIntegrations` swallows all errors → shows "No integrations" on any failure. · _Backend:_ `IntegrationController.java:48,75` · _Flutter:_ `integration_repository.dart:42,57` · _Why (ERP):_ even if a connector existed, the toggle/sync buttons 404 and the card renders blank state. · _Fix:_ align repo to real endpoints (PUT isActive; sync with syncType/direction) and DTO field names; surface errors.

- **[P2] Integration — no sync-history / log viewer** — `GET /{id}/history` (sync logs: records synced, status, errors) has no UI, so a user can't see whether a sync worked. · _Backend:_ `GET /api/v1/integrations/{id}/history` (`IntegrationController.java:83`) · _Flutter:_ none · _Why (ERP):_ sync is fire-and-forget with no audit. · _Fix:_ add a sync-history list per connector.

- **[P3] Currency — no add-currency / set-base; isBase mis-read** — the catalogue tab is read-only and reads `c['isBase']`, a field `Currency` does not have (it has no base flag at all), so no currency is ever flagged base; `decimalPlaces` is hidden. · _Backend:_ `Currency.java` (no isBase) · _Flutter:_ `currency_screen.dart:83` · _Why (ERP):_ base-currency and per-currency precision aren't manageable/visible. · _Fix:_ decide base-currency model (org setting) and show it; display decimalPlaces; add activate/deactivate.

### Wiring & UX issues

- **[P2] Pervasive list-only pattern across SCM/courier/partner — repositories carry create/detail/sub-flow methods that no screen calls** — confirmed dead methods: `placeOrder`, `publishCatalogItem` (no caller), `createRequisition`, `createReturnOrder`, `addItemSupplier`/`getItemSuppliers`/`setPreferredSupplier`, `getForecastsByItem`/`getForecasts`, `getSupplierScorecard`/`calculateSupplierPerformance`, `calculateReorderParams`, `convertAmount`. · _Backend:_ all endpoints exist · _Flutter:_ `supply_chain_repository.dart`, `partner_network_repository.dart`, `currency_repository.dart` · _Why (ERP):_ gives a false impression of completeness — the modules read as "done" but key user actions are unreachable. · _Fix:_ wire the dead methods to create/detail screens (covered by the P1/P2 items above).

- **[P2] Error-swallowing in integration & currency repos masks broken APIs** — `listIntegrations`, `listCurrencies`, `getExchangeRates` all `catch (_) { return []; }`, so a 4xx/5xx silently renders an empty "nothing configured" state instead of an error. · _Flutter:_ `integration_repository.dart:23`, `currency_repository.dart:23,48` · _Why (ERP):_ users (and QA) can't tell "empty" from "broken." · _Fix:_ let errors propagate to the `.when(error:)` branch.

- **[P3] SCM forecast/ABC/scan actions are fire-and-forget snackbars** — `generateForecast`, `runAbcClassification`, `runAlertScan`, `autoCreateRequisition` show a success toast but don't navigate to or refresh the result the user would want to inspect (forecast has no view at all; auto-PR doesn't open the created PR). · _Flutter:_ `supply_chain_dashboard_screen.dart`, `turnover_screen.dart` · _Why (ERP):_ the user triggers a job and sees nothing actionable. · _Fix:_ route to the produced artifact (forecast list / new PR / alert list) after the action.

- **[P3] Courier shipment tile looks tappable but isn't** — `_shipmentTile` renders a trailing `chevron_right` with no `onTap`, implying a detail screen that doesn't exist. · _Flutter:_ `courier_shipment_list_screen.dart:232` · _Why (ERP):_ misleading affordance. · _Fix:_ wire to the (to-be-built) detail screen or drop the chevron.

## Stats
P1=12, P2=17, P3=8, screens-missing=15 (partner order-place, partner catalog-publish, SCM item-supplier, SCM PR-create, SCM PR-detail, SCM return-create, SCM return-detail, SCM shipment-create, SCM shipment-detail, SCM forecast-viewer, SCM supplier-scorecard-detail, integration-create, courier-shipment-create, courier-shipment-detail/tracking, courier-COD-detail; plus transport LR-detail), fields-missing≈30 (partner terms/partial-confirm/SO-PO-link; SCM supplier+item names, reorder-policy fields; LR ~10 fields, rate-card validity/edit, vehicle vendor/ref/notes; banking match-date/bank-account/manual-match; fixed-asset GL accounts + method params + disposal/journal link; currency decimalPlaces/base; integration field-name mismatch)


---

# Platform & Shared — UI/Field Gap Audit

Scope: Auth/users, Organisation/settings, Workflow/approvals, Dashboard, Reporting hub, AI, Notifications, Portal, Platform-admin. Verified against actual backend controllers/DTOs/entities and Flutter screens (not CLAUDE.md "DONE" claims). Two areas (AI/Notifications, Portal/Platform-admin) were deep-dived by sub-agents and folded in below.

## Coverage map

| Sub-domain | Backend key fields/endpoints | Flutter screen(s)? | Wired? |
|---|---|---|---|
| Login (password / OTP) | `POST /auth/login`, `/auth/otp/{request,verify}` | `login_screen.dart`, `otp_screen.dart` | yes |
| Signup / register | `POST /auth/signup`, `/register` | `signup_screen.dart` | yes |
| Forgot/reset password | `POST /auth/password/{forgot,reset}` + email-token variant | `forgot_password_screen.dart`, `reset_password_screen.dart` | yes |
| **Change password (logged-in)** | **none (no `/auth/change-password` mapping)** | `auth_repository.changePassword` (orphan, no caller) | **NO (phantom)** |
| 2FA / MFA / TOTP | none | none | n/a (absent) |
| Org user CRUD (list/invite/role/activate) | `/api/v1/org/users` (full) | `team_screen.dart` | yes |
| API keys | `/api/v1/api-keys` (create/list/revoke) | `api_keys_screen.dart` | yes |
| Org profile (name/gstin/phone/email/address) | `PUT /organisations/{id}` (`UpdateOrgRequest`) | `org_details_screen.dart` | yes |
| Org logo / fiscal year / currency / timezone / bank | entity has `logoUrl`, `fiscalYearStart`, `baseCurrency`, `timezone`; **not in `UpdateOrgRequest`**; no bank fields exist | none | **NO** |
| Branches | `POST /branches`, `GET` only — **no PUT/DELETE** | `branches_screen.dart` (create-only) | partial |
| Warehouses | `POST/GET /warehouses` only — no update/delete | none (only pickers + zone screen) | **NO screen** |
| Business policies (credit/overdue/batch/dispatch/scheme) | `org_settings` via `/settings` | `business_policy_settings_screen.dart` | yes |
| Inventory feature flags | `FeatureFlagController` toggle | `inventory_features_screen.dart` | yes |
| Sidebar/nav customisation | `PUT /settings/nav.disabled` | `nav_customisation_screen.dart` | yes |
| POS settings (UPI/SMS/WhatsApp/receipt/negative-stock) | dedicated `/settings/{upi,sms,whatsapp}` + keys | `pos_receipt_settings_screen.dart` | yes |
| GSP / TCS / composition / 3-way-match settings | `/gst/gsp-settings`, `/tcs/settings`, `/ap/three-way-match/settings` | gsp_settings, gst_compliance_tabs, three_way_match_inbox | yes |
| **~12 documented `org_settings` keys** (valuation_method, etc.) | backend reads them | **no write UI** | **NO** |
| Workflow config (activate/steps/trigger) | `/api/v1/workflows` (list/update/replace-steps) | `workflow_settings_screen.dart` | yes (role-only steps) |
| Approval inbox | `/api/v1/workflow/approval-requests` (+ history) | `approval_inbox_screen.dart` | partial (PENDING only) |
| Dashboard (KPIs/widgets, role+industry) | `/api/v1/dashboard/*` | `dashboard_screen.dart` + 24 widgets, `dashboard_config.dart` | yes |
| Reports hub | static link grid | `reports_hub_screen.dart` | yes (no global export) |
| AI inbox (accept/reject) | `/ai/suggestions/{id}/review` | `ai_chat_screen.dart` | yes |
| AI inbox modify | review action MODIFY + `reviewedValue` | read-only sheet | **NO** |
| AI transaction categorization | `/ai/categorize`, `/ai/categorize/backfill` | none (constants only) | **NO** |
| AI usage/telemetry, training export | `AiTelemetryService`, `/ai/training/{summary,export}` | none | **NO** |
| AI model settings | `OrgAiSettings` (provider/model/baseUrl) + `/status` | `ai_model_settings_screen.dart` | yes (entity shallow; `/status` unused) |
| Notifications list/read | `/api/v1/notifications` (list/unread/read/read-all) | `notification_list_screen.dart`, `notification_bell.dart` | yes (page 0 only, no filter) |
| Notification preferences | none (no table/endpoint) | none | **NO** |
| Push token register | `/notifications/push/register` | `push_notification_service.dart` (all-TODO stub) | **NO (dead e2e)** |
| WhatsApp message log / inbound-order inbox | `/whatsapp/messages`, `/whatsapp/orders/{parse,confirm}` | none | **NO** |
| Org audit-log viewer | `AuditLog` entity/service — **no controller at all** | none | **NO (impossible)** |
| Portal admin (invite/suspend/etc.) | `/api/v1/portal-users` (full) | `portal_users_screen.dart` | yes |
| Portal customer (view invoices/statement) | `PortalSelfController` (read-only) | `portal_home_screen.dart` | yes |
| Portal customer change-password | `POST /portal/change-password` | none | **NO** |
| Platform-admin org lifecycle | `/orgs/*` approve/reject/suspend/plan | `platform_admin_orgs_screen.dart` | yes |
| Platform-admin global users list | **none (`GET /users` missing)** | `platform_admin_users_screen.dart` | **BROKEN 404** |
| Platform-admin user deactivate/reactivate | **none (missing)** | users detail sheet | **BROKEN 404** |
| Tenant backup/export | `GET /admin/backups/org/export` | none | **NO** |

## Gaps

### Missing screens

- **[P1] No "change password" screen for a logged-in user (and the endpoint it calls does not exist).** Flutter ships `auth_repository.changePassword` + `ApiConfig.changePassword = '/api/v1/auth/change-password'` but the backend `AuthController` has only `/password/forgot` and `/password/reset` — no `change-password` mapping exists, and no screen calls the orphan method. The Settings profile card's edit pencil is `onPressed: () {}` (no-op). · _Backend:_ `auth/controller/AuthController.java` (mapping absent) · _Flutter:_ `features/auth/data/auth_repository.dart:186`, `core/api/api_config.dart:27` · _Why (ERP):_ a logged-in user cannot rotate their password without logging out and running the forgot-password OTP flow. · _Fix:_ add `POST /auth/change-password` (old+new, verify current) in AuthController/AuthService and a Change-Password screen off Settings.

- **[P1] Platform-admin "Users" tab is dead (404) — no global users-list endpoint.** `platform_admin_users_screen.dart` calls `GET /api/platform-admin/v1/users`, which has no mapping (`PlatformAdminController` only has `GET /orgs/{orgId}/users` + `POST /users/{id}/reset-password`). The whole tab returns 404 → "No users found". · _Backend:_ missing `GET /api/platform-admin/v1/users` · _Flutter:_ `features/platform_admin/presentation/platform_admin_users_screen.dart` · _Why (ERP):_ a core platform-ops surface is non-functional. · _Fix:_ add `listAllUsers(search, pageable)` + endpoint, or repoint the screen at per-org users.

- **[P1] Push notifications dead end-to-end on the ERP client.** `PushNotificationController` + real FCM dispatch exist, but Flutter `core/services/push_notification_service.dart` is an all-TODO stub: `initialize()`/`requestPermission()`/register are never called and `main.dart` never bootstraps FCM, so no device token is ever stored. Every server push (daily-report reminder, low-stock, collections) silently goes nowhere. · _Backend:_ `notification/push/PushNotificationController.java` · _Flutter:_ `core/services/push_notification_service.dart` (stub) · _Why (ERP):_ a documented "DONE" feature reaches zero phones. · _Fix:_ add `firebase_messaging`, init in `main()`, `POST /notifications/push/register` the token on login/refresh.

- **[P2] No warehouse-management screen (multi-warehouse can't be set up in the UI).** `WarehouseController` exposes create/list/get, but no Flutter screen creates or lists warehouses — every "warehouse" widget is a *picker* inside another screen, and `warehouse_zone_screen.dart` manages *zones*, not warehouses. The `MULTI_WAREHOUSE` feature flag is toggleable but there is nowhere to add a second warehouse. · _Backend:_ `inventory/controller/WarehouseController.java` · _Flutter:_ none · _Why (ERP):_ enabling multi-warehouse leaves the user with one DB-seeded warehouse and no UI to add more, breaking transfer orders / branch stock. · _Fix:_ add a Warehouse list/create/edit screen under Settings → Inventory.

- **[P2] No org audit-log viewer (and no endpoint to build one).** `audit/{AuditLog,AuditService,AuditLogRepository}` exist but there is **no controller** anywhere over them, so an org admin has no way to see who did what. · _Backend:_ `audit/` (no `@RestController`) · _Flutter:_ none · _Why (ERP):_ Indian SMB ERP buyers expect a tamper-evidence/who-changed-this trail for vouchers and masters. · _Fix:_ add `GET /api/v1/audit-log` (org-scoped, filterable) + an audit screen.

- **[P2] No central Notifications-settings / preferences screen.** Settings shows a "Notifications — Push, email & SMS alerts" tile that fires a "coming soon" snackbar; backend has no `notification_preference` table/endpoint either. Every alert fires on every channel unconditionally. · _Backend:_ `common/controller/NotificationController.java` (no prefs) · _Flutter:_ `settings_screen.dart:272` (coming-soon) · _Why (ERP):_ users can't mute low-stock SMS or payment-reminder push — standard at scale. · _Fix:_ add user×event×channel preference table + `GET/PUT /notifications/preferences` + a settings screen; gate send paths on it.

- **[P2] No WhatsApp inbound-order inbox UI.** `WhatsAppOrderController` (`/whatsapp/orders/{parse,confirm}` → drafts a Sales Order from a WhatsApp message) is fully built but has no Flutter constants or screen. The marquee "customer WhatsApps an order → draft SO" flow is unreachable. · _Backend:_ `notification/whatsapp/WhatsAppOrderController.java` · _Flutter:_ none · _Why (ERP):_ a headline distributor capability is invisible. · _Fix:_ add a "WhatsApp orders" screen (parse → preview lines → confirm to draft SO).

- **[P2] No tenant backup/export UI for owners.** `OrgBackupController` `GET /api/v1/admin/backups/org/export` returns a checksummed ZIP of the whole tenant, but nothing in Flutter calls it. · _Backend:_ `admin/backup/OrgBackupController.java` · _Flutter:_ none · _Why (ERP):_ owners can't self-serve a data export (exit/DR/GDPR expectation). · _Fix:_ a "Download org backup" action in Settings hitting the endpoint as a file download.

- **[P3] Dead "coming soon" Settings tiles: GST Settings, Invoice Numbering, Tax Rates, Language, Currency.** All five fire `_showComingSoon` snackbars. Currency is notable — a full `CurrencyController` (`/api/v1/currencies`) exists; Invoice Numbering has no backend at all (sequences are implicit). · _Backend:_ `currency/controller/CurrencyController.java` exists; others none · _Flutter:_ `settings_screen.dart:190,196,202,281,287` · _Why (ERP):_ invoice-number prefix/format and GST filing-frequency are basic config Indian SMBs expect. · _Fix:_ wire Currency to the existing controller; build Invoice-Numbering + GST-Settings screens (need backend).

- **[P3] No AI usage/cost telemetry or training-export UI.** `AiTelemetryService`/`ai_usage_log`/`ai_model_run` log tokens+cost on every Claude call but have no controller; `/ai/training/{summary,export}` exist but no screen calls them. · _Backend:_ `ai/service/AiTelemetryService.java`, `ai/controller/AiController.java:50-66` · _Flutter:_ none · _Why (ERP):_ an org on its own Anthropic key has zero visibility into AI spend/volume/failures. · _Fix:_ a read endpoint over usage logs + "AI usage" card and "Download training data" button in AI settings.

### Missing form/detail fields

- **[P1] Org profile cannot set logo, fiscal-year-start, base currency, or bank details — even server-side.** `UpdateOrgRequest` carries only name/phone/email/gstin/address; the `Organisation` entity has `logoUrl`, `fiscalYearStart`, `baseCurrency`, `timezone`, `taxRegime`, `salaryHandlingMode`, `fssaiLicense` but they are absent from the update DTO, and **there are no bank fields on the org at all** (no logo upload endpoint either). `org_details_screen.dart` shows only the captured subset. · _Backend:_ `organisation/dto/UpdateOrgRequest.java`, `organisation/Organisation.java` · _Flutter:_ `features/settings/presentation/org_details_screen.dart` · _Why (ERP):_ invoice/receipt PDFs need a logo + bank account for NEFT/UPI payment; fiscal-year-start drives every period report; these are first-run setup essentials. · _Fix:_ add the fields (+ org bank columns + logo multipart upload) to the DTO/entity and the org form.

- **[P2] Platform-admin pending-approval triage shows no owner name/email/phone.** Orgs/pending/dashboard screens read `org['ownerName']`/`ownerEmail`/`ownerPhone`/`industry`, but `PlatformOrgResponse` has none of them and the field is `industryCode` not `industry` → every "Owner: …"/"Industry: …" line renders blank. · _Backend:_ `platform/dto/PlatformOrgResponse.java` · _Flutter:_ `platform_admin_pending_screen.dart:104-107`, `platform_admin_orgs_screen.dart:567` · _Why (ERP):_ admins approve/reject signups blind to who requested. · _Fix:_ add owner block to `PlatformOrgResponse` (resolve OWNER `AppUser`); read `industryCode` in Flutter.

- **[P2] Workflow steps cannot target a specific user — only a role.** `WorkflowStep`/`WorkflowStepResponse` carry `approverUserId`, and the Flutter model parses it, but `workflow_settings_screen.dart` `_StepEditorRow` only offers a role dropdown (`OWNER/ADMIN/ACCOUNTANT/OPERATOR`); there's no user picker, so "this person must approve" is impossible in the UI. · _Backend:_ supports `approverUserId` · _Flutter:_ `features/workflow/presentation/workflow_settings_screen.dart:320` · _Why (ERP):_ named-approver workflows (e.g. only the proprietor signs off credit notes) can't be configured. · _Fix:_ add an optional approver-user picker per step.

- **[P3] Notification-list deep-link table is incomplete.** `_navigateToEntity` maps ~13 entity types; WORK_ORDER, PURCHASE_ORDER, payroll, POD, GST-suggestion entities fall through to no navigation. · _Flutter:_ `features/notifications/presentation/notification_list_screen.dart:106` · _Why (ERP):_ tapping many notifications does nothing. · _Fix:_ extend the switch / drive from a shared entity→route map.

- **[P3] Portal admin invite can't set a display name.** `_InviteDialog` hardcodes `fullName: ''` (backend falls back to contact name), and the customer portal app never surfaces `POST /portal/change-password`. · _Backend:_ `portal/controller/PortalUserAdminController.java`, `PortalSelfController.java:65` · _Flutter:_ `portal_users_screen.dart:638`, portal_app (none) · _Why (ERP):_ minor portal polish — no custom portal-login name, no self-service password change for customers. · _Fix:_ add an optional display-name field; add an account menu in `portal_home_screen.dart` posting to `portalChangePassword`.

### Missing business capabilities

- **[P1] Platform-admin deactivate/reactivate user is broken (404).** The user-detail sheet offers Deactivate/Reactivate (`POST /api/platform-admin/v1/users/{id}/{deactivate,reactivate}`) but neither mapping exists in `PlatformAdminController`. · _Backend:_ missing endpoints · _Flutter:_ `platform_admin_users_screen.dart` · _Why (ERP):_ a platform admin cannot disable a compromised org user despite the UI implying it. · _Fix:_ add the two endpoints (`setActive(false)` + token-version bump, mirroring `suspendOrg`).

- **[P2] No way to configure ~12 documented `org_settings` from the UI.** Backend reads these but no screen writes them: `inventory.valuation_method` (FIFO/Weighted-Average — a real costing policy; only `batch_policy` is exposed), `inventory.provisional_margin_pct`, `inventory.low_stock_alert`, `gst.eway_bill_threshold`, `pharma.rx_enforcement_mode`/`h1_strict`, `pos.cash_rounding`/`barcode_scan`/`default_customer`/`print_on_save`, `tax.inclusive_pricing`, `field_sales.geofence_radius_m`, `manufacturing.overhead_rate_per_hour`. The actual-cost-preview screen literally tells the user to "set `manufacturing.overhead_rate_per_hour` in org settings" while offering no UI to do so. · _Backend:_ keys read across `inventory/gst/pharma/pos/tax/fieldsales/manufacturing` services · _Flutter:_ none · _Why (ERP):_ inventory valuation method, Rx enforcement, and e-way threshold are policy decisions an admin must own. · _Fix:_ extend Business-Policies (or add module-specific settings screens) to cover these keys.

- **[P2] AI Inbox cannot "modify" a suggestion (only accept/defer/reject).** `AiSuggestionReviewRequest` supports `reviewedValue` + `correctionReason` and the repo passes `reviewedValue`, but the detail sheet shows `suggestedValue` read-only; the `MODIFIED` status is colour-coded but never produced. · _Backend:_ `POST /ai/suggestions/{id}/review` (MODIFY) · _Flutter:_ `features/ai_chat/presentation/ai_chat_screen.dart` · _Why (ERP):_ disagreeing with one field forces a full reject + manual redo. · _Fix:_ make the payload editable and send `action:'MODIFY'` with the edited value.

- **[P2] AI transaction categorization (vendor→GL account) has zero call sites.** `TransactionCategorizationController` (`/ai/categorize`, `/ai/categorize/backfill`) and Flutter constants exist, but no screen calls them — the bill-line form never suggests an account on vendor select, and there's no "learn from history" trigger. The learned `ai_pattern` is written but never read in the UI. · _Backend:_ `ai/controller/TransactionCategorizationController.java` · _Flutter:_ constants only (`api_config.dart:404`) · _Why (ERP):_ the "AI learns how you book each vendor" feature is invisible. · _Fix:_ suggest the account as a chip on vendor-select in the bill form; add a backfill button in AI settings.

- **[P2] Branches can be created but never edited, deactivated, or re-defaulted.** `BranchController` has only POST + GET; no PUT/DELETE/set-default, and `branches_screen.dart` has a create sheet only — despite the entity carrying full address, `isActive`, `isDefault`, GSTIN. · _Backend:_ `organisation/BranchController.java` · _Flutter:_ `features/settings/presentation/branches_screen.dart` · _Why (ERP):_ a typo'd branch GSTIN/address is permanent; you can't close a branch or change which is default. · _Fix:_ add branch update/deactivate/set-default endpoints + edit UI.

- **[P2] Platform-admin can view per-org modules/features but cannot change them.** `PlatformOrgDetailResponse` returns `enabledModules`/`enabledFeatures` (rendered as chips), but there's no per-feature toggle endpoint (`FeatureFlagService` has no controller); only `PUT /orgs/{id}/plan` exists. · _Backend:_ missing per-feature toggle · _Flutter:_ read-only chips · _Why (ERP):_ entitlement/provisioning changes require a plan-tier change or DB edit. · _Fix:_ `PUT /orgs/{id}/features` + a toggle in the detail sheet.

- **[P3] Approval inbox shows PENDING only; no approved/rejected history and incomplete document open.** `approvalRequestsProvider` hardcodes `status:'PENDING'`; there's no way to review past decisions in-app (the `historyForDocument` API exists but is only used from document detail screens). `_openDocument` handles only SALES_ORDER/CREDIT_NOTE; PAYMENT shows "go find it manually" and every other type (WORK_ORDER, BILL, PO…) shows "view not available". · _Backend:_ `/workflow/approval-requests?status=` supports any status · _Flutter:_ `features/workflow/presentation/approval_inbox_screen.dart` · _Why (ERP):_ no audit of who approved what; dead-end for non-SO/CN documents. · _Fix:_ add a status filter/tabs and extend `_openDocument` routing.

- **[P3] GST/e-invoice/e-way/2B AI-inbox items accept as no-ops.** `EINVOICE_REQUIRED`, `EWAY_BILL_REQUIRED`, `GSTR2B_*`, `ITC_AT_RISK`, `THREE_WAY_MATCH_EXCEPTION` render but only the `DRAFT_*`/`AGENTIC_REPLENISHMENT` types post an action on accept; the rest just flip status. Accepting "e-invoice required" does not generate the IRN — that lives in a separate GST screen. · _Backend:_ producers in `gst/*`, `ap/match/*` · _Flutter:_ `ai_chat_screen.dart` · _Why (ERP):_ the inbox looks actionable for compliance items but only dismisses; user must hunt the right GST tab. · _Fix:_ per-type deep-link CTAs or wire the action through (mirror DRAFT_*).

### Wiring & UX issues

- **[P3] Notification list fetches page 0 only — older notifications unreachable, no filter.** `notification_list_screen.dart:16` watches `notificationListProvider(0)`; `KKeyboardListWrapper.itemCount` is stubbed `() => 0`; no load-more, no read/type/severity filter. Backend `GET /notifications?page=&size=` supports paging. · _Fix:_ infinite scroll + filter chips.

- **[P3] No WhatsApp message-log view.** `GET /whatsapp/messages` and `ApiConfig.whatsappMessages` exist; no screen consumes it, so silent FAILED/SKIPPED sends are invisible. · _Fix:_ a message-log tab in WhatsApp settings.

- **[P3] Platform-admin dashboard drops 3 of 7 stats; audit rows always blank IP.** `DashboardStats` returns `totalUsers`/`newSignupsToday`/`newSignupsThisWeek` but the dashboard renders only Total/Pending/Active/Suspended orgs; `PlatformAdminService.logPlatformAdminAudit` is always called with `ipAddress=null` for org/user actions, so the audit screen's IP column is blank for APPROVE/SUSPEND/RESET. · _Fix:_ render the 3 stats; thread request IP into audit rows.

- **[P3] GRN photo-scan drafts without a review step and only from a PO.** `purchase_order_detail_screen.dart:_scanGrnFromPo` OCRs and immediately drafts (no confirm-lines sheet); there's no PO-less "scan supplier invoice → GRN" entry. · _Fix:_ insert a confirm-lines sheet; add a top-level scan-GRN action.

## Stats
P1=6, P2=15, P3=12, screens-missing=10, fields-missing=8


---

# MR Salesman Mobile App — UI/Field Gap Audit

Scope: `/home/user/katasticho-mr-salesman-app` (Flutter field app) vs backend `/home/user/katasticho/src/main/java/com/katasticho/erp/{fieldsales,fieldforce,attendance,sales,pharma}`.
App calls one shared `FieldApiClient` (`lib/src/core/network/api_client.dart`); navigation is an 8-tab `HomeShell` (`lib/src/features/home/home_shell.dart`) + 3 app-bar pushes (Tour Plan, Daily Report, Sync).

App screens (13): login, today_dashboard, visits, parties, orders, order_builder, collections, expenses, day_close, van_stock, mr/tour_plan, mr/dcr, sync.

## Coverage map

| Capability | Backend endpoint available? | App screen present? | Fields captured vs backend |
|---|---|---|---|
| Login / JWT + refresh | `POST /auth/login`, `/auth/refresh`, `/auth/me` | Yes (`login_screen.dart`, auto-refresh interceptor) | identifier+password only; full |
| Today dashboard (KPIs) | `GET /field-sales/dashboard` | Yes (`today_dashboard_screen.dart`) | full (routes/visits/productive%/orders/collections) |
| Today's routes + start/complete | `GET /executions/me/today`, `/{id}/start`, `/{id}/complete` | Yes (visits + dashboard) | full |
| Route execution **create/start** | `POST /executions` | **No** — app only reads `executions/me/today` | salesperson cannot self-start a route if back-office didn't create one |
| Visit list per route | `GET /executions/{id}/visits` | Yes (`visits_screen.dart`) | full |
| GPS check-in (geofence flag) | `POST /visits/{id}/check-in` | Yes — shows geoVerified/geoDistanceM | lat/lng; full. Offline-queued |
| GPS check-out + notes | `POST /visits/{id}/check-out` | Yes | lat/lng/notes; full. Offline-queued |
| Skip visit + reason | `POST /visits/{id}/skip` | Yes | reason; full |
| Record order (quick value) | `POST /visits/{id}/record-order` | Yes (quick-amount, offline) | salesOrderId+orderValue; full |
| Build line-item SO | `POST /sales-orders` + record-order | Yes (`order_builder_screen.dart`) | item/qty/rate/discountPct/tax/hsn. **No scheme, no batch, no price-list, no per-line discount UI** |
| Record collection | `POST /visits/{id}/record-collection` | Yes (`collections_screen.dart`) | **amount only — no payment mode/UTR/cheque, no receipt** (backend also amount-only) |
| Proof of Delivery + photo/signature | `POST /proof-of-delivery`, `/{id}/attachments` | Yes (in visits — `_RecordPodSheet` + signature pad + image_picker) | recipient/phone/relation/GPS/DC/invoice; photo + signature. **DC/invoice id typed by hand, no picker** |
| Detailing (products/samples/gifts) | `PUT /mr/visits/{id}/products` | Yes (`_DetailingSheet` in visits) | productName/detailed/sampleQty/giftName/giftQty; full |
| E-detailing aids viewer | `GET /mr/detail-aids`, `PUT/GET /visits/{id}/detail-aids` | Yes (`_AidsSheet` in visits) | open url + mark shown; full |
| Day close (cash reconcile) | `POST /day-close/initiate/{exec}`, `/{id}/submit`, `GET /{id}` | Yes (`day_close_screen.dart`) | closingCash/cashDeposited/notes; full (read-only opening/variance) |
| Van stock view + load/return | `GET /vans/{id}/stock`, `POST /van-transfers/load|return`, confirm | Yes (`van_stock_screen.dart`) | warehouseId+lines (**typed UUIDs, no item/warehouse picker, no batch**) |
| Expenses | `GET/POST /expenses`, `GET /accounts` | Yes (`expenses_screen.dart`) | category/amount/notes. **Receipt photo button is a "coming soon" stub** |
| Parties browse + detail | `GET /contacts`, `/contacts/{id}` | Yes (`parties_screen.dart`) | read-only AR/AP/credit/terms/address. **No call/maps/WhatsApp, no ledger, no MR profile shown** |
| Targets / incentives | `GET /targets/me` | Yes (dashboard "My Targets") | type/target/achieved/% bar; full read |
| Attendance punch in/out | `POST /attendance/punch-in|out`, `GET /today` | Yes (dashboard attendance card) | GPS punch; full |
| Apply leave | `POST /attendance/leave` | Yes (dashboard dialog) | from/to/type/reason; full |
| **My leave list / cancel leave** | `GET /attendance/leave/me`, `POST /leave/{id}/cancel` | **No** | client method `getMyLeaves` exists, never rendered; no cancel |
| TA/DA allowance + claim | `GET /allowance/me`, `POST /allowance/claim` | Yes (DCR screen) | GPS km / FLEXIBLE-MANUAL; full. **No claims history (`/allowance/claims/me`)** |
| My sample stock balance | `GET /samples/balance/me` | Yes (DCR screen, read) | balance per product; full read |
| **Sample issue / return / txn history** | `POST /samples/issue|return`, `GET /samples/transactions/{id}` | **No** (OWNER/ADMIN-gated — MR can't self-issue anyway) | n/a for MR |
| Tour Plan (MTP) create/submit | `POST /mr/tour-plans`, `/entries`, `/submit`, `GET /me`, `/{id}` | Yes (`mr/tour_plan_screen.dart`) | planDate/activityType/area/notes; full |
| **Tour-plan approvals (manager)** | `GET /tour-plans/pending`, `POST /{id}/approve|reject` | **No** | manager-on-field can't approve a junior's MTP from the app |
| DCR build/submit/history | `POST /mr/dcr/build|submit`, `GET /me` | Yes (`mr/dcr_screen.dart`) | workType/remarks; full |
| **DCR approvals (manager)** | `GET /dcr/pending`, `POST /{id}/approve|reject` | **No** | manager can't approve DCRs from the app |
| **RCPA (chemist Rx audit)** | `POST /mr/rcpa`, `/me`, `/by-chemist`, `/reports/*` | **No screen** | core pharma-MR capability entirely missing in app |
| **Stockist secondary sales (SSS)** | `POST /field-sales/secondary-sales/statements`, reports | **No screen** | distributor/stockist secondary-sales capture missing |
| **Joint / co-visit (with manager)** | `POST /mr/visits/{id}/joint-visit` | **No** | can't tag a joint working visit |
| **Field hierarchy / my team** | `GET /field-sales/hierarchy/my-team` | **No** | no team view for ABM/RBM users |
| **Coverage reports (deviation/frequency/team)** | `GET /mr/reports/deviation|frequency-compliance|team-dashboard` | **No** | no on-field coverage/compliance view |
| **Visit photo** (shop/doctor board) | `FieldVisit.photoUrl` column exists | **No** — never set | standard SFA "photo of shop/visiting card" absent |
| **New-customer onboarding from field** | `POST /api/v1/contacts` (works) | **No** — app has only `getContacts` (no create) | MR can't add a new doctor/retailer in the field |
| **Offline bundle (bootstrap/push)** | `GET /api/v1/field/sync/bootstrap`, `POST /sync/push` | **No** — app uses per-action queue only | purpose-built offline facade unused; today's beat not pre-cached for offline |
| Sync / offline queue | per-endpoint replay (`offline_queue.dart`) | Yes (`sync_screen.dart`) | CHECK_IN/OUT, RECORD_ORDER/COLLECTION, POD, LOCATION_PING |
| Live GPS breadcrumb ping | `POST /field-sales/locations/ping` | Yes (`location_ping_tracker.dart`, 3-min + background) | full |
| Push notifications (FCM) | `POST /api/v1/notifications/push/*` (register) | **No** — no FCM token registration in app | DCR-reminder/order pushes never reach this app |
| Product catalog browse (standalone) | `GET /items` | Partial — only inside order_builder | no standalone "price list / catalog" browse |

## Gaps

### Missing screens
- **[P1] RCPA (Retail Chemist Prescription Audit)** — no entry/report screen at all. · _Backend:_ `POST /api/v1/mr/rcpa`, `GET /me|/by-chemist/{id}|/reports/share|/reports/competitors` (`RcpaController`) · _App:_ none · _Why (MR/SFA):_ RCPA at the chemist is a core pharma-MR daily task (own-vs-competitor offtake); its absence makes the app non-viable for pharma field teams. · _Fix:_ Add `rcpa_screen.dart` — chemist picker + own/competitor line rows (product, qty, value, competitor name) → `record`; optional link from a visit.
- **[P1] New-customer onboarding from the field** — MR cannot create a doctor/retailer/chemist. · _Backend:_ `POST /api/v1/contacts` (live; `getContacts` already wired) · _App:_ `parties_screen.dart` is read-only; `FieldApiClient` has no `createContact` · _Why (MR/SFA):_ every SFA lets the rep add a new outlet on the spot; today it's a back-office round-trip. · _Fix:_ Add "Add party" FAB on Parties → form (name/type/mobile/GSTIN/address + MR profile category/specialty) → `POST /contacts`.
- **[P2] Manager approvals (Tour Plan + DCR) on mobile** — field managers (ABM/RBM, OPERATOR) can't approve juniors. · _Backend:_ `GET /mr/tour-plans/pending` + `/dcr/pending` + `POST /{id}/approve|reject` (manager-scoped via hierarchy) · _App:_ none · _Why (MR/SFA):_ first-line managers live in the field; approvals shouldn't require the ERP web app. · _Fix:_ Add `mr_approvals_screen.dart` (mirror ERP `MrApprovalsScreen`) gated on having a downline.
- **[P2] Stockist Secondary Sales (SSS) capture** — no screen. · _Backend:_ `POST /api/v1/field-sales/secondary-sales/statements`, `/reports/secondary-sales|/stock-on-hand` · _App:_ none · _Why (MR/SFA):_ distributor/stockist secondary-sales entry is a standard field task for FMCG/pharma distribution. · _Fix:_ SSS statement screen (stockist picker + per-product opening/purchase/sales/return → submit).
- **[P2] My Team / hierarchy view** — manager can't see direct reports/downline. · _Backend:_ `GET /field-sales/hierarchy/my-team` · _App:_ none · _Why (MR/SFA):_ field managers need today's team coverage at a glance. · _Fix:_ "My team" screen (reports + downline count) → drill into team-dashboard.
- **[P3] Coverage / deviation / frequency reports** — no on-field analytics. · _Backend:_ `GET /mr/reports/deviation|frequency-compliance|team-dashboard` · _App:_ none · _Why (MR/SFA):_ MTP-vs-actual deviation and visit-frequency compliance are the metrics managers check daily. · _Fix:_ Reports tab reusing the three endpoints.
- **[P3] Leave history + cancel** — no list of own leave requests. · _Backend:_ `GET /attendance/leave/me`, `POST /leave/{id}/cancel` (client `getMyLeaves` exists, unused) · _App:_ apply-only dialog on dashboard · _Why (MR/SFA):_ rep needs to see pending/approved leaves and withdraw. · _Fix:_ Leave list section (status chips + cancel) below attendance card or in a profile screen.
- **[P3] Standalone catalog / price-list browse** — catalog only reachable inside order builder. · _Backend:_ `GET /items` · _App:_ embedded only · _Why (MR/SFA):_ reps look up price/availability between visits. · _Fix:_ optional "Catalog" tab.

### Missing form / detail fields
- **[P1] Collection payment mode + reference + receipt** — only a rupee amount is captured. · _Backend:_ `POST /visits/{id}/record-collection` itself takes only `collectionAmount` (FieldSalesController:447) — so this is a **backend + app** gap · _App:_ `collections_screen.dart` / visit "Collect" dialog · _Why (MR/SFA):_ cash-vs-cheque-vs-UPI, cheque/UTR number, and an on-the-spot receipt are mandatory for field collections and day-close reconciliation. · _Fix:_ extend the endpoint+DTO with paymentMode/referenceNo (+ optional receipt PDF/SMS), then add the fields to the dialog.
- **[P2] Visit photo capture** (shop board, visiting card, doctor signage) — never captured. · _Backend:_ `FieldVisit.photoUrl` column exists (entity field) but no setter is exposed; check-in/out bodies don't accept it · _App:_ none · _Why (MR/SFA):_ geo-tagged shop/doctor photo is a standard proof-of-visit. · _Fix:_ add a photo field to check-in (or a dedicated `/visits/{id}/photo` attachment) + camera button on the visit card.
- **[P2] Joint-visit tag on a visit** — backend ready, no UI. · _Backend:_ `POST /mr/visits/{id}/joint-visit` (sets `jointVisitUserId`) · _App:_ none · _Why (MR/SFA):_ co-visits with a manager/colleague must be recorded for coverage credit. · _Fix:_ "Joint visit" action on the visit card → user picker.
- **[P2] Order builder: scheme / discount / batch / price-list** — only flat qty×rate. · _Backend:_ SO honours schemes, price-lists, per-line discount, batch (`SchemeService`, `PriceListService`, batch lines) · _App:_ `order_builder_screen.dart` sends `discountPct:0`, no batch, no scheme preview · _Why (MR/SFA):_ field orders routinely need the customer's price list and active schemes/free-goods. · _Fix:_ show resolved price-list rate, per-line discount field, and scheme/free-goods hints on the cart.
- **[P3] Expense receipt photo** — button is a stub (`'Receipt photo capture coming soon.'`). · _Backend:_ `AttachmentService` supports entity attachments · _App:_ `expenses_screen.dart` · _Why (MR/SFA):_ TA/DA reimbursement needs a bill photo. · _Fix:_ wire image_picker → expense attachment (image_picker already in pubspec for POD).
- **[P3] Parties: MR profile + actions** — detail shows AR/AP/address but not medicalCategory/specialty/mrClass/visitsPerMonth, and no call/WhatsApp/maps/ledger. · _Backend:_ ContactResponse carries the MR fields; `/contacts/{id}/ledger` exists · _App:_ `parties_screen.dart` `_ContactDetailScreen` · _Why (MR/SFA):_ a rep needs to tap-to-call, navigate, see ledger, and know the doctor's class/specialty. · _Fix:_ add call/WhatsApp/maps buttons, ledger link, and an MR-profile card.
- **[P3] Van load/return + POD: typed UUIDs instead of pickers** — warehouse id, item id, DC/invoice id are free-text UUID fields. · _Backend:_ pickers data available (`/items`, `/vans/{id}/stock`, contacts' open DCs/invoices) · _App:_ `van_stock_screen.dart` `_showTransferDialog`, `_RecordPodSheet` · _Why (MR/SFA):_ no field user can type a UUID; these flows are effectively unusable on a phone. · _Fix:_ replace UUID text fields with searchable item/warehouse/document pickers.

### Missing business capabilities
- **[P2] Route self-initiation** — if the back-office didn't pre-create today's execution, the rep is stuck ("No route execution for today"). · _Backend:_ `POST /field-sales/executions` (create) + `getMyAssignments` give route+van · _App:_ only reads `executions/me/today`; `startExecution` exists on the client but is never called · _Why (MR/SFA):_ reps must be able to start their assigned beat themselves each morning. · _Fix:_ "Start today's route" using the assignment's routeId+vanId when no execution exists.
- **[P3] Targets are read-only with no breakdown** — single % bar; no period/MTD-vs-target detail or incentive payout. · _Backend:_ `/targets/me` returns the target rows · _App:_ dashboard list · _Why (MR/SFA):_ reps want incentive visibility (earned/projected). · _Fix:_ dedicated targets screen with per-metric progress + computed incentive.

### Wiring, UX & offline issues
- **[P1] No push-notification (FCM) registration** — the app never registers a device token, so all server pushes (daily-report reminder `DailyReportReminderJob`, order/approval pushes) silently never arrive. · _Backend:_ `PushNotificationController` `/api/v1/notifications/push` + real FCM v1 sender exist · _App:_ no FCM dependency / no token POST anywhere · _Why (MR/SFA):_ reminders+nudges are the whole point of an SFA app. · _Fix:_ add firebase_messaging, request permission, register token on login, handle the DCR-reminder push.
- **[P2] Offline coverage is partial / fragile** — only check-in/out, record-order(quick), record-collection, POD-json, location-ping queue offline. SO build, detailing, aids, day-close, expenses, tour-plan, DCR all hard-fail with no connectivity; today's beat is not pre-fetched, so a rep starting in a no-signal area sees nothing. · _Backend:_ purpose-built `GET /field/sync/bootstrap` + `POST /sync/push` exist and are explicitly **unused** (FieldFacadeController comment) · _App:_ `offline_queue.dart` per-endpoint replay; visits/parties only load online · _Why (MR/SFA):_ field reps routinely work in dead zones; an SFA app must be offline-first (cache the beat, queue everything). · _Fix:_ adopt `/sync/bootstrap` to pre-cache today's visits/parties/catalog and `/sync/push` for batched replay; extend the queue to detailing/aids/expense/DCR.
- **[P2] POD photo/signature can't be captured offline** — `_recordPod` queues the JSON but skips attachments because there's no POD id yet (by design). · _Backend:_ attachment needs an existing POD id · _App:_ `visits_screen.dart` `_recordPod` · _Why (MR/SFA):_ the signed-slip photo is the most important part of a POD and is exactly what's lost offline. · _Fix:_ stage photo/signature bytes locally keyed to the queued POD, upload after the POD record syncs.
- **[P3] Order builder "Build order" is not offline-capable; quick-amount is the only offline path** — and even quick-amount sends a bare `orderValue` with no items, losing the line detail. · _Backend:_ `POST /sales-orders` needs connectivity · _App:_ `order_builder_screen.dart` (explicit comment) · _Why (MR/SFA):_ a no-signal order today is captured only as a number. · _Fix:_ queue the SO payload offline (items+rates) and create it on reconnect.
- **[P3] Day-close `dayCloseId` resolution is brittle** — relies on `execution['dayCloseId']`; if absent it always re-initiates and only catches the 409 ("already exists") by message. · _Backend:_ `initiate` is idempotent-ish but returns 409 on dup · _App:_ `day_close_screen.dart` · _Why:_ a rep who reopens the screen can hit confusing errors. · _Fix:_ look up existing day-close for the execution instead of relying on an inline id.
- **[P3] No "today's beat"/route-of-day surfacing independent of an execution** — Visits shows "No route execution" with no way to see the planned beat or its customers. · _Backend:_ `GET /routes/{id}/beats`, `/beats/{id}/customers`, assignments · _App:_ none · _Why (MR/SFA):_ the rep should always see today's planned outlets. · _Fix:_ when no execution, show the assigned route's beats/customers (and offer start).

## Stats
P1=5, P2=11, P3=13, screens-missing=8, fields-missing=7
