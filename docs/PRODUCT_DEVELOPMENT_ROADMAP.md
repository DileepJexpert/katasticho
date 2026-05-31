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

Current active work: distributor workflow controls are being layered onto existing documents without creating duplicate business flows.

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
- Customer Indent is removed; Sales Order with backorder is the customer demand flow.
- Distributor capability should extend existing flows, not fork them.
- Workflow must be org-configurable. No customer-specific code branches.

## Do Not Rebuild

- Sales Order
- GRN / Stock Receipt
- Item master
- POS search
- Existing feature flag and module access services
- Existing pricing and scheme foundation

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
- Next distributor candidates: payment collection exception approval, customer risk dashboard, then stock adjustment approval only after a draft adjustment document exists.
