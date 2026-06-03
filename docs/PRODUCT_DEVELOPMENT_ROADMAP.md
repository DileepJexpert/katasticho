# Katixo ERP Product Development Roadmap

## Product Direction

Katixo is a distributor-first ERP for Indian pharma, FMCG, and retail businesses. Retail and POS stay supported, but distributor workflows become the main product strength.

## Architecture Principles

- Keep the monolith, but keep domain boundaries clean.
- Prefer a policy/config layer before a generic rule engine.
- Reuse existing Sales Order, Purchase Order, GRN, Inventory, Accounting, Pricing, and POS flows.
- Avoid duplicate flows when an existing domain model already covers the use case.
- Make customer-specific behavior configurable before making it custom code.
- Keep changes small enough that one domain bug does not force large refactors in other domains.

## Current Phase

Phase 1: Core document state and approval workflow foundation is implemented across backend and first frontend screens.

Current active work: distributor workflow controls and credit-control visibility are being layered onto existing documents without creating duplicate business flows.

## Session Checkpoint - 2026-06-02

Code is pushed to remote `main` through dealer collection follow-ups.

Hold here for manual testing before new feature development. The next session should start with validation and hardening, not another feature:
1. Verify Sales Order credit approval, overdue controls, Credit Note approval, and payment approval.
2. Verify Sales Order scheme flow end-to-end through confirmation, Delivery Challan dispatch, Sales Invoice creation, and accounting.
3. Verify procurement flow from shortage planning to Purchase Order, draft Goods Receipt, batch/expiry/rack/cost entry, and stock receipt.
4. Fix any test-blocking issues found during those checks before starting distributor dashboard v2, field-sales, or manufacturing work.

## Resume Index - 2026-06-03

Current code is pushed to remote `main` through distributor flow hardening work.

Developed since the previous checkpoint:
1. Workflow context hints are implemented with `WorkflowHintResolver` and `KContextHint`.
2. Workflow hints are wired into Purchase Order, Goods Receipt create/detail, Sales Order detail, and Delivery Challan create/detail screens.
3. Purchase Order receiving flow is clarified: PO starts a draft Goods Receipt; Goods Receipt `Receive Stock` is the only stock posting step.
4. Sales Order dispatch flow is clarified: Sales Order starts a draft Delivery Challan; Delivery Challan `Dispatch` is the only stock deduction step; invoice creation remains the accounting step.
5. Item stock flow is clarified: Item master creation does not create stock movement; opening stock/GRN/adjustment flows are responsible for stock.
6. Stock summary now includes zero-stock inventory-tracked items so newly created stockable items are visible for planning.
7. POS/global shortcut contract is documented in `docs/how-to/KEYBOARD_SHORTCUTS.md` and centralized in Flutter via `KShortcuts`.

Current resume position:
- `RESUME-DIST-2026-06-03-02`
- Start with manual QA and hardening, not a new feature module.
- First validation target: procurement flow from Shortage -> Purchase Order -> draft Goods Receipt -> Receive Stock, including batch, expiry, rack, purchase cost, stock summary, item detail, and accounting side effects.
- Second validation target: Sales Order -> Delivery Challan dispatch -> Sales Invoice, including free scheme lines, stock deduction once, and invoice accounting.
- Third validation target: manual workflow approval QA for Sales Order credit/overdue, Credit Note, and Payment. Backend decision/posting side effects are covered by focused tests.

Still left from planned distributor-first work:
1. Manual QA and bug fixes for the full procurement and dispatch chains.
2. Distributor dashboard v2 only after the above flows are verified.
3. Field-sales/mobile workflows after distributor desktop workflows are stable.
4. Manufacturing workflows after distributor workflows are stable.
5. Bank reconciliation hardening remains deferred; do not let it block distributor validation.

Hardening added after this checkpoint:
1. GRN receive tests now assert backorder fulfilment notification runs once per unique received item.
2. Delivery Challan dispatch tests now assert selected batch id is carried into the stock movement.
3. POS search tests now assert rack code is returned for counter staff when an item has a rack location.
4. Sales invoice posting skips zero-value scheme/free revenue rows while still posting free-goods cost to COGS/inventory.
5. Sales Order partial invoicing after full shipment is covered so status remains `PARTIALLY_INVOICED` until all shipped quantity is billed.
6. Workflow approval hardening now covers Sales Order approval/rejection transitions, payment rejection without accounting or invoice side effects, and approved invoice-linked Credit Notes applying AR only after approval.
7. Distributor dashboard v2 frontend pass has started: distributor/pharma distributor now uses a dedicated operating layout, distributor action labels, SO/DC alerts first, and real expiry/low-stock KPI values instead of zero placeholders.

## Phase Roadmap

1. Cleanup and stabilize the current distributor/pharma baseline.
2. Add document state configuration and approval workflow foundation.
3. Add Distributor Policy Layer v1 using existing org settings.
4. Improve Sales Order for distributor operations.
5. Improve schemes, price lists, and customer-specific pricing.
6. Polish batch, rack, expiry, and FEFO behavior.
7. Add distributor dashboards and reports.
8. Add mobile and field-sales workflows.
9. Add manufacturing workflows later, after distributor workflows are stable.

