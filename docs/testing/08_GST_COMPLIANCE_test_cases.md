# 08 — GST & Tax Compliance

Manual UAT for the GST/compliance surface: GSTR-1, GSTR-3B, GSTR-2B
reconciliation + IMS, e-invoice (IRN), e-way bills, composition (CMP-08),
TDS (26Q), TCS (27EQ), and the compliance calendar. Format matches the rest of
the pack — see `README.md` §3.

> **Prerequisite:** most of these read from **posted** documents. Run the
> **Sales 01** and **Purchase 02** packs first so there are posted invoices,
> POS receipts, credit notes, and vendor bills in the period you test.
> All GST screens live in one place: **`/gst`** (GST dashboard, tabbed) plus the
> **ITC Risk** screen at `/gst/itc-risk`. Roles: OWNER / ADMIN / ACCOUNTANT.

> **Standard data reminder (README §3.2):** org home state = **Maharashtra (27)**.
> Sharma Traders (27) → **intra-state = CGST + SGST**; Verma Stores (09) →
> **inter-state = IGST**. Paracetamol/Cough HSN **3004 @ 5%**, Vitamin C HSN
> **2106 @ 18%**, Thermometer HSN **9018 @ 5%**.

---

## A. Setup for the period

### TC-GST-001 — Post a representative set of documents
| | |
|---|---|
| **Priority / Type** | P0 / Happy (setup) |
| **Route** | `/invoices`, `/pos`, `/bills` · **Role:** OWNER/ACCOUNTANT |
| **Preconditions** | Items + customers + vendors from packs 01/02 |

**Steps (all dated in the SAME month = your "return period"):**
1. **B2B intra** — Invoice to **Sharma Traders (27, has GSTIN)**: 100 × Paracetamol @ ₹15 → subtotal ₹1,500, CGST 2.5% + SGST 2.5% = ₹75. Send (post).
2. **B2B inter** — Invoice to **Verma Stores (09, has GSTIN)**: 100 × Cough Syrup @ ₹78 → ₹7,800, IGST 5% = ₹390. Send.
3. **B2CL** — Invoice to a **B2C inter-state** customer (state 09, **no GSTIN**) for **> ₹1,00,000** taxable. Send.
4. **B2CS** — a small POS cash sale (intra-state, no customer GSTIN).
5. **Credit note** — issue + approve a credit note against invoice (1).
6. **Vendor bill** — post a bill from MediSupply (27) for ₹10,000 + 5% GST.

**Expected result:** All six post cleanly (journals created). Note the invoice
numbers — you'll trace them into GSTR-1/3B below.

**Actual / Status / Notes:**

---

## B. GSTR-1 (outward)

### TC-GST-010 — GSTR-1 B2B table
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/gst` → **GSTR-1** tab · **Role:** ACCOUNTANT (`GET /api/v1/gst/gstr1?period=`) |

**Expected result:** **B2B** section lists invoices (1) and (2) grouped by buyer
GSTIN. (1) shows CGST ₹37.50 + SGST ₹37.50; (2) shows IGST ₹390. Taxable and tax
match the posted invoice to the rupee. The credit note (5) appears under **CDNR**
(against a GSTIN buyer), reducing that buyer's outward value.

**Actual / Status / Notes:**

---

### TC-GST-011 — GSTR-1 B2CL split (inter-state B2C > ₹1L)
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/gst` → GSTR-1 · **Role:** ACCOUNTANT |
| **Preconditions** | Invoice (3) from TC-GST-001 |

**Expected result:** Invoice (3) appears **invoice-level under B2CL** (Table 5 —
inter-state B2C over ₹1,00,000, per Notification 12/2024) and is **excluded from
B2CS**. A sub-₹1L inter-state B2C invoice would instead roll into **B2CS**.

**Actual / Status / Notes:**

---

### TC-GST-012 — GSTR-1 B2CS + HSN incl. POS receipts
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → GSTR-1 · **Role:** ACCOUNTANT |

