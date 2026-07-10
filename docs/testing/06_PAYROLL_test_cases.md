# 06 — Payroll — Manual Test Cases

Covers Indian SMB payroll end-to-end:
**Payroll settings → Employees + salary structure → Payroll run lifecycle
(DRAFT → CALCULATED → APPROVED → POSTED) → PF/ESI/PT/LWF/TDS → LOP → journal
posting → statutory payment.**

> Read [`README.md`](README.md) first. Needs the org + at least two employees.
> Money numbers below are exact for the given salary inputs — use them verbatim so
> the on-screen result can be checked to the paisa.

**Statutory rules exercised here (as implemented)**
- **Two-level gating:** every statutory deduction needs BOTH the org toggle
  (payroll settings, all default **off**) AND the **per-employee applicable
  flag** (pf/esi/pt/lwf on the employee form, all default **off**). Miss either
  and the line silently won't appear.
- **PF** = 12% of **Basic** (employee) + 12% employer — **no ₹15,000 wage
  ceiling** is applied.
- **ESI** = 0.75% (employee) / 3.25% (employer) of **Gross**, **only if Gross ≤
  ₹21,000**; computed at 2 dp HALF_UP (no ESIC whole-rupee round-up — ₹112.50
  stays ₹112.50).
- **PT** = state-wise **slab** (`pt_slab` master) resolved from the **org's GST
  state code** + gender + monthly gross; **₹0** for non-PT states or when the
  org has no state code. Maharashtra: ₹200/month (₹300 in February) for gross ≥
  ₹7,500 (male).
- **LWF** = state-wise `lwf_rule` master, deducted **only in the state's
  collection months** (MH: ₹25/₹75 in **June + December** only; ₹0 other months).
- **TDS** = **manual** — appears only if a TDS deduction line is added to the
  salary structure; the system does not auto-compute slab TDS from tax
  declarations at run time (declarations feed Form 12BB/24Q reporting only).
- **Lifecycle:** DRAFT → CALCULATED → APPROVED → POSTED (each step gated).
- **LOP:** each earning line prorates by `(periodDays − lopDays) / periodDays`
  (factor rounded to 6 dp, each line to 2 dp).

---

## A. Payroll settings

### TC-PAY-001 — Configure payroll settings
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/payroll/settings` · **Role:** OWNER/ADMIN |

**Steps:** Open payroll settings → confirm/enable PF, ESI, PT, LWF; set the pay
schedule (monthly).

**Expected result:** Settings save; the statutory components are available to
salary structures and payroll runs.

**Actual / Status / Notes:**

---

### TC-PAY-002 — Salary components exist
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/payroll/settings` · **Role:** ADMIN |

**Expected result:** Standard earning components (Basic, HRA, Conveyance, Special
Allowance) and deduction components (PF, ESI, PT, LWF, TDS) are present or can be
created.

**Actual / Status / Notes:**

---

## B. Employees & salary structure

### TC-PAY-010 — Employee A (ESI applicable) with a salary structure
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/payroll/employees` · **Role:** OWNER/ADMIN |

**Test data — Employee A**
| Field | Value |
|-------|-------|
| Name | Ravi Kumar |
| Code | EMP-A |
| Date of joining | 2025-04-01 |
| Basic | 10,000 |
| HRA | 4,000 |
| Conveyance | 1,000 |
| **Gross** | **15,000** (≤ ₹21,000 → ESI applies) |
| Pay type | SALARY |
| Statutory flags | **PF, ESI, PT, LWF all marked applicable** (default OFF) |

**Steps:** Create employee → **mark PF/ESI/PT/LWF applicable on the employee
form** → add salary structure with the components above → save.

**Expected result:** Employee + structure save; **gross earnings = ₹15,000**;
the structure is picked up by a payroll run. Remember: a statutory line appears
only when BOTH the org toggle (TC-PAY-001) and this employee flag are on.

**Actual / Status / Notes:**

---

### TC-PAY-011 — Employee B (ESI NOT applicable)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/payroll/employees` · **Role:** ADMIN |

**Test data — Employee B**
| Field | Value |
|-------|-------|
| Name | Sneha Iyer · Code EMP-B |
| Basic | 30,000 · HRA 12,000 · Special 8,000 |
| **Gross** | **50,000** (> ₹21,000 → **no ESI**) |
| Statutory flags | PF, ESI, PT, LWF marked applicable |

**Expected result:** Employee + structure save with gross ₹50,000. This employee
verifies the ESI threshold (no ESI line on her payslip even though her ESI flag
is on — the ₹21,000 gross gate wins).

**Actual / Status / Notes:**

---

### TC-PAY-012 — Exited employee excluded from new runs
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/payroll/runs` · **Role:** ADMIN |
| **Preconditions** | An employee marked EXITED (via TC-HR-082) before the run month |

**Expected result:** A new payroll run for a month **after** exit does **not**
include the exited employee. **Note:** runs include only currently-ACTIVE
employees — an arrears run for a past month will **NOT** include a now-EXITED
employee either (known limitation; verify exclusion only).

**Actual / Status / Notes:**

---

## C. Payroll run lifecycle

### TC-PAY-020 — Full run DRAFT → CALCULATED → APPROVED → POSTED
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/payroll/runs` · **Role:** OWNER/ADMIN → ACCOUNTANT |
| **Preconditions** | Employees A + B with structures **and statutory flags on**; org statutory toggles on (TC-PAY-001); **org GSTIN/state = Maharashtra (27)** — otherwise PT = ₹0; run month **not February** (MH PT is ₹300 in Feb) |

