# Backend Phase 7 — Design Comparison Before Implementation

Before we write a line of backend code, here's how the incumbents (Zoho Books,
QuickBooks Online, Xero) solve each feature we need, and what that means for
Katasticho's architecture. The goal is to copy the best pattern for each
feature, not slavishly follow one vendor.

Our constraints up front:

- Backend is Spring Boot + JPA + Postgres.
- An `AuditService` + `AuditLog` entity already exists — just no HTTP endpoint.
- `openhtmltopdf-pdfbox v1.0.10` already in `pom.xml` (used by `ReceiptPdfService`).
- Flutter client now synthesizes audit events from existing data; any real API
  must be drop-in replaceable without widget changes.
- We're not multi-tenant SaaS yet, so we can skip sharing/permission complexity
  that Zoho/QBO need.

---

## 1. Audit Log / Activity Trail

### How the incumbents do it

| Vendor | API exposure | Data model | Notes |
|---|---|---|---|
| **Zoho Books** | No API (UI-only Activity Logs report) | Internal table with timestamp, user, module, action | Activity Trail is a compiled report, not a queryable feed. |
| **QuickBooks Online** | **Not exposed via API at all.** It's an internal compiled report. | Internal only | Developers repeatedly asked for it; Intuit refuses. |
| **Xero** | `GET /api.xro/2.0/{Entity}/{Guid}/history` (the gold standard) | `Changes[]`, `Details`, `User`, `DateUTC` | `PUT /history` appends a note. Automatic system events can't be edited — only notes can be added. Supports Contacts, Invoices, Bills, Items, Payments, BankTransactions, etc. |

### Recommendation

**Copy Xero's model exactly.** It's the cleanest: one endpoint per record, returns
a unified list that merges automatic system changes with manual user notes.

```
GET  /api/v1/audit/{entityType}/{entityId}  → List<AuditEntry>
POST /api/v1/audit/{entityType}/{entityId}/notes  {message}  → AuditEntry
```

`AuditEntry` shape:

```json
{
  "id": "uuid",
  "entityType": "INVOICE",
  "entityId": "uuid",
  "timestamp": "2026-04-18T10:30:00Z",
  "userId": "uuid",
  "userName": "Rajesh Kumar",
  "eventType": "CREATED | UPDATED | SENT | PAID | OVERDUE | CANCELLED | NOTE_ADDED",
  "summary": "Invoice created",
  "details": { "field": "status", "from": "DRAFT", "to": "SENT" },
  "isSystem": true
}
```

The Flutter `KActivityTimeline` already expects `KTimelineEvent` with
`isSystem`, `message`, `subtext`, `authorName`, `timestamp`, `color`, `icon` —
this maps 1:1 with a client-side transformer. When the API ships, only the
timeline provider changes; widgets stay identical.

**Backend implementation** (low risk, mostly wiring):

- Add `AuditController` exposing the two endpoints above.
- Extend `AuditService` to emit events on invoice sent, bill posted, payment
  applied, invoice cancelled — the state transitions we synthesize today.
- Add `AuditLog.eventType` enum (CREATED, UPDATED, SENT, PAID, …) and a JSONB
  `details` column for field-level diffs.
- Use Spring's `@EventListener` so service code just publishes
  `DomainEvent(invoice, SENT, userId)` — no audit calls scattered through
  business logic.

**What we skip**: field-by-field before/after snapshots for every update (too
much noise). Record only meaningful transitions + user notes.

---

## 2. PDF Generation for Invoices

### How the incumbents do it

| Vendor | Template engine | Customization | API shape |
|---|---|---|---|
| **Zoho Books** | **Flying Saucer** (HTML+CSS → PDF) | Full HTML/CSS editor, multiple templates per org, `template_id` per invoice | `GET /invoices/{id}?accept=application/pdf`, `GET /invoices/templates` |
| **QuickBooks Online** | Internal | Single org-level form style; no per-invoice override | `GET /invoice/{id}/pdf` — returns `application/pdf` |
| **Xero** | Internal | Org-level "branding themes" | `GET /Invoices/{id}` with `Accept: application/pdf` |

### Recommendation

**Copy Zoho's pattern** — we're already on the same engine family.
`openhtmltopdf-pdfbox` is the community successor to Flying Saucer and is
already in our `pom.xml` (used by `ReceiptPdfService`). No new dependency.

Design:

```
GET  /api/v1/invoices/{id}/pdf              → application/pdf (uses default template)
GET  /api/v1/invoices/{id}/pdf?templateId=X → application/pdf (override)
GET  /api/v1/pdf-templates?entityType=INVOICE → List<PdfTemplate>
POST /api/v1/pdf-templates   {name, entityType, html, css}
```

