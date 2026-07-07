# 05 — HR — Manual Test Cases

Covers the 9 Core HR modules:
**Employees + self-service profile → Leave → Attendance/regularization → Shifts →
Timesheets → Help desk → Documents → Analytics → Offboarding.**

> Read [`README.md`](README.md) first. HR is largely independent of the trade
> flow; you only need the org and a few users. Some cases need an employee that is
> **linked to an app user** (the `me()` self-service path) — create that link when
> setting up.

**Key business rules exercised here**
- Self-service `me` writes only **self-editable** fields; manager fields
  (designation/department/salary/statutory IDs/status) stay locked.
- Paid leave checks the balance; **insufficient balance is rejected**
  (`HR_LEAVE_INSUFFICIENT_BALANCE`). Unpaid leave feeds payroll **LOP**.
- Working days exclude **weekends + org holidays**.
- Overlapping leave is blocked; **self-approval is blocked**.
- Offboarding cannot complete until all clearance tasks are done.

---

## A. Employee master + self-service profile

### TC-HR-001 — Create an employee (admin)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/payroll/employees` (shared employee master) · **Role:** OWNER/ADMIN |

**Test data**
| Field | Value |
|-------|-------|
| Name | Anita Rao |
| Employee code | EMP001 |
| Designation | Sales Executive |
| Department | Sales |
| Date of joining | 2025-04-01 |
| Employment type | FULL_TIME |
| Linked app user | anita@test (create/link) |

**Steps:** New employee → fill Basic + Work Info → link an app user → save.

**Expected result:** Employee saves; appears in the list; the app-user link enables
her self-service profile (`/hr/my-profile`).

**Actual / Status / Notes:**

---

### TC-HR-002 — Deepened profile fields (personal/address/emergency)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/payroll/employees` (edit) · **Role:** ADMIN |

**Steps:** Edit Anita → open the Personal Info, Address, Emergency Contact
collapsible sections → fill DOB, gender, blood group, current + permanent address,
emergency contact → save.

**Expected result:** All fields persist and round-trip on reload.

**Actual / Status / Notes:**

---

### TC-HR-003 — Self-service: employee edits own profile
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/my-profile` · **Role:** anita@test (the linked user) |

**Steps:** Log in as Anita → open My Profile → edit personal email + emergency
contact → save.

**Expected result:** Self-editable fields update. Confirm the header + cards show
her data.

**Actual / Status / Notes:**

---

### TC-HR-004 — Self-service cannot change locked fields
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | `/hr/my-profile` (or API) · **Role:** anita@test |

**Steps:** Via the self-service update, attempt to change **designation / salary /
department / employment status**.

**Expected result:** Those fields are **ignored/locked** even if sent — only an
admin can change them. Verify by reloading: locked fields unchanged.

**Actual / Status / Notes:**

---

### TC-HR-005 — my-profile with no linked employee
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/hr/my-profile` · **Role:** a user with no linked Employee |

**Expected result:** A clear **`HR_EMPLOYEE_NOT_LINKED`** (404) guidance message,
not a blank screen or crash.

**Actual / Status / Notes:**

---

### TC-HR-006 — Family / education / experience subresources
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/hr/my-profile` · **Role:** anita@test |

**Steps:** Add a family member, an education record, and a past-experience record
→ then edit and remove one.

**Expected result:** Each subresource CRUD works; the record is stamped to the
correct employee; a user can only touch **their own** records (`HR_NOT_OWNER` for
someone else's).

**Actual / Status / Notes:**

---

## B. Leave management

### TC-HR-010 — Configure a leave type + apply + approve (happy path)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/hr/leave` · **Role:** ADMIN (config) → anita (apply) → ADMIN (approve) |

**Setup:** ADMIN creates leave type "Casual Leave" — paid, annual quota 12,
requires approval. This grants Anita a balance for the year.

**Steps:**
1. As Anita → Apply tab → Casual Leave, 2 working days, pick dates that are **not**
   weekends/holidays → submit.
2. As ADMIN → Approvals tab → approve.

**Expected result**
- Application is created **PENDING**; **working days = 2** (weekends/holidays
  excluded).
- On approval → **APPROVED**; Anita's Casual balance drops by 2 (12 → 10).

**Actual / Status / Notes:**

---

### TC-HR-011 — Insufficient balance is rejected
| | |
|---|---|
| **Priority / Type** | P0 / Negative |
| **Route** | `/hr/leave` · **Role:** anita |
| **Preconditions** | Casual balance = 10 |

