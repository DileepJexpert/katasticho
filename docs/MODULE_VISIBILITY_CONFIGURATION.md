# Module Visibility & Per-Org Configuration

How the app decides which modules an organisation sees in the sidebar, how an
admin tweaks that per organisation, and why one org's choices never affect
another. Also documents the fixed QA test login.

_Last updated: 2026-07-10._

---

## 1. The three layers (how visibility is computed)

Visibility is a **capability** per module (`canUsePos`, `canUsePayroll`, …),
computed in `flutter_app/lib/core/auth/business_capabilities.dart` and consumed
by the sidebar (`_isNavItemVisible` in `flutter_app/lib/routing/shell_screen.dart`).
It is built from three layers, evaluated in order:

1. **Industry default (fallback).** Derived from the org's `businessType` /
   `industryCode`. A retailer gets POS + Inventory; a distributor also gets
   Distribution, Field Sales, Partner Network, HR & Payroll, Supply Planning,
   Courier; a manufacturer gets Manufacturing; a pharmacy gets Pharma + Batch/Expiry.
   Accounting, Reports, Bank, AI Inbox are on for everyone.
2. **Feature flags (per org).** `org_feature_flag` rows (keyed by `org_id`),
   seeded from the industry at signup, **OR-combined** with the fallback — so a
   flag can only *add* a module the vertical doesn't grant by default. Read via
   `GET /api/v1/settings/features`.
3. **Module-visibility overrides (per org, authoritative).** An explicit
   Show/Hide decision per module that **wins outright** over layers 1–2. Stored
   as JSON in `org_settings` key `modules.visibility` (`{"PAYROLL": false, …}`),
   applied by `BusinessCapabilities.applyModuleOverrides`. A module absent from
   the map keeps its computed (layer 1+2) default.

```
effective(module) =
    override present?  → override value          (layer 3, authoritative)
    else               → featureFlag OR fallback  (layers 2 + 1)
```

## 2. Configuring an org (the knobs)

All three are **per organisation** and require **OWNER/ADMIN**.

| Goal | Use | Endpoint / Screen |
|------|-----|-------------------|
| One authoritative toggle per module (**recommended**) | **Modules** settings screen | `/settings/modules` → `PUT /api/v1/settings/module-visibility` |
| Turn a module ON that the vertical hides | Feature flag (or the Modules screen → **Show**) | `PUT /api/v1/settings/features/{MODULE}` `{"enabled":true}` |
| Hide specific menu **entries** (not whole modules) | Sidebar Customisation | `/settings/nav-customisation` → `PUT /api/v1/settings/nav.disabled` |
| Revert an org to its vertical defaults | Modules screen → **Reset**, or | `POST /api/v1/settings/module-visibility/reset` |

### The Modules screen (`/settings/modules`)

Each module has three states:

- **Default** — follow the industry/feature-flag default (no override stored).
- **Show** — force visible even if the vertical hides it.
- **Hide** — force hidden even if the vertical shows it.

Show/Hide are authoritative. This is the single knob that works in **both**
directions (unlike a feature flag, which can only add). Command palette: "Modules".

### API reference (`/api/v1/settings/module-visibility`)

| Method | Path | Role | Effect |
|--------|------|------|--------|
| `GET` | `/` | any authenticated | `{overrides:{MODULE:bool}, modules:[…]}` |
| `PUT` | `/{module}` | OWNER/ADMIN | set one module Show(`true`)/Hide(`false`) |
| `DELETE` | `/{module}` | OWNER/ADMIN | clear one override → back to default |
| `PUT` | `/` | OWNER/ADMIN | replace whole map `{overrides:{…}}` |
| `POST` | `/reset` | OWNER/ADMIN | clear all overrides |

Unknown module codes → `MODULE_VISIBILITY_UNKNOWN_MODULE` (400). Valid codes are
`ModuleCode.ALL` (POS, INVENTORY, DISTRIBUTION, PHARMA, BATCH_EXPIRY,
MANUFACTURING, FIELD_SALES, PARTNER_NETWORK, PAYROLL, SUPPLY_CHAIN, COURIER,
TRANSPORT, ACCOUNTING, AR, AP, GST, BANK_RECON, AI_INBOX, REPORTS, COLLECTIONS,
RECURRING_BILLING, MULTI_ENTITY, PAYMENTS, CA_CONSOLE).

## 3. Multi-organisation isolation (guaranteed, not by convention)

- Every read/write resolves `orgId` from `TenantContext.getCurrentOrgId()` — an
  org can only touch **its own** flags/overrides (`ModuleVisibilityController`,
  `FeatureFlagController`, `OrgSettingsController`).
- Overrides + feature flags are stored per `org_id`; the industry fallback is
  derived from **that org's own** business type.
- Nothing here is global. Org A's Modules-screen changes cannot change what
  org B sees.

## 4. Default vertical matrix (industry fallback)

| Module | Retailer | Distributor | Manufacturer | Pharmacy |
|--------|:---:|:---:|:---:|:---:|
| Point of Sale | ✅ | – | – | ✅* |
| Inventory | ✅ | ✅ | ✅ | ✅ |
| Sales Orders & Delivery (Distribution) | – | ✅ | – | – |
| Pharmacy / Batch & Expiry | – | – | – | ✅ |
| Manufacturing | – | – | ✅ | – |
| Field Sales | – | ✅ | – | – |
| Partner Network | – | ✅ | – | – |
| HR & Payroll | – | ✅ | ✅ | – |
| Supply Planning | – | ✅ | ✅ | – |
| Courier & Transport | – | ✅ | – | – |
| Accounting / Reports / Bank / AI | ✅ | ✅ | ✅ | ✅ |

\* POS shows for retail-style industry codes. Any cell can be flipped per org via
the Modules screen. **2026-07-10 fix:** HR & Payroll / Supply Planning / Courier
were previously shown to *every* vertical (a leak); they are now gated as above.

## 5. Backend enforcement caveat

Visibility is a **frontend** concern (the sidebar). The backend `@RequiresModule`
gate is weak: subscription billing is off by default and **OWNER/ADMIN bypass the
module flag check for all but a few "strict" modules**, so an OWNER can still call
a hidden module's API directly. Hiding a module in the Modules screen removes it
from the UI; it does not lock the API for an OWNER. Tightening the server-side
bypass is a separate, deliberate follow-up.

## 6. Fixed QA test login

For manual testing/bug-fixing there is a config-gated seeded account
(`TestAccountBootstrapService`) that sees **every** module:

- **Off by default.** Enable with `TEST_ACCOUNT_ENABLED=true` (dev/test only).
- Seeds ONE org + OWNER via the real `register()` path with all module flags on
  and onboarding pre-completed. Idempotent; never touches real signups.
- Default login (override via env): **phone `9000000001` / password `Test@12345`**.
- **Do not enable in production** — the password is a known constant.

Config keys: `app.test-account.{enabled,phone,password,full-name,org-name,business-type,country-code}`
(env `TEST_ACCOUNT_*`).
