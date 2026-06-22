# Katixo Internationalization & Multi-Country Plan

**Status:** PLAN (not yet started) · **Created:** 2026-06-22 · **Owner:** solo/small build
**Scope:** make the single Katixo codebase serve India + Gulf (UAE→Oman) + later Africa (Kenya), without forking.
**Companion docs:** competitive teardown (Wafeq), country-selection assessment (UAE→Oman→Kenya; Nigeria dropped).

> **Read this before touching any i18n / multi-country code.** It records the current
> code state (with file evidence), exactly what changes where, effort, risk, and tests,
> so nothing is rediscovered or forgotten mid-build. Update the checkboxes as items ship.

---

## 0. TL;DR — what we found in the code

The codebase is **more internationalization-ready than expected on tax, and exactly as unready as feared on localization + statutory.** Two abstractions already exist (data-driven tax engine; AOP module gating) that make the foundation cheap. The expensive work is Arabic/RTL + Gulf payroll + PINT-AE e-invoicing — all *additive builds*, not refactors of working code.

| Area | Verdict | Why |
|---|---|---|
| Tax engine | ✅ **Already abstracted** | `GenericTaxEngine` is data-driven (reads `tax_group`/`tax_rate`, GL accounts from DB). `TaxSeedService` **already switches on `countryCode` and already seeds UAE VAT 5%**. |
| Module gating | ✅ **Pattern exists to mirror** | `@RequiresModule` + `ModuleAccessAspect` → copy verbatim into `@RequiresCountry`. |
| Org country fields | ✅ **Already present** | `Organisation` carries `countryCode`/`baseCurrency`/`timezone`/`taxRegime`/`fiscalYearStart`. |
| Currency master | ⚠️ **Modeled but unused** | `Currency.decimal_places` column exists — but ~103 `setScale(2)` sites ignore it → OMR/BHD (3dp) break. |
| Chart of Accounts | ⚠️ **Industry-keyed, not country-keyed** | `coa_template` keyed by industry only; UAE org gets Indian CoA → VAT GL accounts (2041/1511) never created → tax seed saves NULL GL. |
| India-pack gating | ❌ **No country guard** | `gst.*`, TDS/TCS, Tally, payroll statutory all run unconditionally if enabled. |
| Currency formatting (Flutter) | ⚠️ **Centralized but locale-locked** | One `CurrencyFormatter`, but hardcoded `en_IN` + ₹. |
| Translation (Flutter) | ❌ **~2,250 hardcoded strings** | l10n wired but 100% unused; only 139 EN keys exist. |
| RTL layout (Flutter) | ❌ **0 RTL-aware** | 30 `EdgeInsets.only(left/right)` + 98 directional icons; `EdgeInsetsDirectional` used nowhere. |
| PDF Arabic typography | ❌ **Latin-only, 2 pipelines** | backend `DocumentPdfService` (10 doc types) + Flutter `pdf` package; neither embeds an Arabic font. |
| E-invoicing (PINT-AE) | ❌ **India IRN hardcoded** | `EInvoiceService` locked to INV-01 JSON; `GspClient` transport is reusable. |
| Gulf payroll (WPS/gratuity) | ❌ **Zero** | Only Indian PF/ESI/PT/LWF; calculators injected unconditionally into `calculatePayslip`. |

**Readiness: ~35%.** Foundation good; the gap is localization + statutory + e-invoice schema, all well-scoped.

---

## 1. Target countries (locked)

Build for these **four only**. Each new abstraction must be justified by this list — no "support the world".

| Country | Currency (dp) | Language | VAT | E-invoice | Weekend | FY start | Priority |
|---|---|---|---|---|---|---|---|
| India 🇮🇳 | INR (2) | en, hi | GST 5/12/18/28 split | IRP/IRN (built) | Sat–Sun | April | live |
| UAE 🇦🇪 | AED (2) | ar, en | VAT 5% flat | Peppol PINT-AE (2027) | Sat–Sun¹ | January | **1st** |
| Oman 🇴🇲 | **OMR (3)** | ar, en | VAT 5% flat | Peppol PINT-OM (2026–28) | Fri–Sat | January | 2nd (cheap adjacency) |
| Kenya 🇰🇪 | KES (2) | en, sw | VAT 16% flat | eTIMS (live) | Sat–Sun | January | 3rd (conditional) |