**Steps:** Apply for **15** days of Casual Leave.

**Expected result:** Rejected with **`HR_LEAVE_INSUFFICIENT_BALANCE`**. No
application created; balance unchanged.

**Actual / Status / Notes:**

---

### TC-HR-012 — Working-days calc excludes weekends + holidays
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/hr/leave` · **Role:** ADMIN (add holiday) → anita (apply) |

**Setup:** ADMIN adds an org holiday in the middle of a Mon–Fri leave span.

**Steps:** Anita applies for that Mon–Fri span (5 calendar days) with the holiday
inside.

**Expected result:** **Working days = 4** (5 minus the 1 holiday; weekends already
excluded). The balance deduction uses working days, not calendar days.

**Actual / Status / Notes:**

---

### TC-HR-013 — Overlapping leave is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/hr/leave` · **Role:** anita |
| **Preconditions** | An approved leave already covers 10–12 of a month |

**Steps:** Apply for a new leave overlapping 11–13.

**Expected result:** Rejected (**`LEAVE_OVERLAPS`**). No double-booking.

**Actual / Status / Notes:**

---

### TC-HR-014 — Unpaid leave (feeds payroll LOP)
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/hr/leave` · **Role:** anita → ADMIN |
| **Preconditions** | An "Unpaid Leave" type (unpaid) exists |

**Steps:** Apply + approve 2 days of Unpaid Leave in the current month.

**Expected result:** Approved with no balance to deduct; the 2 days are recorded so
**payroll prorates earnings (LOP)** for that month (verified in TC-PAY-030).

**Actual / Status / Notes:**

---

### TC-HR-015 — Auto-approve leave type
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/hr/leave` · **Role:** ADMIN (config) → anita (apply) |
| **Preconditions** | A leave type with **requires approval = No** |

**Expected result:** Applying auto-approves immediately (no pending step); paid
balance deducts at apply time.

**Actual / Status / Notes:**

---

### TC-HR-016 — Cancel an approved leave restores balance
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/hr/leave` · **Role:** anita |

**Expected result:** Cancelling an approved paid leave **restores** the deducted
balance.

**Actual / Status / Notes:**

---

### TC-HR-017 — Self-approval is blocked
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/hr/leave` · **Role:** a manager applying for own leave |

**Expected result:** A manager cannot approve their **own** leave request; someone
else in the approval chain must.

**Actual / Status / Notes:**

---

## C. Attendance & regularization

### TC-HR-020 — Punch in / punch out
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/attendance` (or field app) · **Role:** anita |

**Steps:** Punch in, then later punch out.

**Expected result:** One attendance row for the day with in/out times + GPS. A
second punch-in the same day → **`ATT_ALREADY_PUNCHED_IN`**; punch-out without a
punch-in → **`ATT_NOT_PUNCHED_IN`**.

**Actual / Status / Notes:**

---

### TC-HR-021 — Regularization request + approval
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/attendance` · **Role:** anita → ADMIN |

**Steps:** Anita raises a regularization for a missed/incorrect punch → ADMIN
approves.

**Expected result:** On approval the **corrected punch is written** onto the
attendance record; the monthly summary updates.

**Actual / Status / Notes:**

---

### TC-HR-022 — Monthly attendance summary
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/attendance` (summary) · **Role:** ADMIN |

**Expected result:** For a month, the summary shows working days, present days,
approved leave (clipped to the month), holidays, weekends, absent, total hours,
and **payable days = present + paid leave**. The arithmetic ties out
(present + leave + holidays + weekends + absent = calendar days).

**Actual / Status / Notes:**

---

## D. Shifts

### TC-HR-030 — Create a shift + assign
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/hr/shifts` · **Role:** ADMIN |

**Test data:** shift "General" 09:00–18:00, weekly offs Sun.

**Steps:** Create the shift → assign it to Anita effective 2025-04-01.

**Expected result:** Shift + assignment save; `shiftOn(Anita, today)` resolves to
General.

**Actual / Status / Notes:**

---

### TC-HR-031 — Reassign shift auto-closes the prior one
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/hr/shifts` · **Role:** ADMIN |

**Steps:** Assign a new shift to Anita effective a later date.

**Expected result:** The prior open assignment is **auto-closed the day before**
the new one starts — no overlapping open assignments.

**Actual / Status / Notes:**

---

## E. Timesheets

### TC-HR-040 — Log time, submit, approve
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/timesheets` · **Role:** anita → ADMIN |