**Steps:**
1. Create a payroll run for the current month → status **DRAFT**.
2. **Calculate** → status **CALCULATED**; payslips generated.
3. **Approve** → **APPROVED**.
4. **Post** → **POSTED** (journal posts).

**Expected result — Employee A payslip (gross ₹15,000, MH org)**
| Line | Amount |
|------|--------|
| Gross earnings | ₹15,000.00 |
| PF (employee) 12% × 10,000 | ₹1,200.00 |
| ESI (employee) 0.75% × 15,000 | ₹112.50 (2 dp HALF_UP — the system does **not** apply the ESIC whole-rupee round-up) |
| PT (MH slab, gross ≥ ₹7,500) | ₹200.00 |
| LWF (employee) | ₹0.00 in most months — **₹25.00 only when the run month is an MH collection month (June or December)** |
| TDS | ₹0.00 (no TDS line configured — TDS is manual) |
| **Net pay** | **₹13,487.50** (normal months) · **₹13,462.50** (June/December, when LWF ₹25 deducts) |

**Employer contributions (not deducted from net):** PF ₹1,200 + ESI 3.25% ×
15,000 = ₹487.50 (+ LWF ₹75 in collection months).
**If PT/LWF show ₹0 unexpectedly:** check the org state code and the run month
before filing a bug — both are state/month-resolved, not flat defaults.

**On POST the journal:** **DR Salary Expense + Employer Contributions / CR Salary
Payable + PF Payable + ESI Payable + PT Payable + LWF Payable + TDS Payable.**
Σ debits = Σ credits.

**Actual / Status / Notes:**

---

### TC-PAY-021 — Employee B payslip has no ESI
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/payroll/runs` (payslip viewer) · **Role:** ADMIN |
| **Preconditions** | TC-PAY-020 includes Employee B |

**Expected result — Employee B (gross ₹50,000)**
- **No ESI line** (gross > ₹21,000).
- PF (employee) = 12% × 30,000 = **₹3,600** — the system applies **no ₹15,000
  EPF wage ceiling**; employer PF also ₹3,600.
- PT ₹200 (MH org, non-February); LWF only in Jun/Dec.
- Net (normal months) = 50,000 − 3,600 − 200 = **₹46,200.00**.

**Actual / Status / Notes:**

---

### TC-PAY-022 — Cannot approve a DRAFT (must calculate first)
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/payroll/runs` · **Role:** ADMIN |

**Steps:** On a fresh DRAFT run, try **Approve** without calculating.

**Expected result:** Blocked — the lifecycle enforces DRAFT → CALCULATED before
APPROVED. Same for Post before Approve.

**Actual / Status / Notes:**

---

### TC-PAY-023 — Cannot post an already-posted run twice
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/payroll/runs` · **Role:** ACCOUNTANT |
| **Preconditions** | TC-PAY-020 (a POSTED run) |

**Expected result:** Re-posting is blocked; the journal is not duplicated.

**Actual / Status / Notes:**

---

### TC-PAY-024 — Recompute after editing a structure (cancel + new run)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/payroll/runs` · **Role:** ADMIN |

**Steps:** On a CALCULATED (not yet posted) run, change an employee's Basic →
try **Calculate** again on the same run → then Cancel + re-create.

**Expected result:** Calculate on a CALCULATED run is **blocked** with 400
**`PAYROLL_RUN_NOT_DRAFT`** ("Only DRAFT payroll runs can be calculated") —
there is no recalculate/reset-to-DRAFT endpoint. To recompute: **Cancel** the
run (allowed for DRAFT/CALCULATED) → create a **new run** for the same period →
Calculate — the new payslips reflect the new Basic. Once POSTED the run is
locked (`PAYROLL_RUN_POSTED_CANNOT_CANCEL` on cancel).

**Actual / Status / Notes:**

---

## D. LOP (loss of pay)

### TC-PAY-030 — Unpaid leave prorates earnings
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/payroll/runs` · **Role:** ADMIN |
| **Preconditions** | Employee A linked to an app user with **2 approved UNPAID leave days** in the run month (TC-HR-014); month has 30 days |

**Steps:** Run + calculate payroll for that month.

**Expected result**
- **lopDays = 2** on the payslip.
- Earnings prorate **per line** with the LOP factor rounded to 6 dp (28/30 →
  0.933333), each line then HALF_UP to 2 dp: Basic 10,000 → ₹9,333.33, HRA 4,000
  → ₹3,733.33, Conveyance 1,000 → ₹933.33 → **gross = ₹13,999.99** (one paisa
  off gross × 28/30 = 14,000.00 — this is correct behaviour, not a bug).
- PF **is** computed on the prorated Basic: 9,333.33 × 12% = **₹1,120.00**.
- If ESI is enabled: 13,999.99 × 0.75% = **₹105.00**.
- Net pay drops accordingly.

**Actual / Status / Notes:**

---

### TC-PAY-031 — Paid leave = no LOP
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/payroll/runs` · **Role:** ADMIN |
| **Preconditions** | Employee with approved **paid** (Casual) leave, no unpaid |