¹ UAE moved to Sat–Sun in 2022. ² **Nigeria dropped** — micro-base, captured distribution rails, low ARPU. Not deferred — out of scope.
**The two assumptions that bite:** OMR **3 decimal places**, and Fri–Sat weekend (Oman). Bake both into the abstraction from day one.

---

## 2. Architecture — the spine everything hangs off

Four new pieces, all mirroring patterns already in the repo.

### 2.1 `Country` enum + `CountryProfile` registry
A `CountryProfile` per country supplies the defaults applied **once at signup** (then editable per-org). This is the "select country → everything populates" mechanism.

```
CountryProfile (interface)
  ├─ IndiaProfile     ← retrofit current behaviour, byte-identical
  ├─ UaeProfile
  ├─ OmanProfile
  └─ KenyaProfile
CountryRegistry.get(countryCode) → CountryProfile
```

`CountryProfile` fields (each maps to a concrete gap below):

| Field | India | UAE | drives |
|---|---|---|---|
| `taxSeedKey()` | "IN" | "AE" | which `tax_group`/`tax_rate` rows seed (§3) |
| `coaTemplateCountry()` | "IN" | "AE" | which `coa_template` rows seed (§4) |
| `currencyCode()` / `currencyDecimals()` | INR/2 | AED/2 | money precision (§6) |
| `defaultLocales()` | [en,hi] | [ar,en] | i18n (§7) |
| `weekendDays()` | [SAT,SUN] | [SAT,SUN] (Oman FRI,SAT) | HR/payroll (§5, §12) |
| `fiscalYearStart()` | 4 | 1 | reports |
| `taxIdLabel()` | "GSTIN" | "TRN" | contact/org forms (§12) |
| `eInvoiceProvider()` | IndiaIrp | PintAe | e-invoice (§10) |
| `statutoryCalculators()` | [PF,ESI,PT,LWF,TDS] | [Gratuity,WPS] | payroll (§11) |
| `enabledCountryModules()` | gst.*, tax.*, tally.* | vat.*, (zoho import later) | gating (§5) |

### 2.2 `@RequiresCountry` annotation + aspect
**Mirror `@RequiresModule` exactly.** Evidence: `common/module/RequiresModule.java` (annotation) + `common/module/ModuleAccessAspect.java` (`@Aspect @Component`, intercepts `@within || @annotation`, calls `requireEnabled`). Copy to:
- `common/country/RequiresCountry.java` → `String[] value()` (e.g. `{"IN"}`)
- `common/country/CountryAccessAspect.java` → reads org country from `TenantContext`, throws `FEATURE_NOT_AVAILABLE_IN_COUNTRY` if not whitelisted.
- Needs `TenantContext.getCurrentOrgCountry()` (add — cache org country at auth time alongside orgId).

~150 LOC. This is **Phase 1** — the single highest-leverage, lowest-risk step.

### 2.3 Data-over-code rule
Tax rates, CoA, currencies, holidays → **tables with effective dates**, never Java constants. The tax engine already does this; extend the discipline. A rate change (e.g., GST 2.0, or Oman 5%→7%) becomes a data migration, not a release.

---

## 3. Tax engine + VAT activation — ✅ CHEAP

