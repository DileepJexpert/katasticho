# 09 — Field Sales & MR (SFA)

Manual UAT for the field-sales / MR execution pack: beats, routes, vans, route
execution + visits, van stock, day-close, targets, TA/DA allowances, samples,
live tracking, MR reporting (tour plan / DCR / detailing / RCPA / secondary
sales), reporting hierarchy, and field attendance. Format matches the rest of
the pack — see `README.md` §3.

> **Module gate:** Field Sales is capability-gated (`FIELD_SALES` /
> `canUseFieldSales`). Distributor orgs get it by default; for any other org
> enable it first on the **Modules** screen (doc 07) or `PUT
> /api/v1/settings/features/FIELD_SALES {"enabled":true}`.

> **Two apps:** the **ERP** (`/field-sales/*` screens) is the manager/admin side
> — masters, approvals, dashboards. The **field app**
> (`katasticho-mr-salesman-app`) is the salesperson's side — route execution,
> check-in/out, orders, DCR, punch. Cases below say which app to use.

> **Roles:** admin/masters/approvals = **OWNER/ADMIN**; a **salesperson** is an
> **OPERATOR**. Visit actions are ownership-checked — only the execution's own
> salesperson may act (`FS_NOT_ASSIGNED_SALESPERSON`, 403).

> **Standard field data (create once, reuse):**
> | Salesperson | Role | Beat | Customers |
> |---|---|---|---|
> | Ravi (op) | OPERATOR | Andheri-Beat | Sharma Traders, Verma Stores |
> | Manager (Meena) | ADMIN | — | approves day-close / DCR |

---

## A. Masters — beats, routes, vans, assignment, hierarchy

### TC-FS-001 — Create a beat + assign customers
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | ERP `/field-sales/beats` (`POST /api/v1/field-sales/beats`) · **Role:** OWNER/ADMIN |

**Test data:** Beat **Andheri-Beat**; assign **Sharma Traders** (seq 1, freq
Weekly) + **Verma Stores** (seq 2, Weekly).

**Expected result:** Beat created; two customers linked with visit sequence +
frequency (`.../beats/{id}/customers`). An OPERATOR attempting to create a beat is
**403** (masters are OWNER/ADMIN).

**Actual / Status / Notes:**

---

### TC-FS-002 — Create a route from beats
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | ERP `/field-sales/routes` (`POST /routes`, `.../routes/{id}/beats`) · **Role:** OWNER/ADMIN |

**Test data:** Route **North-Route**, day-of-week **Mon**, ordered beats:
Andheri-Beat.

**Expected result:** Route created and beats linked in order. Route is filterable
by day-of-week.

**Actual / Status / Notes:**

---

### TC-FS-003 — Create a van + assign salesperson
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | ERP `/field-sales/vans` + assignment (`POST /vans`, `POST /assignments`) · **Role:** OWNER/ADMIN |

**Test data:** Van **MH-01-AB-1234** (capacity 500). Assignment: **Ravi → North-Route + Van MH-01-AB-1234**, effective today.

**Expected result:** Van created; salesperson assignment links Ravi → route + van
+ territory with effective dates. `GET /assignments/me` (as Ravi) returns it.

**Actual / Status / Notes:**

---

### TC-FS-004 — Reporting hierarchy (assign manager)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | ERP `/field-sales/org-chart` (`PUT /api/v1/field-sales/hierarchy/users/{id}/manager`) · **Role:** OWNER/ADMIN |

**Test data:** Set Ravi's manager = Meena.

**Expected result:** Ravi appears under Meena in `/org-chart`; `GET
.../hierarchy/my-team` (as Meena) lists Ravi + downline count. **Guards:**
assigning a user as their own manager → `FH_SELF_MANAGER`; creating a cycle
(A→B→A) → `FH_CYCLE`.

**Actual / Status / Notes:**

---

## B. Route execution & visits (field app)

### TC-FS-010 — Start today's route → visits auto-created
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | field app / ERP `/field-sales/executions` (`POST .../executions/{id}/start`, `GET .../executions/me/today`) · **Role:** OPERATOR (Ravi) |

**Steps:** As Ravi, open today's route and **Start** it.

**Expected result:** Execution PLANNED → **IN_PROGRESS**; one **field visit** is
auto-created per customer on the route's beats (Sharma, Verma), in sequence
order.

**Actual / Status / Notes:**

---

### TC-FS-011 — Check-in (geofence flag, non-blocking)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | field app (`POST .../visits/{id}/check-in`) · **Role:** OPERATOR (Ravi) |

