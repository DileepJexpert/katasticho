# React Estimates and Quotations Acceptance

Date: 2026-09-05
Tracker: R-05 commercial pre-sales extension
Owner: Codex, outside Antigravity's 5A-5D implementation scope
Status: BUILDING. Source inspection and implementation are not runtime acceptance.

## Scope and Evidence

Existing routes remain `/estimates`, `/estimates/new`, `/estimates/:estimateId`.
Edit reuses a form on the existing detail route. No duplicate menu was added.

Read-only contract references:
- `src/main/java/com/katasticho/erp/estimate/controller/EstimateController.java`
- `src/main/java/com/katasticho/erp/estimate/dto/` (create/update/line/response)
- `src/main/java/com/katasticho/erp/estimate/service/EstimateService.java`
- `src/main/java/com/katasticho/erp/estimate/service/EstimatePdfService.java`
- `src/main/java/com/katasticho/erp/common/service/DocumentShareService.java`
- `src/main/java/com/katasticho/erp/common/service/DocumentEmailService.java`
- `src/main/java/com/katasticho/erp/common/controller/CommentController.java`
- `flutter_app/lib/features/estimates/` (reference only; defects not copied)

| Area | React source state | Acceptance still required |
|---|---|---|
| List | PagedResponse, 25/page, status OR customer filtering, labelled page-local keyword search | More than 25 records, inactive historical customer, empty/error/last-page states |
| Create | Actual line DTO, product and customer search, free-text services, currency/default, validity, notes/terms | Persisted read-back, mixed rates/discounts, search beyond first result page |
| Edit | DRAFT/SENT only, shared form, complete line replacement, no currency on PUT | Field retention, clear notes, expiry restriction, concurrent status change |
| Actions | Confirmed send/resend/accept/decline/delete with role gates and visible failures | Real backend roles, stale state, retry/repeated submissions, email result |
| Detail | Response field names, server totals/currency, no double discount, invoice link, timestamps | Display alongside Flutter/server results |
| Documents | Tenant/auth-aware PDF; deliberate WhatsApp draft opening using server message | Discounted PDF presentation, share-link access, recipient selection, delivery |
| Activity | Read-only paged comments/system timeline | Lifecycle events, long history, failures, tenant isolation |

Shared components/tokens only: 34px controls, 36px table rows, 32px compact rows,
existing typography/surface/border/radius tokens, FormCard/FormGrid/FormField,
EntityPicker, DataTable, Modal, Money and Quantity. No feature CSS was added.
Tables use the existing keyboard-accessible horizontal scroll wrapper; pickers
use bounded results and server search rather than loading an entire directory.
Runtime responsive layout has not been checked.

## Frozen Backend Blockers

1. **Conversion is rejected for valid customers.**
   `EstimateService.convertToInvoice` compares `List.of("CUSTOMER", "BOTH")`
   with `contact.getContactType()` (a ContactType enum), unlike
   `requireBuyerContact`, which compares the enum name. React shows a disabled
   conversion action and explains the blocker. Do not issue a separate invoice
   POST to fake estimate conversion. Fixing Java requires separate authorisation.
2. **Discounted PDF presentation is inconsistent.**
   `recalcTotals` stores subtotal after line discounts; `EstimatePdfService`
   prints that subtotal followed by another negative discount row, while the
   final total still uses the correct persisted amount. React's own summary
   labels the discount as already included and warns users to review the PDF.
   Do not approve external-document acceptance from the React total alone.
3. **External document currency is hard-coded to INR.**
   `EstimatePdfService.fmtCurr` and `DocumentShareService.formatAmount` prefix
   rupees. Email attaches that PDF. React retains saved currencies, but disables
   PDF/send/share for non-INR estimates rather than relabelling their amounts.
4. **Filter semantics do not combine.**
   With contactId present, the service ignores status; no search parameter exists.
   React resets the alternative filter and labels keyword search as current-page.
   Combined full-directory filters need a separately approved API change.
5. **Some update fields cannot be cleared.**
   Null expiry means unchanged. React permits changing a saved expiry but rejects
   clearing it. Currency is create-only. Empty note/reference/subject/terms
   strings are preserved on PUT so they can be cleared.