## Active Decisions

- Do not build a full generic rule engine now.
- Use `org_settings` for the first policy layer.
- Credit policy v1 supports `WARN`, `BLOCK`, and `APPROVAL_REQUIRED`.
- Overdue invoice policy v1 supports `WARN`, `BLOCK`, and `APPROVAL_REQUIRED`, with `sales.overdue_grace_days` controlling how many grace days are allowed after invoice due date.
- Approval workflow is template-driven and role-based, with org-level admin APIs and Settings UI for activation, trigger JSON, and ordered approval steps.
- Credit Note approval is integrated before issue/posting. If an active `CREDIT_NOTE` workflow matches, the credit note moves to `PENDING_APPROVAL`; approval issues/posts it, rejection marks it `REJECTED`.
- Inactive contacts are blocked from Sales Order creation with `SO_CONTACT_INACTIVE`.
- Explicit customer sales hold is supported on Contact with `salesHold`, `salesHoldReason`, and `salesHoldUntil`. Active holds block Sales Order creation with `SO_CONTACT_SALES_HOLD`; expired holds are ignored.
- Customer risk reporting is exposed through AR credit reminders using existing contacts, invoices, credit limits, overdue invoices, and sales holds. It is read-only and introduces no posting or workflow side effects.
- Customer risk UI is reused inside the existing Credit Ledger screen with risk labels and a risk-only filter; no duplicate customer risk module/page is introduced.
- Dealer collection workflow is layered onto Credit Ledger. Follow-ups are stored as collection activity on reminder tracking, payment entry remains invoice-specific, and no follow-up action changes ledger, invoice balance, payment, stock, or journal state.
- Customer Indent is removed; Sales Order with backorder is the customer demand flow.
- AR payment approval is being introduced in phases. Phase 1 added payment lifecycle status and a single `postPayment()` accounting gate. Phase 2 reuses existing workflow definitions for `PAYMENT`; matching payments move to `PENDING_APPROVAL`, approval posts them through `postPayment()`, and rejection voids them without accounting side effects.
- Payment approval frontend visibility is wired into existing screens: record-payment feedback, invoice Payments tab status chips, and Approval Inbox recognition for `PAYMENT` requests.
- Distributor dashboard first pass reuses existing dashboard providers: Sales Order alerts, dealer collections, supplier dues, branch rollups, low-stock, and expiry-risk widgets are surfaced on distributor/pharma-distributor dashboards without a new backend endpoint.
- Business policy settings are exposed in Settings -> Business Policies, backed by existing `org_settings`; no new policy storage layer is introduced.
- Sales Order creation uses the same customer/default price-list resolver as Invoice creation, so distributor quotes/orders reflect customer-specific rates before dispatch or billing.
- Sales Order to Invoice conversion preserves booked Sales Order line rates and uses an explicit invoice creation path that skips price-list re-resolution.
- Sales Order scheme visibility v1 is complete. Linked Sales Order lines show applicable scheme hints using the existing scheme lookup.
- Sales Order scheme application v2 is manual only. `PERCENT_DISCOUNT` schemes update the existing line discount percent; `BUY_X_GET_Y` schemes add an explicit zero-rate free line. There is still no automatic scheme application and no new backend scheme schema.
- Sales Order scheme apply policy v3 uses `sales.scheme_apply_mode = MANUAL | AUTO | DISABLED`. Default is `MANUAL`; Settings -> Business Policies exposes it. `AUTO` applies the first applicable scheme on the SO line; `DISABLED` hides SO scheme lookup/actions.
- Purchase Order does not post stock. PO action starts receiving by opening a draft Goods Receipt; only Goods Receipt detail `Receive Stock` posts inventory movement.
- Sales Order does not post stock. Confirmed Sales Order starts dispatch by opening a draft Delivery Challan; only Delivery Challan detail `Dispatch` posts stock movement.
- Delivery Challan does not post accounting. Dispatched or delivered challans create invoices through the existing Sales Order `convert-to-invoice` path; invoice posting updates AR/accounting and must skip duplicate stock movement.
- Sales Order scheme free lines are allowed to invoice as zero-value lines only through the Sales Order invoice path. Normal invoice creation still rejects zero-value lines. Free goods stock is deducted on Delivery Challan dispatch and invoice posting skips stock movement.
- Distributor capability should extend existing flows, not fork them.
- Workflow must be org-configurable. No customer-specific code branches.

## Do Not Rebuild

- Sales Order
- GRN / Stock Receipt
- Item master
- POS search
- Existing feature flag and module access services
- Existing pricing and scheme foundation

## Reference Plans

- Workflow context hints: `docs/WORKFLOW_CONTEXT_HINTS_PLAN.md`
- Future partner network/B2B ordering module: `docs/PARTNER_NETWORK_MODULE_PLAN.md`

## Next Implementation Task