**Steps:** Check in at Sharma Traders with the phone's GPS.

**Expected result:** Visit marked checked-in. If the customer has stored coords,
`geoVerified` + `geoDistanceM` are set vs the `field_sales.geofence_radius_m`
(default 250 m) — **it flags, never blocks**. Out-of-radius → a warning snackbar
but the check-in still succeeds. No stored coords → geoVerified null.

**Actual / Status / Notes:**

---

### TC-FS-012 — Record order + collection at a visit
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | field app (`POST .../visits/{id}/record-order`, `.../record-collection`) · **Role:** OPERATOR |

**Test data:** Order ₹2,000; collection ₹500 cash.

**Expected result:** Order value + collection recorded on the visit; they roll up
into the execution + secondary-sales dashboard. Check out (`.../check-out`) closes
the visit.

**Actual / Status / Notes:**

---

### TC-FS-013 — Ownership guard on visit actions
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | API `.../visits/{id}/check-in` · **Role:** a **different** OPERATOR |

**Expected result:** A salesperson who is **not** the execution's assigned
salesperson calling any visit action (check-in/out, skip, record-order/collection)
is rejected **403** with `FS_NOT_ASSIGNED_SALESPERSON`. (Pass = the 403.)

**Actual / Status / Notes:**

---

### TC-FS-014 — Skip a visit + complete the execution
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | field app (`.../visits/{id}/skip`, `.../executions/{id}/complete`) · **Role:** OPERATOR |

**Expected result:** A visit can be **skipped** with a reason; after visiting/
skipping all, the execution can be **Completed** (IN_PROGRESS → COMPLETED). Only a
COMPLETED execution can start a day-close.

**Actual / Status / Notes:**

---

## C. Van stock

### TC-FS-020 — Load van from warehouse
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | ERP `/field-sales/vans` (`POST .../van-transfers/load`, `.../{id}/confirm-load`) · **Role:** OWNER/ADMIN |

**Test data:** Load 100 × Paracetamol onto Van MH-01-AB-1234.

**Expected result:** A LOAD transfer moves stock **out of the warehouse into the
van** (via InventoryService) once confirmed; `GET .../vans/{id}/stock` shows the
van balance. Confirm-load is the posting step.

**Actual / Status / Notes:**

---

### TC-FS-021 — Return van stock
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | ERP (`.../van-transfers/return`, `.../{id}/confirm-return`) · **Role:** OWNER/ADMIN |

**Expected result:** A RETURN moves unsold van stock back to the warehouse on
confirm; van balance decreases by the returned qty. Warehouse stock is restored.

**Actual / Status / Notes:**

---

## D. Day-close

### TC-FS-030 — Day-close cash reconciliation
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | ERP `/field-sales/day-close` (`POST .../day-close/initiate/{routeExecutionId}`, `.../{id}/submit`) · **Role:** OPERATOR then OWNER/ADMIN |
| **Preconditions** | A COMPLETED execution (TC-FS-014) |

**Test data:** opening ₹0, collections ₹500, expenses ₹50, deposited ₹450.

**Expected result:** Day-close initiated from the completed execution; cash
reconciliation computes **variance = opening + collections − expenses − deposited
= ₹0** (flags non-zero variance). Stock + visit summaries shown. **Submit** →
manager **Approve/Reject** (`.../{id}/approve|reject`, OWNER/ADMIN).

**Actual / Status / Notes:**

---

## E. Targets & incentives

### TC-FS-040 — Create a target + track achievement
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | ERP `/field-sales/targets` (`POST /targets`, `.../{id}/achievement`) · **Role:** OWNER/ADMIN |

**Test data:** Ravi, type **REVENUE**, target ₹1,00,000 for the month.

**Expected result:** Target created (types REVENUE/VOLUME/VISITS/COLLECTIONS/
NEW_CUSTOMERS). Achievement update computes **percentage** + **incentive amount**.
`GET /targets/me` (as Ravi) shows his targets.

**Actual / Status / Notes:**

---

## F. TA/DA allowances

### TC-FS-050 — Claim TA/DA (GPS-based)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | field app (`GET /allowance/me`, `POST /allowance/claim`) · **Role:** OPERATOR |
| **Preconditions** | Org set `field_sales.ta_per_km` + `da_per_day`; a day with GPS pings |

**Expected result:** TA = day's GPS-trail km (haversine) × `ta_per_km`; DA =
`da_per_day` on days with movement. **Claim** creates a real **expense** (Travel &
Conveyance **5240** / Cash **1010**, mode CASH) and stores the expense id.
Re-claiming the same day → `FS_ALLOWANCE_ALREADY_CLAIMED`; nothing to claim →
`FS_ALLOWANCE_NOTHING_TO_CLAIM`. TA/DA card is hidden until rates are configured.