**Current state (evidence):**
- `tax/GenericTaxEngine.java:47-99` — `calculate(orgId, taxGroupId, taxable, type)` reads `tax_group_rate` → `tax_rate`, GL from `tax_rate.gl_output_account_id`/`gl_input_account_id`. `@Service`, the only impl. `TaxEngineFactory` is a deprecated empty stub. Wired into `InvoiceService`, `SalesReceiptService` (POS), `PurchaseBillService`, `CreditNoteService`, `SalesOrderService`, `ExpenseService`, `VendorCreditService`.
- `tax/TaxSeedService.java:88-105` — **already country-aware**: switches on `org.getCountryCode()` (IN/VN/AE/GB/US/MY/ID); for AE already seeds VAT 5% (output `2041`/input `1511`).
- Tables `tax_group`, `tax_group_rate`, `tax_rate` exist in V1 baseline, seeded in V2.
- `IndiaGSTEngine.java` — legacy, **not** `@Service`/`@Primary`; effectively dead. *(Action: confirm unused, delete to avoid confusion.)*

**What to change:** essentially nothing in the engine. UAE VAT = data. The ONLY blocker is §4 (CoA must create accounts 2041/1511 for AE orgs, else `findAccountId` returns null → rate saved with NULL GL).
**One real bug:** `GenericTaxEngine.java:68` rounds tax at `setScale(2)` — wrong for OMR (3dp). Fix via §6 money util.

**Effort:** S (½ day once §4 lands). **Risk:** Low. **Tests:** seed AE org → post invoice → assert single 5% VAT line with correct GL (no CGST/SGST split); seed OM org → assert 3dp rounding.

---

## 4. Chart of Accounts per country — ⚠️ NEEDS A SEAM

**Current state:** `accounting/service/AccountService.java:102-157` `seedDefaultChartOfAccounts` → `seedFromTemplate(orgId, org.getIndustry())` reads `coa_template` keyed by **industry only** (TRADING/RETAIL/SERVICES/F_AND_B). `OrgBootstrapService.java:124-156` orchestrates; **no country passed.** So a UAE org gets the Indian 61-account CoA — which lacks VAT GL accounts 2041/1511 → §3 tax seed fails silently.

**What to change:**
1. Migration: add `country` column to `coa_template` (default `'IN'` for existing rows — non-breaking).
2. `AccountService.seedFromTemplate(orgId, industry, countryCode)` — resolve template by `(country, industry)`, fall back to `('IN', industry)` if no country-specific template (so existing behaviour is identical).
3. `OrgBootstrapService` passes `org.getCountryCode()`.
4. Seed a **Gulf TRADING CoA template** (`country='AE'`) including VAT output `2041` / input `1511`, no CGST/SGST/IGST accounts. Reuse for OM (same 5% VAT). Kenya later (16% VAT account).

**Effort:** M (2–3 days incl. drafting the Gulf CoA). **Risk:** Med — touches signup bootstrap; guard with "fall back to IN template" so India is untouched. **Tests:** AE signup seeds Gulf CoA incl. 2041/1511; IN signup byte-identical (61 accounts); tax seed finds the GL accounts.

---

## 5. India-pack gating — ❌ ADD `@RequiresCountry("IN")`

These run unconditionally today and will misfire on a UAE org. Gate each. **Event-driven ones must be gated at the handler, not just the controller.**

| Pack | Files | Invocation | Guard placement |
|---|---|---|---|
| GST filing | `gst/service/GstService` (GSTR-1/3B) | controller (`@RequiresModule(GST)`) | add `@RequiresCountry("IN")` on `GstController` |
| E-invoice (IRN) | `gst/service/EInvoiceService.java:62-82` | **INVOICE_POSTED handler** | runtime country check in `detectForInvoice` *before* `isEnabled()` |
| E-way bill | `gst/service/EwayBillService` | INVOICE_POSTED handler | runtime country check in handler |
| 2B recon / composition | `Gstr2bReconService`, `CompositionService` | controller | `@RequiresCountry("IN")` on controllers |
| TDS | `tax/service/TdsService` | **inline in `PurchaseBillService.create`** | inline `if (countryIs("IN"))` guard + `@RequiresCountry` on `TdsController` |
| TCS | `tax/service/TcsService` | **inline in `SalesInvoiceService`/posting** | inline guard + `@RequiresCountry` on `TcsController` |
| Tally migration | `migration/tally/*` | controller | `@RequiresCountry("IN")` (Gulf migrates from Zoho, not Tally) |
| Payroll statutory | `ProfessionalTaxCalculator`, `LabourWelfareFundCalculator`, `PfEcrFileGenerator`, `EsiReturnFileGenerator` | unconditional in `calculatePayslip` | see §11 (pluggable registry) |

