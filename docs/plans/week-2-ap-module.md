# Week 2: Purchase Bills + Vendor Payments + Vendor Credits

Phase 0 is complete. Branch entity exists. branchId is
on all Java entities. Dashboard shows real numbers.

Now build the AP (Accounts Payable) module.
This is the mirror of AR (Invoices/Payments).
Same patterns, opposite direction of money flow.

Read ZOHO_PARITY_ARCHITECTURE.md Sprint F12, F13, F14.

═══════════════════════════════════════════════
STEP 1: MIGRATION
═══════════════════════════════════════════════

Next migration file. Create these tables:

1. purchase_bill + purchase_bill_line
2. vendor_payment + vendor_payment_allocation
3. vendor_credit + vendor_credit_line + vendor_credit_application

(Full column definitions in ZOHO_PARITY_ARCHITECTURE.md)

Key points:
  - All tables have branch_id FK to branch
  - purchase_bill has vendor_bill_number
    (vendor's own invoice number — different from our bill_number)
  - vendor_payment_allocation is many-to-many:
    one payment can cover multiple bills
  - vendor_credit_application tracks which bills
    a credit was applied to

═══════════════════════════════════════════════
STEP 2: ENTITIES + REPOSITORIES
═══════════════════════════════════════════════

Package: com.katasticho.erp.ap

Entities with proper JPA mappings:
  PurchaseBill (with BillStatus enum)
  PurchaseBillLine
  VendorPayment (with PaymentMode enum)
  VendorPaymentAllocation
  VendorCredit (with CreditStatus enum)
  VendorCreditLine
  VendorCreditApplication

Repositories:
  PurchaseBillRepository:
    findByOrgIdAndStatus
    findByOrgIdAndContactId
    findByOrgIdAndBranchId
    findOverdueBills:
      WHERE due_date < CURRENT_DATE
      AND status IN ('OPEN','PARTIALLY_PAID')
    findByOrgIdAndBillDateBetween

  VendorPaymentRepository:
    findByOrgIdAndContactId
    findByOrgIdAndPaymentDateBetween

  VendorCreditRepository:
    findByOrgIdAndContactId
    findByOrgIdAndStatus('OPEN')

═══════════════════════════════════════════════
STEP 3: PURCHASE BILL SERVICE
═══════════════════════════════════════════════

PurchaseBillService:

create(CreatePurchaseBillRequest):
  - Validate contact.contactType = VENDOR or BOTH
  - Generate bill_number (BILL-YYYY-NNNN)
  - Calculate due_date = bill_date + payment_terms_days
  - Calculate line totals, subtotal, tax, total
  - Set balance_due = total, status = DRAFT
  - Auto-set branchId from user context or warehouse
  - Save — NO journal on draft

post(billId):
  1. Validate status = DRAFT
  2. Call postJournal():

     For EACH line:
       DR line.account_id                    line.amount

     DR GST Input Credit CGST              cgst_amount
     DR GST Input Credit SGST              sgst_amount
     (or IGST if place_of_supply != org state)

     If contact.tdsApplicable:
       CR TDS Payable (section)             tds_amount

     CR Accounts Payable                    total - tds_amount

  3. For each line with item_id + item.trackStock = true:
     inventoryService.recordMovement(
       type = PURCHASE,
       quantity = +line.quantity,
       unitCost = line.rate,
       referenceType = PURCHASE_BILL,
       referenceId = bill.id,
       branchId = bill.branchId
     )

  4. Update contact.outstandingAp += bill.balanceDue
  5. Set status = OPEN
  6. CommentService.addSystemComment(
       "BILL", bill.id, "Bill posted successfully"
     )

void(billId):
  1. Validate: no payments applied (balance_due = total)
  2. Reverse all stock movements for this bill
  3. Reverse journal via postJournal() with negated amounts
  4. contact.outstandingAp -= bill.balanceDue
  5. Set status = VOID
  6. CommentService.addSystemComment("Bill voided")

scheduledJob @Scheduled(cron = "0 0 1 * * *"):
  Find all OPEN or PARTIALLY_PAID bills
  where due_date < today
  Set status = OVERDUE
  Create notification for owner

═══════════════════════════════════════════════
STEP 4: VENDOR PAYMENT SERVICE
═══════════════════════════════════════════════

VendorPaymentService:

recordPayment(VendorPaymentRequest):
  Request:
    contactId, amount, paymentMode, paymentDate,
    paidThroughId, referenceNumber,
    allocations: [{billId, amountApplied}],
    tdsAmount (optional)

  Validate:
    SUM(allocations.amountApplied) <= amount
    Each bill.balanceDue >= allocation.amountApplied
    Contact exists and is VENDOR or BOTH

  1. Generate payment_number (VPAY-YYYY-NNNN)

  2. postJournal():
     DR Accounts Payable       total amount
     CR paidThroughId          amount - tdsAmount
     CR TDS Payable            tdsAmount (if > 0)

  3. For each allocation:
     Create VendorPaymentAllocation
     bill.amountPaid += amountApplied
     bill.balanceDue -= amountApplied
     if bill.balanceDue == 0: bill.status = PAID
     if bill.balanceDue > 0:  bill.status = PARTIALLY_PAID
     CommentService on bill:
       "Payment of ₹{amountApplied} applied"

  4. contact.outstandingAp -= amount

  5. Return payment with allocations

═══════════════════════════════════════════════
STEP 5: VENDOR CREDIT SERVICE
═══════════════════════════════════════════════

VendorCreditService:

post(creditId):
  postJournal():
    DR Accounts Payable      total
    CR Purchase Returns      subtotal
    CR GST Payable           tax (we're returning goods,
                             so reverse input credit)

applyToBill(creditId, billId, amount):
  Validate credit.balance >= amount
  Validate bill.balanceDue >= amount
  Create VendorCreditApplication
  credit.balance -= amount
  if credit.balance == 0: credit.status = APPLIED
  bill.balanceDue -= amount
  if bill.balanceDue == 0: bill.status = PAID

═══════════════════════════════════════════════
STEP 6: CONTROLLERS
═══════════════════════════════════════════════

PurchaseBillController → /api/v1/bills
  POST   /                create
  GET    /                list (status, contact, date, branch filter)
  GET    /{id}            detail with lines + payment history
  PUT    /{id}            update (DRAFT only)
  DELETE /{id}            soft delete (DRAFT only)
  POST   /{id}/post       post → journal + stock
  POST   /{id}/void       void → reverse
  GET    /{id}/payments   payments on this bill
  POST   /{id}/comments   add comment
  GET    /{id}/comments   list comments + history
  POST   /{id}/attachments upload file
  GET    /{id}/attachments list files

VendorPaymentController → /api/v1/vendor-payments
  POST   /               record payment
  GET    /               list (contact, date, mode filter)
  GET    /{id}           detail with allocations
  DELETE /{id}           delete if no allocations

VendorCreditController → /api/v1/vendor-credits
  POST   /               create
  GET    /               list
  GET    /{id}           detail
  POST   /{id}/post      post
  POST   /{id}/void      void
  POST   /{id}/apply     apply to bill

═══════════════════════════════════════════════
STEP 7: REPORTS
═══════════════════════════════════════════════

Add to ReportsController:

GET /api/v1/reports/ap-ageing
  Returns vendors with bills grouped by:
  Current | 1-30 days | 31-60 days | 61-90 days | 90+ days

  Query:
  SELECT c.display_name,
    SUM(CASE WHEN due_date >= today THEN balance_due END) as current,
    SUM(CASE WHEN due_date BETWEEN today-30 AND today-1
             THEN balance_due END) as days_1_30,
    SUM(CASE WHEN due_date BETWEEN today-60 AND today-31
             THEN balance_due END) as days_31_60,
    SUM(CASE WHEN due_date BETWEEN today-90 AND today-61
             THEN balance_due END) as days_61_90,
    SUM(CASE WHEN due_date < today-90
             THEN balance_due END) as days_90_plus,
    SUM(balance_due) as total
  FROM purchase_bill pb
  JOIN contact c ON pb.contact_id = c.id
  WHERE pb.org_id = ?
  AND pb.status IN ('OPEN','PARTIALLY_PAID','OVERDUE')
  GROUP BY c.id, c.display_name
  ORDER BY total DESC

GET /api/v1/reports/vendor-balance
  All vendors with outstanding_ap summary

Update P&L report to include expenses from posted bills.
P&L is now COMPLETE: Revenue - COGS - Expenses = Profit

═══════════════════════════════════════════════
STEP 8: FLUTTER
═══════════════════════════════════════════════

1. Bill List Screen (/bills):
   Filter chips: All | Draft | Open | Overdue | Paid
   Card shows: vendor name, bill no, total,
               due date, status (red if overdue)
   FAB: + New Bill

2. Create Bill Screen:
   Contact picker (VENDOR/BOTH only — filter by type)
   Vendor bill number field
   Bill date, payment terms → auto-calculates due date
   Line items (reuse invoice line component)
   Total section with GST breakdown
   [Save Draft] [Post Bill] buttons

3. Bill Detail Screen:
   Header: vendor, amounts, status badge, due date
   Tabs: Lines | Payments | Comments | Attachments
   Actions (based on status):
     DRAFT: [Post] [Edit] [Delete]
     OPEN/OVERDUE: [Record Payment] [Void] [Add Attachment]
     PAID: [View Only]

4. Record Vendor Payment Screen:
   Show all unpaid bills for selected vendor
   Checkbox + amount input per bill
   Payment mode selector (Cash/UPI/Bank/Cheque)
   Reference number
   Total amount auto-sum
   [Record Payment] button

5. AP Ageing Report Screen:
   Table: vendor × ageing buckets
   Color coded (red = older buckets)
   Total row

6. Update Dashboard:
   Add "AP Outstanding" to cash position widget
   Show "Bills Due This Week" count

7. Navigation:
   Add "Purchases" section to sidebar:
     Bills
     Vendor Payments
     Vendor Credits
     Purchase Orders (coming Week 3)

═══════════════════════════════════════════════
TESTS
═══════════════════════════════════════════════

1. Bill post creates correct journal
   (DR Purchase + DR GST Input Credit, CR AP)
2. Bill with items increases stock
3. Bill restricted to VENDOR/BOTH contacts only
4. Vendor payment reduces bill.balanceDue
5. Full payment: bill.status = PAID
6. Partial payment: bill.status = PARTIALLY_PAID
7. Void reverses journal and stock movements
8. Vendor credit applied to bill reduces balance
9. Overdue scheduler correctly updates status
10. AP Ageing report correct bucketing
11. P&L now includes bill expenses
12. Trial Balance balances after all AP transactions
13. All existing AR tests still pass
14. Contact with type=CUSTOMER rejected on bill create