**Actual / Status / Notes:**

---

### TC-FS-051 — Allowance modes (FLEXIBLE / GPS / MANUAL)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | ERP rate card / field app claim dialog (`field_sales.allowance_mode`) |

**Expected result:** **FLEXIBLE** (default) prefills GPS km, editable (e.g. deduct
personal detours). **GPS** ignores any requested km (strict). **MANUAL** requires
km (`FS_ALLOWANCE_KM_REQUIRED` if blank). When claimed km ≠ GPS km, the expense
description shows "X km claimed (GPS Y km)" for the approver.

**Actual / Status / Notes:**

---

## G. Samples

### TC-FS-060 — Issue / return + balance
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | ERP `/field-sales/samples` (`POST /samples/issue|return`, `GET /samples/balance/{id}`) · **Role:** OWNER/ADMIN |

**Test data:** Issue 50 sample strips to Ravi; he distributes 10 on visits;
return 5.

**Expected result:** Balance = **issued − returned − distributed** = 50 − 5 − 10 =
**35**. Distributed comes from visit product logs. A product **distributed but
never issued** shows a **negative** balance (an issue-register gap to fix). Ravi's
own stock via `/samples/balance/me`.

**Actual / Status / Notes:**

---

## H. Live tracking

### TC-FS-070 — Live locations + trail
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | ERP `/field-sales/live-tracking` (`GET .../locations/live`, `.../locations/trail/{executionId}`) · **Role:** OWNER/ADMIN |
| **Preconditions** | Field app pinging during an IN_PROGRESS execution |

**Expected result:** Live screen (30 s auto-refresh) lists the latest ping per
salesperson today; **stale (>15 min)** rows highlighted; open-in-Google-Maps
works. The **trail** bottom sheet shows the day's breadcrumb + total km
(haversine). Pings post via `POST /locations/ping` (batched); offline pings queue
and replay.

**Actual / Status / Notes:**

---

## I. MR reporting (pharma)

### TC-FS-080 — Tour plan (MTP) lifecycle
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | field app `Tour Plan` / ERP `/field-sales/mr-approvals` (`/api/v1/mr/tour-plans...`) · **Role:** OPERATOR then manager |

**Steps:** Ravi drafts a monthly tour plan with day-wise entries → **Submit**;
Meena (manager) **Approves**.

**Expected result:** DRAFT → SUBMITTED → APPROVED. **Guards:** owner-only edits in
DRAFT/REJECTED; entries must fall **in the plan month**; **empty-plan submit
blocked**; **self-approval blocked** (`MR_SELF_APPROVAL_FORBIDDEN`); a non-manager
approving → `MR_NOT_MANAGER`. Only OWNER/ADMIN **or the submitter's reporting
manager** (any ancestor) may approve.

**Actual / Status / Notes:**

---

### TC-FS-081 — DCR (Daily Report) build + submit + approve
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | field app `Daily Report` / ERP MR approvals (`/api/v1/mr/dcr/build|submit`, `.../dcr/{id}/approve`) |

**Expected result:** `dcr/build` create-or-refreshes a **DRAFT** from the day's
visits — doctor/chemist split (via `contact.medicalCategory`), POB = Σ order
value, samples from product logs. **Submit**: work type **FIELD_WORK needs ≥1
visit**; LEAVE/MEETING/OFFICE don't. Manager approve/reject mirrors day-close;
pending lists scope to the manager's **downline** for non-admins.

**Actual / Status / Notes:**

---

### TC-FS-082 — Detailing + e-detailing aids on a visit
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | field app visit → Detail / Aids (`PUT .../visits/{id}/products`, `.../visits/{id}/detail-aids`) |

**Expected result:** Products detailed + samples + gifts logged per visit
(replace-style, post-check-in only). **Detail aids** (URL-hosted PDF/image/video/
link, managed at ERP `/field-sales/detail-aids`) can be opened + marked shown;
usage counts increment. Owner-only, aids org-validated.

**Actual / Status / Notes:**

---

## J. RCPA (Retail Chemist Prescription Audit)

### TC-FS-090 — Record RCPA + share report
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | ERP `/field-sales/rcpa` (`POST /api/v1/mr/rcpa`, `GET .../reports/share`) · **Role:** OPERATOR/ADMIN |

**Test data:** At a chemist, our brand qty 10 (₹150), competitor "XYZ" qty 6 (₹90).