**Steps:** Anita logs daily project/task hours (billable flag) → submit a date
range → ADMIN approves.

**Expected result:** Entries go DRAFT → SUBMITTED → APPROVED; the summary shows
total / billable / non-billable hours + a by-project breakdown.

**Actual / Status / Notes:**

---

### TC-HR-041 — Hours 0–24 guard; owner-DRAFT-only edit
| | |
|---|---|
| **Priority / Type** | P1 / Validation |
| **Route** | `/hr/timesheets` · **Role:** anita |

**Steps:** Try to log **25** hours in a day; then try to edit a **submitted** entry.

**Expected result:** 25h rejected (0–24 guard). A submitted/approved entry can't be
edited by the owner (only DRAFTs are editable).

**Actual / Status / Notes:**

---

## F. Help desk

### TC-HR-050 — Raise a ticket + thread + resolve
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/helpdesk` · **Role:** anita → ADMIN |

**Steps:** Anita raises a ticket (category, subject, priority) → ADMIN assigns it
(→ IN_PROGRESS) → adds a comment → sets RESOLVED with a resolution note.

**Expected result:** Lifecycle OPEN → IN_PROGRESS → RESOLVED (→ CLOSED); the comment
thread shows both messages; the resolution is stored. Anita sees it under **My
Tickets**, ADMIN under **HR Inbox**.

**Actual / Status / Notes:**

---

## G. Documents

### TC-HR-060 — Upload a document
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/documents` · **Role:** anita (self) / ADMIN (on behalf) |

**Steps:** Upload a PDF (category "ID Proof", title, optional expiry) via the file
picker.

**Expected result:** The file is stored (real attachment); it lists under My
Documents; an ADMIN upload targets the right employee.

**Actual / Status / Notes:**

---

### TC-HR-061 — Expiring-documents watchlist
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/hr/documents` (Expiring tab) · **Role:** ADMIN |
| **Preconditions** | A document with an expiry within the window |

**Expected result:** The Expiring tab lists documents due for renewal within N
days. Deleting a document (owner-or-admin) removes it from the lists.

**Actual / Status / Notes:**

---

## H. Analytics

### TC-HR-070 — HR dashboard snapshot
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/hr/analytics` · **Role:** OWNER/ADMIN |

**Expected result:** The dashboard rolls up: headcount + by-department, on-leave
today, pending leaves, pending regularizations, pending timesheets, open tickets,
documents expiring in 30 days. The numbers match what you created in the cases
above.

**Actual / Status / Notes:**

---

## I. Offboarding

### TC-HR-080 — Initiate offboarding (seeds clearance tasks)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/offboarding` · **Role:** OWNER/ADMIN |

**Steps:** Initiate offboarding for an employee (resignation date, last working
day, reason).

**Expected result:** An offboarding record (INITIATED) is created with **5 default
clearance tasks** (IT/FINANCE/HR/ADMIN).

**Actual / Status / Notes:**

---

### TC-HR-081 — Cannot complete with pending tasks
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | `/hr/offboarding` · **Role:** ADMIN |

**Steps:** Try to **Complete** while some clearance tasks are unchecked.

**Expected result:** Blocked with **`OFFB_TASKS_PENDING`**. Complete only 4 of 5 →
still blocked.

**Actual / Status / Notes:**

---

### TC-HR-082 — Complete offboarding marks employee EXITED
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/hr/offboarding` · **Role:** ADMIN |

**Steps:** Complete all clearance tasks → record F&F amount → **Complete**.

**Expected result:** The linked payroll **Employee is marked EXITED** with the
date of exit; the offboarding record → COMPLETED. An exited employee is excluded
from new payroll runs (verify in TC-PAY-011).

**Actual / Status / Notes:**

---

### TC-HR-083 — Cancel an offboarding
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/hr/offboarding` · **Role:** OWNER |

**Expected result:** An INITIATED offboarding can be cancelled; the employee stays
ACTIVE. A COMPLETED one cannot be re-cancelled.

**Actual / Status / Notes:**

---

### Result summary (fill in)

| Section | Cases | Pass | Fail | Blocked |
|---------|-------|------|------|---------|
| A Employee + profile | 6 | | | |
| B Leave | 8 | | | |
| C Attendance | 3 | | | |
| D Shifts | 2 | | | |
| E Timesheets | 2 | | | |
| F Help desk | 1 | | | |
| G Documents | 2 | | | |
| H Analytics | 1 | | | |
| I Offboarding | 4 | | | |
| **Total** | **29** | | | |
