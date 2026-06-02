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
- Customer Indent is removed; Sales Order with backorder is the customer demand flow.
- AR payment approval is being introduced in phases. Phase 1 added payment lifecycle status and a single `postPayment()` accounting gate. Phase 2 reuses existing workflow definitions for `PAYMENT`; matching payments move to `PENDING_APPROVAL`, approval posts them through `postPayment()`, and rejection voids them without accounting side effects.
- Payment approval frontend visibility is wired into existing screens: record-payment feedback, invoice Payments tab status chips, and Approval Inbox recognition for `PAYMENT` requests.
- Distributor dashboard first pass reuses existing dashboard providers: Sales Order alerts, dealer collections, supplier dues, branch rollups, low-stock, and expiry-risk widgets are surfaced on distributor/pharma-distributor dashboards without a new backend endpoint.
- Business policy settings are exposed in Settings -> Business Policies, backed by existing `org_settings`; no new policy storage layer is introduced.
- Sales Order creation uses the same customer/default price-list resolver as Invoice creation, so distributor quotes/orders reflect customer-specific rates before dispatch or billing.
- Purchase Order does not post stock. PO action starts receiving by opening a draft Goods Receipt; only Goods Receipt detail `Receive Stock` posts inventory movement.
- Sales Order does not post stock. Confirmed Sales Order starts dispatch by opening a draft Delivery Challan; only Delivery Challan detail `Dispatch` posts stock movement.
- Delivery Challan does not post accounting. Dispatched or delivered challans create invoices through the existing Sales Order `convert-to-invoice` path; invoice posting updates AR/accounting and must skip duplicate stock movement.
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

Pricing implementation plan:
1. Keep price lists and schemes inside the existing pricing module.
2. Apply price-list resolution at Sales Order creation and Invoice creation.
3. Next hardening task: prevent SO-to-invoice conversion from re-pricing locked Sales Order rates if a price list changes after order booking.

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