**Expected result:** Lines recorded with `brand_type` **OWN/COMPETITOR**
(competitor name kept only for COMPETITOR, our item id only for OWN). Share report
computes **ownShareByQty/ValuePct** (10/16 = 62.5% by qty). Competitor league
(`.../reports/competitors`) ranks competitor brands value-desc.

**Actual / Status / Notes:**

---

## K. Stockist secondary sales (SSS)

### TC-FS-100 — Stockist statement + derived closing
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | ERP `/field-sales/secondary-sales` (`POST /api/v1/field-sales/secondary-sales/statements`) · **Role:** OWNER/ADMIN/OPERATOR |

**Test data:** For a stockist, per product: opening 100, purchase 50, sales 120,
return 5.

**Expected result:** **Closing = opening + purchase − sales − return = 25**
(derived per line). DRAFT-only upsert (replace-style lines); editing a SUBMITTED
statement → `SSS_NOT_DRAFT`. `reports/secondary-sales` aggregates sales by product
across statements; `reports/stock-on-hand` sums closing lying at stockists.

**Actual / Status / Notes:**

---

## L. Coverage, frequency & team dashboard (downline-scoped)

### TC-FS-110 — Deviation + frequency compliance
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | ERP `/field-sales/coverage` (`GET /api/v1/mr/reports/deviation|frequency-compliance`) · **Role:** OWNER/ADMIN/OPERATOR-manager |

**Expected result:** **Deviation** compares tour-plan entries vs actual executions
day-by-day → AS_PLANNED / MISSED / UNPLANNED_WORK / WORKED_ON_NON_FIELD_DAY /
NO_PLAN (future days skipped). **Frequency compliance** compares each contact's
`visits_per_month` vs completed visits, worst-gaps-first.

**Actual / Status / Notes:**

---

### TC-FS-111 — Team dashboard is downline-scoped
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | ERP `/field-sales/coverage` (`GET /api/v1/mr/reports/team-dashboard`) · **Role:** manager (Meena), then a peer |

**Expected result:** A manager sees per-salesperson KPIs (route days, visits
planned/completed/%, orders, collections, GPS km, DCRs) for **their downline
only**; admins see all. A manager viewing a salesperson **not in their tree** →
`FH_NOT_IN_TEAM`. Confirms hierarchy scoping.

**Actual / Status / Notes:**

---

## M. Attendance (field app + ERP)

### TC-FS-120 — Punch in / out
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | field app Today card (`POST /api/v1/attendance/punch-in|punch-out`, `GET /me`) · **Role:** OPERATOR |

**Expected result:** GPS-stamped punch in sets on-duty; punch out closes the day
(one row/user/day). **Guards:** double punch-in → `ATT_ALREADY_PUNCHED_IN`; punch
out without in → `ATT_NOT_PUNCHED_IN`; double punch-out → `ATT_ALREADY_PUNCHED_OUT`.
Manager sees the team's punches by date (`GET /attendance/team`, OWNER/ADMIN).

**Actual / Status / Notes:**

---

### TC-FS-121 — Field leave apply + approve (self-approval blocked)
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | field app leave dialog / ERP attendance (`/api/v1/attendance/leave...`) |

**Expected result:** Apply leave (date range + type); overlapping leave →
`LEAVE_OVERLAPS`. Manager approves/rejects (`.../leave/{id}/approve|reject`). A
user **approving their own** leave is blocked (`LEAVE_SELF_APPROVAL_FORBIDDEN`).

**Actual / Status / Notes:**

---

## N. Role / negative summary

### TC-FS-130 — OPERATOR cannot touch masters/approvals
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | API various · **Role:** OPERATOR |

**Expected result:** An OPERATOR is **403** on masters + admin ops (beat/route/van
CRUD, customer assignment, van-transfers, day-close approve/reject, target create,
sample issue/return). They **can** do their own read-only, `/me`, visit actions,
dashboard, allowance/samples-me, DCR/tour-plan own lifecycle. (403 on the blocked
ops = pass.)

**Actual / Status / Notes:**

---

### TC-FS-131 — Module gate hides Field Sales for a plain retailer
| | |
|---|---|
| **Priority / Type** | P2 / Role |
| **Route** | sidebar · **Role:** OWNER of a **retailer** org (no override) |

**Expected result:** The **Field Sales** group is **not** in the sidebar for a
retailer (see doc 07). Enabling `FIELD_SALES` on the Modules screen reveals it.
Confirms the vertical gating.

**Actual / Status / Notes:**
