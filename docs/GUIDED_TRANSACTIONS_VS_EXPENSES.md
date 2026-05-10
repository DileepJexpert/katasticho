# Guided Transactions vs Expenses

## Purpose

Katasticho has two different ways to record money movement:

- **Expenses** for normal business expense documents and operational spending.
- **Create Transaction** for guided accounting events where the user should not manually choose debit and credit accounts.

These two screens can look similar to a shop owner because both may record money going out. Product behavior must keep them conceptually separate so accounting remains reliable.

## Simple Rule

Use **Expenses** when there is a normal business expense or receipt.

Use **Create Transaction** when there is no proper source document and the system needs to create an accounting adjustment.

## Expenses

The Expenses page is the right place for regular operating expenses.

Examples:

- Rent
- Electricity
- Internet
- Packaging
- Delivery charges
- Staff salary, until payroll exists
- Bank charges, until bank feed matching exists
- Miscellaneous business expenses

Expected behavior:

- User records the business expense in a familiar form.
- User may attach a receipt or supporting document.
- User can select vendor/contact where relevant.
- System posts the correct expense journal behind the scenes.
- The transaction remains understandable to a non-accountant.

For a kirana shop owner, salary paid from cash can be recorded from Expenses if payroll is not implemented yet.

## Create Transaction

Create Transaction is for accounting events that are not ordinary bills, receipts, invoices, POS sales, or expenses.

Examples:

- Owner withdrawal
- Loan received
- Loan EMI split between principal and interest
- Depreciation
- Opening balances during first-time setup
- Bank charge only as a fallback until bank feed/expense flow handles it cleanly

Expected behavior:

- User selects a guided transaction type.
- User fills business-language fields such as amount, reason, paid from, principal, interest.
- System previews the debit and credit impact.
- System posts through the journal API.
- User does not need to know double-entry accounting.

## Why Salary Can Appear in Both

Salary is a normal business expense, so the preferred long-term location is **Expenses** or a future Payroll module.

The Salary Payment guided transaction is only a fallback for very small shops that do not use payroll and may not maintain clean expense documents.

Long-term product direction:

- Keep salary in Expenses if the expense flow is strong enough.
- Remove or de-emphasize Salary Payment from Create Transaction later.
- Or make the guided Salary tile open a prefilled Expense instead of directly posting a journal.

## What Must Not Be Done as a Simple Guided Journal

Some events look like journal adjustments but require sub-ledger or inventory updates. These should not be implemented as GL-only guided journals.

### Bad Debt Write-Off

Do not post only:

```text
DR Bad Debt Expense
CR Accounts Receivable
```

This reduces the general ledger AR control account but does not reduce the customer balance, invoice balance, AR aging, or customer statement.

Correct design:

1. Select customer.
2. Show open invoices.
3. Select invoice or amount to write off.
4. Reduce invoice/customer outstanding.
5. Create the journal in the same transaction.
6. AR aging and AR control account must still reconcile.

### Stock Write-Off

Do not post only:

```text
DR Stock Write-off Expense
CR Inventory
```

This changes accounting value but does not reduce item quantity. The system would show stock physically available when accounting says it is written off.

Correct design:

1. Use inventory adjustment/write-off flow.
2. Reduce item quantity.
3. Reduce inventory value.
4. Post the accounting journal from that inventory transaction.

## Current Product Direction

Create Transaction should focus on non-document accounting events:

- Owner withdrawal
- Loan received
- Loan EMI
- Depreciation
- Opening balance

Expenses should own normal spending:

- Rent
- Salary
- Utilities
- Bank charges
- Office and shop expenses

This keeps the UI simple for owners while preserving accounting correctness.

## Future AI-First Direction

The guided form is the foundation. Later, the system should suggest these transactions automatically.

Examples:

- Bank statement contains a service charge, so system suggests a bank charge entry.
- A monthly rent pattern is missing, so system suggests recording rent.
- Loan EMI is detected from bank feed, so system suggests principal and interest split.
- Customer invoice is overdue for many months, so system suggests follow-up, reminder, or write-off workflow.

The owner should confirm business events. The system should handle accounting direction.