- `PdfTemplate` entity: `id, name, entityType, html, css, isDefault, createdBy`.
- `InvoicePdfService` renders: loads template → Thymeleaf substitution for
  `${invoice.*}` → openhtmltopdf to PDF bytes.
- Ship one sensible default template baked into resources; let users clone and
  customize in a later phase.
- The Flutter `invoice_pdf_screen.dart` already renders a client-side PDF for
  preview. Once the server endpoint ships, switch `PdfPreview.build` to
  download bytes from the server so what the customer sees = what's emailed.

**What we skip for now**: per-invoice template selection UI, multiple template
management. One default HTML template is enough to replace the client-side PDF.

---

## 3. Bulk Operations

### How the incumbents do it

| Vendor | Pattern | Max size | Per-item result | Notes |
|---|---|---|---|---|
| **QuickBooks Online** | `POST /batch` with heterogeneous `BatchItemRequest[]` | 30 ops | Yes, `BatchItemResponse[]` | Serial execution. 40 batch req/min limit. Can mix create+update+delete. |
| **Zoho Books** | No generic batch; some entity-specific bulk endpoints (bulk invoice delete, bulk mark as sent) | Per endpoint | Varies | |
| **Xero** | POST a collection (array of Invoices) to list endpoint; `?summarizeErrors=false` for per-item status | ~60 | Yes | Same URL for single-or-bulk. |

### Recommendation

**Zoho's pattern, not QBO's.** A generic batch endpoint is over-engineered for
our use cases. Our UX only ever bulk-acts on one entity type with one
operation (delete 5 invoices, cancel 3 bills). Per-entity verbs map better to
permissions and are easier to test.

```
POST /api/v1/invoices/bulk-cancel  {ids: [...], reason?: string}
POST /api/v1/bills/bulk-delete     {ids: [...]}
POST /api/v1/contacts/bulk-delete  {ids: [...]}
POST /api/v1/items/bulk-delete     {ids: [...]}
POST /api/v1/estimates/bulk-delete {ids: [...]}
```