**Expected result:** The **B2CS** section aggregates the small POS sale (4) by
rate + place-of-supply. The **HSN** summary lists 3004/2106/9018 with total qty,
taxable value and tax — and **POS receipts are included** (per-line rate resolved
from the HSN master, intra/inter from the receipt header). HSN totals reconcile
with B2B + B2C taxable.

**Actual / Status / Notes:**

---

### TC-GST-013 — GSTR-1 export
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/gst` → GSTR-1 → Export (`GET /api/v1/gst/gstr1/export?period=`) |

**Expected result:** A downloadable GSTR-1 file (JSON/CSV) for the period whose
totals match the on-screen tables. Opens without error.

**Actual / Status / Notes:**

---

## C. GSTR-3B (summary)

### TC-GST-020 — GSTR-3B outward + inward ITC
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/gst` → **GSTR-3B** tab (`GET /api/v1/gst/gstr3b?period=`) |

**Expected result:** **3.1 Outward** taxable + tax = Σ of all invoices + POS +
B2CL + B2CS for the period (net of credit notes), split IGST/CGST/SGST.
**4. Eligible ITC** reflects the vendor bill (6) input tax ₹500. The 3B outward
tax total ties to the GSTR-1 grand total (TC-GST-010/012). Export produces a file.

**Actual / Status / Notes:**

---

## D. GSTR-2B reconciliation + IMS

### TC-GST-030 — Upload GSTR-2B → match / mismatch / not-in-books
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/gst` → **GSTR-2B** tab → Upload 2B JSON (`POST /api/v1/gst/gstr2b/upload`) |
| **Preconditions** | Vendor bill (6) posted; a portal GSTR-2B JSON for the period |

**Test data:** A 2B JSON containing: (a) MediSupply's invoice matching bill (6)
exactly; (b) the same invoice with a **different value** (₹1 beyond tolerance);
(c) an invoice **not in your books**.

**Expected result:** Row (a) → **MATCHED**; (b) → **VALUE_MISMATCH**; (c) →
**NOT_IN_BOOKS**. A supplier who filed nothing for a bill you booked →
**supplier-not-filed (ITC at risk)**. Mismatches create **AI Inbox** suggestions
(the snackbar says "N issue(s) sent to your AI Inbox"). Matching tolerance = ₹1.

**Actual / Status / Notes:**

---

### TC-GST-031 — Re-upload the same 2B (dedupe)
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | `/gst` → GSTR-2B → Upload again |
| **Preconditions** | TC-GST-030 done |

**Expected result:** Re-uploading the same period's 2B **replaces** the entries
and **clears the prior PENDING** GSTR2B suggestions — the AI Inbox does **not**
accumulate duplicate items (already-reviewed rows are preserved).

**Actual / Status / Notes:**

---

### TC-GST-032 — Auto-fetch 2B via GSP
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/gst` → GSTR-2B → **Auto-fetch from GSP** (`POST /api/v1/gst/gstr2b/fetch?period=`) |

**Expected result:** With **no GSP configured**, a friendly "GSP not configured"
hint (code `GSP_NOT_CONFIGURED`) — no crash. With a GSP configured, it fetches +
reconciles through the same pipeline as upload. Empty response → `GST_2B_EMPTY`.

**Actual / Status / Notes:**

---

### TC-GST-033 — IMS Accept / Reject / Pending
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → **IMS** tab (`/api/v1/gst/ims/...`) |
| **Preconditions** | 2B uploaded (TC-GST-030) |

**Expected result:** Each inward 2B invoice can be set **Accept / Reject /
Pending**. The summary counts update on each action. (Under IMS, an invoice left
with no action is **deemed accepted** at portal cutoff — the tab explains the ITC
exposure of leaving rows pending.)

**Actual / Status / Notes:**

---

## E. E-Invoice (IRN)

### TC-GST-040 — B2B invoice auto-flagged for e-invoice
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → **E-Invoice** tab (`/api/v1/gst/einvoices`) · **Role:** ACCOUNTANT |
| **Preconditions** | `gst.einvoice_enabled = true`; a **B2B** invoice (buyer has GSTIN) posted |

