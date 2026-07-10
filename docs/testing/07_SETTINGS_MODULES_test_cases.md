# 07 — Settings: Module Visibility & Access

Manual UAT for **per-organisation module visibility** (the `/settings/modules`
screen), the vertical defaults, multi-org isolation, and the fixed QA test login.
Format matches the rest of the pack — see `README.md` §3.

**Feature reference:** `docs/MODULE_VISIBILITY_CONFIGURATION.md`.

> **Why this matters:** a retailer should see a lean sidebar (POS, Inventory,
> Accounting, Reports), not Manufacturing / Field Sales / Payroll. An org that
> *does* need an extra module must be able to turn it on for itself — without
> changing what any other org sees.

---

### TC-MOD-001 — Modules screen loads (OWNER)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/settings/modules` (Settings → **Modules**, or command palette "Modules") · **Role:** OWNER |

**Steps:** Open Settings → Modules.

**Expected result:** Two cards — **Vertical modules** (POS, Inventory, Sales
Orders & Delivery, Pharmacy, Batch & Expiry, Manufacturing, Field Sales, Partner
Network, HR & Payroll, Supply Planning, Courier & Transport) and **Core**
(Accounting, Bank Reconciliation, AI Inbox, Reports). Each row has a
**Default / Show / Hide** dropdown; all start at **Default** for a fresh org.
**Save** + **Reset** actions in the app bar.

**Actual / Status / Notes:**

---

### TC-MOD-002 — Non-admin cannot change modules
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/settings/modules` · **Role:** VIEWER (then OPERATOR) |

**Expected result:** The screen shows a **"Not authorised"** empty state (only
owners/admins may change modules). A direct `PUT /api/v1/settings/module-visibility/PAYROLL`
as VIEWER/OPERATOR is rejected **403**. (GET is allowed for any role — the sidebar
reads it for everyone.)

**Actual / Status / Notes:**

---

### TC-MOD-003 — Hide a module the vertical shows (authoritative)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/settings/modules` · **Role:** OWNER of a **distributor** org |
| **Preconditions** | Distributor org (Field Sales is visible by default) |

**Steps:** Set **Field Sales → Hide** → **Save** → reload the app.

**Expected result:** The **Field Sales** group disappears from the sidebar even
though the distributor default shows it (the explicit Hide wins). `GET
/api/v1/settings/module-visibility` returns `{"FIELD_SALES": false}`.

**Actual / Status / Notes:**

---

### TC-MOD-004 — Show a module the vertical hides
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/settings/modules` · **Role:** OWNER of a **retailer** org |
| **Preconditions** | Retailer org (HR & Payroll hidden by default) |

**Steps:** Set **HR & Payroll → Show** → **Save** → reload.

**Expected result:** The **HR & Payroll** group now appears in the retailer's
sidebar. Override map has `{"PAYROLL": true}`. (Equivalent alt path: `PUT
/api/v1/settings/features/PAYROLL {"enabled":true}` also reveals it.)

**Actual / Status / Notes:**

---

### TC-MOD-005 — Default reverts to the vertical baseline
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/settings/modules` · **Role:** OWNER |
| **Preconditions** | TC-MOD-003 applied (Field Sales = Hide on a distributor) |

**Steps:** Set **Field Sales → Default** → **Save** → reload.

**Expected result:** Field Sales is visible again (distributor default). The
override for `FIELD_SALES` is removed from the map (not stored as `true`).

**Actual / Status / Notes:**

---

### TC-MOD-006 — Reset clears all overrides
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/settings/modules` · **Role:** OWNER |
| **Preconditions** | At least one Show/Hide override set |

**Steps:** Tap **Reset** in the app bar.

**Expected result:** Every row returns to **Default**; the sidebar returns to the
pure vertical baseline. `GET` returns `overrides: {}`.

**Actual / Status / Notes:**

---

### TC-MOD-007 — Per-org isolation (multi-tenant)
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/settings/modules` · **Role:** OWNER of **Org A**, then OWNER of **Org B** |
| **Preconditions** | Two separate orgs (two signups) |

**Steps:** In **Org A**, set Manufacturing → Show and Save. Log out, log in as
**Org B**'s OWNER, open Modules.

**Expected result:** Org B's Modules screen is **unaffected** — Manufacturing is
still **Default** for Org B, and Org B's sidebar is unchanged. Org A's override
did not leak. (Confirms every read/write is scoped to the caller's own org.)

**Actual / Status / Notes:**

---

### TC-MOD-008 — Retailer default sidebar is lean (the fix)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | app sidebar · **Role:** OWNER of a fresh **retailer** org (no overrides) |

**Expected result:** The sidebar does **not** show **HR & Payroll**, **Supply
Planning**, or **Courier & Transport** (these previously leaked to every vertical).
It also does not show Manufacturing / Field Sales / Partner Network / Pharma. It
**does** show POS, Inventory, Accounting, Reports, Bank, AI Inbox.

**Actual / Status / Notes:**

---

### TC-MOD-009 — Distributor default shows trade/ops modules
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | app sidebar · **Role:** OWNER of a fresh **distributor** org |

**Expected result:** The sidebar **does** show Sales Orders & Delivery, Field
Sales, Partner Network, HR & Payroll, Supply Planning, and Courier & Transport
(distributor defaults) — proving the gating hides by vertical, not for everyone.

**Actual / Status / Notes:**

---

### TC-MOD-010 — Fixed QA test login sees every module
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | login screen · **Role:** the seeded QA account |
| **Preconditions** | Backend booted with `TEST_ACCOUNT_ENABLED=true` |

**Steps:** Log in with identifier **`9000000001`** / password **`Test@12345`**.

**Expected result:** Lands straight in the app (onboarding pre-completed) and the
sidebar shows **every** module group (all feature flags enabled for this org).
Re-booting the app does not create a duplicate (idempotent). Not enabling the env
var → the account does not exist and login fails with `AUTH_BAD_CREDENTIALS`.

**Actual / Status / Notes:**

---

### TC-MOD-011 — Unknown module code is rejected
| | |
|---|---|
| **Priority / Type** | P2 / Negative |
| **Route** | API `PUT /api/v1/settings/module-visibility/NONSENSE` · **Role:** OWNER |

**Expected result:** Rejected **400** with code **`MODULE_VISIBILITY_UNKNOWN_MODULE`**;
nothing is written. Valid codes only (see `ModuleCode.ALL`).

**Actual / Status / Notes:**

---

### TC-MOD-012 — Malformed stored map degrades safely
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | app sidebar / `GET /settings/module-visibility` · **Role:** OWNER |
| **Preconditions** | `org_settings.modules.visibility` contains malformed JSON (simulate via DB or a bad bulk write) |

**Expected result:** The app treats the overrides as **empty** (no crash) — the
sidebar falls back to the vertical/flag default. GET returns `overrides: {}`.
(Service swallows parse errors by design.)

**Actual / Status / Notes:**
