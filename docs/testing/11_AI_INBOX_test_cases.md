# 11 — AI Inbox & AI-first Entry

Manual UAT for the AI decision layer: the AI Inbox (accept/reject/modify
suggestions), AI-first document drafting (bill / GRN / conversational journal),
natural-language query, proactive + rule agents, and AI settings. Format matches
the rest of the pack — see `README.md` §3.

> **Safety invariant (verify throughout):** AI **never** directly posts a
> journal, moves stock, or files GST. Everything is a **DRAFT / suggestion** the
> user must approve — approve routes through the same services as manual entry,
> reject discards. The AI Inbox lives at **`/ai-chat`** (Inbox + Assistant tabs);
> settings at **`/settings/ai`**. Roles: OWNER/ADMIN/ACCOUNTANT.

> **Module gate:** `AI_INBOX` / `canUseAiInbox` (on for every business by default).

---

## A. AI Inbox — review queue

### TC-AI-001 — Inbox lists suggestions with summary
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/ai-chat` → Inbox tab (`GET /api/v1/ai/suggestions`, `/suggestions/summary`) · **Role:** OWNER/ADMIN |
| **Preconditions** | Some suggestions exist (post an invoice/bill, or run TC-AI-030) |

**Expected result:** The inbox lists open suggestions (type, priority, payload
summary). The summary strip shows counts by type/priority. Each row offers
**Accept / Reject / Modify**.

**Actual / Status / Notes:**

---

### TC-AI-002 — Accept / reject / review a suggestion
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | inbox row (`POST /api/v1/ai/suggestions/{id}/review`, `.../{id}/approve|reject`) |

**Expected result:** **Accept** applies the suggested action **through the normal
service** (e.g. posts the drafted document) and closes the row. **Reject** closes
it with no side effect. A reviewed row leaves the open queue. Idempotent — the
same suggestion can't be actioned twice.

**Actual / Status / Notes:**

---

## B. AI-first bill drafting

### TC-AI-010 — Scan a bill → DRAFT purchase bill
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | AI scan / `POST /api/v1/ai/scan-bill` → `/api/v1/ai/bill-drafts` · **Role:** ACCOUNTANT |
| **Preconditions** | A vendor bill image/PDF |

**Expected result:** The scan extracts vendor + lines; a **DRAFT purchase_bill**
is created with vendor **matched-or-created**, each line matched to an **item
(GOODS)** or an **expense (SERVICE)**, and **HSN→GST** filled. A `DRAFT_BILL`
suggestion appears in the inbox. Nothing is posted yet.

**Actual / Status / Notes:**

---

### TC-AI-011 — Approve the bill draft (posts + learns)
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | inbox → approve (`POST /api/v1/ai/bill-drafts/{id}/approve`) |

**Expected result:** Approve **posts** the bill via `PurchaseBillService` (AP +
purchase-account journal, per Purchase pack 02) and **learns** an `ai_pattern`
(vendor + HSN → account) so the next similar bill drafts better. **Reject**
(`.../reject`) deletes the draft, no journal.

**Actual / Status / Notes:**

---

## C. GRN drafting

### TC-AI-020 — Scan a supplier invoice → DRAFT GRN
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `POST /api/v1/ai/scan-purchase-invoice` → `/api/v1/ai/grn-drafts` · **Role:** ACCOUNTANT/OPERATOR |

**Expected result:** A **DRAFT stock receipt (GRN)** is drafted from the scanned
invoice (items + qty + batch/expiry where present). Approve receives stock via
the normal GRN path (stock posts once, per Purchase pack); reject deletes.

**Actual / Status / Notes:**

---

## D. Conversational entry

### TC-AI-030 — Type a sentence → DRAFT journal
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/ai-chat` quick-entry (`POST /api/v1/ai/entry`) · **Role:** ACCOUNTANT |

**Test data:** `Paid 5000 to Sharma for rent by bank`.