**Expected result:** On posting a B2B invoice, it is auto-flagged **PENDING** in
the e-invoice list + an AI Inbox suggestion is raised. A **B2C** invoice is
**not** flagged. When disabled, nothing is flagged. Duplicate posts don't double-flag.

**Actual / Status / Notes:**

---

### TC-GST-041 — INV-01 JSON + record IRN + cancel
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → E-Invoice → per-invoice actions |

**Steps:** Open a PENDING e-invoice → **Download JSON** (`.../{id}/portal-json`)
→ (portal returns IRN) → **Record IRN/Ack/QR** (`.../{id}/record`) → later
**Cancel** (`.../{id}/cancel`).

**Expected result:** JSON is a valid **IRP INV-01 v1.1** shape (seller/buyer
GSTIN, item list, value block). After recording, status → **generated** with the
IRN/Ack no/signed QR shown. Cancel moves it to cancelled. **One-click GSP**
(`.../{id}/generate-gsp`) returns `GSP_NOT_CONFIGURED` when no GSP set (Download-
JSON remains the manual path).

**Actual / Status / Notes:**

---

## F. E-Way Bill

### TC-GST-050 — Invoice ≥ ₹50k auto-flagged for e-way bill
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → **E-Way Bill** tab (`/api/v1/gst/eway-bills`) |
| **Preconditions** | An invoice with taxable value **≥ `gst.eway_bill_threshold` (default ₹50,000)** posted |

**Expected result:** The invoice is auto-flagged **PENDING** for an e-way bill +
a HIGH AI Inbox suggestion. An invoice under the threshold is not flagged.

**Actual / Status / Notes:**

---

### TC-GST-051 — Vehicle-aggregate rule
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/gst` → E-Way Bill → **Check vehicle** (`/api/v1/gst/eway-bills/check-vehicle`) |

**Expected result:** Several **sub-₹50k** invoices in **one vehicle** whose
combined value crosses ₹50k are surfaced together (aggregate rule) — so a
consignment split across invoices still needs an EWB.

**Actual / Status / Notes:**

---

### TC-GST-052 — Portal JSON + record + validity + cancel
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/gst` → E-Way Bill → per-row actions |

**Expected result:** **Portal JSON** (`.../{id}/portal-json`) is the NIC EWB
shape with intra/inter split. **Record** (`.../{id}/record`) stores the EWB no +
sets **validity = 1 day per 200 km**. **Cancel** works. One-click GSP →
`GSP_NOT_CONFIGURED` when unset.

**Actual / Status / Notes:**

---

## G. Composition (CMP-08)

### TC-GST-060 — Enable composition + CMP-08
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → **Composition** tab (`/api/v1/gst/composition/settings|/cmp08`) |

**Steps:** Set `gst.composition_enabled = true`, rate `1%` (trader). Post a few
sales/POS in a quarter. Open CMP-08 for that FY + quarter.

**Expected result:** CMP-08 turnover = Σ posted invoice turnover + POS receipts;
tax = turnover × **1%**, split **CGST 0.5% + SGST 0.5%**. Restaurant rate 5%,
services 6% honoured when set. A bad quarter value is rejected.

**Actual / Status / Notes:**

---

### TC-GST-061 — Calendar swaps to CMP-08 when composition is on
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `/gst` → **Compliance Calendar** tab |

**Expected result:** With composition **on**, the calendar replaces GSTR-1/3B/2B
with **CMP-08 (18th after quarter)** + annual **GSTR-4 (Apr 30)**. Turning it off
restores the monthly GSTR-1/3B/2B deadlines.

**Actual / Status / Notes:**

---

## H. TDS (26Q) & TCS (27EQ)