Response shape (copy QBO's partial-success idea):

```json
{
  "successCount": 8,
  "failureCount": 2,
  "failures": [
    {"id": "uuid", "reason": "Cannot delete: invoice has payments"},
    {"id": "uuid", "reason": "Not found"}
  ]
}
```

- Synchronous (sizes always small — this is a list-screen action, not an ETL).
- Run each item in its own transaction so one failure doesn't roll back the
  batch.
- Cap at 50 ids per request — reject with 400 above that.
- Flutter already shows `"✓ 8 deleted, ✗ 2 failed"` SnackBars — drop-in fit.

**What we skip**: async job queue, progress polling, batch IDs. Premature.

---

## 4. Banking Module

### How the incumbents do it

| Vendor | API | Bank feeds | Reconciliation API |
|---|---|---|---|
| **Zoho Books** | Full `/bankaccounts` + `/banktransactions` CRUD, match endpoint, bulk categorize | Yes (provider integrations) | Yes, including AI-suggested matches |
| **QuickBooks Online** | Bank accounts as `Account.AccountType = Bank`, bank transactions as `Deposit`/`Purchase` | Yes | Reconciliation UI-only, not API |
| **Xero** | Bank Transactions API (spend/receive money) but **no import or reconciliation via API** — kept out on purpose for commercial reasons | Partner-only Bank Feeds API | No |

### Recommendation

**Zoho's model, phase-gated.** Banking is the largest net-new feature — don't
boil the ocean. Ship in three slices:

**Phase B1 — Manual ledger** (MVP, ship first):

```
BankAccount: id, name, bankName, accountNumber (masked), currency,
             accountType (SAVINGS|CURRENT|CREDIT_CARD), openingBalance,
             currentBalance, isActive

BankTransaction: id, bankAccountId, date, amount, type, status,
                 description, referenceNumber,
                 matchedEntityType (INVOICE|BILL|null),
                 matchedEntityId, categoryId, createdBy

Transaction types: DEPOSIT, WITHDRAWAL, TRANSFER_IN, TRANSFER_OUT,
                   PAYMENT_RECEIVED, PAYMENT_MADE, BANK_CHARGE, INTEREST
```

Endpoints: standard CRUD `/bank-accounts`, `/bank-transactions`, plus
`POST /bank-transactions/{id}/match` and `POST /bank-transactions/{id}/categorize`.

**Phase B2 — CSV/OFX import** (unblocks real use):

```
POST /api/v1/bank-accounts/{id}/import-statement
  multipart/form-data: file (.csv | .ofx)
  → {importedCount, duplicatesSkipped, errors}
```

- Parse client-side into `BankTransaction` rows with `status = UNCATEGORIZED`.
- Hash `(accountId + date + amount + description)` to dedupe re-imports.

**Phase B3 — Auto-match suggestions** (nice-to-have):

- Given an uncategorized deposit, rank open invoices by
  `|amount - tx.amount| + abs(dayDiff) * 10 + contactNameSimilarity`. Return
  top 3.
- Zoho's "AI-assisted" pitch is basically this plus confidence scoring. We
  don't need ML for v1.

**What we skip**: live bank feeds (requires regulated partnerships — TrueLayer,
Plaid India, etc.), PSD2, direct RBI integration. All are multi-month
integrations.

---

## 5. Saved Views (Server Sync)

### How the incumbents do it

| Vendor | Approach |
|---|---|
| **Zoho CRM** | Server-side `CustomView` entity with scope (`me` / `shared` / `everyone`) and criteria JSON. |
| **Zoho Books** | Similar but less documented. |
| **QuickBooks Online** | Not in API. |
| **Xero** | Not in API. |

### Recommendation

**Copy Zoho CRM's model, drop the sharing.** Currently views live in
`SharedPreferences` — device-local, lost on reinstall. A simple server entity
unlocks cross-device sync with no new UX.

```
SavedView: id, userId, entityType, name, filters (jsonb), createdAt

GET  /api/v1/saved-views?entityType=invoices  → List<SavedView>
POST /api/v1/saved-views  {entityType, name, filters}
DELETE /api/v1/saved-views/{id}
```

- Scope = always "me" for now (userId = current user, no sharing column).
- Flutter `SavedViewsNotifier` swaps its SharedPreferences backend for a
  repository call; the `SavedView` model already matches 1:1.
- Optional: keep SharedPreferences as a local cache + offline fallback.

**What we skip**: team-wide shared views, per-role default view, pinned views.
Add when there's a real user.

---

## 6. Email Send

### How the incumbents do it

| Vendor | Pattern |
|---|---|
| **Zoho Books** | `POST /invoices/{id}/email` with `to_mail_ids`, `subject`, `body`, `attachments`, `send_from_org_email_id`. Stored email templates per entity. |
| **QuickBooks Online** | Set `EmailStatus = NeedToSend` on invoice → QBO sends. Also `POST /invoice/{id}/send?sendTo={email}` for immediate send. |
| **Xero** | `POST /Invoices/{id}/Email` — no params; uses invoice's own saved template. |

### Recommendation

**Zoho's pattern** — it's the only one that gives the caller a preview/edit
step. QBO and Xero's "just send" flows feel like black boxes.

```
POST /api/v1/invoices/{id}/email
{
  "to": ["customer@example.com"],
  "cc": [],
  "bcc": [],
  "subject": "Invoice INV-00042 from Katasticho",
  "body": "<html>…</html>",
  "attachPdf": true,
  "templateId": null
}
→ 202 Accepted, {emailId, status: "QUEUED"}

GET  /api/v1/email-templates?entityType=INVOICE
POST /api/v1/email-templates
```

- Use Spring's `JavaMailSender` + SMTP config. No third-party dependency yet.
- Store each send as an `EmailLog` row (entityType, entityId, to, subject,
  sentAt, status) — this feeds **directly into the audit timeline** as a
  `SENT` event, closing the loop with Feature #1.
- Variable substitution: simple `{{invoice.number}}`, `{{contact.name}}` style.
  Don't bring in a full template engine yet.

**What we skip**: open tracking, click tracking, bounce handling, per-user SMTP
relay. All belong to a deliverability provider (SendGrid / SES) — add when
volume justifies it.

---

## Recommended Implementation Order

Suggest tackling in this sequence — each phase unlocks the next:

1. **Audit API** (1–2 days). Smallest scope, largest UX unlock. Swaps
   synthesized events for real ones and enables user-added notes.
2. **Invoice/Bill PDF API** (2–3 days). Server template becomes the source of
   truth for what customers see.
3. **Email Send API** (1–2 days). Depends on PDF (attaches it). Generates
   `SENT` audit events, which the audit API then surfaces.
4. **Bulk endpoints** (1 day). Pure wiring — backend changes small, frontend
   already sends the right shape.
5. **Saved Views sync** (1 day). Trivial once schema is in.
6. **Banking Phase B1** (3–5 days). Largest scope. Do last so it doesn't block
   everything else.

Explicitly deferred: live bank feeds, shared saved views, multi-template
management UI, email deliverability tracking.

---

## Open Questions Before We Start

1. **Audit detail granularity** — do we record every field change as a diff
   (noisy, Xero-style) or only named state transitions (concise)? Recommend
   named transitions for v1.
2. **PDF templates** — single baked-in default, or shippable as a migration
   seed row that users can clone? Recommend seed row for forward compat.
3. **Email sender identity** — single org-wide `from` address, or per-user
   `from` with reply-to org? Affects SMTP config and domain auth (SPF/DKIM).
4. **Banking currency** — single currency per account, or multi-currency at the
   transaction level? Recommend single — matches Zoho and simplifies
   reconciliation.