**Effort:** M (2 days after §2.2). **Risk:** Low (additive gates; India keeps all). **Tests:** AE org calling a GST endpoint → `FEATURE_NOT_AVAILABLE_IN_COUNTRY`; INVOICE_POSTED on an AE invoice → no IRN/EWB suggestion created; IN org unchanged (regression: full gst/tax test suites stay green).

---

## 6. Currency precision — ⚠️ MODELED, UNUSED

**Current state:** `common/currency/entity/Currency.java:34` has `decimal_places` (default 2). `OrgSettingsService` seeds `org.decimal_places="2"` but **nothing reads it in posting.** ~103 `setScale(2, HALF_UP)` hardcoded across `accounting/` (JournalService), `ar/` (InvoiceService), `ap/`, `tax/` (`GenericTaxEngine:68`), `pos/` (SalesReceiptService). **No central money utility.** → OMR/BHD (3dp), KWD (3dp), JPY (0dp) all round wrong.

**What to change:**
1. New `common/money/MoneyUtil.roundForPosting(BigDecimal amount, int decimals)` (+ overload resolving decimals from the org's base currency).
2. Replace the ~103 `setScale(2)` posting-path sites (start with the critical 5: JournalService, InvoiceService, GenericTaxEngine, SalesReceiptService, PurchaseBillService; then sweep the rest).
3. Hook `Currency.decimalPlaces` → seed OMR=3, BHD=3, KWD=3, JPY=0 (most already in the 30-currency seed; verify decimals).

**Effort:** M (2–3 days; mechanical but wide). **Risk:** Med — touches money math; **every change must keep INR(2) byte-identical**. Do India-first regression after each batch. **Tests:** `MoneyUtilTest` (2/3/0 dp); OMR invoice posts at 3dp and the journal balances; INR posting unchanged (re-run accounting/AR/tax suites).

---

## 7. Translation / i18n (Flutter) — ❌ BIG SWEEP

**Current state:** l10n is wired (`main.dart` delegates + `supportedLocales`) but **100% unused** — ~**2,250 hardcoded `Text('…')`** across features (top: manufacturing 267, inventory 213, field_sales 179, pos 126, hr 112). Only **139** EN keys + 77 HI exist. No locale **controller** (device-locale only, no in-app language switch). No `Locale('ar')`.

**What to change:**
1. **Locale controller** (mirror `ThemeModeController` + SharedPreferences) + a language picker (reuse the brand-palette switcher UX) → runtime switch. ~1 day.
2. Extend `supportedLocales` → add `ar`, later `sw`.
3. **String extraction sweep**: migrate `Text('…')` → `AppLocalizations.of(context).key`. ~2,250 strings. Do it **feature-by-feature, highest-traffic first** (POS → invoices → contacts → dashboard → …). Budget realistically: this is the single largest line item — ~2–3 weeks of grind, parallelizable.
4. Arabic translation of the key set — **needs a real Arabic speaker** for GST/VAT/finance terms, not machine translation. Machine-translate as a stub to unblock RTL testing, mark `@needs-review`.

**Effort:** L (3 wks). **Risk:** Low technically, high tedium. **Tests:** golden test that no `Text('literal')` remains in swept features (lint); locale switch flips strings.

---

## 8. RTL layout (Flutter) — ❌ LONGEST POLE

**Current state:** `EdgeInsetsDirectional` used **nowhere**. 30 `EdgeInsets.only(left:/right:)` + ~29 `Alignment.centerLeft/Right`. **98 directional icons** (`arrow_forward`/`chevron_right`/…) across 85 files that won't auto-flip. POS + shell sidebar are mostly direction-neutral (good); the custom widgets are the work.

**What to change:**
1. Force `Locale('ar')` in dev (one line) and click every screen — fastest bug finder.
2. Convert `EdgeInsets.only(left/right)` → `EdgeInsetsDirectional.only(start/end)`; `Alignment.centerLeft` → `AlignmentDirectional.centerStart`.
3. Directional icons: swap fixed `Icons.arrow_forward`/`chevron_right` for auto-mirroring usage, or wrap with `Directionality`-aware logic. `KDataTable` column order + `KMoney` (wrap money in LTR so digits don't reverse) need explicit handling.
4. Re-audit POS cart, wizard step arrows (PO→GRN, SO→DC→Invoice), keyboard-help overlay.

**Effort:** L (3–4 wks, *after* §7 so real strings reveal alignment bugs). **Risk:** Med — visual, needs native-Arabic QA. **Tests:** widget tests pumped with `TextDirection.rtl`; manual screenshot diff per major screen.

---

## 9. PDF Arabic typography — ❌ TWO PIPELINES

**Current state:** **(a) Backend** `common/service/DocumentPdfService.java` (open-html-to-pdf) feeds **10 doc types** (invoice, bill, credit note, challan, SO, estimate, payslip, Form 16, food label, BMR) — Latin default font. **(b) Flutter** `pdf` package screens (`invoice_pdf_screen.dart`, bill/challan/estimate) — `pw.` default Helvetica (Latin-only) → Arabic renders as boxes.

**What to change:**
1. **Backend (centralized — fix once):** register **Noto Naskh Arabic** in `DocumentPdfService` font config + `dir="rtl"` on the HTML when locale=ar. Covers all 10 doc types at a stroke. ~1 day.
2. **Flutter:** embed Noto Sans Arabic in `pubspec.yaml`, pass `pw.Font` to the `pw.TextStyle`s; enable bidi. ~2 days.

**Effort:** M (3 days). **Risk:** Low. **Tests:** render an AE invoice with an Arabic customer name + item → glyphs not boxes; RTL column order on the invoice table.

---

## 10. E-invoicing PINT-AE / Peppol — ❌ NEEDS A SEAM

**Current state:** `gst/service/EInvoiceService.java` hardcoded to India INV-01 JSON (`buildRow`), INVOICE_POSTED-driven. `gst/service/GspClient.java` transport **is** generic/reusable (provider-agnostic REST + bearer, org-settings driven).

**What to change:**
1. Extract `EInvoiceProvider` interface: `buildPayload(Invoice) → schema`, `submit(payload) → ack`.
2. `IndiaIrpProvider` = current logic moved behind the interface (byte-identical).
3. `PintAeProvider` = Peppol **UBL XML** (BIS Billing 3.0 / PINT-AE), submitted via an **accredited ASP** (don't build ASP accreditation — integrate one from the MoF list). Reuse `GspClient` transport shape.
4. `CountryProfile.eInvoiceProvider()` dispatches. Gate India provider with §5.

**Effort:** L (1–2 wks for the interface + PINT-AE; ASP integration depends on partner). **Risk:** Med — external spec + partner. **Defer** until UAE design partners sign (per assessment Stage 2). **Tests:** IN invoice still produces INV-01 (regression); AE invoice produces valid PINT-AE UBL (schema-validate against the published XSD).

---

## 11. Gulf payroll (WPS + gratuity) — ❌ FROM SCRATCH, PLUGGABLE

**Current state:** `payroll/service/PayrollService.calculatePayslip` injects Indian calculators (`ProfessionalTaxCalculator`, `LabourWelfareFundCalculator`, …) **unconditionally**; they assume Indian `stateCode` (14 states). No registry. Gulf has **no income tax / PF / ESI** — instead **end-of-service gratuity** + **WPS** (MOHRE/WPS SIF file).

**What to change:**
1. `StatutoryDeductionCalculator` interface; register implementations per country.
2. India calculators → behind the interface, gated `@RequiresCountry("IN")`.
3. `GratuityCalculator` (UAE: ~21 days/yr first 5y, 30 days/yr after, capped) + `WpsFileGenerator` (SIF format).
4. `calculatePayslip` pulls `countryRegistry.statutoryCalculators(country)` — empty/Gulf set for AE, full set for IN.

**Effort:** L (1–2 wks). **Risk:** Med — payroll correctness is unforgiving. **Defer** to UAE Stage 2. **Tests:** IN payslip byte-identical (regression: `PayrollServiceTest` + LOP tests); AE payslip = gross − nothing + gratuity accrual; WPS SIF validates.

---

## 12. Field-level Indian assumptions — ⚠️ SCATTERED SWEEP

| Assumption | Evidence | Change |
|---|---|---|
| Phone = 10-digit Indian | `login_screen`, `signup_screen`, `employee_form_screen`, `contact_create_screen` (`length < 10`, `[6-9]` regex) | per-country phone rule from `CountryProfile` (UAE +971/9, Oman +968/8); use `intl_phone` or country dial-code lookup |
| Tax-ID label "GSTIN"/"PAN" | 24 Flutter files + `contact` DTOs (`ContactResponse`, `CreateContactRequest`) | label from `CountryProfile.taxIdLabel()` ("TRN" UAE, "VAT No" Oman, "PIN" Kenya); keep the stored column generic (`taxId`) |
| State / GST state-code | 38 backend files (`stateCode`, `gst_state`, `billingState`) | India-only; for Gulf, "state" = emirate/governorate, no GST split — gate state-code logic to IN; address keeps a free `region` field |
| Weekend Sat–Sun | `hr/AttendanceManagementService`, `hr/LeaveManagementService` (DayOfWeek) | `CountryProfile.weekendDays()` (Oman Fri–Sat) — drives working-days, leave, payroll LOP |
| Fiscal year April | `Organisation.fiscalYearStart=4` | already a field; `CountryProfile` sets 1 for Gulf/Kenya at signup |
| Number format `en_IN` + ₹ | `core/utils/currency_formatter.dart` (`NumberFormat(locale:'en_IN')`, ₹) — **centralized (good)** | parametrize: `format(amount, currency, locale)`; symbol + grouping from currency/locale, not hardcoded |

**Effort:** M (3–4 days). **Risk:** Low–Med. **Tests:** UAE phone accepts 9 digits; contact form shows "TRN"; Oman weekend = Fri–Sat in leave calc.

---

## 13. Onboarding country picker — ⚠️ INSERT A STEP

**Current state:** onboarding flow exists: `business-type → industry → sub-category → details → complete` (`routing/app_router.dart:376-380`, screens in `features/onboarding/presentation/`). `signup_screen` collects orgName/businessType/industryCode. **No country step.**

**What to change:** add **country** as the FIRST onboarding step (or on `business_details`). Pass `countryCode` → `register` → `Organisation` → `OrgBootstrapService` resolves `CountryRegistry.get(code)` → seeds CoA(§4) + tax(§3) + locale + weekend + fiscal + enabled modules. Lock country after first posted invoice.

**Effort:** S (1–2 days). **Risk:** Low. **Tests:** pick UAE → org created with AED/ar/Jan-FY/VAT, Gulf CoA, GST modules off.

---

## 14. Deferred / out of scope (record so we don't forget *why*)

- **Live bank feeds (UAE banks).** Today: `banking/BankStatementParser` (file/CSV upload) works for any country. Live UAE bank APIs = post-traction. **Defer.**
- **KSA ZATCA Phase 2.** Multi-year, only if Saudi entry. **Out.**
- **Hijri calendar.** Gulf ledger runs Gregorian; Hijri only on customer-facing PDF date + KSA HR. Model as org setting `dates.show_hijri`, dual-display on PDFs only. **Defer to polish.**
- **Multi-entity consolidation, mature mobile, ecosystem integrations** — Wafeq-parity items, not wedge. **Later.**
- **Nigeria** — dropped, not deferred (different company).
- **M-Pesa reconciliation / eTIMS** — Kenya gating items; first-class work when Kenya is greenlit, not abstraction freebies.

---

## 15. Phasing — the disciplined sequence

**Hard rule from the assessment: the internationalization-ready refactor is ≤ 6 weeks. If it leaks to week 8 you've drifted into product build — stop and reassess.**

### Phase 0 — Internationalization-ready refactor (≤6 wks, ship to main, ZERO behaviour change for India)
| Wk | Deliverable | §  |
|---|---|---|
| 1 | `Country` enum + `CountryProfile` + `CountryRegistry`; retrofit `IndiaProfile`. `@RequiresCountry` + aspect + `TenantContext` country. | 2 |
| 2 | Gate India packs (`@RequiresCountry("IN")` on gst/tax/tally + event-handler guards). Confirm `IndiaGSTEngine` dead → delete. | 5 |
| 3 | `MoneyUtil` + replace critical posting `setScale(2)`; hook `Currency.decimalPlaces`; seed OMR/BHD/KWD/JPY decimals. | 6 |
| 4 | CoA `country` column + `seedFromTemplate(country)` + Gulf CoA template. Activate UAE VAT 5% end-to-end (test invoice posts 5% VAT). | 3,4 |
| 5 | Flutter: locale controller + language picker + `supportedLocales+ar`; `CurrencyFormatter` locale param; onboarding country step. | 7,12,13 |
| 6 | PDF Arabic font (backend `DocumentPdfService` + Flutter); Arabic ARB **stub** (machine, marked review); **PINT-AE XML stub** (generates valid UBL, not ASP-routed) as the design-partner demo prop. | 9,7,10 |

**Exit:** an Indian customer is byte-identical; a **UAE signup** gets AED, 5% VAT (posts correctly), English+Arabic locale, RTL-capable shell, and emits a PINT-AE-shaped invoice — enough to demo to 5 design partners. No ASP commitment, no Gulf payroll yet.

### Phase 1 — UAE design-partner validation (no further heavy build)
Recruit 5–10 UAE Indian-origin FMCG distributors on Tally/Zoho. Sell migration + AI + WhatsApp + distributor depth (the verified wedge). **Gate:** ≥5 paying intents before Phase 2.

### Phase 2 — UAE production (only after the gate clears)
Full RTL sweep (§8), real PINT-AE provider + ASP integration (§10), Gulf payroll WPS+gratuity (§11), professional Arabic translation (§7), field-level localization (§12).

### Phase 3 — Oman bolt-on (cheap; self-serve only, no dedicated GTM)
Reuse Gulf stack; OMR 3dp (already handled in Phase 0 §6); Fri–Sat weekend; PINT-OM provider variant.

### Phase 4 — Kenya (separate, deliberate, only after UAE is cash-flow positive)
First-class M-Pesa reconciliation + eTIMS + KE payroll (PAYE/NSSF/SHIF/Housing/HELB) + Swahili. Not a freebie.

---

## 16. Master checklist (tick as shipped)

**Phase 0 — foundation**  *(progress 2026-06-22 — commits f43684d…f447428)*
- [x] `Country` enum + `CountryProfile` + `CountryRegistry` + `IndiaProfile` (byte-identical) — **0.1**
- [x] `@RequiresCountry` + `CountryAccessAspect` (CountryAccessService caches org country; no TenantContext change needed) — **0.1**
- [x] Gate gst.* (7 controllers + both INVOICE_POSTED handlers for e-invoice/e-way-bill) — **0.2**
- [x] Gate TDS/TCS (controllers). *Inline PurchaseBill/SalesInvoice guards skipped — already setting-gated; controller gate suffices* — **0.2**
- [x] Gate migration/tally.* — **0.2**
- [~] Delete dead `IndiaGSTEngine` — *left in place; it has a test + is inert (not a bean). Low-value cleanup, deferred.*
- [x] `MoneyUtil.roundForPosting` + `MoneyPrecisionService` (infra). *Critical setScale(2) sweep DEFERRED to Oman — UAE is 2dp, every site already correct* — **0.3**
- [x] Hook `Currency.decimalPlaces` (MoneyPrecisionService); V3 adds OMR/BHD/KWD=3, SAR/QAR/KES=2 (AED/JPY already correct) — **0.3**
- [x] `coa_template.country` column (V4) + `seedFromTemplate(country)` + IN fallback — **0.4**
- [x] Gulf TRADING CoA template (54 accts: VAT 2041/1511, no CGST/SGST/TDS/PF) — **0.4**
- [x] **UAE VAT 5% activates end-to-end** — verified LIVE: AE signup → Gulf CoA + "VAT 5%" group; IN signup byte-identical (61 accts, GST split) — **0.4/0.5**
- [x] Flutter locale controller + language picker + `app_ar.arb`/`app_sw.arb` stubs — **0.5**
- [ ] `CurrencyFormatter` locale/currency parametrized (kill hardcoded en_IN/₹) — *app-wide money display; needs Flutter SDK to verify safely*
- [x] Onboarding country step → bootstrap wires profile (register/signup pass countryCode; AuthService applies CountryProfile) — **0.5**
- [x] Backend `DocumentPdfService` Arabic font (Noto Naskh) + ICU bidi/shaping — **0.7** (covers all 10 backend PDF doc types in one place; +openhtmltopdf-rtl-support dep)
- [ ] Flutter `pdf` Arabic font + bidi — *pending (needs SDK)*
- [x] Arabic ARB stub (33 labels translated, rest English placeholder @needs-review) — **0.5**
- [x] PINT-AE XML stub (valid UBL, unrouted) for demo — **0.6**: EInvoiceProvider seam + PintAeProvider (UBL 2.1, TRNs, 5% VAT, totals) + PintAeEInvoiceService (maps real Invoice) + endpoint gated @RequiresCountry({"AE","OM"})
- [x] Country-profile endpoint (`GET /api/v1/reference/country-profile` → taxIdLabel/currency/symbol/decimals/weekend/fiscal) for Flutter field localization — **0.6**
- [x] **Regression: full backend suite 1245 green; India byte-identical (live signup verified)** — **after each commit**

**Phase 0 remaining (need Flutter SDK / next session):** CurrencyFormatter locale param · PDF Arabic fonts (backend one-place + Flutter) · then the two long poles below.

**Phase 2+ (post-validation)**
- [ ] `EInvoiceProvider` interface + `IndiaIrpProvider` (byte-identical) + `PintAeProvider` + ASP integration
- [ ] `StatutoryDeductionCalculator` registry + India calcs behind it + `GratuityCalculator` + `WpsFileGenerator`
- [ ] Full string extraction sweep (~2,250) + professional Arabic translation
- [ ] Full RTL sweep (EdgeInsetsDirectional + 98 directional icons + KDataTable + POS)
- [ ] Field localization (phone, tax-id label, state→region, weekend Fri–Sat)
- [ ] UAE VAT 201 return builder
- [ ] Oman PINT-OM variant + Fri–Sat weekend
- [ ] (Kenya, gated) M-Pesa recon + eTIMS + KE payroll + Swahili

---

## 17. Decisions to lock before Phase 0 (don't start without these)

1. **One product, country-aware** (recommended) — confirmed, no fork. ✅ this plan assumes it.
2. **One country per org**, locked after first invoice (recommended) — avoids multi-jurisdiction tax tangle. **CONFIRM.**
3. **Target list = IN, UAE, Oman, Kenya** (Nigeria out). **CONFIRM.**
4. **ASP partner** for PINT-AE (don't self-accredit) — pick from MoF list (ClearTax/Defmacro, Flick) before Phase 2. **CONFIRM intent.**
5. **Hijri** = display-only on PDFs, opt-in setting (not ledger). **CONFIRM.**

---

*Evidence basis: backend country-readiness audit + Flutter i18n/RTL audit + direct greps, 2026-06-22. File:line references current as of that date — re-verify before editing a cited file.*