**Expected result:** Parses direction (paid), amount (₹5,000), instrument
(bank→**1020**), party/category (rent expense), and drafts a **balanced DRAFT
journal** + a `DRAFT_ENTRY` suggestion. Amounts like `2k` / `1.5 lakh` parse.
An unparseable sentence returns **drafted=false** + a rephrase hint (no draft
created).

**Actual / Status / Notes:**

---

### TC-AI-031 — Approve / reject the drafted journal
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | inbox (`POST /api/v1/ai/entry/{id}/approve|reject`) |

**Expected result:** Approve **posts** the journal via `JournalService.postEntry`
(it appears in the journal register + trial balance). Reject deletes the draft;
nothing posts. Confirms the "draft, then approve" safety rule.

**Actual / Status / Notes:**

---

## E. Natural-language query (tenant-safe)

### TC-AI-040 — Ask a question in English
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/ai-chat` Assistant (`POST /api/v1/ai/query`) · **Role:** OWNER/ADMIN |

**Test data:** `top 5 customers by sales this month`.

**Expected result:** Returns a tabular answer built from a **SELECT** the AI
generated. The query is validated + rewritten to inject `org_id = <caller>` into
every select (`SqlValidator`) so it only reads **this org's** data.

**Actual / Status / Notes:**

---

### TC-AI-041 — NLP query cannot cross tenants or read credentials
| | |
|---|---|
| **Priority / Type** | P0 / Negative (security) |
| **Route** | `POST /api/v1/ai/query` · **Role:** OWNER |

**Test data:** Prompts that try to read another org's rows or a non-allowlisted
table (e.g. `app_user`, `api_key`, `refresh_token`) — incl. a UNION attempt.

**Expected result:** Rejected / returns nothing cross-tenant. Only allowlisted
platform-reference tables (drug/HSN/currency/…) are readable un-filtered; every
org-scoped table is `org_id`-pinned; credential tables are refused. A UNION/
subquery exfiltration attempt fails. (This is a **P0 security** case — a leak is
a Fail.)

**Actual / Status / Notes:**

---

## F. Proactive & rule agents

### TC-AI-050 — Run proactive agents
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | `/ai-chat` → Run checks (`POST /api/v1/ai/agents/proactive/run`) · **Role:** OWNER/ADMIN |
| **Preconditions** | An overdue customer + an open just-ended month |

**Expected result:** Drafts inbox suggestions: one **COLLECTIONS_REMINDER** per
overdue customer (with a ready-to-send WhatsApp draft, priority by days overdue);
a **MONTH_CLOSE_CHECKLIST** if the prior month's period is still OPEN; plus the
anomaly sweep. All **idempotent** — re-running doesn't pile up duplicates.

**Actual / Status / Notes:**

---

### TC-AI-051 — Rule-based anomaly / GST / inventory checks
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `POST /api/v1/ai/agents/rule-checks/run` · **Role:** OWNER/ADMIN |

**Expected result:** Runs rule-based agents (anomaly detection, GST compliance,
inventory intelligence) with **no external AI call** — flags surface as inbox
suggestions. Deterministic; re-run is idempotent.

**Actual / Status / Notes:**

---

## G. Settings

### TC-AI-060 — AI settings + model test
| | |
|---|---|
| **Priority / Type** | P2 / Happy |
| **Route** | `/settings/ai` (`GET/PUT /api/v1/settings/ai`, `/ai/test`, `/ai/models`) · **Role:** OWNER/ADMIN |

**Expected result:** Toggle AI on/off, pick a model/provider, and **Test** the
connection. With AI disabled, scan/query/agent features are inert (rule agents
still run — they need no model). API keys are write-only/masked on read.

**Actual / Status / Notes:**

---

### TC-AI-070 — Non-admin cannot change AI settings
| | |
|---|---|
| **Priority / Type** | P2 / Role |
| **Route** | `/settings/ai` · **Role:** OPERATOR / VIEWER |

**Expected result:** Read-only or hidden; a write returns **403**. Viewing the
inbox may be allowed per role, but posting an approval routes through the
underlying document's own role gate.

**Actual / Status / Notes:**
