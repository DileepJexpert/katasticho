# React Wave 5 Review Corrections

Date: 2026-09-05. Scope: the nine reported Antigravity migration findings and
directly related detail-page/form regressions. React and documentation only.
Java, migrations, backend tests and Flutter are unchanged.

## Validation

- Final full React suite: **357 tests passed in 90 files**, exit 0, using
  `node node_modules/vitest/vitest.mjs run --maxWorkers=2` (142.82 seconds).
  This includes the earlier Estimates tests without changing their source.
- Final `npm run lint`: passed with zero warnings, exit 0.
- Final `npm run build`: passed, including `tsc --noEmit`, exit 0.
  Vite reports the existing large main-bundle warning (about 2.15 MB minified).
- Default full-suite runs encountered varying async UI lookup timeouts in
  untouched payment-term/inventory/picklist tests. No assertions, application
  behaviour or global timeout settings were weakened to hide these failures.
  The final two-worker run passed without those failures. Default-worker
  reliability remains a test-runner resource consideration, not a hidden pass.
- No dev server, browser app, real transaction, Java test or Flutter test was
  run for this work. Mocked component/request tests are not live acceptance.
- No measured 100% coverage claim is made.
- `git diff --check` passed; protected-path diff for `src`, `flutter_app` and
  `pom.xml` is empty. This work is included in the 2026-09-05 Git checkpoint,
  separately from the earlier Estimates implementation.

## Manual Acceptance

Use a disposable development organisation with known test records. Compare
React results to Flutter against the same organisation and date range. Do not
use a client/production organisation for monthly posting tests: both run
endpoints affect every eligible record in the selected organisation/month.

| Area | Check | Expected result | State |
|---|---|---|---|
| Budgets `/budgets` | Open an existing FY with nonzero, zero and inactive-account lines; save unchanged, reload, then change one amount | All other amounts and notes remain; request uses `annualAmount`/`accountCode` | Pending |
| Budget variance | Compare posted actuals for the same April-March FY; fail the report request | Server report values agree; error is shown, not zero actuals | Pending |
| Amortization `/amortization` | Create with explicit recognition DR/CR accounts; try missing/same accounts | Invalid account choices block submission; no Cash/TDS fallback | Pending |
| Amortization detail | Open monthly run, verify scope, cancel, then confirm one test month | No request before confirmation; run summary and posted entries refresh | Pending |
| Fixed assets `/fixed-assets` | Register SLM and WDV assets; leave WDV rate blank once | Blank/invalid rate blocked; saved rate and preview match backend | Pending |
| Depreciation detail | Confirm monthly scope with two eligible assets; rerun same month | Org-wide summary, real opening/closing values, no duplicate period posting | Pending |
| Disposal detail | Select proceeds and gain/loss accounts, submit valid date/proceeds | Actual disposal fields sent; ledger/result checked in Flutter | Pending |
| Transport | Search a customer/vendor outside the first page; choose, change and clear | Server search returns the named record; correct ID submitted; no automatic first-record choice | Pending |
| Franchise `/franchise` | Create/edit/deactivate and open store detail; update stored policy | Real name/rate/fee fields persist; branch link retained on edit | Pending |
| Franchise unavailable operations | Open node detail and royalty history | No executable fake sync/override/royalty-post actions; limitation visible | Pending |
| Loyalty `/loyalty` | Select customer, review signed transactions and eligibility, clear customer | Correct wallet; no double negative; clear stays empty; no standalone wallet mutation | Pending |
| PDF settings | Load false flags, clear watermark/terms, save and reload; switch document during a slow request | Correct field values persist; old response does not overwrite current document | Pending |
| PDF output | Export each configured document using existing API/Flutter | Verify renderer actually honours each option; settings-save success alone is insufficient | Pending |
| AI training | Owner/Admin downloads JSONL; deny request once; test Operator | Raw NDJSON downloads; error visible; Operator cannot request/export training data | Pending |
| Role/tenant safety | Open a financial draft, switch organisation/role, then return | Draft/selections discarded, new tenant queries used; no stale submission | Pending |
| Responsive UI | Keyboard-only and narrow-screen review of changed forms/tables | Shared modal scrolling/focus, labelled fields and usable table overflow | Pending |

Monthly posting comparison must include the journal register and affected
account balances, not just a green status message. Registration of a fixed
asset is not acquisition journal posting. Amortization account choices are
for recurring recognition, not the original cash receipt/payment.

## Explicit Remaining Limits

- Franchise backend rejects royalty calculation/invoicing, catalog sync and
  branch-price operations until organisation-to-branch integrations exist.
  This migration does not alter or bypass those safeguards.
- Loyalty receipt-linked earn/redeem request types are corrected, but this
  wallet screen intentionally does not expose unsupported bonus adjustments or
  non-atomic sale-independent redemption. Safe checkout integration, reversals
  and idempotency need a separately scoped contract review.
- PDF options are persisted configuration; renderer effectiveness remains a
  live acceptance question, not a simulated client preview.
- This is not completion of all CA, UDF, platform, franchise hierarchy, loyalty
  tier or financial-depth requirements. Wider migration rows remain BUILDING.
- Existing Estimates work and tests belong to the earlier independent slice
  and are not overwritten by these corrections.