No backend files were changed. These limitations must not be marked fixed.

## Remaining Parity

- Bulk actions are not exposed by this slice. Their response type was corrected,
  but service bulk loops self-invoke transactional actions. Transaction/lazy-load,
  partial-success and email semantics need an independent review before exposure.
- Comment creation/deletion is not implemented here; existing comments and system
  events can be reviewed. Add/delete author rules and plain String request-body
  semantics require their own tests when that parity work is picked up.
- Sending marks SENT even when there is no email or delivery fails. The UI tells
  the user to inspect activity; an email attempt is not a recipient-delivery receipt.
- Public share-link authorization, expiry and rendering were not accepted. A
  generated URL/message is not evidence of secure public-document delivery.
- Concurrency and idempotency guarantees are backend responsibilities. Disabling
  pending UI controls does not establish protection against multiple clients.

## Deferred Manual Sequence

Use disposable test data; do not send quotations to real customers during QA.

1. Open Sales > Estimates & Quotations (`/estimates`). Confirm dense layout at
   desktop and narrow widths, focus visibility, horizontal table access and no
   first-page-only metrics presented as organisation totals.
2. With more than 25 estimates, visit page 2, select a customer by name/phone/GSTIN,
   and then select Sent. Confirm customer filtering resets status and status
   filtering clears customer, both returning to page 1. Keyword search is local.
3. Create a quote using a CUSTOMER/BOTH contact, one catalog item at quantity 10,
   rate 45, discount 10%, tax 18%, unit PCS. Expected preview and saved values:
   discount 45.00, subtotal after discount 405.00, tax 72.90, total 477.90.
   Check request keys `discountPct`, `taxRate`, `unit`; there must be no
   `discountPercentage`, `taxGroupId` or `batchId`.
4. Add a free-text service, a fractional quantity, and a zero-rate sample.
   Ensure blanks, invalid/negative values and percentages over 100 block saving.
   Check 1 x 10.075 rounds to 10.08 and mixed-line totals follow per-line rounding.
5. Edit the draft, clear notes, save and reload. Confirm unit/HSN/tax/discount
   survive and clearing an existing expiry is explicitly rejected. Repeat for
   SENT; accepted/invoiced estimates must not offer editing.
6. With a controlled test email, review the PDF first and acknowledge the open
   discount presentation issue. Send only after confirmation. Check the actual
   system comment for the email attempt outcome, then record acceptance/decline.
   Conversion must stay unavailable with the documented blocker.
7. Verify VIEWER cannot see write controls and OPERATOR cannot delete drafts.
   Exercise rejected requests and a status changed in another session; no fake
   success or automatic fallback action may occur.
8. Verify authenticated PDF access and errors. Prepare a WhatsApp message and
   review it without sending to a real person. Non-INR quotes must keep their
   currency while PDF/send/share are disabled with an explanation.
9. Review more than 20 activity entries, retry a failed history request, and
   switch organisations. No prior organisation quote data should be reused.
10. Independently verify no stock, journal or AR posting occurs from quotation
    create/edit/accept/decline. Existing backend behavior, not frontend assumptions,
    is the acceptance authority.

## Validation Record

- Source/contract inspection: performed.
- Regression tests: `estimate-form-model.test.ts`, `estimates-api.test.ts`,
  `estimates-pages.test.tsx`; executed in the final full React suite on
  2026-09-05: **357 tests passed across 90 files**, using two test workers.
- `git diff --check -- react_app/src/features/estimates`: passed (line-ending
  notices only). Protected backend/Flutter paths had no working-tree changes.
- ESLint and production build (including TypeScript): passed. The build retains
  its large-bundle warning. See the Wave 5 acceptance record for the full-suite
  command and default-worker timeout limitation.
- Browser, PDF rendering and live API acceptance: NOT RUN. React was not
  started; these remain deferred to the user's manual testing.
- This slice is included in the 2026-09-05 Git checkpoint separately from the
  Wave 5 corrections. No coverage percentage, production readiness or full
  parity is claimed.