### TC-GST-070 — TDS auto-deducted on a vendor bill
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/bills` (create) then `/gst` TDS / `GET /api/v1/tds/register` · **Role:** ACCOUNTANT |
| **Preconditions** | A vendor flagged TDS-applicable (section **194C**, rate 1/2%) |

**Test data:** Bill to a 194C contractor for **₹1,20,000** (crosses the ₹1L
aggregate / ₹30k single threshold).

**Expected result:** TDS is deducted on the **base (excl. GST)**; `balanceDue =
total − TDS`. The **26Q register** lists the vendor + section + amount paid + TDS.
A bill **below** the section threshold deducts nothing. FY window = Apr–Mar.

**Actual / Status / Notes:**

---

### TC-GST-071 — Form 26Q export (CSV + FVU)
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `GET /api/v1/tds/26q/csv` + `/26q/fvu` · **Role:** ACCOUNTANT (`@RequiresCountry("IN")`) |

**Expected result:** CSV = register (Sr/Vendor/PAN/Section/Amount/TDS/Bills/Rate%
+ TOTAL). FVU = `^`-delimited DD block with the **real per-row section code**
(194C→94C), deductee code (01 company / 02 non-company from PAN 4th char), and
`PANNOTAVBL` for blank PANs.

**Actual / Status / Notes:**

---

### TC-GST-072 — TCS 206C(1H) collected past ₹50L
| | |
|---|---|
| **Priority / Type** | P0 / Edge |
| **Route** | `/gst` → **TCS** tab / `GET /api/v1/tcs/register` · **Role:** ACCOUNTANT |
| **Preconditions** | `tax.tcs_enabled = true`, rate 0.1% |

**Steps:** To one buyer, post invoices until FY consideration (incl. GST) crosses
**₹50,00,000**, then one more invoice.

**Expected result:** No TCS until the buyer crosses ₹50L; on the crossing invoice
TCS is collected on the **excess only** and added to `tcsAmount / totalAmount /
balanceDue`; posting credits **TCS Payable (2031)**. The **27EQ** + register list
the buyer + collected TCS. Disabling the setting collects nothing.

**Actual / Status / Notes:**

---

## I. Compliance calendar & ITC risk

### TC-GST-080 — Compliance calendar statuses
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/gst` → **Compliance Calendar** tab (`/api/v1/gst/compliance-calendar`) |

**Expected result:** Deadlines listed with status **UPCOMING / DUE_SOON /
OVERDUE**: GSTR-1 (11th), GSTR-3B (20th), TDS (7th), 26Q (quarterly), a 2B-recon
nudge after the 14th, plus rows for **pending e-way bills** and **pending
e-invoices**. Statuses are correct relative to today's date.

**Actual / Status / Notes:**

---

### TC-GST-081 — ITC risk view
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/gst/itc-risk` (`/api/v1/gst/itc-risk`) |

**Expected result:** Surfaces ITC at risk — bills booked whose supplier hasn't
filed / 2B mismatch — with a rollup total. Reconciles with the NOT_IN_BOOKS /
supplier-not-filed rows from TC-GST-030.

**Actual / Status / Notes:**

---

## J. Negative / role

### TC-GST-090 — VIEWER cannot file/record
| | |
|---|---|
| **Priority / Type** | P1 / Role |
| **Route** | `/gst` · **Role:** VIEWER / OPERATOR |

**Expected result:** Read-only. Actions that write (record IRN/EWB, upload 2B,
change composition/TCS settings) are hidden or return **403**. Viewing the
returns is allowed. A 403 on a write is a **pass** for this negative case.

**Actual / Status / Notes:**

---

### TC-GST-091 — Country gate (non-IN org)
| | |
|---|---|
| **Priority / Type** | P2 / Negative |
| **Route** | TDS/26Q, statutory registers · **Role:** OWNER of a **UAE/AE** org |

**Expected result:** India-only endpoints (`@RequiresCountry("IN")` — 26Q/27EQ
FVU, statutory registers) are **not available** for a non-India org (403 /
hidden). Core GST returns are India-specific too. This confirms the compliance
pack doesn't leak into Gulf/Africa orgs.

**Actual / Status / Notes:**