Manual QA for workflow v1:
1. Open Settings -> Workflows.
2. Enable Sales Order Credit Approval.
3. Keep trigger JSON as `credit.exposureAmount > credit.creditLimit`.
4. Set approval step 1 to `OWNER` or `ADMIN` and save.
5. Create a customer with a credit limit.
6. Create a Sales Order above that limit.
7. Confirm the order appears as `PENDING_APPROVAL`.
8. Open Settings -> Approval Inbox and approve or reject it.
9. Confirm approved orders return to `DRAFT` and can then be confirmed.

Next implementation task:
- Test Sales Order overdue invoice controls manually:
  1. Create or use a customer with one outstanding invoice past due date.
  2. Keep `sales.overdue_policy=WARN` and create a Sales Order; it should be created with a system warning comment.
  3. Enable `SALES_ORDER_OVERDUE_APPROVAL` from Settings -> Workflows and create another order; it should go to `PENDING_APPROVAL`.
  4. Disable the workflow, set `sales.overdue_policy=BLOCK`, and retry; backend should reject with `SO_OVERDUE_INVOICES`.
- Test Credit Note approval manually:
  1. Open Settings -> Workflows.
  2. Enable `CREDIT_NOTE_RETURN_APPROVAL`.
  3. Keep trigger JSON as `creditNote.totalAmount >= 5000`, or adjust threshold for demo.
  4. Create a credit note above threshold.
  5. Click Issue; it should move to `PENDING_APPROVAL` instead of posting.
  6. Approve from Settings -> Approval Inbox.
  7. Confirm the credit note becomes `ISSUED` or `APPLIED` and journal/stock effects happen after approval.
- Next distributor candidates: payment collection exception approval, distributor dashboard summaries, then stock adjustment approval only after a draft adjustment document exists.

Payment lifecycle implementation plan:
1. Add payment status fields to the existing `payment` table.
2. Reuse existing `PaymentService.recordPayment()` for the public API.
3. Save new payments as `DRAFT`, then immediately call `postPayment()` for normal payments.
4. Make `postPayment()` the only method allowed to post the journal, update invoice balance, and mark payment `POSTED`.
5. Keep bank reconciliation behavior unchanged in this phase because it still calls `recordPayment()`.
6. Payment approval reuses the existing workflow engine with inactive default templates for high-value and backdated payments.
7. Bank reconciliation state changes remain deferred; current bank reconciliation still calls `recordPayment()`.
8. Frontend payment approval visibility is complete in existing screens; do not create a duplicate payment approval module.

Distributor dashboard implementation plan:
1. Reuse existing dashboard APIs before adding new endpoints.
2. Surface Sales Order alerts prominently for distributor/pharma distributor.
3. Surface expiry risk prominently for pharma distributor.
4. Add new backend summary endpoints only when an existing widget cannot express the operating question.

Dealer collection implementation plan:
1. Reuse Credit Ledger and AR risk APIs instead of creating a duplicate dealer module.
2. Track follow-up status (`TO_CALL`, `VISITED`, `PROMISED`, `DISPUTED`), promise-to-pay date, and notes as collection activity.
3. Show latest follow-up compactly in Credit Ledger.
4. Record payments from invoice rows only, using the existing invoice payment posting path.
5. Follow-ups must never mutate invoices, payments, journals, or stock.

Pricing implementation plan:
1. Keep price lists and schemes inside the existing pricing module.
2. Apply price-list resolution at Sales Order creation and Invoice creation.
3. Preserve Sales Order rates during SO-to-invoice conversion, even if a price list changes after order booking.
4. Sales Order scheme visibility v1 is complete.
5. Sales Order manual scheme application v2 is complete:
   - percent schemes fill the existing discount percent field;
   - buy/get schemes add explicit zero-rate free lines;
   - stale linked free lines are removed when the paid line item or quantity changes.
6. Sales Order scheme apply policy v3 is complete:
   - `MANUAL` keeps the compact `Apply` action;
   - `AUTO` applies the first applicable scheme once per paid line;
   - `DISABLED` suppresses SO scheme lookup and actions.
7. Sales Order scheme safety tests are complete for percent discount preservation, zero-rate free line invoicing, paid/free stock deduction at Delivery Challan dispatch, and invoice stock-skip behavior.
8. Next hardening task: manually test SO scheme mode end-to-end through confirmation, delivery challan, invoice, and accounting in the running app.

Procurement flow decision:
1. Purchase Order button label is `Create Goods Receipt`.
2. That action opens GRN creation, prefilled from PO supplier, pending quantities, and expected unit prices.
3. GRN is saved as `DRAFT` for quantity, batch, expiry, rack, and cost verification.
4. GRN detail `Receive Stock` is the only stock posting action.

Sales dispatch flow decision:
1. Sales Order button label is `Create Delivery Challan` after confirmation.
2. That action opens Delivery Challan creation prefilled from the Sales Order.
3. Delivery Challan is saved as `DRAFT` for shipped quantity and transport verification.
4. Delivery Challan detail `Dispatch` is the only customer dispatch stock posting action.
5. After dispatch or delivery, Delivery Challan detail can create a Sales Invoice from the linked Sales Order using the challan's SO-line quantities.
6. Sales Invoice creation/posting remains the receivable/accounting step and must not deduct stock again for Sales Order invoices.