**Expected result:** **lopDays = 0**; **full pay** — paid leave does not reduce
earnings.

**Actual / Status / Notes:**

---

### TC-PAY-032 — Leave spanning the month boundary counts only in-period days
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/payroll/runs` · **Role:** ADMIN |
| **Preconditions** | An unpaid leave that starts before / ends after the run month |

**Expected result:** Only the unpaid days **inside** the run period count toward
LOP for that month; the overhang counts in the adjacent month.

**Actual / Status / Notes:**

---

## E. Journal posting & statutory payment

### TC-PAY-040 — Posted run's journal is balanced & correct
| | |
|---|---|
| **Priority / Type** | P0 / Validation |
| **Route** | Day Book / `/reports/trial-balance` · **Role:** ACCOUNTANT |
| **Preconditions** | TC-PAY-020 (POSTED run) |

**Expected result:** The payroll journal debits **Salary Expense + employer
contribution expenses** and credits **Salary Payable + each statutory payable
(PF/ESI/PT/LWF/TDS)**. Σ Dr = Σ Cr; the Trial Balance still balances after
posting.

**Actual / Status / Notes:**

---

### TC-PAY-041 — Record salary payment
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/payroll/runs` (record payment) · **Role:** ACCOUNTANT |
| **Preconditions** | POSTED run with net-pay payable |

**Steps:** Record the net salary payment (via Bank).

**Expected result:** Journal **DR Salary Payable / CR Bank**; the payment entity
carries the journal id; salary-payable liability clears.

**Actual / Status / Notes:**

---

### TC-PAY-042 — Record a statutory payment (e.g. PF)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/payroll/runs` (statutory payment) · **Role:** ACCOUNTANT |

**Steps:** Record the PF (or ESI/PT/LWF/TDS) remittance.

**Expected result:** Journal **DR {PF/ESI/PT/LWF/TDS} Payable / CR Bank**; the
corresponding statutory-payable liability clears. Each statutory head can be paid
independently.

**Actual / Status / Notes:**

---

## F. Payslip & outputs

### TC-PAY-050 — Payslip viewer shows the full breakdown
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/payroll/runs` → payslip · **Role:** ADMIN |

**Expected result:** The payslip lists each earning + deduction line, gross, total
deductions, net pay, and (for OWNER/ADMIN) employer contributions. Numbers match
TC-PAY-020.

**Actual / Status / Notes:**

---

### TC-PAY-051 — Payroll is admin-only (no self-service payslips yet)
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/payroll/*` APIs · **Role:** an OPERATOR/VIEWER (non-admin employee user) |

**Expected result:** A non-admin user gets **403 on every `/api/v1/payroll`
endpoint** — they cannot view ANY payslip, including their own (self-service
payslip viewing is not yet implemented; the whole controller is gated
OWNER/ADMIN/ACCOUNTANT), and cannot create/calculate/approve/post runs. The only
payroll self-service today is **tax declarations** (`/payroll/tax-declaration` →
`/api/v1/payroll/tax-declarations/me`). If an employee-facing payslip is
expected, log it as a feature request, not a test failure.

**Actual / Status / Notes:**

---

### TC-PAY-052 — Production→payroll labour pay (hourly/piece-rate)
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/payroll/labor-pay-preview` · **Role:** ADMIN |
| **Preconditions** | An employee on an HOURLY or PIECE_RATE structure with completed manufacturing job cards |

**Expected result:** The preview computes labour pay from job-card hours × rate (or
pieces × rate); a payroll run adds a **LABOR_PAY** earning line and bumps gross. A
SALARY employee shows an info card — production data doesn't apply.

**Actual / Status / Notes:**

---

## G. India gratuity (optional, IN-only)

### TC-PAY-060 — Gratuity preview on exit
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/api/v1/payroll/gratuity/india/{employeeId}` or exit flow · **Role:** ACCOUNTANT |
| **Preconditions** | `payroll.india_gratuity_enabled = true`; an employee with ≥5 years service |

**Expected result:** Gratuity = (Basic+DA) × 15/26 × completed years (final year
≥6 months rounds up), ₹20L cap. An employee with **<5 years** → **nil** (no phantom
journal). Monthly accrual posts **DR Gratuity Expense (5130) / CR Gratuity
Provision (2080)**, idempotent per period.

**Actual / Status / Notes:**

---

### Result summary (fill in)

| Section | Cases | Pass | Fail | Blocked |
|---------|-------|------|------|---------|
| A Settings | 2 | | | |
| B Employees/structure | 3 | | | |
| C Run lifecycle | 5 | | | |
| D LOP | 3 | | | |
| E Journal/statutory | 3 | | | |
| F Payslip/outputs | 3 | | | |
| G Gratuity | 1 | | | |
| **Total** | **20** | | | |
