# Deep code-review findings — 2026-07-05

Full-project adversarial code review: every finding independently verified
before fixing. All 81 confirmed findings below were fixed across 8 cluster commits on
`claude/medicine-database-collection-95z3sd`, merged to `main` (merge `450dcac`).

> Source of record: fixes live in git (each cluster commit message lists its defects).
> This file is the consolidated findings register. Raw JSON was produced during review
> (`all_findings.json` 83 raw / `confirmed_all.json` 81 confirmed).

- **Confirmed findings:** 81
- **Severity:** critical 2, high 32, medium 34, low 13
- **Verdict:** CONFIRMED 74, PARTIAL 7 (PARTIAL = real but narrower than first stated)

| Cluster | Fix commit | Findings |
|---|---|---|
| AR — Accounts Receivable | 1/8 · 3e40e7d | 6 |
| AP — Accounts Payable | 2/8 · fe92fca | 7 |
| Manufacturing + Accounting engine | 3/8 · a089566 | 12 |
| Inventory + POS + Sales | 4/8 · 628e044 | 16 |
| GST/Tax + Banking + Payment | 5/8 · 6b1965e | 12 |
| Payroll + HR + Field-sales | 6/8 · 1126e41 | 13 |
| Security + Auth + Infra | 7/8 · 73fdf26 | 15 |


## AR — Accounts Receivable
**Fix commit 1/8 · 3e40e7d** — 6 findings (high 3, medium 3)

### AR-1. [HIGH/money] Credit note application has no invoice status or balance guard — a CN can over-credit AR, mark a DRAFT invoice PAID, or resurrect a CANCELLED invoice into a payable state
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ar/service/CreditNoteService.java (postCreditNote, ~lines 264-305; createCreditNote ~88-91)`

**Failure scenario:** createCreditNote only checks the linked invoice EXISTS (`invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse` — no status check), and postCreditNote does `invoiceRepository.findById(cn.getInvoiceId())` then `invoiceService.updatePaymentStatus(invoice, cn.getTotalAmount())` with NO cap against balanceDue, no status check, and no pessimistic lock (PaymentService locks the invoice via findLockedByIdAndOrgIdAndIsDeletedFalse; this path does not). Three concrete failures: (1) Everyday over-application — invoice ₹100 SENT, customer pays ₹80 (balance ₹20), full-value return CN ₹100 issued → journal CR AR ₹100 posts, updatePaymentStatus sets amountPaid=180 > totalAmount, balanceDue −80 clamped to 0, status PAID. The customer's ₹80 refund entitlement vanishes (no customer-advance/refund liability is booked) and GL 1100 goes ₹80 credit-negative for this cycle. (2) CN linked to a DRAFT invoice → issue → CR AR journal posts and updatePaymentStatus flips the DRAFT to PAID/PARTIALLY_PAID even though the invoice never posted its own DR AR journal — AR is credited with no matching debit ever, and the invoice can no longer be sent (sendInvoice requires DRAFT). (3) CN ₹30 linked to a CANCELLED invoice (₹100, journal already reversed) → updatePaymentStatus recomputes balanceDue = 100−30 = 70 and sets status PARTIALLY_PAID — the cancelled invoice is resurrected as payable, and payments can now be recorded against a document whose revenue journal was reversed.

**Fix applied:** In createCreditNote and postCreditNote: when invoiceId is linked, load the invoice org-scoped WITH the pessimistic lock, require status ∈ {SENT, PARTIALLY_PAID, OVERDUE}, and cap the applied amount at invoice.balanceDue (route any excess to Customer Advance 2100 or reject with AR_CN_EXCEEDS_BALANCE).

---

### AR-2. [HIGH/money] Credit-note return restores stock at SALE price and posts no COGS/inventory reversal — inventory valuation inflates and GL drifts from the stock ledger on every itemised return
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ar/service/CreditNoteService.java (postCreditNote lines 271-283 passing line.getUnitPrice()); accounting/posting/AccountingPostingEngine.postCreditNote lines 277-315; inventory/service/InventoryService.restoreStockForCreditNote lines 607-680`

**Failure scenario:** The invoice posting books DR COGS / CR Inventory(1200) at cost (SalesInvoicePostingRule.appendCogs). Its mirror, AccountingPostingEngine.postCreditNote, only reverses Revenue + GST + AR — no DR Inventory / CR COGS legs at all — while CreditNoteService.postCreditNote simultaneously restores physical stock via restoreStockForCreditNote(..., line.getUnitPrice(), ...), i.e. the RETURN_IN movement's unitCost is the SALE price, not cost. Concrete: item costs ₹60, sells ₹100. Sell 10 (COGS 600 booked, GL 1200 down 600, stock −10). Customer returns all 10 via itemised CN: stock ledger +10 valued at ₹1000 (sale price), for FIFO orgs a new cost lot opens at ₹100/unit so the NEXT sale books COGS at 100 not 60 (overstated ₹400); meanwhile GL 1200 stays 600 short and COGS keeps the ₹600 of goods that came back — P&L permanently overstates cost and the stock-summary valuation diverges from GL 1200 by ₹1000 per such return.

**Fix applied:** Restore at cost (resolve via FifoCostingService / item.purchasePrice / CostResolverService, not line.unitPrice), and add DR Inventory / CR COGS legs for the restored cost to postCreditNote, mirroring the invoice's appendCogs.

---

### AR-3. [HIGH/money] contact.outstanding_ar is decremented by invoice payments but never incremented at invoice issue — a payment void mints phantom khata outstanding that the khata-settlement endpoint will convert into an unbacked DR Cash / CR AR journal
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ar/service/PaymentService.java (postPayment line 206, voidPayment line 255, adjustContactOutstandingAr lines 353-360); CustomerReceiptService.java (recordReceipt line 190, voidReceipt line 308, recordKhataSettlement guard lines 229-236)`

**Failure scenario:** The only code that ever INCREMENTS contact.outstanding_ar is the POS CREDIT (khata) sale in SalesReceiptService (and the void-restore paths). InvoiceService.sendInvoice never bumps it. Yet PaymentService.postPayment does adjustContactOutstandingAr(−amount) and CustomerReceiptService.recordReceipt does −totalAllocated for INVOICE-backed collections, clamped at zero. Two concrete failures: (1) Phantom khata minting: customer with NO khata history; invoice ₹1000 posted and paid → outstanding_ar = max(0, 0−1000) = 0; the payment is then voided → voidPayment does adjustContactOutstandingAr(+1000) → outstanding_ar = 1000. The customer now shows ₹1000 invoice-less outstanding, and recordKhataSettlement (POST /api/v1/customer-receipts/khata-settlement, OPERATOR-accessible) accepts collecting ₹1000: it posts DR Cash / CR AR 1000 with no receivable behind it — GL 1100 goes negative, and since voidPayment also restored invoice.balanceDue to ₹1000, the invoice can be collected AGAIN (double CR AR for one sale). (2) Khata erasure: customer has real khata outstanding ₹500 (POS credit sale, GL 1100 carries it); they pay an unrelated ₹1000 invoice → outstanding_ar clamps to 0 → the legitimate ₹500 khata settlement is now rejected with AR_KHATA_EXCEEDS_OUTSTANDING while GL 1100 still holds the ₹500 — books and the settlement mirror permanently desync.

**Fix applied:** Make the mirror symmetric: either increment outstanding_ar on invoice post and decrement on cancel/CN (true full-AR mirror), or scope the decrement/restore in PaymentService/CustomerReceiptService to khata-only balances (do not touch outstanding_ar for invoice-backed payments). Remove the silent max(ZERO) clamp so drift fails loud.

---

### AR-4. [MEDIUM/tenancy] Cross-org IDOR: payments for any invoice UUID are readable without an org check on two endpoints
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ar/service/PaymentService.java (listForInvoice lines 328-331, getPaymentsForInvoice lines 333-335) exposed via InvoiceController.java:81-87 and PaymentController.java:62-69`

**Failure scenario:** GET /api/v1/invoices/{invoiceId}/payments and GET /api/v1/payments/invoice/{invoiceId} call `paymentRepository.findByInvoiceIdAndIsDeletedFalse(invoiceId)` — no TenantContext org filter anywhere on the path (the controller @PreAuthorize only checks role, and the service never verifies the invoice belongs to the caller's org). Any authenticated user (down to VIEWER) in org A who obtains an org-B invoice UUID (they leak through wa.me share links, payment-link URLs, e-invoice payloads, emailed PDFs' metadata) receives org B's full payment records: amounts, payment methods, reference/UTR numbers, bank account strings, contact ids, notes. The sibling CustomerReceiptService.listReceiptsForInvoice correctly uses findByOrgIdAndInvoiceId, confirming this is an omission, not a design choice.

**Fix applied:** Resolve the invoice org-scoped first (invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse) and 404 if absent, or add orgId to the repository queries: findByOrgIdAndInvoiceIdAndIsDeletedFalse(TenantContext.getCurrentOrgId(), invoiceId).

---

### AR-5. [MEDIUM/correctness] findLineIdForTaxLine assumes 3 tax components per line, so source_line_id is wrong on virtually every multi-line GST invoice — regressing the BUG-1 line-level tax join fix
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ar/service/InvoiceService.java (findLineIdForTaxLine lines 718-737)`

**Failure scenario:** The mapper walks a fixed window of `accumulated..accumulated+3` positions per invoice line regardless of how many tax components that line actually produced. Indian GST yields 2 components per line (CGST+SGST intra-state) or 1 (IGST inter-state), never 3. Concrete: 2-line intra-state invoice → allTaxLines = [L1-CGST(0), L1-SGST(1), L2-CGST(2), L2-SGST(3)]. For index 2 the loop scans j=0..2 under line 1 and returns line 1's id — L2's CGST is stamped with L1's source_line_id (index 3 lands correctly on line 2 only because line 1 consumed a phantom third slot). Inter-state is worse: L2's single IGST component (index 1) is attributed to L1. Every tax_line_item row after the first line on a multi-line invoice carries the wrong sourceLineId, so DetailedReportService's line-level tax joins (the explicit BUG-1 fix: 'Tax JOINs changed to line-level via source_line_id') now attribute tax to the wrong register rows/HSN lines. Per-invoice totals are conserved, but per-line/per-item tax reporting is wrong.

**Fix applied:** Record the component count per line while building allTaxLines (e.g. keep a parallel List<Integer> of per-line component counts, or set sourceLineId directly on the TaxLineItem at build time inside the per-line loop after the InvoiceLine is persisted) instead of the hardcoded 3-slot window.

---

### AR-6. [MEDIUM/concurrency] sendInvoice and issueCreditNote are check-then-act with no lock or @Version — concurrent double-submit double-deducts stock and double-posts journals
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ar/service/InvoiceService.java (sendInvoice lines 422-461); CreditNoteService.java (issueCreditNote lines 215-246)`

**Failure scenario:** Invoice has no @Version and sendInvoice loads it with plain findByIdAndOrgIdAndIsDeletedFalse (no PESSIMISTIC_WRITE — contrast PaymentService.findInvoiceForPayment which does lock). Two concurrent POST /api/v1/invoices/{id}/send (double-click, or a client retry racing bulk-send) both read status=DRAFT, both pass validateStockForInvoice, both run inventoryService.deductStockForInvoice (append-only SALE movements → stock deducted TWICE), and both post postingEngine.postSalesInvoice → two POSTED SALES journals; the invoice keeps only the last journalEntryId, so the orphaned duplicate journal (revenue + AR + COGS) can never be reversed via cancelInvoice. Same shape in issueCreditNote: two concurrent issues of one DRAFT CN both pass the status check, post two CR-AR journals, and call updatePaymentStatus twice — the linked invoice's amountPaid is credited double. Unlike voidPayment (protected downstream by JournalService.reverseEntry's isReversed guard), these are fresh posts with no idempotency backstop.

**Fix applied:** Load the invoice / credit note with a PESSIMISTIC_WRITE org-scoped query (or add @Version) at the top of sendInvoice / issueCreditNote / postCreditNote so the second transaction re-reads the flipped status and fails the DRAFT check.

---


## AP — Accounts Payable
**Fix commit 2/8 · fe92fca** — 7 findings (high 4, medium 2, low 1)

### AP-1. [HIGH/money] Vendor outstandingAp drifts by the TDS amount on every TDS bill, and voidBill corrupts it further (including on never-posted DRAFT bills)
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ap/service/PurchaseBillService.java (postBill ~line 350, voidBill ~lines 377-409)`

**Failure scenario:** Three inconsistent adjustments to contact.outstandingAp: (1) postBill adds gross `bill.getTotalAmount()`, but the vendor is only ever owed total − TDS — recordPayment reduces outstanding by the payment amount (= total − TDS when fully settled), so every TDS bill leaves its TDS amount permanently stuck in outstandingAp (bill 100/TDS 10: +100 at post, −90 at full payment → residual 10 forever). (2) voidBill subtracts `bill.getBalanceDue()` (= total − TDS) instead of the totalAmount that was added → voiding an unpaid posted TDS bill also leaves +TDS behind. (3) voidBill has no DRAFT guard (only blocks status VOID and amountPaid>0), so `POST /api/v1/bills/{id}/void` on a DRAFT bill — which never bumped outstanding — still executes `contact.setOutstandingAp(outstanding − balanceDue)`, driving the vendor's outstanding negative by the full bill value.

**Fix applied:** Post/void symmetrically in net-of-TDS terms: postBill adds (totalAmount − tdsAmount); voidBill subtracts the same, and skips the contact adjustment (and stock/journal reversal is already conditional) when the bill was never posted (status DRAFT / journalEntryId == null). Alternatively block voidBill for DRAFT (deleteBill is the DRAFT path).

---

### AP-2. [HIGH/concurrency] recordPayment allocation validation is check-then-act with no lock — concurrent payments against the same bill both pass and double-pay (postBill has the same TOCTOU for double journal + double stock)
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ap/service/VendorPaymentService.java (recordPayment ~lines 110-133); ap/service/PurchaseBillService.java postBill ~lines 312-344`

**Failure scenario:** recordPayment reads the bill via plain findByIdAndOrgIdAndIsDeletedFalse (no PESSIMISTIC_WRITE; BaseEntity has no @Version), checks `alloc.amountApplied() <= bill.getBalanceDue()`, then posts the journal and updates the bill. Two concurrent payments each allocating the full balanceDue both pass the check → two cash credits and two AP debits post, amountPaid = 2×balance, and updatePaymentStatus clamps balanceDue to 0 hiding the over-payment. The AR mirror (PaymentService) was given pessimistic locking in the BUG-2 fix; the AP side never was. Same pattern in postBill: two concurrent POST /bills/{id}/post both read status DRAFT, both run postingEngine.postPurchaseBill + recordStockForBill → duplicate journal, duplicate PURCHASE stock movements, outstandingAp bumped twice.

**Fix applied:** Add a @Lock(PESSIMISTIC_WRITE) findByIdAndOrgIdForUpdate on PurchaseBillRepository and use it in recordPayment (per allocation) and at the top of postBill/voidBill, mirroring the AR PaymentService and the H4 acceptMatch fix.

---

### AP-3. [HIGH/correctness] updateBill silently severs purchaseOrderLineId on every line, defeating the GRN double-stock guard — editing a PO-drafted bill then posting double-counts inventory
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ap/service/PurchaseBillService.java (updateBill line builder ~lines 649-670; UpdatePurchaseBillRequest.BillLineRequest has no purchaseOrderLineId field)`

**Failure scenario:** PurchaseOrderService.createBillFromPo stamps purchaseOrderLineId on each draft bill line. UpdatePurchaseBillRequest.BillLineRequest (ap/dto/UpdatePurchaseBillRequest.java) has no purchaseOrderLineId field and updateBill rebuilds lines without `.purchaseOrderLineId(...)`, so ANY edit of the draft (even fixing a description) clears every PO-line FK. On postBill, recordStockForBill's skip condition (`line.getPurchaseOrderLineId() != null && GRN received`) no longer fires → a PURCHASE stock movement is posted for goods the GRN already booked → stock and inventory valuation double-counted. The 3-way match also degrades to NO_PO (which neither assertPostable nor assertPayable blocks), so the entire P2P control chain is bypassed by one innocuous edit.

**Fix applied:** Add purchaseOrderLineId to UpdatePurchaseBillRequest.BillLineRequest and carry it through updateBill's line builder (mirroring createBill), or preserve existing FKs by matching lines positionally/by itemId when the request omits them.

---

### AP-4. [HIGH/money] voidPayment restores bill balanceDue ignoring TDS, enabling vendor over-payment and a stuck AP debit
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ap/service/VendorPaymentService.java (voidPayment, ~lines 263-275)`

**Failure scenario:** PurchaseBillService.updatePaymentStatus computes balanceDue = totalAmount − tdsAmount − amountPaid, but voidPayment restores with `bill.setBalanceDue(bill.getTotalAmount())` (full reversal) or `bill.getTotalAmount().subtract(newAmountPaid)` (partial) — TDS is dropped. Bill total ₹100 with TDS ₹10 → balanceDue 90; pay 90 → PAID; void the payment → balanceDue becomes 100 (not 90). The next payment passes the `alloc <= balanceDue` check at 100, over-paying the vendor by ₹10; the journal DR AP 100 against the bill's AP credit of 90 leaves a ₹10 debit stranded in 2010. Partial-void branch has the same defect (pay 40+30, void 30 → balanceDue = 60 instead of 50).

**Fix applied:** In voidPayment, restore using the same formula as updatePaymentStatus: balanceDue = totalAmount − (tdsAmount==null?0:tdsAmount) − newAmountPaid (clamped at totalAmount−tds for the full-reversal branch).

---

### AP-5. [MEDIUM/money] No vendor↔document consistency check: a vendor payment can allocate to ANOTHER vendor's bills, and a vendor credit can be applied to another vendor's bill
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ap/service/VendorPaymentService.java (recordPayment allocation loop ~lines 110-133); ap/service/VendorCreditService.java applyToBill ~lines 334-368`

**Failure scenario:** recordPayment validates each allocation's bill only by org (`findByIdAndOrgIdAndIsDeletedFalse(alloc.billId(), orgId)`) — it never checks `bill.getContactId().equals(request.contactId())`. A payment recorded against vendor A with an allocation to vendor B's bill posts the journal, marks B's bill PAID via updatePaymentStatus, but subtracts the amount from A's outstandingAp (line 198) — B's outstanding never decreases and A's goes wrong by the full amount. VendorCreditService.applyToBill has the identical gap: credit.contactId is never compared to bill.contactId, so vendor A's credit reduces vendor B's bill balance while A's outstanding was already reduced at postCredit. Both vendors' subledgers permanently diverge from the AP control account.

**Fix applied:** In both paths, reject allocations/applications where the bill's contactId differs from the payment's/credit's contactId (e.g. AP_ALLOCATION_WRONG_VENDOR, 400).

---

### AP-6. [MEDIUM/money] voidCredit never reverses the RETURN_OUT stock movements that postCredit recorded — voided vendor credit leaves inventory permanently understated vs the GL
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/ap/service/VendorCreditService.java (voidCredit ~lines 294-330 vs postCredit/recordStockReturnForCredit ~lines 256-259, 467-496)`

**Failure scenario:** postCredit posts the DR AP / CR Expense+ITC journal AND records a RETURN_OUT stock movement (negative qty) per item line. voidCredit reverses the journal (journalService.reverseEntry) and restores contact.outstandingAp, but never calls inventoryService.reverseMovement for the RETURN_OUT rows — contrast PurchaseBillService.voidBill, which has reverseStockForBill. Scenario: post a 100-unit return credit by mistake, void it → GL is fully restored but stock_balance stays 100 units short and (for FIFO orgs) the consumed cost lots are never restored, so inventory valuation no longer matches the balance sheet.

**Fix applied:** Mirror voidBill: look up the credit's RETURN_OUT movements by (ReferenceType.DEBIT_NOTE, credit.id) and reverse each via inventoryService.reverseMovement before flipping status to VOID.

---

### AP-7. [LOW/correctness] PO numbers are generated from a soft-delete-sensitive row count with no uniqueness constraint — duplicates are silently created
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/procurement/service/PurchaseOrderService.java (generatePoNumber ~lines 198-201)`

**Failure scenario:** `generatePoNumber` returns `PO-%05d` of `countByOrgIdAndIsDeletedFalse + 1`. V1 baseline has no unique index on purchase_orders(org_id, po_number) (only pkey + two non-unique indexes), so: (a) soft-delete any PO that isn't the latest → count drops → the next create reuses an existing number (create PO-00001..PO-00005, delete PO-00002, create → second PO-00005); (b) two concurrent creates read the same count and both insert the same number. Every other document in the codebase uses the pessimistically-locked InvoiceNumberSequence table (V21 hardening); PO was left on MAX-count+1. Duplicate PO numbers then ambiguate GRN/bill drafting references, supplier communications, and the 3-way match audit trail.

**Fix applied:** Switch generatePoNumber to the shared InvoiceNumberSequence generator (prefix "PO") like bills/GRNs, and add a unique partial index on purchase_orders(org_id, po_number) WHERE is_deleted = false.

---


## Manufacturing + Accounting engine
**Fix commit 3/8 · a089566** — 12 findings (high 7, medium 3, low 2)

### MFG_ACCT-1. [HIGH] Backflush mode double-counts raw-material cost: rawMaterialCost starts at the full planned cost and the backflushed issue cost is added on top, inflating FG unit cost, the completion journal, and material variance by ~100%
`CONFIRMED`
**Fix applied:** In backflushMaterials (ManufacturingService.java ~line 1073-1095), stop seeding the accumulator from the current rawMaterialCost. Change `BigDecimal actualRmCost = wo.getRawMaterialCost();` to `BigDecimal actualRmCost = BigDecimal.ZERO;`, and in the loop accumulate the CUMULATIVE per-line cost rather than only this receipt's slice — i.e. after `line.setLineCost(lineCost)` (where lineCost = unitCost × newIssued, the cumulative issued qty), do `actualRmCost = actualRmCost.add(lineCost);` instead of `actualRmCost.add(line.getUnitCost().multiply(issueQty)...)`. Because backflushMaterials runs per (possibly partial) receipt and line.issuedQty already accumulates across receipts, summing line.getLineCost() yields the correct running RM cost (= Σ unitCost×cumulativeIssuedQty) with no double-count and no loss across partial receipts. This one change fixes all three symptoms together: rawMaterialCost lands at the true issued total (e.g. 1500 on full receipt), fgUnitCost = totalCost/qty is correct, the completion journal CR WIP now equals the issue-time DR WIP (planned rawMaterialCost was 1500, post-backflush is 1500 → WIP nets to zero), and buildCostSummary's actualRm==plannedRm → zero phantom variance. No Flyway migration needed (in-memory computation only; stock movements append-only and unaffected). Regression test to add (ManufacturingServiceTest): a backflush WO with a known BOM (e.g. one line, unitCost 15 × requiredQty 100 = planned RM 1500), issue to production, receive the full quantity, then assert wo.getRawMaterialCost().compareTo(1500)==0 (NOT 3000), wo.getUnitCost() == totalCost/qty computed with single RM, and the saved ProductionCostSummary.materialVariance()==0 when actual==planned; add a second case receiving in two halves and assert the final rawMaterialCost is still 1500 (proves partial-receipt accumulation is correct, not lost).

---

### MFG_ACCT-2. [HIGH] Cancelling an IN_PROGRESS work order with partial FG receipts returns ALL issued raw material and leaves the received FG in stock — phantom inventory is created and the GL diverges from the stock subledger
`CONFIRMED`
**Fix applied:** Fix in ManufacturingService.cancelWorkOrder. Inside the `if ("IN_PROGRESS".equals(wo.getStatus()))` block, when `wo.getQuantityProduced().signum() > 0`, also reverse the FG (and co-product) receipts so the subledger returns to its pre-issue state — matching the full-RM return and full WIP reversal the method already performs (this mirrors JobWorkService.cancelJobWorkOrder and the "cancel = undo" semantics already in use).

Concretely:
1. Add a StockMovementRepository finder for the WO's non-reversed production receipts, e.g. `findByOrgIdAndReferenceTypeAndReferenceIdAndMovementTypeAndReversedFalse(orgId, ReferenceType.WORK_ORDER, wo.getId(), MovementType.PRODUCTION_RECEIVE)` (there is no existing method for this exact predicate; the class already has reference-scoped queries like findSaleMovementsByBatch to model on).
2. In cancelWorkOrder, before or after the RM-return loop, iterate those movements and call `inventoryService.reverseMovement(mv.getId(), "Reversal — work order " + wo.getWorkOrderNumber() + " cancelled")` for each. This removes the 50 FG (and any co-products) from stock. reverseMovement (InventoryService:232) already handles FIFO lot restoration.
3. WIP journal reversal (line 1228-1230) stays as-is; since no completion journal was ever posted for a partial WO, only the WIP journal needs undoing, so GL Inventory + WIP both return to original with the FG now removed — subledger and GL stay consistent.
4. Alternatively (weaker) block cancel when quantityProduced > 0 and force complete-at-produced or scrap; the reverse-FG approach is preferred because it keeps cancel usable and self-consistent.

No Flyway migration required (append-only reversal movements only).

Regression test (ManufacturingServiceTest): build a 100-unit non-backflush WO, issueToProduction (stub RM PRODUCTION_ISSUE + WIP journal), receiveFinishedGoods(50) leaving status IN_PROGRESS, then cancelWorkOrder; assert (a) reverseMovement is invoked for the FG PRODUCTION_RECEIVE movement, (b) the RM ADJUSTMENT still returns full issuedQty, (c) WIP journal reversed once — i.e. net stock delta is zero (all RM back, no residual FG). Add a backflush variant asserting the FG receipt is reversed there too.

---

### MFG_ACCT-3. [HIGH] Completion journal double-relieves WIP for scrap: it credits WIP totalCost + scrapCost while WIP was only ever debited totalCost, leaving the WIP asset account with a permanent credit balance and Inventory GL overstated by scrapCost
`CONFIRMED`
**Fix applied:** In ManufacturingWipPostingRule.generateCompletionEntry (lines 102-145), relieve WIP by exactly totalCost (matching the issue debit) and split the FG-vs-scrap allocation on the DEBIT side. Concretely: compute BigDecimal scrapCost = calculateMaterialVariance(wo) (already >=0); BigDecimal fgValue = wo.getTotalCost().subtract(scrapCost). Emit: (1) if fgValue.signum() > 0 → DR INVENTORY_ASSET(1200) = fgValue ("FG receipt: "+num); (2) if scrapCost.signum() > 0 → DR MATERIAL_VARIANCE(5050) = scrapCost ("Production scrap: "+num); (3) CR WIP_INVENTORY(1210) = wo.getTotalCost() ("WIP relieved: "+num). Delete the current unconditional DR Inventory=totalCost line (105-108), the CR WIP=totalCost line (110-113), and the entire materialVariance if/else block (115-136) — the else (favorable/negative) branch is dead anyway because scrapCost is never negative. Net effect: DR (fgValue + scrapCost) = totalCost = CR WIP, journal balances, WIP nets to zero against the issue debit, and Inventory carries only the value of goods that reached stock. NOTE ALSO (out-of-scope but related, flag for follow-up): the FG subledger unit cost at ManufacturingService:835-837 (fgUnitCost = totalCost/quantityToProduce) still bakes scrapped material into good units, so the physical FG subledger is likewise overstated by scrapCost — a full fix would base fgUnitCost on (totalCost − scrapCost); this journal fix alone corrects the GL WIP corruption but leaves that subledger overstatement, so do both to fully close the double-count. NO Flyway migration needed (pure journal-line arithmetic; accounts 1200/1210/5050 already seeded). Regression test: add ManufacturingWipPostingRuleTest (mock DefaultAccountService.getCode to return 1200/1210/5050/etc). Test A: WO totalCost=1000, scrapCost=100 → completion lines = DR 1200 = 900, DR 5050 = 100, CR 1210 = 1000; assert total debit == total credit == 1000, assert CR-1210 == issue DR-1210 (post generateWipEntry on the same rm+labor+overhead=1000 WO and compare), assert no net WIP. Test B: WO totalCost=1000, scrapCost=0 → only DR 1200=1000 / CR 1210=1000, no 5050 line. Test C (guard): scrapCost equal to totalCost → no DR 1200 line, DR 5050=totalCost / CR 1210=totalCost still balances.

---

### MFG_ACCT-4. [HIGH] Non-backflush production scrap deducts warehouse stock twice: RM already deducted at issue is deducted again by the PRODUCTION_SCRAP movement
`CONFIRMED`
**Fix applied:** In ScrapService.recordScrap, gate the warehouse stock movement on backflush mode. Change the unconditional inventoryService.recordMovement(PRODUCTION_SCRAP, ...) call (lines 86-97) to only fire when wo.isBackflushMode() is true — in backflush the RM is still in the warehouse (issueMaterials is skipped until FG receipt), so scrap genuinely consumes warehouse stock; in the non-backflush path the RM already left the warehouse at issueToProduction, so recording a second negative movement double-deducts. When backflush is false, skip the movement entirely but STILL save the ProductionScrap row and update wo.scrapQty/scrapCost (the loss is bookkeeping-only, mirroring the WIP journal that already carries it). Concretely: wrap the recordMovement(...) call in `if (wo.isBackflushMode()) { inventoryService.recordMovement(...); }`. No migration needed (code-only; no schema change). Regression tests to add/update in ScrapServiceTest: (a) the existing recordScrap_inProgressOrder_createsMovementAndUpdatesWoTotals test uses buildWorkOrder(...) which leaves backflushMode=false — it currently asserts verify(inventoryService).recordMovement(any()); after the fix this must assert verify(inventoryService, never()).recordMovement(any()) while still asserting the ProductionScrap row + wo.scrapQty/scrapCost update; (b) add a new test recordScrap_backflushWo_recordsMovement that builds a WO with backflushMode=true IN_PROGRESS and asserts verify(inventoryService).recordMovement(any()) plus the WO-total updates, proving the legitimate backflush path is preserved; (c) optionally add recordScrap_nonBackflush_noStockMovement asserting the movement is skipped for the default (false) path. Also consider adding a comment documenting that WIP loss is tracked via wo.scrapQty/scrapCost, not a second warehouse deduction, to prevent regression.

---

### MFG_ACCT-5. [HIGH] Reversing a year-end close entry corrupts both fiscal years and makes re-close a permanent silent no-op, because reverseEntry dates every reversal LocalDate.now() while closeYear's recomputation still includes the reversed close lines
`PARTIAL`
**Fix applied:** Two coordinated changes, no migration.

1) Let the reversal be dated in the original entry's period. In JournalService add an overload reverseEntry(UUID entryId, LocalDate reversalDate); keep the existing no-arg reverseEntry delegating with LocalDate.now() for backward compatibility. In the overload, use the supplied date for effectiveDate + computeFiscalYear/periodMonth + requireOpen + generateEntryNumber (everything currently derived from `today`). This preserves current behavior for callers that want a current-date reversal while allowing an in-period reversal.

2) Make the year-end reopen actually work. Add YearEndCloseService.reopenYear(int fiscalYear): resolve the live (non-reversed, non-reversal) close entry for (SOURCE_MODULE, closeId), then call journalService.reverseEntry(entry.getId(), entry.getEffectiveDate()) so the reversal lands on the FY's last day and nets the close lines within the FY (4010 credit balance restored, RE returns to pre-close). Requires the FY's period to be open (requireOpen inside reverseEntry) — correct behavior; reopening a locked period should fail loudly.

3) Fix the idempotency guard so a reversal entry does not count as a live close marker: at YearEndCloseService:68-70 change the filter to .anyMatch(e -> !e.isReversed() && !e.isReversal()). After a reopen (step 2), the original is isReversed=true and the reversal is isReversal=true, so alreadyClosed=false and closeYear can legitimately re-close, recomputing the true P&L nets.

Optionally guard the generic reverse endpoint against reversing a YEAR_END_CLOSE entry with a now()-date (route it through reopenYear instead) to prevent the corrupting path entirely.

Regression tests to add (accounting/service, mock JournalService-backed or integration): (i) close FY -> reopenYear -> assert reversal.effectiveDate == FY end, 4010 credit balance restored, RE balance back to pre-close, and FY+1 P&L shows NO phantom revenue; (ii) close -> reopenYear -> closeYear(sameFY) succeeds (no YEAR_END_ALREADY_CLOSED) and re-books net income to RE; (iii) close -> reverse via the generic now()-dated path -> closeYear throws YEAR_END_ALREADY_CLOSED (documents current broken behavior / that the sanctioned path is reopenYear).

---

### MFG_ACCT-6. [HIGH] postWipJournal and postCompletionJournal swallow every exception — stock moves commit while the matching GL entry silently never posts, and wipJournalEntryId stays null so cancel has nothing to reverse
`CONFIRMED`
**Fix applied:** In ManufacturingService.postWipJournal and postCompletionJournal (lines 2387-2407), stop swallowing. Remove the try/catch and let `journalService.postJournal(...)` propagate so the whole @Transactional `issueToProduction` / `receiveFinishedGoods` rolls back atomically — no stock movement without its matching GL entry, and no COMPLETED/IN_PROGRESS status flip on a failed post. This is the correct posture for a books-integrity ERP: the operator is blocked until the missing default account (WIP_INVENTORY 1210 / DIRECT_LABOR 5040 / MANUFACTURING_OVERHEAD 5030 / MATERIAL_VARIANCE 5050) or the closed period is fixed, exactly as the sales/AP posting rules already behave (they don't swallow). Concretely:\n\n  private void postWipJournal(WorkOrder wo) {\n      PostingContext ctx = PostingContext.manufacturingWip(wo);\n      JournalEntry entry = journalService.postJournal(wipPostingRule.generate(ctx));\n      wo.setWipJournalEntryId(entry.getId());\n      log.info(\"WIP journal {} posted for work order {}\", entry.getEntryNumber(), wo.getWorkOrderNumber());\n  }\n\n(and symmetrically for postCompletionJournal → setJournalEntryId). No migration needed.\n\nIf a hard blocker on the shop floor is unacceptable product-wise, the safe alternative is: keep the movement+status in the txn but set a `wo.journalPending=true` flag (new nullable boolean column — WOULD then need a migration) and raise a HIGH AiSuggestion (AiSuggestionService.createSuggestion, idempotent via existsOpenSuggestion) plus expose a re-post endpoint that calls postWipJournal/postCompletionJournal for the pending WO. But the minimal, no-migration, correctness-first fix is to let it propagate.\n\nRegression test (ManufacturingServiceTest, mocked deps as the existing suite does): stub `journalService.postJournal(any())` to `thenThrow(new BusinessException(\"account missing\", \"...\", HttpStatus.BAD_REQUEST))`; call `issueToProduction(woId)` and assert it throws (not swallowed) — before the fix the method returns normally and `wo.getWipJournalEntryId()` is null while movements were recorded. Add the mirror test for `receiveFinishedGoods` completing (post-fix the completion throws instead of leaving a COMPLETED WO with a null journalEntryId).

---

### MFG_ACCT-7. [HIGH] receiveFinishedGoods and issueToProduction are check-then-act with no lock — concurrent double-submit records duplicate stock movements and posts the completion/WIP journal twice
`CONFIRMED`
**Fix applied:** Add a pessimistic-lock finder to WorkOrderRepository and re-read the WO through it at the top of every state-transition method, mirroring the acceptMatch/payment-link fixes. No Flyway migration needed — a pessimistic lock is a runtime SELECT ... FOR UPDATE, no schema change (avoid the @Version alternative precisely because that WOULD need a DDL column add).

1) WorkOrderRepository — add:
   @Lock(LockModeType.PESSIMISTIC_WRITE)
   @Query("select w from WorkOrder w where w.id = :id and w.orgId = :orgId and w.isDeleted = false")
   Optional<WorkOrder> findByIdAndOrgIdForUpdate(@Param("id") UUID id, @Param("orgId") UUID orgId);
   (imports: jakarta.persistence.LockModeType, org.springframework.data.jpa.repository.Lock/Query, Param.)

2) In ManufacturingService, replace workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(...) with findByIdAndOrgIdForUpdate(...) at the top of the four @Transactional mutators that gate on WO state: issueToProduction (~672), receiveFinishedGoods(4-arg, ~790), executeDisassembly (~1108), cancelWorkOrder (~1195). Each is already @Transactional, so the FOR UPDATE row lock is held to commit; a concurrent second call blocks until the first commits, then re-reads the now-updated status/quantityProduced and correctly hits MFG_NOT_DRAFT / MFG_NOT_IN_PROGRESS / MFG_EXCEEDS_PLANNED. (Split-merge helpers that also transition state and any other findByIdAndOrgId... used for a write path should get the same treatment, but the four named cover the double-movement/double-journal exposure.)

3) Regression test — because the defect is a true race, a Mockito unit test can't exercise it; add an integration test (real DB, e.g. the existing Testcontainers/embedded-Postgres @SpringBootTest harness) ManufacturingConcurrencyIT: create an IN_PROGRESS WO for the full planned qty, fire two receiveFinishedGoods(woId, plannedQty) calls on two threads via a CyclicBarrier, then assert exactly ONE succeeds and the other throws MFG_EXCEEDS_PLANNED/MFG_NOT_IN_PROGRESS; assert exactly one PRODUCTION_RECEIVE stock_movement for the WO and exactly one completion journal / one production_cost_summary row. Add a parallel case for issueToProduction asserting a single WIP journal and a single set of ISSUED movements. If a full IT is out of scope for this round, at minimum add a repository test asserting findByIdAndOrgIdForUpdate exists and returns the WO, plus a static assertion that each of the four mutators calls the ForUpdate finder (guards against regression to the plain finder).

---

### MFG_ACCT-8. [MEDIUM] closeYear is check-then-act with no DB backstop: two concurrent year-end-close requests both pass the alreadyClosed check and each posts a full closing journal, driving every P&L account to its inverse balance and doubling Retained Earnings
`CONFIRMED · migration`
**Fix applied:** Two-layer fix (defense in depth).

PRIMARY (in-code, no data-migration risk): serialise closeYear per org before the idempotency check.
1. In OrganisationRepository add: @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select o from Organisation o where o.id = :id") Optional<Organisation> findByIdForUpdate(@Param("id") UUID id);
2. In YearEndCloseService.closeYear, replace the org load at line 58 with organisationRepository.findByIdForUpdate(orgId) so the row lock is held for the whole transaction. Now two concurrent closes serialise: the first locks the org, checks, posts, commits (releasing the lock); the second then acquires the lock, re-reads the idempotency check, sees the just-posted non-reversed close, and throws YEAR_END_ALREADY_CLOSED. This mirrors the existing pessimistic-lock pattern used in PaymentService.voidPayment and PaymentLinkService.

BACKSTOP (migration): add a partial unique index so even a lock-bypass path (or a future refactor) fails at commit. DDL (I assign the version):
CREATE UNIQUE INDEX uq_je_year_end_close ON public.journal_entry (org_id, source_module, source_id) WHERE source_module = 'YEAR_END_CLOSE' AND is_reversal = FALSE AND is_reversed = FALSE;
(Use is_reversal=FALSE AND is_reversed=FALSE, not just is_reversal=FALSE, so the predicate matches the service's active-close semantics and a legitimately-reversed year could still be re-closed.) The second concurrent INSERT then hits a unique violation → its transaction rolls back with no partial journal, and the caller can be mapped to a clean 409.

REGRESSION TESTS:
- YearEndCloseServiceTest: add a test asserting closeYear invokes organisationRepository.findByIdForUpdate (verify the locking method is called before the idempotency query) — a structural guard that the lock wasn't dropped. Keep the existing already-closed test (mocks the find to return a POSTED non-reversed entry → expects YEAR_END_ALREADY_CLOSED).
- A @DataJpaTest (or the existing integration harness) that inserts two YEAR_END_CLOSE journal_entry rows with the same (org_id, source_id), is_reversal=FALSE, is_reversed=FALSE and asserts the second insert throws a DataIntegrityViolation, proving the partial unique index backstops the double-close.

```sql
CREATE UNIQUE INDEX uq_je_year_end_close ON public.journal_entry (org_id, source_module, source_id) WHERE source_module = 'YEAR_END_CLOSE' AND is_reversal = FALSE AND is_reversed = FALSE;
```

---

### MFG_ACCT-9. [MEDIUM] createBomVersion leaves the old version's rows live (not soft-deleted), and every unversioned BOM read has no version filter — after one 'create BOM version' click all BOM consumers see v1+v2 rows and double every component quantity and cost
`PARTIAL · migration`
**Fix applied:** Two coordinated changes are required because the unique index and multi-version history are currently incompatible.\n\n1) Flyway migration (needed): make the unique index version-aware so multiple live BOM versions can coexist as history: DROP the old index and recreate it including version. See migrationDdl.\n\n2) Make the DEFAULT (unversioned) BOM reads return only the LATEST version — otherwise once the migration lets v1+v2 both stay live, the finding's doubling becomes REAL. Add a repository query that returns the current version's rows, e.g. in BomComponentRepository:\n   @Query(\"SELECT b FROM BomComponent b WHERE b.orgId=:orgId AND b.parentItemId=:parentItemId AND b.isDeleted=false AND b.version=(SELECT COALESCE(MAX(b2.version),1) FROM BomComponent b2 WHERE b2.orgId=:orgId AND b2.parentItemId=:parentItemId AND b2.isDeleted=false) ORDER BY b.createdAt\") List<BomComponent> findCurrentBom(...).\n   Route every 'current BOM' consumer through it (they currently call findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc): ManufacturingService createWorkOrder default branch (line 156), 757, 830, 1282, scrapPercentByChild (2166), substituteWorkOrderLine, rollupChildren (2250/2279/2326); BomService.explode/rollup (153/211/285); InventoryService (475, 630 — invoice-time composite stock deduction); MrpService.explosion (204). Version-specific reads (getBomVersion / diffBomVersions) keep using the version-scoped finder and now legitimately see historical versions since old rows stay live.\n   Also make the addComponent duplicate guard version-aware (existsByOrgIdAndParentItemIdAndChildItemIdAndIsDeletedFalse must be scoped to the current max version) so editing a new version isn't blocked by an old-version row.\n\n3) In createBomVersion, copy scrapPercent and variantFilter into the new BomComponent.builder() (and set effectiveFrom/version as today). Do NOT soft-delete the old rows (they are the history the version-scoped readers need).\n\n(If keeping history in the not-deleted table is deemed too invasive, the alternative is: soft-delete old rows in createBomVersion AND change getBomVersion/diffBomVersions to read isDeleted-inclusive — but the version-in-index approach above is cleaner and matches the finding's second suggestion.)\n\nRegression test (must hit a real DB / @DataJpaTest so the unique index is enforced — a mocked repo hides the whole bug): create a COMPOSITE item with 2 components (one with non-zero scrapPercent and a variantFilter), call createBomVersion, then assert: (a) no exception is thrown; (b) findCurrentBom returns exactly 2 rows at version 2 (not 4); (c) createWorkOrder(bomVersion=null) materializes 2 lines with un-doubled quantities and rawMaterialCost; (d) the new-version rows carry the original scrapPercent and variantFilter; (e) getBomVersion(1) still returns the original 2 rows (history preserved).

```sql
DROP INDEX IF EXISTS idx_bom_component_unique;
CREATE UNIQUE INDEX idx_bom_component_unique ON public.bom_component USING btree (parent_item_id, child_item_id, version) WHERE (NOT is_deleted);
```

---

### MFG_ACCT-10. [MEDIUM] postVendorPayment books payment-level TDS on the wrong side: it DEBITS TDS Payable and credits cash for the full amount, under-debiting AP and wiping the TDS liability before remittance
`CONFIRMED`
**Fix applied:** Fix the journal shape in AccountingPostingEngine.postVendorPayment non-FX branch to the accounting-correct payment-time-withholding form and keep it consistent with the subledger reduction (bill is reduced by the full amountApplied, so AP must be debited by the full amount): change lines 421-424 to `apDebitBase = amount; paidBase = amount.subtract(tdsAmount);` (face amounts — payRate is legitimately ignored here since fxApplies is false whenever tds>0). Then change the TDS line (lines 433-439) from a debit to a CREDIT: `new JournalLineRequest(defaultAccountService.getCode(orgId, DefaultAccountPurpose.TDS_PAYABLE), BigDecimal.ZERO, tdsAmount, "TDS: " + paymentNumber, null, null)`. Resulting journal: DR AP amount / CR Cash (amount−tds) / CR TDS Payable tds — balances, clears the AP control by the same amount the subledger drops, and books the govt liability. IMPORTANT design decision to document in the method javadoc (currently lines 45-53 describe the wrong shape and must be updated): the system convention is TDS-at-BILL-time (TdsService auto-deducts on PurchaseBillService create/update, balanceDue = total − TDS, bill posting already CR TDS Payable). Payment-time tdsAmount therefore double-counts TDS for a bill that already withheld it. Preferred belt-and-braces: additionally guard in VendorPaymentService.recordPayment — reject a positive request.tdsAmount when the allocated bill(s) already carry bill-time TDS (throw a BusinessException e.g. AP_TDS_ALREADY_WITHHELD), so payment-level TDS is only accepted for bills that were booked gross. No Flyway migration needed (2030 TDS_PAYABLE already seeded). Regression test: replace/extend PaymentForexPostingTest.vendor_tdsPresent_keepsLegacyPathEvenWithRates to assert the corrected shape — 3 lines, DR AP 3000 (lines.get(0).debit()), CR TDS Payable 30 on the 2030 account, CR bank 2970 — and assert totalDebit==totalCredit; add a case asserting the AP debit equals the sum of amountApplied so the subledger/GL consistency is locked in.

---

### MFG_ACCT-11. [LOW] mergeWorkOrders silently discards the sources' planned direct-labor and overhead costs, undervaluing the merged WO's WIP journal and FG cost
`CONFIRMED`
**Fix applied:** In ManufacturingService.mergeWorkOrders, before the createWorkOrder call at line 557, sum the sources' conversion costs mirroring how totalQty is summed: BigDecimal totalLabor = sources.stream().map(WorkOrder::getDirectLaborCost).filter(Objects::nonNull).reduce(BigDecimal.ZERO, BigDecimal::add); BigDecimal totalOverhead = sources.stream().map(WorkOrder::getOverheadCost).filter(Objects::nonNull).reduce(BigDecimal.ZERO, BigDecimal::add); then pass totalLabor, totalOverhead in place of the two BigDecimal.ZERO arguments at line 559. Summing (not averaging) is correct because the merged WO produces the summed quantity, so it should carry the summed planned conversion cost. No migration needed — this is pure service logic over existing entity fields. Regression test: add to ManufacturingServiceTest a case that merges two same-FG DRAFT WOs each with directLaborCost=5000/overheadCost=2000 and asserts the merged WO's directLaborCost=10000, overheadCost=4000, and totalCost = summedRmCost + 14000 (mirrors the existing 'merge consolidates two same-FG DRAFTs' test but adds the cost assertions).

---

### MFG_ACCT-12. [LOW] postJournal validates double-entry balance BEFORE per-line setScale(2, HALF_UP) rounding, so a raw-balanced request with sub-paise amounts persists rounded lines that no longer balance and dies at commit as an opaque DB-trigger 500 instead of a clean 400
`CONFIRMED`
**Fix applied:** In JournalService.postJournal, round each line's debit/credit to 2dp HALF_UP ONCE up front and use those rounded values for BOTH the balance/zero check AND persistence, so the gate validates exactly what it writes. Concretely: before the Step-3 balance block, build a parallel list of rounded amounts (e.g. for each JournalLineRequest compute rd = line.debit().setScale(2, HALF_UP), rc = line.credit().setScale(2, HALF_UP)); sum rd/rc for totalDebit/totalCredit and run the existing compareTo imbalance + zero checks against those; then in the Step-9 line loop set .debit(rd).credit(rc) (and .baseDebit(rd.multiply(rate).setScale(2, HALF_UP)) / .baseCredit likewise) reusing the same rounded figures. This turns the sub-paise case into a clean ACCT_JOURNAL_IMBALANCE 400 before any persistence. Additionally (belt-and-suspenders, cleaner client error) add @Digits(integer = 13, fraction = 2) to the debit and credit fields on JournalLineRequest so >2dp input is rejected at bean-validation as a 400 with a clear message. No Flyway migration needed (numeric(15,2) columns + trigger already correct). Regression test: add to accounting/service/JournalServiceTest a case posting a JournalPostRequest with lines [DR 0.005, DR 0.005, CR 0.01], autoPost=true, asserting a BusinessException with code ACCT_JOURNAL_IMBALANCE (HttpStatus.BAD_REQUEST) is thrown and journalEntryRepository.save is never invoked — i.e. the imbalance is caught pre-persistence, not via the DB trigger; and a companion case [DR 100.005, CR 100.005] that still posts successfully (symmetric rounding stays balanced).

---


## Inventory + POS + Sales
**Fix commit 4/8 · 628e044** — 16 findings (high 4, medium 9, low 3)

### INV-1. [HIGH] Cross-tenant IDOR: GET /api/v1/picklists/by-sales-order/{salesOrderId} returns any org's picklists — no org filter
`CONFIRMED`
**Fix applied:** Two-line fix, no migration needed. (1) In PicklistRepository add: `List<Picklist> findBySalesOrderIdAndOrgIdAndIsDeletedFalse(UUID salesOrderId, UUID orgId);` (2) In PicklistService.listBySalesOrder (L115-118) change the body to: `UUID orgId = TenantContext.getCurrentOrgId(); return picklistRepository.findBySalesOrderIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId).stream().map(this::toResponseWithNames).toList();` — mirroring findOrThrow's scoping. Optionally delete the now-unused findBySalesOrderIdAndIsDeletedFalse method to prevent future misuse (confirm no other caller via grep first). Regression test to add in PicklistServiceTest: seed a picklist under orgA for salesOrderId X; set TenantContext to orgB; assert listBySalesOrder(X) returns an empty list (and, with TenantContext orgA, returns the picklist). This mirrors the tenancy-scoping assertions already present for get()/list().

---

### INV-2. [HIGH] Delivery challan flow allows over-dispatch: draft challans aren't counted at create and dispatch() never re-validates shippable quantity, enabling double stock deduction and double invoicing
`CONFIRMED`
**Fix applied:** Primary fix (no migration): in DeliveryChallanService.dispatch(), before mutating quantityShipped, re-validate each line against the order quantity. Inside the for-loop at ~line 160, after resolving soLine, compute BigDecimal newShipped = soLine.getQuantityShipped().add(line.getQuantity()); if (newShipped.compareTo(soLine.getQuantity()) > 0) throw new BusinessException(String.format("Dispatch would exceed ordered qty for %s: Ordered=%.2f, AlreadyShipped=%.2f, ThisChallan=%.2f", desc, soLine.getQuantity(), soLine.getQuantityShipped(), line.getQuantity()), "DC_EXCEEDS_ORDERED", HttpStatus.BAD_REQUEST); then setQuantityShipped(newShipped). This closes the double-invoice path because it caps cumulative quantityShipped at the order qty.\n\nDefence-in-depth in create(): make the shippableQty computation subtract the sum of line quantities on other non-cancelled/non-deleted DRAFT+DISPATCHED challans for the same soLineId (add a DeliveryChallanLineRepository/DeliveryChallanRepository query summing line.quantity by salesOrderLineId across challans whose status not in (CANCELLED) and isDeleted=false, minus the shipped already counted), so two full-qty drafts can't both be created.\n\nConcurrency hardening: change findOrThrow's lookup used by dispatch() to a PESSIMISTIC_WRITE variant (add DeliveryChallanRepository.findByIdAndOrgIdAndIsDeletedFalseForUpdate with @Lock(LockModeType.PESSIMISTIC_WRITE)) and call it in dispatch() so the DRAFT->DISPATCHED transition serialises; the same lock protects concurrent dispatch of one challan. This needs no schema change (no @Version column).\n\nRegression tests in sales/service/DeliveryChallanServiceTest.java: (1) create two DRAFT challans each for the full SO line qty, dispatch the first, then assert the second dispatch throws DC_EXCEEDS_ORDERED and quantityShipped stays at the order qty; (2) assert convertToInvoice cannot exceed order qty after the fix; (3) create()-level test that a second full-qty draft is rejected once one open draft exists (DC_EXCEEDS_AVAILABLE), verifying open drafts are counted.

---

### INV-3. [HIGH] Transfer-order cancel returns in-transit stock at item.purchasePrice instead of the shipped cost — a cancelled warehouse move creates/destroys inventory value
`CONFIRMED`
**Fix applied:** Fix in TransferOrderService.cancel(), IN_TRANSIT branch (L202-217). Preferred: reverse the original TRANSFER_OUT movements exactly rather than posting a fresh costed TRANSFER_IN. Query the shipment's out legs and reverse each: for each StockMovement of this TO with movementType=TRANSFER_OUT and reversal=false (via a repo lookup by referenceType=STOCK_TRANSFER, referenceId=to.getId(), movementType=TRANSFER_OUT — mirror the existing stockMovementRepository access used in receive()), call inventoryService.reverseMovement(movement.getId(), \"Transfer cancelled — stock returned\"). This restores the exact FIFO lots at original.getUnitCost(), marks the out legs reversed (fixing the skewed sumCostAndQtyByReferences map too), and re-enters the from-warehouse at the correct cost. Minimal alternative (if adding a repo query is undesirable): mirror receive()'s shippedUnitCost computation verbatim inside cancel() — build the Map<UUID,BigDecimal> from stockMovementRepository.sumCostAndQtyByReferences(orgId, ReferenceType.STOCK_TRANSFER, List.of(to.getId()), MovementType.TRANSFER_OUT) and pass shippedUnitCost.get(line.getItemId()) as the TRANSFER_IN unitCost instead of null (L209). This preserves total value but opens a new lot rather than restoring the exact original lots, and does not mark the TRANSFER_OUT rows reversed — so the reverseMovement approach is strictly better. No Flyway migration required (pure service logic; stock_movement schema unchanged). Regression test: add to inventory/service/TransferOrderServiceTest.java a case for a FIFO org — create item with purchasePrice=150, seed/ship stock whose consumed lots cost 100 (TRANSFER_OUT records unitCost≈100), then cancel() the IN_TRANSIT order and assert the returning TRANSFER_IN (or reversal) movement carries unitCost≈100 (not 150) and that the from-warehouse StockBalance total value is unchanged versus pre-ship (round-trip nets to zero value change). Also assert the original TRANSFER_OUT movement(s) are marked reversed if the reverseMovement fix is chosen.

---

### INV-4. [HIGH] Voided (RETURNED) POS receipts are still counted in GSTR-1 B2CS/HSN, GSTR-3B outward tax, and CMP-08 turnover — GST returns overstate output tax after a POS void
`CONFIRMED`
**Fix applied:** No Flyway migration needed — this is a JPQL filter fix. Add two dedicated repo methods on SalesReceiptRepository that exclude returned rows (do NOT edit the shared findByOrgAndDateRange / sumTotalByOrgAndDateRange, which dashboards, SummaryCacheWarmer, and OperationalReportService also call — changing those is a broader behavioural change best kept out of this fix):

  @Query("SELECT r FROM SalesReceipt r WHERE r.orgId = :orgId AND r.isDeleted = false AND r.status <> 'RETURNED' AND r.receiptDate BETWEEN :from AND :to ORDER BY r.receiptDate DESC, r.createdAt DESC")
  List<SalesReceipt> findCompletedByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

  @Query("SELECT COALESCE(SUM(r.total), 0) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate BETWEEN :from AND :to AND r.isDeleted = false AND r.status <> 'RETURNED'")
  BigDecimal sumCompletedTotalByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

Then repoint the three GST/composition call sites:
  - GstService.generateGstr1 line 95: findByOrgAndDateRange → findCompletedByOrgAndDateRange
  - GstService.generateGstr3b line 581: findByOrgAndDateRange → findCompletedByOrgAndDateRange
  - CompositionService.cmp08 line 83: sumTotalByOrgAndDateRange → sumCompletedTotalByOrgAndDateRange

Regression tests: extend GstServiceTest — seed one COMPLETED and one RETURNED POS receipt in the same period, assert GSTR-3B net outward taxable/CGST/SGST/IGST and GSTR-1 B2CS totals reflect ONLY the COMPLETED receipt. Extend CompositionServiceTest.cmp08 — assert a RETURNED receipt's total is excluded from composition turnover/tax. (Optional follow-up, out of scope for this fix: dashboard POS-sales figures also read the shared sum and thus overstate revenue after a return — flag separately since the ledger is already correct via the reversal journal.)

---

### INV-5. [MEDIUM] Cash register expected-closing and all POS sales sums include RETURNED (voided) receipts — false drawer variance and overstated sales
`CONFIRMED`
**Fix applied:** Add a status guard to every aggregate sum/count in SalesReceiptRepository so RETURNED receipts stop contributing. On each of the JPQL aggregate queries (lines 56-69, 71-94, 101-102, 104-105, and the contact sum at 137-147 for consistency) append `AND (r.status IS NULL OR r.status <> 'RETURNED')`. Example: `sumByOrgDateAndMode` becomes `... AND r.paymentMode = :mode AND r.isDeleted = false AND (r.status IS NULL OR r.status <> 'RETURNED')`. Apply identically to sumTotalByOrgAndDate, countByOrgAndDate, sumTotalByOrgAndDateRange, sumTotalByOrgBranchAndDateRange, countByOrgAndDateRange, countByOrgBranchAndDateRange, sumTotalByBranch, sumTotalDailyByOrg, sumTotalByContact. (findFiltered is a list view, not a money aggregate — leave it, or optionally surface status so returns are visible; not required for correctness.)
No Flyway migration needed — the status column already exists and is populated (default 'COMPLETED', set to 'RETURNED' by voidReceipt); this is a pure query change.
Regression tests: (a) CashRegisterServiceTest — open a register (opening 1000), record a CASH receipt 500 dated today, then voidReceipt it same day; assert buildSummary().cashSales == 0 and expectedClosing == 1000 (currently 500 / 1500). (b) A repository slice test (@DataJpaTest) persisting one COMPLETED and one RETURNED CASH receipt for the same org/date and asserting sumByOrgDateAndMode and sumTotalByOrgAndDate exclude the RETURNED row's amount and countByOrgAndDate excludes it. Note in the test/comment that next-day return drawer cash-out remains a separate unhandled gap.

---

### INV-6. [MEDIUM] Concurrent convertToInvoice double-invoices the same shipped quantity — SO line quantityInvoiced gate is check-then-act with no lock
`CONFIRMED`
**Fix applied:** Serialize per-SO by loading the order under a write lock at the top of convertToInvoice. 1) Add a locked finder to SalesOrderRepository: `@Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select s from SalesOrder s where s.id = :id and s.orgId = :orgId and s.isDeleted = false") Optional<SalesOrder> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);` (import jakarta.persistence.LockModeType + org.springframework.data.jpa.repository.Lock). 2) In SalesOrderService.convertToInvoice (currently line 465), replace `SalesOrder so = findOrThrow(soId, orgId);` with a call that uses the new locked finder: `SalesOrder so = salesOrderRepository.findByIdAndOrgIdForUpdate(soId, orgId).orElseThrow(() -> BusinessException.notFound("Sales Order", soId));`. The @Transactional method already exists, so the PESSIMISTIC_WRITE lock is held until commit; the second concurrent conversion blocks on the row lock, then re-reads the now-incremented quantityInvoiced and correctly fails the remaining-check (SO_INVOICE_EXCEEDS_SHIPPED). No schema/Flyway change needed — locking is query-level. Regression test: add to SalesOrderServiceTest a test that drives two convertToInvoice calls for the full shipped qty and asserts exactly one invoice is created and the second throws SO_INVOICE_EXCEEDS_SHIPPED (a unit test can assert the service now calls findByIdAndOrgIdForUpdate rather than the unlocked finder; a true concurrency assertion belongs in an integration test with two threads sharing the row). Optionally also lock in the SO→DC dispatch/ship path if quantityShipped mutation shows the same race, but that is out of scope for this finding.

---

### INV-7. [MEDIUM] Concurrent voidReceipt double-reverses the POS journal and double-restocks — status guard and both reversal primitives are unlocked check-then-act
`CONFIRMED`
**Fix applied:** Add a pessimistic-lock read of the receipt at the top of voidReceipt, mirroring PaymentService.voidPayment / BankReconciliationService.acceptMatch. 1) In SalesReceiptRepository add: @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("SELECT r FROM SalesReceipt r WHERE r.id = :id AND r.orgId = :orgId AND r.isDeleted = false") Optional<SalesReceipt> findByIdAndOrgIdForUpdate(@Param("id") UUID id, @Param("orgId") UUID orgId); (imports jakarta.persistence.LockModeType + org.springframework.data.jpa.repository.Lock). 2) In SalesReceiptService.voidReceipt replace the line-403 findByIdAndOrgIdAndIsDeletedFalse call with findByIdAndOrgIdForUpdate, keeping the same orElseThrow. The existing "RETURNED".equals(receipt.getStatus()) guard at 406 then serialises: the second concurrent void blocks on the row lock until the first commits, re-reads status=RETURNED and throws SR_ALREADY_RETURNED. No Flyway migration required (the receipt row lock alone closes the window; the inner reverseEntry/reverseMovement no longer see a second caller). Optionally, as defence-in-depth, a follow-up migration could add unique partial indexes on journal_entry(reversal_of_id) WHERE reversal_of_id IS NOT NULL and stock_movement(reversal_of_id) WHERE reversal_of_id IS NOT NULL, but that is not needed for this fix and could collide with any legitimate multi-reversal semantics elsewhere, so keep it out of scope. Regression test (new SalesReceiptVoidConcurrencyTest or add to existing SalesReceipt test): stub the repo so the first findByIdAndOrgIdForUpdate returns a POSTED receipt and assert that a second invocation after status flips to RETURNED throws SR_ALREADY_RETURNED (unit level); and/or a @SpringBootTest with two parallel threads calling voidReceipt on the same receipt id asserting exactly one reversal journal + one reversal movement are created and the second call fails with SR_ALREADY_RETURNED.

---

### INV-8. [MEDIUM] Direct-invoice SALE movements record the SALE price as unit cost — corrupts FIFO fallback COGS and weighted-average cost on reversal (POS path was fixed; invoice path was not)
`CONFIRMED`
**Fix applied:** In InventoryService.buildInvoiceSaleRequest (line 587) replace line.getUnitPrice() with null as the 5th (unitCost) argument, mirroring the BOM-child branch (L506) and the DC-dispatch path (DeliveryChallanService:180). With null, recordMovement falls back to item.getPurchasePrice() for the weighted-average path (correct COGS basis and no reversal re-blend inflation) and to purchasePrice for the FIFO uncovered-slice fallback (L137). No Flyway migration needed (behavioural change only; stock_movement is append-only, historical rows keep their recorded cost). Optional parity upgrade: to match the POS bill-freely fix, inject CostResolverService and pass costResolver.resolve(item, orgId) so a zero-purchase-price item resolves cost via MRP-minus-margin instead of booking 0 — but the minimal, provably-correct fix is passing null. Regression tests to add in InventoryServiceFefoTest: (a) deductStockForInvoice on a non-batch weighted-average item with purchasePrice=₹100 and line unitPrice=₹150 records a SALE stock_movement whose unitCost==100 (assert it is NOT 150); (b) reverse that SALE movement and assert stock_balance.averageCost is unchanged (no upward re-blend). Also add a FIFO case: a direct-invoice sale exceeding available lots records the uncovered slice at purchasePrice, not sale price.

---

### INV-9. [MEDIUM] Double-submit TOCTOU on TransferOrderService.ship()/receive() and StockCountService.post() — status check-then-act with no lock and no @Version → duplicate stock movements
`CONFIRMED`
**Fix applied:** Add a pessimistic-write finder to both repositories and use it in the mutating lifecycle methods so a concurrent second submit blocks on the row lock and then sees the flipped status.

1) TransferOrderRepository: add
   @Lock(LockModeType.PESSIMISTIC_WRITE)
   @Query("SELECT t FROM TransferOrder t WHERE t.id = :id AND t.orgId = :orgId AND t.isDeleted = false")
   Optional<TransferOrder> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);
   (imports: org.springframework.data.jpa.repository.Lock, jakarta.persistence.LockModeType)

2) StockCountRepository: add the analogous findByIdAndOrgIdForUpdate for StockCount.

3) TransferOrderService: in ship(), receive(), and cancel(), replace the findOrThrow(id, orgId) load with a locking variant — e.g. add a private helper findForUpdate(id, orgId) that calls transferOrderRepository.findByIdAndOrgIdForUpdate(...).orElseThrow(...). Keep get()/list() on the plain finder. The status guard immediately after the locked load then correctly rejects the loser (TO_NOT_DRAFT / TO_NOT_IN_TRANSIT / TO_ALREADY_RECEIVED).

4) StockCountService: in post() (and, for symmetry, cancel()), load via stockCountRepository.findByIdAndOrgIdForUpdate(...) instead of findOrThrow so the second concurrent post reads status=POSTED and throws SC_NOT_DRAFT.

Because both services are already @Transactional, the row lock is held to commit; the second transaction blocks at the locked SELECT, then re-reads the committed IN_TRANSIT/POSTED row and its guard throws. No Flyway migration required (runtime locking only; no schema change — a @Version column would be an alternative but is a larger, cross-cutting change to BaseEntity).

Regression test (add to TransferOrderServiceTest and StockCountServiceTest): a structural guard asserting the lifecycle path uses the locking finder — verify(transferOrderRepository).findByIdAndOrgIdForUpdate(id, orgId) is invoked by ship()/receive() and never findByIdAndOrgIdAndIsDeletedFalse for those methods; likewise post() on StockCountService. For a true race assertion, an @DataJpaTest / Testcontainers integration test that runs two concurrent ship() calls on one DRAFT TO on a real Postgres and asserts exactly one succeeds (the other throws TO_NOT_DRAFT) and only one TRANSFER_OUT movement set exists.

---

### INV-10. [MEDIUM] POS receipt with taxInclusive=false/null credits forward-computed tax out of a total that never includes it — GST over-remitted and revenue understated
`CONFIRMED`
**Fix applied:** Fix in SalesReceiptService.create so the receipt is coherent under both interpretations. Two coordinated changes: (1) Default a null taxInclusive to true (POS/MRP retail semantics — rate is the tax-inclusive shelf price), matching the Flutter client and the pharma MRP model: change line 203 to `boolean isTaxInclusive = !Boolean.FALSE.equals(lineReq.taxInclusive());`. (2) Make the explicit-exclusive path (taxInclusive==false) genuinely exclusive by adding the line tax to the amount charged, so total = subtotal + tax rather than the hybrid. Concretely, compute a per-line `lineGrossCharged`: for the inclusive branch it stays `lineAmount` (tax already inside); for the exclusive branch it becomes `lineAmount.add(lineTax)`. Accumulate `grossTotal` from `lineGrossCharged` (not raw lineAmount) and keep subtotal = grossTotal - totalTax; by construction subtotal then equals Σ taxableBase and total = subtotal + totalTax in both branches. Leave `line.amount` = lineAmount (the entered rate×qty) as-is and keep taxableBase feeding the tax_line_item (already correct: back-calc for inclusive, lineAmount for exclusive). No DTO/schema change; no Flyway migration (the sales_receipt columns already exist). Regression test to add — new PosReceiptTaxTest (or extend an existing POS test) posting through SalesReceiptService.create with a line rate 100 qty 1 and an 18% tax group: (a) taxInclusive omitted (null) → assert receipt.subtotal ≈ 84.75, taxAmount ≈ 15.25, total == 100 (inclusive default); (b) taxInclusive=false explicit → assert subtotal == 100, taxAmount == 18, total == 118 (coherent exclusive); (c) taxInclusive=true → unchanged 84.75/15.25/100. Also assert, in each case, that Σ(tax_line_item.taxableAmount) == receipt.subtotal so the header and the tax rows can never diverge again.

---

### INV-11. [MEDIUM] ProvisionalCostReconciler REQUIRES_NEW journal survives a rolled-back GRN receive, and DRAFT-GRN cancellation never reverts it — orphan true-up journal nothing will ever reverse
`CONFIRMED`
**Fix applied:** Primary fix (fully closes the orphan): defer reconciliation to after the receive() transaction commits, so it only runs when the GRN is durably RECEIVED. In StockReceiptService.receive(): instead of calling provisionalCostReconciler.reconcileForItem(...) synchronously inside the per-line loop (300-309), collect the reconcile inputs (orgId, item.getId(), landedUnitCost, receipt.getReceiptNumber(), receipt.getId()) into a local List during the loop, then register ONE org.springframework.transaction.support.TransactionSynchronization via TransactionSynchronizationManager.registerSynchronization(...) whose afterCommit() iterates the list and calls reconcileForItem per item (keep the existing per-item try/catch so a reconcile hiccup is logged, not thrown — afterCommit runs on the request thread while TenantContext is still populated, and reconcileForItem takes orgId as a param and stays @Transactional(REQUIRES_NEW), opening a fresh tx). On rollback, afterCommit never fires, so no orphan JE/stamps are ever committed. This is the same after-commit pattern already used for POS WhatsApp auto-send. No behavioural change on the happy path (reconcile still fires once per item, first-call-wins since it settles all pending rows). No regression on reconcile failure: its REQUIRES_NEW tx rolls back, stamps stay null, a future GRN re-reconciles — same as today. Defensive complement (cheap, handles a manually-cancelled orphaned DRAFT from any legacy state): in cancel(), move the provisionalCostReconciler.revertSettlementForGrn(receipt.getId()) call OUT of the if(wasReceived) block so it runs on every cancel — it is idempotent (no-op when no settlement rows match the grnId), so a normal DRAFT cancel with no orphan is unaffected. No Flyway migration needed — StockMovement.costSettledAt/costSettledByGrnId already exist (V5). Regression test (StockReceiptServiceTest): construct a multi-line DRAFT GRN where line 1's item has an unsettled provisional SALE and a later line forces a failure (e.g. batch-tracked item with a blank batch number -> GRN_BATCH_REQUIRED); call receive(), assert it throws AND verify(provisionalCostReconciler, never()).reconcileForItem(...) fired synchronously (with deferral it is only registered, and afterCommit never runs under a rolled-back/aborted tx in the test). Add a second test: a clean multi-line receive that commits DOES invoke reconcileForItem for the item with pending SALEs (afterCommit path). Plus a cancel() test asserting revertSettlementForGrn is invoked for a DRAFT cancel (defensive fix).

---

### INV-12. [MEDIUM] createFromEstimate silently drops line tax — the resulting SO and its downstream invoice bill zero GST for a taxed, accepted estimate
`CONFIRMED`
**Fix applied:** Preserve the estimate's per-line tax through the SO so the existing SO→Invoice rate-fallback picks it up.

1) `sales/dto/SalesOrderLineRequest.java`: add an optional trailing field `BigDecimal gstRate` (raw percent, e.g. 18). Keep it nullable; compact constructor unchanged. Update all existing construction/deserialization sites to pass null (the estimate path passes the real value). NOTE: this record is also built in the normal `create` REST flow and in `duplicate`/mapping at SalesOrderService line ~952 — pass null there to preserve current behaviour.

2) `SalesOrderService.create()` (lines 163-169): when `lr.taxGroupId() == null` but the new `lr.gstRate()` is non-null and > 0, resolve a group mirroring the invoice path — `UUID resolvedGroup = taxEngine.resolveGroupId(orgId, lr.gstRate(), org.getStateCode(), so.getPlaceOfSupply()).orElse(null)` (fetch `org` via organisationRepository as InvoiceService does, or reuse an existing reference) — then run `taxEngine.calculate(orgId, resolvedGroup, lineAmount, SALE)` and set `taxRate`/accumulate `totalTax` exactly as the taxGroupId branch does; also set the SO line's `taxGroupId(resolvedGroup)`. If resolveGroupId returns empty, fall back to a direct arithmetic tax so nothing is lost: `lineTax = lineAmount × gstRate/100`, `taxRate = gstRate`. Ensure `SalesOrderLine.taxRate` ends up = gstRate so `convertToInvoice` (line 504) forwards a positive gstRate → the invoice's resolveGroupId fallback (InvoiceService 299-302) recomputes tax correctly.

3) `SalesOrderService.createFromEstimate()` (lines 257-261): pass `el.getTaxRate()` into the new `gstRate` slot of each `SalesOrderLineRequest` (taxGroupId stays null — estimates have no group).

No Flyway migration: SalesOrderLine already has `tax_rate` and `tax_group_id` columns (used elsewhere); this only populates them.

Regression test (add to SalesOrderServiceTest, or a new EstimateToSalesOrderTest): build an ACCEPTED Estimate with one line taxable ₹100 @ taxRate 18 (estimate taxAmount 18); stub `taxEngine.resolveGroupId(...)` to return a group and `taxEngine.calculate(...)` to return 18; call `createFromEstimate(estimateId)`; assert the created SO's `taxAmount` == 18, `total` == 118, and the persisted SO line's `taxRate` == 18. Add a second assertion for the arithmetic fallback: with `resolveGroupId` empty, taxAmount still == 18 and line.taxRate == 18 (guards against a group not existing for the rate). Optionally chain `convertToInvoice` and assert the invoice line tax is non-zero.

---

### INV-13. [MEDIUM] recordMovement never validates that batchId belongs to the movement's item (or even this org) — explicit batch picks can corrupt another item's / another org's batch ledger
`CONFIRMED`
**Fix applied:** In InventoryService.recordMovement, right after step 3b's flag checks (around line 118), when `request.batchId() != null` load the batch org-scoped and assert it belongs to this item:

  if (request.batchId() != null) {
      StockBatch batch = stockBatchRepository
          .findByIdAndOrgIdAndIsDeletedFalse(request.batchId(), orgId)
          .orElseThrow(() -> BusinessException.notFound("StockBatch", request.batchId()));
      if (!batch.getItemId().equals(item.getId())) {
          throw new BusinessException(
              "Batch " + batch.getBatchNumber() + " belongs to a different item",
              "INV_BATCH_ITEM_MISMATCH", HttpStatus.BAD_REQUEST);
      }
  }

Add `private final StockBatchRepository stockBatchRepository;` to InventoryService (constructor is Lombok-generated). This guard sits at the single gate so it protects every batch-movement caller (invoice explicit-pick, DC dispatch, credit-note RETURN_IN, manufacturing), not just the invoice path. It also incidentally rejects nonexistent/foreign-org batch UUIDs (notFound) since findByIdAndOrgId is org-scoped, closing the phantom-row credit-note case.

Regression test (InventoryServiceTest or a new InventoryServiceBatchGuardTest): seed item A (trackBatches=true) and item B with a batch belonging to B; build a StockMovementRequest with itemId=A.id and batchId=B.batch.id; assert recordMovement throws BusinessException with code INV_BATCH_ITEM_MISMATCH and that neither StockBatchBalance nor stock_movement was written. Add a happy-path assertion that a batchId belonging to A passes. No Flyway migration required.

---

### INV-14. [LOW] Consignment settlement numbers generated from a GLOBAL row count — cross-org collisions/duplicates under concurrency and a tenant-volume information leak
`CONFIRMED · migration`
**Fix applied:** 1) Add an org-scoped sequence query to ConsignmentSettlementRepository, mirroring TransferOrderRepository.nextSequence:
   @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(s.settlementNumber, LENGTH(:prefix) + 2) AS int)), 0) + 1 FROM ConsignmentSettlement s WHERE s.orgId = :orgId AND s.settlementNumber LIKE CONCAT(:prefix, '-%')")
   int nextSequence(UUID orgId, String prefix);
2) Rewrite ConsignmentService.generateSettlementNumber(orgId) to:
   String prefix = "CS-" + LocalDate.now().getYear();
   int seq = settlementRepo.nextSequence(orgId, prefix);
   return String.format("%s-%06d", prefix, seq);
   (drops the global count() entirely; format matches TO-/PL- so the SUBSTRING offset LENGTH(prefix)+2 lines up).
3) Migration (assign next free version centrally): add a unique partial index as the concurrency backstop (MAX+1 still has a residual race — the index makes the losing concurrent insert fail loudly instead of persisting a duplicate, exactly the V21 pattern for network_order/job_work_order/NCR):
   CREATE UNIQUE INDEX uq_consignment_settlement_org_number ON consignment_settlement (org_id, settlement_number) WHERE settlement_number IS NOT NULL AND NOT is_deleted;
4) Regression test — add to a ConsignmentServiceTest: mock settlementRepo.nextSequence(orgA, "CS-<year>") -> 1 and assert recordSale() produces "CS-<year>-000001"; assert generateSettlementNumber never calls settlementRepo.count(); and assert two different orgIds each start their sequence at 1 (proving per-org scoping / no global leak).

```sql
CREATE UNIQUE INDEX uq_consignment_settlement_org_number ON consignment_settlement (org_id, settlement_number) WHERE settlement_number IS NOT NULL AND NOT is_deleted;
```

---

### INV-15. [LOW] POS receipt contactId is never org-validated for CASH/UPI/CARD modes — a foreign org's contact can be attached and receives the receipt SMS/WhatsApp
`PARTIAL`
**Fix applied:** Two-part fix, no migration. (1) Validate contactId org-scoped for ALL payment modes at the top of create(). After resolving orgId (after line 112), add: if (request.contactId() != null) { contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId).orElseThrow(() -> BusinessException.notFound("Contact", request.contactId())); }. Keep the CREDIT-specific block (customer-type check) as-is; it can reuse the already-fetched contact or leave it — the added guard makes a foreign/deleted contactId impossible to persist. (2) Defense-in-depth on the read paths so existing/legacy rows can't leak either: in toResponse() (line 559) change contactRepository.findById(receipt.getContactId()) to contactRepository.findByIdAndOrgIdAndIsDeletedFalse(receipt.getContactId(), orgId) (orgId already = receipt.getOrgId() at line 555); in the SMS block (line 372) change contactRepository.findById(smsContactId) to contactRepository.findByIdAndOrgIdAndIsDeletedFalse(smsContactId, orgId). Do NOT touch the WhatsApp path — it is already org-scoped. Regression test (add to a SalesReceiptService test, e.g. new PosReceiptContactTenancyTest): (a) create() with paymentMode=CASH and a contactId belonging to a different org throws BusinessException with code/notFound for "Contact" and persists no receipt; (b) create() with a valid same-org contactId still succeeds and the SMS lookup resolves; (c) a receipt row carrying a foreign contactId (constructed directly) rendered through toResponse() returns contactName == null (no cross-tenant leak).

---

### INV-16. [LOW] Phantom-composite BOM children are silently skipped on invoice stock deduction — BomService.explode() (the phantom flattener) has zero production callers
`PARTIAL`
**Fix applied:** Two viable fixes; pick one. (A) Make the current unsupported-ness explicit and safe: in BomService.addComponent, tighten the guard to reject ALL composite children including phantoms until the sales path supports them — change `if (child.getItemType()==COMPOSITE && !child.isPhantom()) throw BOM_NESTED_NOT_SUPPORTED` to reject any COMPOSITE child (drop the phantom exemption), AND correct the explode() javadoc which currently lies ('Called from InventoryService#deductStockForInvoice') to note it is presently used only by MRP/planning, not the sales ledger path. (B) Actually wire it: route both InventoryService.deductStockForInvoice (~L473) and restoreStockForCreditNote (~L628) through BomService.explode(orgId, item.getId()) instead of the direct findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc call, so phantom children are flattened (BOM_PHANTOM_CYCLE-protected) into their real leaf GOODS before the trackInventory/SERVICE skip and the SALE/RETURN_IN movements are posted for the grandchildren. Given no phantom-setter exists, (A) is the lower-risk fix and keeps behaviour byte-for-byte identical for every real BOM. No Flyway migration needed (is_phantom column already exists; no data change). Regression test: if (A), add BomServiceTest case asserting addComponent with a phantom COMPOSITE child now throws BOM_NESTED_NOT_SUPPORTED (documents the constraint). If (B), add an InventoryServiceInvoiceDeductionTest that (via a test-only path setting item.phantom=true) builds Hamper→phantom BasePack→2×Soap, sends an invoice for 1 Hamper, and asserts a SALE movement of -2 is posted against Soap (and a symmetric RETURN_IN on credit-note restore).

---


## GST/Tax + Banking + Payment
**Fix commit 5/8 · 6b1965e** — 12 findings (high 5, medium 5, low 2)

### GST_BANK-1. [HIGH/money] MATCHED bank transaction can be double-posted via ignore → rerun → accept, bypassing the accept-time guard
`CONFIRMED`
**File:** `src/main/java/com/katasticho/erp/banking/service/BankReconciliationService.java (ignoreTransaction ~line 232, rerunMatches ~line 207, acceptMatch ~line 284)`

**Failure scenario:** acceptMatch blocks a second posting only via `if ("MATCHED".equals(transaction.getStatus())) throw BANK_TX_ALREADY_MATCHED`, and rerunMatches blocks re-suggestion only for status MATCHED. But `ignoreTransaction` has NO status guard — it flips any transaction, including a MATCHED one whose payment/journal is already posted, to IGNORED (`transaction.setStatus("IGNORED")` with no check). Sequence: (1) credit ₹5,000 matched to invoice A (balance ₹10,000) → accept → AR payment posted, tx MATCHED; (2) user clicks Ignore (no guard, status → IGNORED, the ACCEPTED match row survives untouched); (3) user clicks Re-run match — the `"MATCHED".equals(status)` guard passes because status is now IGNORED, a fresh SUGGESTED match against invoice A (still ₹5,000 outstanding) is created and status set to SUGGESTED; (4) accept the new match — match is SUGGESTED ✓, tx is SUGGESTED not MATCHED ✓ → a SECOND ₹5,000 AR payment is posted for the same physical bank credit. Same path double-posts ACCOUNT-rule journals and vendor payments. All three actions are plain UI buttons for OWNER/ACCOUNTANT.

**Fix applied:** In ignoreTransaction, throw BANK_TX_ALREADY_MATCHED (or require an explicit un-match/reversal flow) when transaction.getStatus() == "MATCHED" or transaction.getPaymentId() != null. Additionally, make acceptMatch refuse when the transaction already has a non-null paymentId regardless of status.

---

### GST_BANK-2. [HIGH] Razorpay webhook thread never sets TenantContext userId, but journal_entry.created_by is NOT NULL — webhook payment settlement can never post its journal; Razorpay retries forever and the captured payment is never booked
`CONFIRMED`
**Fix applied:** No migration needed. Fix in PaymentLinkService: before delegating to paymentService.recordForInvoice(...) (around line 211 in applyPayment, after the PaymentLink is loaded), populate the actor on TenantContext using the link's own creator, which is a real org user set at link-creation on a request thread (createForInvoice sets link.createdBy = TenantContext.getCurrentUserId() at line 93). Concretely: `if (TenantContext.getCurrentUserId() == null && link.getCreatedBy() != null) TenantContext.setCurrentUserId(link.getCreatedBy());` immediately before the recordForInvoice call. Add an org-owner fallback for the (rare) null-createdBy link: resolve via AppUserRepository (e.g. first OWNER for the org) and throw a BusinessException (deterministic → caught → 200 + dedupe, not an infinite retry) if none resolvable, so a genuinely un-actorable event stops resending instead of storming. Do NOT weaken journal_entry.created_by to nullable — the NOT NULL is a books invariant relied on across every posting path; the correct fix is to supply the actor on the webhook thread, matching the RecurringDocumentJob/other-job pattern. Regression test (PaymentLinkServiceTest): add a case where TenantContext.getCurrentUserId() is null on entry to handleWebhook (simulating the webhook thread) and the PaymentLink carries a non-null createdBy; stub paymentService.recordForInvoice with a Mockito Answer that captures TenantContext.getCurrentUserId() at invocation time and assert it equals link.getCreatedBy() (i.e. non-null) — this guards the exact gap the mocked-repo tests currently miss. Optionally add a second case asserting the org-owner fallback path when link.createdBy is null.

---

### GST_BANK-3. [HIGH] Re-fetching GSTR-2B/2A for a period hard-deletes all Gstr2bEntry rows and silently destroys every recorded IMS Accept/Reject action — and the scheduled ItcRiskMonitorJob triggers this automatically every month for GSP-configured orgs
`CONFIRMED`
**Fix applied:** In Gstr2bReconService.upload(String period, Map portalJson, String source): after loading `prior` (the existing period rows already fetched at ~line 116), before the delete, build an IMS snapshot map keyed by matchKey(supplierGstin, invoiceNumber): Map<String,Gstr2bEntry> priorByKey = prior.stream().collect(Collectors.toMap(e -> matchKey(e.getSupplierGstin(), e.getInvoiceNumber()), e -> e, (a,b)->a)). Then after `List<Gstr2bEntry> parsed = ...` (or immediately after saveAll(parsed) but before reconcile), iterate parsed rows and, for any whose matchKey exists in priorByKey AND has a non-null imsAction, copy over imsAction, imsActionAt, imsActionBy, imsRemarks, and imsAiRecommendation from the prior row onto the parsed row. Do this before entryRepository.saveAll(parsed) so the carried-over IMS fields persist (reconcile()'s subsequent saveAll re-persists them too). Only carry keys that still exist in the new feed (rows dropped from the new 2A/2B legitimately vanish). Keep it null-safe: skip prior rows with null imsAction. No Flyway migration needed — purely service logic; schema unchanged. Regression test to add in Gstr2bReconServiceTest: upload a period with one supplier invoice; stamp an IMS ACCEPT (imsAction=ACCEPT, imsRemarks, imsActionBy) on the saved row (via ImsService.action or direct save with TenantContext set); re-upload the SAME period with the same supplier GSTIN + invoice number (a fresh portal Map with IMS fields absent); assert the reloaded entry for that matchKey still has imsAction=ACCEPT and imsRemarks preserved (actor/timestamp non-null), while a second invoice present only in the re-upload has imsAction=null. Add a second assertion that an invoice actioned then absent from the re-upload is gone (no resurrection).

---

### GST_BANK-4. [HIGH] Statement parser discards Cr/Dr suffix on single-amount columns — every debit imports as a CREDIT
`CONFIRMED`
**Fix applied:** In BankStatementParser, capture the Cr/Dr suffix from the single-amount cell and let it win over the sign fallback. (1) Add a helper `static String directionSuffix(String raw)` that, on the RAW cell (before comma/currency stripping), matches trailing `(?i)(cr|dr)\\.?$` case-insensitively and returns \"DEBIT\" for dr, \"CREDIT\" for cr, else null. (2) In fromGrid's single-amount else branch (lines 121-128), compute `String suffix = directionSuffix(cell(row, cols.amount));` and change the direction derivation to a precedence ladder: suffix (if non-null) > explicit direction column (existing explicit.startsWith(\"D\")/\"W\") > sign (single.signum()>=0 ? CREDIT : DEBIT). Do NOT touch the debit/credit split-column branch (unambiguous) or the AI-fallback path (already maps direction). Leave parseAmount returning abs value unchanged — only the single-amount branch needs the suffix. Regression test: add to banking/service/BankStatementParserTest a case feeding a grid/text with header `Date,Particulars,Ref,Amount,Balance` and two data rows — `01/01/2024,Vendor payment,REF1,5,000.00 Dr,95,000.00` and `02/01/2024,Customer receipt,REF2,1,200.00 Cr,96,200.00` — asserting the Dr row parses direction==DEBIT and the Cr row CREDIT (and amounts positive). Optionally a third row with no suffix and a signed/positive amount to confirm the sign fallback still applies. No Flyway migration required.

---

### GST_BANK-5. [HIGH] TDS annual-threshold crossing deducts only on the current bill instead of the whole FY aggregate — statutory under-deduction under 194J/194H/194I/194A/194C
`CONFIRMED`
**Fix applied:** In TdsService.computeForBill, change the else branch (currently `deductibleBase = taxableBase`) to catch up on the untaxed FY aggregate on the first crossing bill. Detect first crossing as: annualHit is true AND the aggregate had NOT already crossed, i.e. `aggregateBefore.compareTo(annual) <= 0`. On first crossing, deduct on the whole not-yet-taxed aggregate; on subsequent bills (aggregateBefore already > annual) keep deducting on taxableBase only (prior aggregate already bore TDS). Robust, double-tax-safe base: introduce a repo method PurchaseBillRepository.sumPostedTaxedSubtotalByOrgAndContactAndDateRange (sum of subtotal of posted, non-void bills WHERE COALESCE(tds_amount,0) > 0) for the FY; then on first crossing set `deductibleBase = aggregateWithThis.subtract(alreadyTaxedBase)` (= the whole year aggregate minus what was already taxed under the single limb). This is exactly correct for 194C's mixed single/aggregate case and collapses to aggregateWithThis for pure-aggregate sections (194J/H/I/A) where alreadyTaxedBase is 0. Keep the note text distinguishing single-bill vs aggregate crossing. When singleHit is true but annualHit is false (single bill over 30k, aggregate still under 1L), keep deductibleBase = taxableBase (no catch-up — correct). 194Q branch unchanged. No Flyway migration — pure computation change; tds_amount is already stamped per-bill and the crossing bill legitimately bears the catch-up deduction, which the 26Q register (sum of bill.tdsAmount) then reports correctly. Regression tests (TdsServiceTest): (1) UPDATE fyAggregateCrossing1LakhTriggers194c — with aggregateBefore 95,000 (all untaxed) + 20,000 bill @2%, expect amount 2,300 (2% of 1,15,000), not 400; (2) NEW aggregateOnlySectionCatchesUpWholeAggregate — 194J @10%, aggregateBefore 25,000 (untaxed), bill 10,000, expect 3,500 (10% of 35,000); (3) NEW subsequentBillAfterCrossingDeductsOnlyOwnBase — 194J @10%, aggregateBefore 60,000 (already over threshold), bill 10,000, expect 1,000; (4) NEW section194cSingleLimbNotDoubleTaxedOnAggregateCrossing — prior 40,000 bill already taxed under single limb, then aggregate crosses 1L, assert catch-up base excludes the already-taxed 40,000. Mock the new sumPostedTaxedSubtotal repo method in the test fixture alongside the existing fyAggregate helper.

---

### GST_BANK-6. [MEDIUM] Auto-apply of a bank rule into a closed fiscal period poisons the whole statement import transaction (UnexpectedRollbackException, entire import lost)
`CONFIRMED`
**Fix applied:** Two viable approaches; recommend the same-bean pre-validation to match the existing GL-account guard pattern.

APPROACH A (recommended, consistent with the codebase): pre-validate the fiscal period inside postAccountJournal, BEFORE calling journalService.postJournal, using a DIRECT repository read (NOT FiscalPeriodService.requireOpen, which is @Transactional and would re-introduce the same proxy-boundary rollback-only mark). Steps:
1. Inject FiscalPeriodRepository into BankReconciliationService.
2. Compute the fiscal year/month exactly as JournalService does: replicate computeFiscalYear(effectiveDate, org.getFiscalYearStart()) — extract JournalService.computeFiscalYear into a small shared static helper (e.g. FiscalPeriodService.computeFiscalYear or a util) and reuse it in both places to avoid divergence; periodMonth = transaction.getTransactionDate().getMonthValue(). Fetch org.getFiscalYearStart() (Organisation is already loadable; add an OrganisationRepository read or pass through).
3. In postAccountJournal, before building lines: fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, py, pm).filter(FiscalPeriod::isClosed).ifPresent(fp -> { throw new BusinessException("Fiscal period ... is closed", "ACCT_PERIOD_CLOSED", HttpStatus.CONFLICT); }); This throw originates in the same bean (no @Transactional interceptor between it and the importRows catch), so it propagates to the existing catch(RuntimeException) without marking the outer tx rollback-only, and the row degrades to a suggestion.

APPROACH B (alternative): move the auto-apply accept into a separate @Transactional(propagation=REQUIRES_NEW) method on a DISTINCT bean. Caveat: the PaymentMatch and BankTransaction rows are saved in the OUTER (uncommitted) tx, and a REQUIRES_NEW physical tx would not see them (acceptMatch re-loads by id incl. a pessimistic findByIdAndOrgIdForUpdate) — so the extracted method must accept the already-materialised entities rather than re-loading by id, and the outer must flush first. This is more invasive; Approach A is preferred.

REGRESSION TEST (BankReconciliationServiceTest, mirror importCsv_ruleMatch_autoApply_deletedTargetGl_fallsBackToSuggestedNotAbort at line 640): import a CSV with two rows — one dated in a CLOSED fiscal period matching an autoApply rule with a reference/UTR, plus one normal row. Stub fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth to return a closed FiscalPeriod for the old-dated row's period. Assert: importRows returns without throwing, the closed-period transaction status == SUGGESTED (auto-apply degraded to a suggestion), the normal row imported, and journalService.postJournal was NOT invoked for the closed-period row (verify(journalService, never())...). Add a companion test asserting no UnexpectedRollbackException surfaces (i.e. the outer tx is not marked rollback-only) — can be asserted structurally by confirming postJournal is never reached for the closed row.

---

### GST_BANK-7. [MEDIUM] GSTR-1 puts every unregistered credit note in CDNUR with hardcoded typ "B2CL" and never nets credit notes out of B2CS — intra-state B2C returns produce an invalid GSTR-1 that overstates liability vs GSTR-3B
`CONFIRMED`
**Fix applied:** Two coordinated changes in GstService.java, plus wiring in generateGstr1. No migration.

1) Load the original-invoice values for CNs. In generateGstr1, after fetching creditNotes, collect their `invoiceId`s and build `Map<UUID,BigDecimal> cnOriginalValue` via `invoiceRepository.findAllById(...)` mapping id→getTotalAmount() (the original invoice may be from a prior period, so do NOT rely on the period `invoices` list). Pass this map (and the CN totals) into both buildCDNUR and buildB2CS.

2) buildCDNUR: add a `isCdnurB2cl(CreditNote cn, List<TaxLineItem> tls, Map<UUID,BigDecimal> cnOriginalValue)` guard mirroring isB2cl — inter-state = any IGST tax line with positive amount, AND `cnOriginalValue.get(cn.getInvoiceId())` (fallback to cn.getTotalAmount() when null) `> B2CL_THRESHOLD`. Only emit a CDNUR row when this holds (keep typ="B2CL"); `continue` for every other unregistered CN so intra-state / small inter-state CNs never reach CDNUR.

3) buildB2CS: extend to also accept the credit-note list + the same cnOriginalValue map. After the invoice accumulation loop, iterate the unregistered CNs that are NOT CdnurB2cl (same isCdnurB2cl test, negated; skip CNs whose contact has a GSTIN — those belong to CDNR) and SUBTRACT their per-(rate,pos) taxable/igst/cgst/sgst into the same `buckets` map (sums[0] -= taxable, sums[1/2/3] -= igst/cgst/sgst). Net negative buckets are legitimate GSTR-1 B2CS rows. Keep the existing sply_tp INTER/INTRA derivation (a fully-netted-to-zero bucket can be left in or pruned; matching GSTR-3B is the goal).

4) Regression tests in gst/service/GstServiceTest.java:
 - intraStateB2cCreditNoteNetsIntoB2csAndNotCdnur: ₹5,000 intra-state B2C invoice (CGST/SGST) + same-month ₹5,000 intra-state B2C CN → assert the B2CS bucket for that rate/pos nets to zero taxable/tax, and cdnur list contains NO row for that CN.
 - interStateB2cLargeCreditNoteGoesToCdnurB2cl: inter-state B2C CN (IGST line) whose linked original invoice total > ₹1L → assert one cdnur row typ="B2CL" carrying IGST only, and that CN is NOT netted into B2CS.
 - reconciliation guard: assert GSTR-1 B2CS net taxable + CDNUR nets == GSTR-3B net outward taxable for a mixed invoice+CN period.

---

### GST_BANK-8. [MEDIUM] GspClient performs server-side requests to an org-admin-controlled base URL with no SSRF guard and no https requirement — internal-network probe oracle, unlike the hardened webhook action
`CONFIRMED`
**Fix applied:** Extract the WorkflowRuleService resolve-and-inspect guard into a shared, reusable validator and apply it to every GSP outbound URL — both at save time and immediately before each call.

1) New shared util com.katasticho.erp.common.net.OutboundUrlGuard with a static validate(String url) that is a verbatim lift of WorkflowRuleService.validateWebhookUrl + isBlockedAddress (https-only; URI.create; null/blank host reject; strip IPv6 brackets; InetAddress.getAllByName; reject isAnyLocal/isLoopback/isLinkLocal/isSiteLocal/isMulticast + 100.64.0.0/10 CGNAT + IPv6 fc00::/7 ULA). Refactor WorkflowRuleService.validateWebhookUrl to delegate to it so both callers share one implementation (avoids drift like the fc00::/7 fix having to be made twice). Throw BusinessException with a GSP-specific code, e.g. GSP_URL_NOT_ALLOWED / GSP_URL_NOT_HTTPS (HttpStatus.BAD_REQUEST).

2) GspController.update(): after collecting the effective baseUrl (body value if present, else current setting) build the composed URLs the client will actually hit (base + einvoicePath, + ewaybillPath, + gstr2bPath, + gstr2aPath, and base alone for testConnection) and OutboundUrlGuard.validate() each before persisting, so a bad host is rejected at config time. Simplest: validate the effective baseUrl (host is shared across all paths) — reject the save if it fails.

3) GspClient: add a private guard(String url) that calls OutboundUrlGuard.validate(url) and invoke it at the top of exchange() (covers post + fetch2b), get() (covers getReturn/fetchGstr2b/fetchGstr2a), and testConnection() (validate the trimmed base before the exchange). This is the authoritative gate — it runs on the fully composed URL immediately before the RestTemplate call, closing the window even if a setting was written by some other path.

Note: https-only will reject any http GSP endpoint; real aggregators (Masters India/ClearTax) are https, and the webhook feature already enforces https, so this is consistent and desirable (also fixes the cleartext-token sub-issue).

Regression test: new GspClientSsrfTest — (a) testConnection with baseUrl=http://169.254.169.254 throws GSP_URL_NOT_HTTPS/NOT_ALLOWED and never calls gspRestTemplate.exchange (verify via Mockito never()); (b) baseUrl=https://10.0.0.5 (or https://[::1]) throws GSP_URL_NOT_ALLOWED; (c) a public https baseUrl passes the guard and reaches the mocked RestTemplate. Plus GspControllerTest — update() with baseUrl=http://169.254.169.254 rejected before orgSettingsService.set persists it.

---

### GST_BANK-9. [MEDIUM] Import dedupe key is (org, utr, direction) only — recurring same-reference transactions (NACH/EMI mandates, split charges) are silently dropped
`CONFIRMED`
**Fix applied:** 1) Add a repository method to BankTransactionRepository: `boolean existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(UUID orgId, String utr, String direction, LocalDate transactionDate, BigDecimal amount);` (all four are existing entity fields; derived query, no @Query needed). 2) In BankReconciliationService.importRows change the dedupe check (lines 97-98) to `bankTransactionRepository.existsByOrgIdAndUtrAndDirectionAndTransactionDateAndAmount(orgId, row.reference(), row.direction(), row.date(), row.amount().setScale(2, RoundingMode.HALF_UP))` — the amount MUST be scaled to 2 HALF_UP so it matches the persisted value written at line 107 (otherwise a scale mismatch would never dedupe a true re-import). This keeps true re-imports (identical ref+date+amount+direction) caught while letting genuinely distinct same-reference rows through. 3) No change to the autoApply `hasReference` gate is required: its invariant — a reference-bearing row is deduped, so re-import is caught and auto-posting is safe — still holds under the stronger key, since a real re-import matches ref+date+amount+direction. No Flyway migration (query-method + logic change only). Regression test (BankReconciliationServiceTest): (a) import two rows with same reference+direction but different amount (or different date) → both imported, skipped==0, two BankTransaction saves; (b) import the exact same row twice (same ref+date+amount+direction) → second is skipped (skipped==1, one save) so genuine duplicate protection is preserved.

---

### GST_BANK-10. [MEDIUM] Razorpay capture against an already-settled invoice is silently swallowed — real collected money leaves no accounting trace and no alert
`CONFIRMED`
**Fix applied:** In PaymentLinkService.applyPayment, replace the two bare stampPaid(...,null) swallows (lines 192-196 "invoice not payable" and 203-206 "nothing due") with a call that BOTH stamps the link PAID (keep, so retries dedupe and providerPaymentId is captured) AND raises an idempotent HIGH-priority AI-Inbox suggestion so a human refunds or applies the capture. Concretely: (1) inject AiSuggestionService (already the codebase pattern used by ThreeWayMatchService/GSTR-2B). (2) Add a private helper handleUnattributedCapture(orgId, link, wp, invoice, reason) that, guarded by AiSuggestionRepository.existsOpenSuggestion (keyed on entityType=PAYMENT_LINK + link.getId() + a suggestion type e.g. GATEWAY_CAPTURE_UNAPPLIED), builds an AiSuggestion (type GATEWAY_CAPTURE_UNAPPLIED, priority HIGH, orgId=orgId, payload carrying invoiceNumber, link.providerPaymentId, wp.amount, reason "invoice already settled / nothing due — refund or apply as advance") via AiSuggestionService.createSuggestion, THEN stampPaid(link, wp, eventId, null). Return e.g. "unapplied capture flagged". Idempotency matters because the webhook bus is at-least-once and Razorpay sends both payment.captured and payment_link.paid — existsOpenSuggestion prevents duplicate inbox rows (the link is also under the pessimistic write lock taken at line 179, so the two events serialise). Set logRow.setProcessed(false) is fine (leave as-is) — the suggestion is the actionable surface. (2b, defence-in-depth, optional) prevent the situation: have the AR settlement path best-effort cancel any open PaymentLink for the invoice — add RazorpayClient.cancelPaymentLink(orgId, providerLinkId) POSTing /v1/payment_links/{id}/cancel and call it from PaymentService.recordForInvoice / updatePaymentStatus when balanceDue hits zero, wrapped in try/catch so a gateway hiccup never fails the manual receipt; and set expire_by in createForInvoice so stale links die on their own. The AI-Inbox alert (step 1-2) is the required fix; the cancel/expire hook is hardening. No Flyway migration needed. Regression test: PaymentLinkServiceTest +1 — build a link (status CREATED, recordedPaymentId null) whose invoice is now status PAID (or balanceDue 0), feed a payment.captured webhook with a fresh paymentId, assert (a) a HIGH AiSuggestion of type GATEWAY_CAPTURE_UNAPPLIED was created via the mocked AiSuggestionService, (b) the link is stamped PAID with providerPaymentId set and recordedPaymentId still null, (c) PaymentService.recordForInvoice was NEVER called; a second identical event asserts existsOpenSuggestion short-circuits so no duplicate suggestion is created.

---

### GST_BANK-11. [LOW] POS-derived inter-state B2CS rows report the org's own state as place of supply — invalid GSTR-1 (POS must be the destination state and must differ from the supplier state for INTER rows)
`CONFIRMED · migration`
**Fix applied:** Two-part fix; the complete (correct-reporting) version needs a migration, a no-migration fallback also fully removes the invalid JSON.

PROPER FIX (recommended, needs migration):
1. Add a destination-state column to SalesReceipt so inter-state POS sales carry a real place of supply. Entity: add `private String placeOfSupply;` to com.katasticho.erp.pos.entity.SalesReceipt.
2. In SalesReceiptService.create (around lines 293-298 where cgst/sgst/igst are stamped), populate it: when igstTotal>0 resolve the destination from the linked contact's billing state code (receipt.getContactId() → Contact.stateCode) and set receipt.setPlaceOfSupply(that); otherwise default to org.getStateCode(). Guard: if igst>0 but no contact/state is available, keep null so the reporting layer can flag it (see step 4).
3. In GstService.buildPosB2cs: give the bucket Key a `pos` component (mirror buildB2CS's Key(rate,pos)) so each receipt contributes under its own place of supply; emit `key.pos()` at line 411 instead of the constant orgState. For INTRA rows use receipt.getPlaceOfSupply() ?? orgState.
4. For any INTER receipt whose placeOfSupply is null or equals orgState, exclude it from the auto-built b2cs and add a `warnings` entry to the generateGstr1 result so the filer supplies POS manually (prevents ever emitting an INTER row with pos==filer state).

NO-MIGRATION FALLBACK (if shipping quickly): in buildPosB2cs, skip buckets where inter==true (do not emit them) and surface a warning row/count; INTRA rows keep using orgState (correct for counter sales). This removes the invalid INTER row at the cost of under-reporting the rare inter-state POS sale until the migration lands.

REGRESSION TEST (GstServiceTest, gst/service): add a POS SalesReceipt with igst>0 and a contact whose stateCode differs from orgState; assert the generated gstr1 "b2cs" contains no row with sply_tp==INTER && pos==orgState — either the INTER row carries the contact's state as pos (proper fix) or the receipt is excluded with a warning (fallback). Complements the existing GstServiceTest POS-in-B2CS/HSN coverage.

```sql
ALTER TABLE sales_receipt ADD COLUMN place_of_supply VARCHAR(2);
-- nullable; backfill not required (existing rows treated as intra-state = org state at read time)
```

---

### GST_BANK-12. [LOW] Webhook double-settlement lock is ineffective: the PESSIMISTIC_WRITE re-read returns the stale first-level-cache entity loaded before the lock
`PARTIAL`
**Fix applied:** In PaymentLinkService.applyPayment, replace the stale-returning locked re-read with an explicit refresh-under-lock so check (4) sees committed state. Inject the EntityManager (@PersistenceContext private final EntityManager entityManager; or field) and change lines ~179-185 from:
  PaymentLink link = paymentLinkRepository.findByIdAndIsDeletedFalse(resolved.getId()).orElse(resolved);
to:
  PaymentLink link = resolved;
  entityManager.refresh(link, LockModeType.PESSIMISTIC_WRITE);
entityManager.refresh(entity, PESSIMISTIC_WRITE) both acquires the row FOR UPDATE lock (preserving the existing serialization the CLAUDE.md Phase-H hardening intended) AND re-hydrates the managed instance from the committed row, so link.getStatus()/getRecordedPaymentId() reflect tx1's PAID stamp and the line-183 settled-check short-circuits with "link already paid". Keep logRow.setPaymentLinkId(link.getId()) after the refresh. The now-unused repository method findByIdAndIsDeletedFalse(UUID) @Lock can be dropped (or retained for other callers — grep shows only this call site). No behavioural change to the non-concurrent path.
Regression test: a JPA integration test (@DataJpaTest or @SpringBootTest with a real Postgres/H2) is required because the defect is L1-cache staleness that pure Mockito repo mocks cannot reproduce. Test shape: persist a PaymentLink (status CREATED); in the service call path, after resolveLink has loaded it into the session, mutate/commit the same row to PAID via a separate connection/native update, then assert applyPayment returns "link already paid" and PaymentService.recordForInvoice is NEVER invoked. Add to PaymentLinkServiceTest as an integration variant (the existing class mocks repos, so a new @DataJpaTest sibling is cleaner). A lighter structural guard in the existing mocked test can assert entityManager.refresh(link, LockModeType.PESSIMISTIC_WRITE) is called before the settled-check, but the integration test is the one that actually proves the fresh read.

---


## Payroll + HR + Field-sales
**Fix commit 6/8 · 1126e41** — 13 findings (high 4, medium 5, low 4)

### PAY_HR_FS-1. [HIGH] Day-close submit/initiate and route-execution start/complete have no salesperson-ownership check — any OPERATOR can falsify another salesperson's cash reconciliation
`CONFIRMED`
**Fix applied:** Add two ownership guards in FieldSalesService mirroring ensureVisitOwnership(), role-aware via TenantContext.getCurrentRole() (which exists):

private void ensureExecutionOwnership(RouteExecution execution) { String role = TenantContext.getCurrentRole(); if ("OWNER".equals(role) || "ADMIN".equals(role)) return; if (!execution.getSalespersonId().equals(TenantContext.getCurrentUserId())) throw new BusinessException("Only the assigned salesperson can perform this action","FS_NOT_ASSIGNED_SALESPERSON",HttpStatus.FORBIDDEN); }

and an analogous ensureDayCloseOwnership(DayClose) using dayClose.getSalespersonId().

Wire them in:
- startRoute(): after loading execution, call ensureExecutionOwnership(execution) before the PLANNED status check.
- completeRoute(): after loading execution, call ensureExecutionOwnership(execution) before the IN_PROGRESS check.
- initiateDayClose(): after loading execution, call ensureExecutionOwnership(execution) before the COMPLETED check.
- submitDayClose(): after loading dayClose, call ensureDayCloseOwnership(dayClose) before the PENDING check.
- startExecution(routeId, salespersonId, ...): guard creation for a foreign salespersonId — if caller is not OWNER/ADMIN, require salespersonId.equals(TenantContext.getCurrentUserId()) else throw FS_NOT_ASSIGNED_SALESPERSON. (Admins legitimately plan for others; this is the assignment-style path.)

Note the role string form: confirm whether TenantContext.getCurrentRole() stores "OWNER" vs "ROLE_OWNER" (Spring authorities use the ROLE_ prefix but @PreAuthorize hasAnyRole strips it) — match whatever setCurrentRole() is fed at the JWT/API-key filter; adjust the equals() comparison accordingly. No Flyway migration needed — pure service-layer authorization.

Regression test (add to FieldSalesServiceTest, following the 3 existing geofence/ownership tests): with TenantContext user = B (OPERATOR role) and a DayClose/RouteExecution whose salespersonId = A, assert submitDayClose, initiateDayClose, startRoute, completeRoute each throw BusinessException with code FS_NOT_ASSIGNED_SALESPERSON; and assert that with role ADMIN (user = B) the same calls succeed; and that with user = A (owner of the record, OPERATOR) they succeed. Also assert startExecution with a foreign salespersonId under OPERATOR throws, under ADMIN succeeds.

---

### PAY_HR_FS-2. [HIGH] Payroll run posting builds an imbalanced journal whenever a deduction's payslip line is missing or unmapped, so postRun permanently fails with ACCT_JOURNAL_IMBALANCE
`CONFIRMED`
**Fix applied:** Make the journal CR side derive from the same deduction total that reduces netPay, so it can never fall short.

1) In buildJournalLines (PayrollService.java ~1037): after aggregating the mapped statutory totals, compute the employee-deduction total actually recognised as CR payables = pfEmployeeTotal + esiEmployeeTotal + ptTotal + lwfEmployeeTotal + tdsTotal. Compare against run.getDeductionTotal() (the value that drove netPay). If run.getDeductionTotal() > recognisedEmployeeDeductions, add a CR line for the remainder to the Salary Payable account (settings.getDefaultSalaryPayableAccountId(), already required at line 1121) with narration "Other deductions payable" — or a dedicated 'Other Deductions Payable' GL if one is added. This guarantees total CR = netPay + totalDeductions = gross (+ employer legs) = total DR for any custom or unmapped deduction. (Aggregate the unmapped amount directly while iterating payslip lines: any PayslipLine with componentType == "DEDUCTION" whose code is not one of the seven mapped codes → add to an `otherDeductionsTotal`, then emit one CR line for it.)

2) In addStatutoryLine (~1006): for STATUTORY codes (PF_EMPLOYEE/PF_EMPLOYER/ESI_*/PT/LWF/TDS/GRATUITY_ACCRUAL) do NOT silently skip when the component is absent — throw a BusinessException (e.g. PAYROLL_STATUTORY_COMPONENT_MISSING, BAD_REQUEST) so the failure surfaces at calculateRun (before APPROVED), not as an unrecoverable imbalance at post time. Alternatively, ensure the component exists first.

3) Wire seedDefaultComponents into org/payroll bootstrap (e.g. call it from the payroll-settings initialisation / org onboarding path, or lazily from calculateRun before the componentsByCode load) so a fresh org that enables PF/ESI/PT/LWF/TDS always has the matching components, and (2)'s guard is not tripped by the common case.

No Flyway migration required for the minimal fix (crediting the remainder to the existing Salary Payable account). A dedicated 'Other Deductions Payable' liability GL would need a coa_template/seed addition + DefaultAccountPurpose entry — optional, not required to restore balance.

Regression tests (PayrollServiceTest): (i) a run whose structure includes a custom DEDUCTION component (code ADVANCE, FIXED amount) — after calculateRun+postRun, assert the JournalPostRequest passed to journalService.postJournal has sum(debit) == sum(credit) and includes a CR line covering the ADVANCE; (ii) a run with settings.pfEnabled and employee.pfApplicable but NO PF_EMPLOYEE component present — assert calculateRun (or postRun) fails loudly with the new PAYROLL_STATUTORY_COMPONENT_MISSING code rather than producing an imbalanced journal; (iii) a run after seedDefaultComponents runs at bootstrap posts a balanced PF/ESI journal end-to-end.

---

### PAY_HR_FS-3. [HIGH] confirmVanLoad/confirmVanReturn are check-then-act on DRAFT status with no lock — concurrent double-confirm posts duplicate stock movements and double van credit
`CONFIRMED`
**Fix applied:** Add a pessimistic re-read to VanStockTransferRepository and use it in both confirm methods, mirroring BankReconciliationService.acceptMatch's PESSIMISTIC_WRITE re-read.

1) VanStockTransferRepository: add
   @Lock(LockModeType.PESSIMISTIC_WRITE)
   @Query("select t from VanStockTransfer t where t.id = :id and t.orgId = :orgId and t.isDeleted = false")
   Optional<VanStockTransfer> findByIdAndOrgIdForUpdate(@Param("id") UUID id, @Param("orgId") UUID orgId);

2) In FieldSalesService.confirmVanLoad and confirmVanReturn, replace the loading call
   `vanStockTransferRepository.findByIdAndOrgIdAndIsDeletedFalse(transferId, orgId)`
   with `vanStockTransferRepository.findByIdAndOrgIdForUpdate(transferId, orgId)`
   BEFORE the `!"DRAFT".equals(transfer.getStatus())` check. This serialises the two txns: the second blocks on SELECT ... FOR UPDATE until the first commits status=CONFIRMED, then reads CONFIRMED and throws FS_TRANSFER_NOT_DRAFT — no duplicate movements. Both @Transactional methods already run in a transaction so the lock is held to commit. No Flyway migration needed (no schema change).

Regression test (FieldSalesServiceTest): (a) simple guard test — mock findByIdAndOrgIdForUpdate to return a transfer whose status is already CONFIRMED and assert confirmVanLoad throws BusinessException code FS_TRANSFER_NOT_DRAFT and that inventoryService.recordMovement is never called (verify(inventoryService, never())). (b) concurrency-intent test — verify confirmVanLoad/confirmVanReturn invoke the *forUpdate* finder (verify(vanStockTransferRepository).findByIdAndOrgIdForUpdate(...)) and NOT the plain findByIdAndOrgIdAndIsDeletedFalse, locking in that the locked read path is used. (A true two-thread double-confirm test needs a DB-backed integration test with a CountDownLatch; the mock-based tests above pin the code contract.)

---

### PAY_HR_FS-4. [HIGH] getOrCreateSettings saves the default PayrollSettings inside a readOnly transaction — the INSERT is silently lost, and PUT /payroll/settings then 404s forever on a fresh org
`CONFIRMED`
**Fix applied:** Add a writeable transaction to the create path so the INSERT flushes at commit. Simplest correct fix: annotate `getOrCreateSettings()` with `@Transactional` (readOnly=false, the default) at PayrollService.java:52, which overrides the class-level readOnly for this method. Because internal self-invocation from `calculateRun()` (line 473) bypasses the Spring proxy, that call still safely participates in calculateRun's own writeable tx — no behavioural change there. (Alternative if a purist wants the GET path to stay readOnly: split out a private-but-proxied `@Transactional PayrollSettings createDefaults(orgId)` bean method invoked through a self-reference, but the direct annotation is the least-risk change and matches how `updateSettings` is already annotated.) No Flyway migration needed. Regression test: add to PayrollServiceTest (or a new PayrollSettingsPersistenceTest) a structural guard mirroring the existing `NotificationJobTransactionTest` pattern — assert via reflection that `PayrollService.getOrCreateSettings` resolves to a transaction attribute that is NOT readOnly (i.e. `AnnotationTransactionAttributeSource().getTransactionAttribute(method, PayrollService.class).isReadOnly()` is false). Additionally, an integration-level test (@SpringBootTest with a real/embedded Postgres, or reuse the fresh-DB boot harness the repo already has) that: fresh org → GET /api/v1/payroll/settings → then in a NEW transaction `settingsRepository.findByOrgId(orgId)` is present (proves the INSERT flushed) → PUT /api/v1/payroll/settings succeeds (no PAYROLL_SETTINGS_NOT_FOUND). The pure structural test is enough to lock the fix; the integration test proves the end-to-end flow.

---

### PAY_HR_FS-5. [MEDIUM] Leave balance is never reserved for PENDING requests and never re-checked at approval — two requests can both be approved against one balance, driving 'used' past entitlement
`CONFIRMED`
**Fix applied:** Two-part fix, no migration needed.

1) Re-validate at approval (closes the deterministic sequential defect): In adjustBalanceOnDecision, when consume==true, after loading the balance b (line 271) and before b.setUsed(...), check b.getAvailable().compareTo(req.getWorkingDays()) < 0 and throw new BusinessException("Insufficient "+type.getName()+" balance ...", "HR_LEAVE_INSUFFICIENT_BALANCE", HttpStatus.BAD_REQUEST). This makes approveLeave reject the second approval once the first has consumed the balance. (Restore path consume==false is unchanged.)

2) Serialize concurrent consumers (closes the lost-update race): Add a pessimistic-locked finder on LeaveBalanceRepository, e.g. @Lock(LockModeType.PESSIMISTIC_WRITE) Optional<LeaveBalance> findForUpdateByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(...), and use it in getOrCreateBalance so both the auto-approve consume in applyLeave and the approve-time consume read the row under a row lock within their @Transactional method. No schema change (avoids @Version DDL). Note the create-on-miss branch still races on first insert; the hr_leave_balance table should already have a unique index on (org_id,user_id,leave_type_id,year) — if not, the race there is a separate concern, but the common path (balance already exists) is fully serialized.

Regression tests to add in LeaveManagementServiceTest:
- twoDisjointPendingRequests_secondApproveRejected: entitled=5, apply Feb 1-5 and Mar 1-5 (requiresApproval type) both PENDING; approveLeave(first) succeeds and sets used=5; approveLeave(second) throws BusinessException with code HR_LEAVE_INSUFFICIENT_BALANCE; assert used never exceeds entitled.
- approveWithinBalance_stillSucceeds: sanity that a single approvable request still consumes correctly.

---

### PAY_HR_FS-6. [MEDIUM] POST /api/v1/hr/leave/{id}/cancel has no role guard and no ownership check — any authenticated org user can cancel any colleague's PENDING or APPROVED leave
`CONFIRMED`
**Fix applied:** No Flyway migration needed — pure service/authz fix.

In LeaveManagementService.cancelLeave (lines 181-193), after loading `req` and before mutating status, enforce owner-or-admin:

  UUID caller = TenantContext.getCurrentUserId();
  boolean isAdmin = <role check for OWNER/ADMIN>;
  if (!isAdmin && !req.getUserId().equals(caller)) {
      throw new BusinessException("Only the requester can cancel this leave",
              "LEAVE_NOT_OWNER", HttpStatus.FORBIDDEN);
  }

For the admin bypass, read authorities from the Spring SecurityContext (SecurityContextHolder.getContext().getAuthentication().getAuthorities() containing ROLE_OWNER/ROLE_ADMIN) — the codebase already sets ROLE_<role> authorities (see ApiKeyAuthenticationFilter/JWT filter). If a role helper isn't readily injectable, the minimal safe fix is owner-only (mirror AttendanceService.cancelLeave exactly), which is a strict improvement over the current any-user behaviour; admin cancellation can be layered on separately. Do NOT rely solely on a controller @PreAuthorize('OWNER','ADMIN') — that would block employees from cancelling their own leave, which the /apply + /me self-service model intends to allow; the ownership check must live in the service.

Regression test — add to LeaveManagementServiceTest:
  - cancelLeave by a non-owner (TenantContext.getCurrentUserId() != req.userId) throws BusinessException with code LEAVE_NOT_OWNER (403), and the request status stays APPROVED and the balance is NOT restored (verify balanceRepository.save is never called with a decremented used).
  - cancelLeave by the owner succeeds (status → CANCELLED, balance restored for approved paid leave).
  - (if admin bypass implemented) cancelLeave by an OWNER/ADMIN for another user's leave succeeds.

---

### PAY_HR_FS-7. [MEDIUM] Van RETURN re-enters warehouse stock at current item.purchasePrice instead of the load-leg's recorded cost — a van round-trip mints or destroys inventory value on FIFO orgs
`CONFIRMED · migration`
**Fix applied:** Make the van round-trip value-neutral by carrying the load cost on the van, mirroring how stock_balance carries averageCost.

1) Migration: add a nullable `average_cost NUMERIC(15,4)` column to `van_stock_balance` (ddl-auto=validate, so entity + DDL must match). Add the matching field `private BigDecimal averageCost;` (@Column(name="average_cost")) to VanStockBalance.

2) FieldSalesService.confirmVanLoad: the TRANSFER_OUT movement returned by inventoryService.recordMovement now carries the true FIFO unit cost — capture `movement.getUnitCost()` and pass it into adjustVanStockBalance so the van tracks what the goods cost when loaded.

3) FieldSalesService.adjustVanStockBalance(orgId, vanId, itemId, batchId, delta, unitCost): on a positive delta (load), maintain `averageCost` as a weighted average of existing on-hand value + delta×unitCost; on a negative delta (return/unload) leave averageCost unchanged (it is the cost of what remains). Keep the existing signature as a thin overload passing null for callers that do not have a cost.

4) FieldSalesService.confirmVanReturn: before the TRANSFER_IN, read the VanStockBalance for (van,item[,batch]) and pass its `averageCost` as the `unitCost` argument of the StockMovementRequest (replacing the hardcoded null at line 640). Now the warehouse re-opens the returned lot at the same basis the goods carried on the van, so load→return nets to zero inventory-value change under both FIFO and weighted-average.

Fallback: if averageCost is null (legacy van_stock_balance rows created before the column existed), fall back to item.getPurchasePrice() — i.e. current behaviour — so no NPE and no regression for un-costed vans.

Regression test (new FieldSalesVanCostingTest, or extend an existing FieldSales test): on a FIFO org, seed a warehouse item with a known lot cost (₹80), confirmVanLoad qty 10, then bump item.purchasePrice to ₹100, then confirmVanReturn qty 10; assert the TRANSFER_IN StockMovement's unitCost is ₹80 (the load cost), not ₹100 — i.e. total inventory lot value after the round-trip equals the value before it. Add a second case asserting the null-averageCost fallback still uses purchasePrice.

```sql
ALTER TABLE van_stock_balance ADD COLUMN average_cost NUMERIC(15,4);
```

---

### PAY_HR_FS-8. [MEDIUM] Van stock balance lookup for a null-batch line matches ALL batch rows of the item — Optional-returning derived query crashes (500) once a van holds an item in two batches, and silently mis-books against a batch row when it holds one
`CONFIRMED`
**Fix applied:** Add a dedicated null-batch grain lookup and route the null-batch path through it. (1) VanStockBalanceRepository: add `Optional<VanStockBalance> findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(UUID orgId, UUID vanId, UUID itemId);` — matches the COALESCE(batch_id, zero-uuid) unique-index grain exactly (the null-batch row is its own grain). (2) FieldSalesService.adjustVanStockBalance (~709-718): change the `else` branch from `findByOrgIdAndVanIdAndItemId(orgId, vanId, itemId)` to `findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(orgId, vanId, itemId)`. (3) FieldSalesService.validateVanStock (~763-770): same change in the `else` branch. Both now target only the null-batch row, so a null-batch line can never match batched grains: the crash disappears and a null-batch return against a van that only holds batched stock correctly falls to available=0 and throws FS_VAN_INSUFFICIENT_STOCK (correct behaviour) instead of mutating a batched row. No Flyway migration needed — the grain index already exists and correctly enforces the intended semantics; only the query grain was wrong. Regression test (FieldSalesServiceTest): (a) mock two van_stock_balance rows for (van,item) batches B1+B2, confirm a RETURN line with batchId=null for that item → assert BusinessException FS_VAN_INSUFFICIENT_STOCK (not IncorrectResultSizeDataAccessException/500) and that findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull is the method invoked; (b) mock a single batched row (B1) + a null-batch adjust → assert the batched B1 row is untouched and a new null-batch row is created via save (verify the saved entity has batchId==null and B1's quantity unchanged).

---

### PAY_HR_FS-9. [MEDIUM] postRun is check-then-act with no lock — two concurrent posts of the same APPROVED run book the entire payroll expense journal twice
`CONFIRMED`
**Fix applied:** 1) PayrollRunRepository: add a locking lookup —
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("SELECT pr FROM PayrollRun pr WHERE pr.id = :id AND pr.orgId = :orgId")
  Optional<PayrollRun> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);
(import jakarta.persistence.LockModeType and org.springframework.data.jpa.repository.Lock).

2) PayrollService.postRun (line 575): replace runRepository.findByIdAndOrgId(runId, orgId) with runRepository.findByIdAndOrgIdForUpdate(runId, orgId). The method is already @Transactional, so the row lock is held for the duration; the second concurrent transaction blocks on the SELECT ... FOR UPDATE, then re-reads status = POSTED and throws PAYROLL_RUN_NOT_APPROVED at line 579. No behavioural change for the single-threaded path.

3) Apply the same swap to approveRun (line 545, CALCULATED->APPROVED) for consistency — lower stakes (no journal) but prevents a concurrent approve+post race from slipping through. Optionally also harden recordPayment (line 675) the same way if it reads-then-writes the run.

No Flyway migration required — the fix is a JPA lock hint over the existing schema; the existing non-unique idx_je_source index is untouched.

Regression test (PayrollServiceTest): add a test that stubs runRepository.findByIdAndOrgIdForUpdate to return an APPROVED run on the first call and a POSTED run on the second, asserting postRun succeeds once (verify journalService.postJournal called exactly once) and the second invocation throws BusinessException with code PAYROLL_RUN_NOT_APPROVED — and, crucially, verify the production code path calls findByIdAndOrgIdForUpdate (not findByIdAndOrgId) so the lock can't silently regress. A structural/Mockito verify on the locking method is the enforceable guard since a true two-thread race isn't deterministic in a unit test.

---

### PAY_HR_FS-10. [LOW] Allowance claim posts an immediately-booked cash-out journal from wholly salesperson-controlled inputs — FLEXIBLE (default) and MANUAL modes accept unbounded km with no approval gate
`PARTIAL`
**Fix applied:** Scope the fix to the genuine defect: enforce FLEXIBLE mode's documented adjust-down-only contract. In `FieldAllowanceService.resolveClaimedKm` (lines 160-179), change the FLEXIBLE (default) branch so a supplied requestedKm is capped at gpsKm rather than accepted verbatim: e.g. `default -> requestedKm != null ? requestedKm.min(gpsKm) : gpsKm;` (min against gpsKm; still allow downward adjustment, block upward inflation). GPS mode is already strict; MANUAL is by design salesperson-entered because the org has explicitly opted into manual entry (no GPS to cap against) — leave MANUAL as-is, or, if the org wants a ceiling, add an optional org setting `field_sales.max_claim_km` and throw a BusinessException (e.g. FS_ALLOWANCE_KM_EXCEEDS_MAX) when requestedKm exceeds it; do NOT introduce an allowance-only DRAFT/approval path, since that would be inconsistent with the existing (intentional) design where OPERATORs post expenses directly with no approval.

Do NOT escalate this to an authorization change (removing OPERATOR from the claim endpoint) — that would diverge from the existing ExpenseController OPERATOR grant without closing the actual hole.

Regression test to add to FieldAllowanceServiceTest: with mode=FLEXIBLE, gpsKm=12, requestedKm=100000 → distanceKm resolves to 12 (capped, not 100000), and the resulting taAmount = 12 × ta_per_km; assert the claim cannot exceed the GPS trail. Also keep the existing downward-adjust case (requestedKm=8 with gpsKm=12 → 8) passing.

No Flyway migration required.

---

### PAY_HR_FS-11. [LOW] LOP proration is skipped on the grossMonthly fallback path — an employee with approved unpaid leave on a line-less salary structure is paid the full month
`CONFIRMED`
**Fix applied:** In PayrollService.calculatePayslip, change the fallback block (lines 873-876) to apply the same lopFactor already computed at lines 800-804: `if (grossPay.compareTo(BigDecimal.ZERO) == 0 && structure.getGrossMonthly() != null) { grossPay = structure.getGrossMonthly(); if (lopFactor.compareTo(BigDecimal.ONE) < 0) { grossPay = grossPay.multiply(lopFactor).setScale(2, RoundingMode.HALF_UP); } }`. This mirrors the per-line proration at 832-834 (same lopFactor, same HALF_UP scale-2 rounding) and correctly flows into basicAmount (line 879) → PF/ESI statutory bases → the payroll journal, so a 15-of-30-day LOP on a ₹60,000 grossMonthly structure yields ₹30,000 gross. No other caller of the fallback is affected (lopFactor is ONE when lopDays==0, so the multiply is a no-op for the normal full-attendance case). No Flyway migration needed — pure computation change. Regression test to add in PayrollServiceTest: build an ACTIVE line-less EmployeeSalaryStructure with grossMonthly=60000, an Employee with a linked userId, one APPROVED leave of leaveType "UNPAID" spanning 15 days inside a 30-day run period; assert the resulting payslip has lopDays=15 AND grossPay=30000 (currently 60000). Add a companion assertion that a full-attendance run on the same structure still yields grossPay=60000 (no-op path).

---

### PAY_HR_FS-12. [LOW] RCPA record() with an existing auditId has no ownership check — any OPERATOR can overwrite another MR's audit while it stays attributed to the victim
`CONFIRMED`
**Fix applied:** In RcpaService.record, gate the update branch on ownership. When auditId != null, after `RcpaAudit audit = load(auditId);`, add: `if (!isAdmin() && !TenantContext.getCurrentUserId().equals(audit.getSalespersonId())) throw new BusinessException("Only the audit owner can modify this RCPA audit", "RCPA_NOT_OWNER", HttpStatus.FORBIDDEN);`. Add the same private static isAdmin() helper used in MrReportingService (lines 426-429): reads TenantContext.getCurrentRole() and returns true when it contains OWNER or ADMIN, so OWNER/ADMIN retain their legitimate edit ability while an OPERATOR is confined to their own audits. Cleanest placement is inside load() only for the edit path, or inline in record after the load call (keep getAudit's read-only load() untouched — reads are already scoped and non-mutating). No Flyway migration needed (pure service-layer authorization guard). Regression test: add to RcpaServiceTest a case where an audit is created with salespersonId=A, then TenantContext is switched to user B (OPERATOR role) in the same org and record(existingAuditId, ...) is invoked — assert it throws BusinessException with code RCPA_NOT_OWNER (403) and that lineRepository.deleteByOrgIdAndAuditId / save are never called; plus a companion case where the owner (user A) successfully updates, and one where an ADMIN role (getCurrentRole contains ADMIN) is allowed to edit a foreign audit.

---

### PAY_HR_FS-13. [LOW] recordPayment / recordStatutoryPayment accept negative and unbounded amounts — a negative amount posts a sign-inverted journal that passes the balance check
`PARTIAL`
**Fix applied:** Two hardening changes, no migration (the DB CHECK already prevents the corruption the finding headlines):\n\n1) Input validation — turn the DB-constraint 500 into a clean 400: add jakarta.validation.constraints.@Positive to the amount field in both PayrollPaymentRequest.java and StatutoryPaymentRequest.java. The controller endpoints already carry @Valid (@Valid @RequestBody PayrollPaymentRequest at PayrollController line 365, and the statutory endpoint), so this is enforced at the boundary. Since these DTOs are mapped to the PayrollPayment/StatutoryPayment entities before the service call, also add a defensive service-level signum guard in recordPayment/recordStatutoryPayment: if payment.getAmount()==null || payment.getAmount().signum()<=0 throw new BusinessException(\"Payment amount must be positive\", \"PAYROLL_PAYMENT_AMOUNT_INVALID\", HttpStatus.BAD_REQUEST) — placed right after the POSTED-status check.\n\n2) Over-payment cap in recordPayment: before posting the journal, sum existing payments for the run — BigDecimal alreadyPaid = paymentRepository.findByOrgIdAndPayrollRunId(orgId, runId).stream().map(PayrollPayment::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add) — and if alreadyPaid.add(payment.getAmount()).compareTo(run.getNetPayTotal()) > 0 throw new BusinessException(\"Payment exceeds net pay for run\", \"PAYROLL_PAYMENT_EXCEEDS_NET\", HttpStatus.BAD_REQUEST). (Mirror of the AR AR_PAYMENT_EXCEEDS_BALANCE guard.) recordStatutoryPayment has no analogous run-level total to cap against, so leave it to the @Positive/signum guard only.\n\nRegression tests (add to PayrollServiceTest): (a) recordPayment with a negative amount throws PAYROLL_PAYMENT_AMOUNT_INVALID and never calls journalService.postJournal; (b) a second recordPayment whose cumulative total exceeds run.netPayTotal throws PAYROLL_PAYMENT_EXCEEDS_NET; (c) a payment within netPayTotal still posts (behaviour unchanged).

---


## Security + Auth + Infra
**Fix commit 7/8 · 73fdf26** — 15 findings (critical 2, high 5, medium 7, low 1)

### SEC-1. [CRITICAL] SqlValidator tenant filter is bypassed by a CTE named identically to a real org-scoped table, leaking all tenants' data via /api/v1/ai/query
`CONFIRMED`
**Fix applied:** Reject any query whose CTE alias collides with a known public table name, so a real org-scoped table can never be shadowed (fail-closed, simplest and safe — users never need to name a CTE after a real table). In `secure()` (SqlValidator.java ~line 150-152), after `collectSelect(select, plainSelects, cteNames)` populates `cteNames`, add a guard loop before the injection loop: `for (String cte : cteNames) { if (tableScopes().containsKey(cte)) throw unsafe("CTE name '" + cte + "' collides with a real table"); }`. `tableScopes()` keys are every public table (all org-scoped, reference, and `organisation`), so this catches shadowing of any real table including credential/reference tables. Note `tableScopes()` may also need the same guard against DENYLISTED_TABLES-named CTEs, but the containsKey check already covers them since denylisted tables exist in the public schema. No Flyway migration needed — pure code change. Regression test to add to SqlValidatorTest: a case like `WITH invoice AS (SELECT total FROM invoice) SELECT total FROM invoice` asserting `validator.secure(sql, orgId)` throws BusinessException with code ERR_AI_UNSAFE_SQL (HTTP 403); optionally a second case shadowing a reference table (e.g. `WITH drug_master AS (...) ...`) also rejected, and re-confirm the existing non-colliding T-AI-30 still passes (CTE name differing from any real table still injects the org filter on the base-table body).

---

### SEC-2. [CRITICAL] stock_movement CHECK constraints reject all 5 manufacturing movement types and 6 newer reference types — issue-to-production, FG receipt, scrap, job-work, and van load/return all crash with a constraint violation
`CONFIRMED · migration`
**Fix applied:** Add a new Flyway migration (I assign the version) that drops both stale CHECK constraints, mirroring the V34 precedent — these columns are set from Java enum constants (not user input) and are used only for reporting/filtering, so the enum guard's only net effect is latent crashes. DDL: `ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_movement_type_check;` and `ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_reference_type_check;` (columns stay movement_type VARCHAR(20) NOT NULL / reference_type VARCHAR(30)). Prefer DROP over re-add-widened so future enum additions (the same drift will recur) don't reintroduce the bug — consistent with V34's rationale. Note movement_type is length 20 and reference_type length 30; the longest new values (PRODUCTION_RECEIVE=17, JOB_WORK_ORDER=14) fit, so no column-length change is needed. Regression test: add a @DataJpaTest (or reuse the existing Flyway/Testcontainers boot harness) `StockMovementConstraintTest` that persists one stock_movement row for EVERY value of MovementType and EVERY value of ReferenceType against the real migrated schema and asserts no DataIntegrityViolationException — this both proves the fix and guards against future enum-vs-DDL drift (the class of bug that keeps recurring here). Also add an assertion iterating the enums so a newly-added enum value automatically gets covered.

```sql
ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_movement_type_check;
ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_reference_type_check;
```

---

### SEC-3. [HIGH] Domain-event retry/dead-letter machinery is dead for flush-time failures: a handler write that fails at commit escapes DomainEventProcessor's catch, rolls back the retryCount bump, and the un-guarded DomainEventWorker loop then head-of-line-blocks the whole queue forever
`CONFIRMED`
**Fix applied:** Two coordinated changes, no schema change (DomainEvent already has retryCount, deadLetter, processingError, processed columns). (A) DomainEventWorker.processPendingEvents: wrap each `eventProcessor.processOne(event)` in try/catch so one poison event no longer aborts the batch — other/newer events keep processing. In the catch, call a new separate-transaction failure recorder: `eventProcessor.markFailed(event.getId(), ex.getMessage())`. (B) Add to DomainEventProcessor a `@Transactional(propagation = REQUIRES_NEW) public void markFailed(UUID eventId, String error)` that re-reads the event via eventRepository.findById(eventId), increments retryCount, sets processingError=error, sets deadLetter=true when retryCount >= MAX_RETRY_COUNT, and saves. Because this runs in a fresh transaction started AFTER the business tx rolled back, the retry accounting survives and the poison event eventually dead-letters instead of blocking the head forever. (Optional hardening, not a substitute: after the handler loop in processOne, before setting processed, an explicit entityManager.flush() inside the try converts most deferred constraint violations into in-try failures for the common case — but keep markFailed as the authoritative path since a flush-poisoned session cannot commit the in-tx retryCount update.) Regression tests: (1) DomainEventWorkerTest — given 3 pending events where eventProcessor.processOne throws only for the first, verify processOne is still invoked for events 2 and 3 (Mockito times(1) each) and markFailed is invoked for event 1 (loop isolation). (2) DomainEventProcessorTest.markFailed — increments retryCount by 1 and saves; when retryCount reaches MAX_RETRY_COUNT it sets deadLetter=true; assert the method carries @Transactional(REQUIRES_NEW) (or verify behaviorally that it re-reads by id and saves independently). Optionally an integration-style test proving a handler whose deferred INSERT violates a unique index eventually flips the event to deadLetter rather than re-failing forever.

---

### SEC-4. [HIGH] Generic attachments API lets any org user (VIEWER/OPERATOR) list, download and delete every attachment in the org, bypassing HR-document and POD authorization
`CONFIRMED`
**Fix applied:** Add function-level authorization + per-entityType ownership/role enforcement to the generic attachment path; no migration needed (entity_attachment already carries orgId, entityType, entityId, uploadedBy).

1) Introduce an AttachmentAccessPolicy (new class in common.service) with two methods: assertCanRead(EntityAttachment a) and assertCanDelete(EntityAttachment a), reading roles via SecurityContextHolder authorities and the current userId via TenantContext.getCurrentUserId(). Policy per entityType:
   - "EMPLOYEE": allow if caller has ROLE_OWNER/ROLE_ADMIN, OR entityId.equals(currentUserId) (the owning user). Else throw BusinessException 403 (e.g. new BusinessException("Not permitted", "ATTACHMENT_FORBIDDEN", HttpStatus.FORBIDDEN)).
   - "POD": read allow OWNER/ADMIN/ACCOUNTANT/OPERATOR; delete allow only OWNER/ADMIN/ACCOUNTANT (mirror ProofOfDeliveryController).
   - "OPERATION" (manufacturing work instructions): allow OWNER/ADMIN/OPERATOR.
   - default (unknown/other types): deny for read/delete unless OWNER/ADMIN (fail-closed) — sensitive types must be explicitly allowlisted rather than open by default.

2) In AttachmentService: call policy.assertCanRead(attachment) inside download() after the findByIdAndOrgId lookup and before storage.read; call policy.assertCanDelete(attachment) inside delete() after lookup and before setDeleted(true). For list(entityType, entityId), enforce the read policy on the (entityType, entityId) pair before/after the query (build a lightweight check that does not need a loaded row for the EMPLOYEE ownership case: entityId.equals(currentUserId) or OWNER/ADMIN). upload() can keep delegating to the per-domain controllers (which already gate) but add a matching policy.assertCanUpload check for defense-in-depth.

3) On AttachmentController add baseline method-level @PreAuthorize("isAuthenticated()") is already implied; the real gate is the service policy above so it applies regardless of caller (JWT or API-key). Do NOT rely on controller-only annotations since AttachmentService is also called internally — the policy in the service is the enforcement point for the externally-reachable list/download/delete.

Regression tests (AttachmentServiceTest / new AttachmentAccessPolicyTest, mock SecurityContext + TenantContext):
   - OPERATOR calling download() of an EMPLOYEE attachment whose entityId != currentUserId -> throws ATTACHMENT_FORBIDDEN.
   - The owning user (entityId == currentUserId) downloading their own EMPLOYEE attachment -> succeeds.
   - VIEWER list("EMPLOYEE", otherUserId) -> throws.
   - OPERATOR delete() of a POD attachment -> throws (POD delete requires OWNER/ADMIN/ACCOUNTANT); ACCOUNTANT delete succeeds.
   - OWNER/ADMIN read/delete of any type -> succeeds.

---

### SEC-5. [HIGH] Login/refresh always mint access tokens with tokenVersion=0, so any tokenVersion bump permanently locks the user out
`CONFIRMED`
**Fix applied:** Single-line root fix in AuthService.buildAuthResponse (line 586): replace jwtService.generateAccessToken(user.getId(), user.getOrgId(), user.getRole()) with the 4-arg overload jwtService.generateAccessToken(user.getId(), user.getOrgId(), user.getRole(), user.getTokenVersion()) (JwtService:57 (UUID,UUID,String,int)). This makes every login/otp-login/refresh/acceptInvitation/switchOrg token carry the user's current version, so a bumped version invalidates only PRE-existing tokens (the intended behavior) while a fresh login works. No Flyway migration needed — token_version column already exists and is mapped. The finding's secondary suggestion to reset tokenVersion in reactivateOrg is NOT required once tokens carry the real version (users left at v1 after suspend will log in and mint v1, which matches) and would actually undo the invalidation semantics; leave suspend/reactivate as-is. Regression test: add to AuthServiceTest (or a focused unit test) — seed/persist an AppUser with tokenVersion=1, exercise login() (and refreshToken()), then parse the returned accessToken via jwtService.validateAndExtract(token) and assert the "tokenVersion" claim == 1 (== user.getTokenVersion()); assert the pre-fix value 0 would fail. Optionally add a filter-level test: with the fixed token, JwtAuthenticationFilter does NOT 401 a user whose DB tokenVersion is 1. A second regression test worth adding: PasswordResetService bump + subsequent login yields a usable token (claim matches new version).

---

### SEC-6. [HIGH] credit_note status CHECK lacks PENDING_APPROVAL and REJECTED — the entire credit-note approval workflow (seeded transitions included) crashes at the first status write
`CONFIRMED · migration`
**Fix applied:** Migration (assign next central version): widen credit_note_status_check to include PENDING_APPROVAL and REJECTED — DROP the existing constraint and re-ADD it with the full set {DRAFT, PENDING_APPROVAL, ISSUED, APPLIED, REJECTED, CANCELLED}. DDL sketch:\n\n  ALTER TABLE credit_note DROP CONSTRAINT credit_note_status_check;\n  ALTER TABLE credit_note ADD CONSTRAINT credit_note_status_check\n    CHECK (status IN ('DRAFT','PENDING_APPROVAL','ISSUED','APPLIED','REJECTED','CANCELLED'));\n\nNo Java change is required — CreditNoteService.issueCreditNote (line 231) and CreditNoteWorkflowHandler.java:47 already write the correct string values; the DB constraint is the only thing rejecting them. Bundle this in the same migration as the analogous sales_order status-CHECK fix (the finding references a shared V35).\n\nRegression test: add an integration/DB-backed test (NOT a mocked-repo unit test — the current CreditNoteService tests mock creditNoteRepository, which is precisely why this slipped through). Using a real Postgres/Flyway-migrated schema: (a) seed + activate the CREDIT_NOTE_RETURN_APPROVAL workflow for an org, (b) create a DRAFT credit note with totalAmount >= 5000, (c) call issueCreditNote and assert it persists with status PENDING_APPROVAL and commits without a DataIntegrityViolation/CHECK violation, then (d) drive CreditNoteWorkflowHandler reject and assert status persists as REJECTED. Cover the plain issue path (no active workflow → ISSUED) too. Simplest home: an @SpringBootTest slice against the test datasource, or add to any existing Flyway-backed integration suite that exercises the credit-note lifecycle.

```sql
ALTER TABLE credit_note DROP CONSTRAINT credit_note_status_check;\nALTER TABLE credit_note ADD CONSTRAINT credit_note_status_check\n  CHECK (status IN ('DRAFT','PENDING_APPROVAL','ISSUED','APPLIED','REJECTED','CANCELLED'));
```

---

### SEC-7. [HIGH] sales_order status CHECK lacks PENDING_APPROVAL and REJECTED — activating the seeded sales-order approval workflow makes every over-limit SO creation fail with a 500
`CONFIRMED · migration`
**Fix applied:** Add a Flyway migration that drops and re-creates the CHECK with the two missing statuses (preferred over dropping it entirely — SALES_ORDER status is a bounded state machine, unlike the source_module label set dropped in V34). DDL sketch (no version number):

ALTER TABLE sales_order DROP CONSTRAINT IF EXISTS sales_order_status_check;
ALTER TABLE sales_order ADD CONSTRAINT sales_order_status_check CHECK (status IN ('DRAFT','PENDING_APPROVAL','CONFIRMED','REJECTED','BACKORDER','PARTIALLY_SHIPPED','SHIPPED','PARTIALLY_INVOICED','INVOICED','COMPLETED','CANCELLED','VOID'));

No entity change needed (status is already String, @Column length ≥20 accommodates 'PENDING_APPROVAL'). Also update the V1 baseline CHECK definition for future fresh installs to include the two values (keep the new migration too, for already-migrated DBs), consistent with how prior baseline fixes were folded in.

Regression test: add a persistence-layer test that exercises the real constraint rather than the mocked repo. Either (a) a @DataJpaTest / native-insert test asserting `INSERT INTO sales_order (... status ...) VALUES (..., 'PENDING_APPROVAL')` and `'REJECTED'` succeed (and a bogus value still fails), or (b) a SalesOrderService test that stubs approvalWorkflowService.findMatchingWorkflow to return an active workflow and uses a real EntityManager/H2-with-Postgres-mode-plus-the-CHECK so save() actually flushes, asserting the created SO persists with status PENDING_APPROVAL. Preferred is (a) since existing service tests mock the repo and cannot catch CHECK violations.

```sql
ALTER TABLE sales_order DROP CONSTRAINT IF EXISTS sales_order_status_check;
ALTER TABLE sales_order ADD CONSTRAINT sales_order_status_check CHECK (status IN ('DRAFT','PENDING_APPROVAL','CONFIRMED','REJECTED','BACKORDER','PARTIALLY_SHIPPED','SHIPPED','PARTIALLY_INVOICED','INVOICED','COMPLETED','CANCELLED','VOID'));
```

---

### SEC-8. [MEDIUM] CA delegated-access token binds '15' to the tokenVersion overload instead of a 15-minute expiry, producing a wrong tokenVersion claim and default expiry
`CONFIRMED`
**Fix applied:** In `CaClientLinkService.accessToken(UUID linkId)` change the token generation to pass the CA user's REAL tokenVersion and an explicit 15-minute expiry via the 5-arg overload, so the JWT's tokenVersion claim matches what JwtAuthenticationFilter (line 71) checks and the JWT lifetime is genuinely 15 minutes.

Replace:
    String token = jwtService.generateAccessToken(caUserId, link.getClientOrgId(), "CA_EXTERNAL", 15);
with:
    AppUser caUser = appUserRepository.findById(caUserId)
        .orElseThrow(() -> new BusinessException("CA user not found", "CA_USER_NOT_FOUND", HttpStatus.NOT_FOUND));
    String token = jwtService.generateAccessToken(
        caUserId, link.getClientOrgId(), "CA_EXTERNAL", caUser.getTokenVersion(), 15L);

Notes:
- The `15L` long literal now unambiguously selects the 5-arg `(UUID,UUID,String,int tokenVersion,long expiryMinutes)` overload (JwtService.java:61); `caUser.getTokenVersion()` supplies the int. This makes the DB expiresAt (now+15min) and the JWT exp agree, and makes the tokenVersion check pass.
- No Flyway migration.

Regression test (new CaClientLinkServiceTest, or extend an existing CA test) using a REAL JwtService (or one wired with a known secret + expiry):
1. Arrange a CA firm + ACTIVE CaClientLink, TenantContext.currentUserId = caUserId, and an AppUser(caUserId) with tokenVersion=0; mock appUserRepository.findById(caUserId) to return it.
2. Call accessToken(linkId); parse the returned token with jwtService.validateAndExtract(token).
3. Assert claims.get("tokenVersion", Integer.class) == 0 (matches the CA user, so JwtAuthenticationFilter line 71 passes), NOT 15.
4. Assert the JWT expiry (claims.getExpiration()) is ~15 minutes from issuedAt (≤ 16 min), proving it is no longer the default 60-min access-token lifetime.
5. (Optional) A second case: AppUser tokenVersion=3 → assert the claim is 3, guarding against a regression that hardcodes a version.

---

### SEC-9. [MEDIUM] ExpiryAlertJob (and the 3 sibling notification jobs) run every org in ONE transaction with no per-org isolation — a single org's failure rolls back all orgs' batch-expiry state changes and aborts the sweep
`CONFIRMED`
**Fix applied:** Restructure each affected job so the per-org body runs in its own transaction, isolated by a per-org try/catch — matching the DepreciationJob pattern. Migration NOT required (pure code change).

Primary fix (ExpiryAlertJob.java):
1. Remove `@Transactional` from `run()`; keep `@Scheduled`/`@SchedulerLock`. Leave run() non-transactional.
2. Extract the per-org body (lines 52-107: markExpired + expiring scan + notification build/send) into a collaborator bean method so Spring's proxy applies a fresh transaction per org. Two acceptable shapes:
   - Add a new bean `ExpiryAlertJobRunner` with `@Transactional public int processOrg(Organisation org, LocalDate today, LocalDate horizon)` containing the body; inject it into ExpiryAlertJob. (Self-invocation of a @Transactional method on the same bean would NOT open a new tx, so the body MUST live on a different bean or be called through an injected self-proxy.)
3. In run(): `for (Organisation org : orgs) { try { batchCount += runner.processOrg(org, today, horizon); } catch (Exception e) { log.warn("Expiry alert failed for org {}: {}", org.getId(), e.getMessage()); } }`. Optionally set/clear TenantContext(org, "SYSTEM") in try/finally for parity with DepreciationJob.

Net effect: each org commits independently; org #50's failure only skips org #50, never rolls back #1-49's markExpired flips, and #51+ still process.

Apply the identical extraction to the four siblings (DailySalesSummaryJob, OverdueBillJob, LowStockAlertJob, PaymentReminderJob) — each gets a per-org @Transactional collaborator method + per-org try/catch in a non-transactional run(). (They keep needing a tx because notificationService.send persists a Notification; per-org tx satisfies that without the all-or-nothing blast radius.)

Regression test (ExpiryAlertJobIsolationTest, MockitoExtension):
- Mock orgRepository to return 3 active orgs; batchRepository/notificationService mocked. Configure notificationService.send (or batchRepository.markExpired) to throw for org #2 only. Invoke run(). Assert: markExpired invoked for all 3 orgs (org #3 still processed after org #2 threw), and run() completes without propagating. This proves per-org isolation.
- Optional structural guard (mirror the existing NotificationJobTransactionTest): assert run() is not annotated @Transactional and the extracted processOrg is @Transactional.

---

### SEC-10. [MEDIUM] GET /api/v1/settings/sms echoes the raw SMS provider API key to ANY authenticated role, contradicting the write-only/masking policy enforced everywhere else in the same controller
`CONFIRMED`
**Fix applied:** In OrgSettingsController.getSmsSettings() (lines 108-118), stop echoing the raw key. Replace the two lines `String apiKey = settingsService.get(orgId,"sms.api_key",null); if (apiKey != null) result.put("apiKey", apiKey);` with a write-only "set" flag mirroring the WhatsApp endpoint: `result.put("apiKeySet", settingsService.get(orgId,"sms.api_key","").isBlank() ? "false" : "true");`. The PUT /sms (lines 120-129) already accepts and stores `apiKey` unchanged, so the config UI keeps working (report-set-then-overwrite pattern). Optionally add `@PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")` on getSmsSettings to match the PUT and the sensitivity of the data — recommended but the masking is the load-bearing fix. No Flyway migration needed (org_settings storage/policy unchanged). Regression test: add an OrgSettingsControllerTest (WebMvc slice or unit) asserting that with `sms.api_key` set, getSmsSettings' response body contains key `apiKeySet`=="true" and does NOT contain any key `apiKey` / does not contain the plaintext value; a companion assertion that PUT /sms still persists a supplied apiKey. If the codebase lacks a controller-test harness, a service-agnostic unit test constructing the controller with a stub OrgSettingsService returning a known key and asserting the returned Map has no "apiKey" entry suffices.

---

### SEC-11. [MEDIUM] OTP-based password reset and self-service change do not invalidate existing sessions or refresh tokens
`CONFIRMED`
**Fix applied:** Three coordinated changes in AuthService.java, no migration (token_version column + revokeAllByUserId already exist).

1) resetPassword (lines 381-387 loop): inside the `for (AppUser user : matches)` loop, after `user.resetFailedLogins();`, add `user.incrementTokenVersion();` before `userRepository.save(user);`, and after the save add `refreshTokenRepository.revokeAllByUserId(user.getId());`.

2) changePassword (lines 358-360): after `user.resetFailedLogins();` add `user.incrementTokenVersion();` before `userRepository.save(user);`, then `refreshTokenRepository.revokeAllByUserId(user.getId());`. (This forces the caller to re-authenticate, which is the intended behavior for a password change.)

3) buildAuthResponse (line 586) — REQUIRED for correctness, otherwise (1)/(2) lock out the legitimate user's fresh logins: change `jwtService.generateAccessToken(user.getId(), user.getOrgId(), user.getRole())` to `jwtService.generateAccessToken(user.getId(), user.getOrgId(), user.getRole(), user.getTokenVersion())` (the 4-arg overload already exists in JwtService, line 57). This makes every login/verifyOtp/refresh/switchOrg/acceptInvitation mint tokens carrying the user's current version so the filter passes for legitimate sessions while old-version tokens are rejected. (Note: this also finally activates the tokenVersion mechanism that was inert because all app-user tokens were minted at version 0.)

Regression test — AuthServiceTest (new or extend auth/service): (a) resetPassword bumps tokenVersion 0->1 on every matched user AND calls refreshTokenRepository.revokeAllByUserId(userId) for each; (b) changePassword bumps tokenVersion and calls revokeAllByUserId(userId); (c) after buildAuthResponse fix, a user with tokenVersion=2 logging in mints an access token whose parsed `tokenVersion` claim == 2 (assert via JwtService.validateAndExtract). Mock RefreshTokenRepository, AppUserRepository, OtpService, PasswordEncoder, JwtService (or spy the real JwtService for (c)).

---

### SEC-12. [MEDIUM] Recurring bill/journal generate-now can double-post a real journal (no lock, no idempotency) on concurrent or repeated clicks
`CONFIRMED`
**Fix applied:** Serialize concurrent generations by re-reading the template under a pessimistic write lock inside generateFromTemplate, mirroring the H1 PaymentLinkService TOCTOU fix already in the codebase.

1) RecurringJournalRepository: add
   @Lock(LockModeType.PESSIMISTIC_WRITE)
   @Query("select t from RecurringJournal t where t.id = :id and t.orgId = :orgId and t.isDeleted = false")
   Optional<RecurringJournal> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);
   Replace the plain findByIdAndOrgIdAndIsDeletedFalse call at RecurringJournalService.generateFromTemplate (line 148) with the locking finder. This makes the two concurrent transactions serialize on the template row so they cannot both read cursor D and both post for the same period.

2) RecurringBillRepository + RecurringBillService.generateFromTemplate: apply the identical locking-finder change.

Because a pure lock still lets a deliberate sequential double-click generate a second document for the advanced cursor, ALSO add per-period idempotency to make generate-now safe: after acquiring the lock, before posting, short-circuit if a generation already exists for the template's current nextRunDate. Cheapest form without a migration: guard on lastGeneratedAt / cursor by checking generationRepository for an existing row whose target period equals the current nextRunDate. If a fully robust per-period dedupe is wanted, that WOULD need a migration to add a target_period date column + unique index (org_id, recurring_journal_id, target_period) on recurring_journal_generation (and the bill mirror) — flag this as the optional hardening; the pessimistic lock alone closes the concurrent double-post which is the confirmed defect and needs no migration.

Regression tests:
- RecurringJournalServiceTest: verify generateFromTemplate invokes the locking finder (Mockito verify on findByIdAndOrgIdForUpdate) — structural guard that the lock path is used.
- RecurringBillServiceTest: same structural assertion.
- If the idempotency guard is added: a test that a second generateFromTemplate for the same unchanged cursor date returns null / no second generation row and posts no second journal.

---

### SEC-13. [MEDIUM] WhatsApp CUSTOM provider POSTs server-side to an org-configurable URL with no SSRF guard, and reflects internal responses into the readable message log
`CONFIRMED`
**Fix applied:** Code-only fix; no Flyway migration. (1) Extract the SSRF host-validation from WorkflowRuleService (the getAllByName + isBlockedAddress resolve-and-inspect logic covering loopback/any-local/link-local incl. 169.254 cloud-metadata/site-local/multicast/RFC-4193 fc00::/7 ULA/CGNAT 100.64.0.0/10, plus https-only) into a shared helper — e.g. `common/net/UrlGuard.validateOutbound(String url)` throwing BusinessException(\"URL_BLOCKED\") on a disallowed scheme/host — and refactor WorkflowRuleService to call it so both sites share one implementation. (2) In WhatsAppService.sendCustom, after reading `url` and before building the HttpRequest, call `UrlGuard.validateOutbound(url)`; because sendTemplate already wraps sendCustom in try/catch that converts exceptions to SendResult.fail, a blocked URL becomes a recorded FAILED row without issuing the request. (3) Enforce the same guard at settings-write time for the `whatsapp.custom_url` key in the settings controller handling PUT /api/v1/settings/whatsapp and the generic PUT /api/v1/settings/{key}, so a bad URL is rejected at 400 on save rather than silently stored. (4) Stop persisting raw non-2xx bodies: change the CUSTOM (and mirror the META) failure line to `SendResult.fail(\"CUSTOM\", \"HTTP \" + resp.statusCode())` or truncate/sanitize resp.body() to ~100 chars with control chars stripped, so a response body can never be reflected verbatim into WhatsAppMessage.errorMessage. Regression tests: (a) WhatsAppServiceTest — configure whatsapp.custom_url to a loopback/link-local host (e.g. http://127.0.0.1/x and http://169.254.169.254/x) and assert sendTemplate returns SendResult ok()==false with a URL_BLOCKED-style error AND that the HttpClient was never invoked (or, if UrlGuard is unit-testable in isolation, assert validateOutbound throws for loopback/link-local/ULA/http-scheme and passes for a normal https public host); (b) assert a non-2xx failure no longer contains the response body (status only / truncated); (c) a settings-controller test asserting PUT of whatsapp.custom_url with an internal host returns 400.

---

### SEC-14. [MEDIUM] pharma.h1_strict=true permanently blocks every H1 sale (prescription can never exist at receipt-create time), and register prescriber fields are always null even in non-strict mode
`CONFIRMED`
**Fix applied:** Two complementary changes, no migration (prescriber_name/prescriber_reg_number/prescriber_address already exist on statutory_register_entry from V6).

1. Capture prescriber/Rx inline on the sale so strict mode has real data to gate on and entries carry prescriber fields at write time. In pos/dto/CreateSalesReceiptRequest add optional receipt-level fields: prescriptionNumber, prescriberName, prescriberRegNumber, prescriberAddress (String). In pos/service/SalesReceiptService.create, pass these to the register writer. Change StatutoryRegisterService.recordSaleEntries signature to accept an inline prescriber context (e.g. recordSaleEntries(receipt, itemMap, PrescriberContext ctx)); populate prescriberName/RegNumber/Address from ctx (fall back to the by-receipt-id lookup for legacy callers/back-office). Base the strict-mode gate (lines 135-140) on whether ctx has a prescription number/prescriber name — not on the always-null findByReceiptId — so H1 sales with a real Rx pass and only genuinely-Rx-less H1 sales throw RX_PRESCRIPTION_REQUIRED. This makes the strict path reachable instead of a catch-22.

2. Add StatutoryRegisterService.backfillPrescriber(receiptId, doctorName, doctorRegNumber, address): loads existing statutory_register_entry rows for that receipt (add StatutoryRegisterRepository.findByOrgIdAndSaleReceiptIdAndIsDeletedFalse) and sets the three prescriber columns where currently null. Call it at the end of PrescriptionService.create when request.receiptId() != null (and enrich the POS _savePrescriptionRecords payload with doctorName/doctorRegNumber so real prescriber data flows). This closes the "shop records the prescription after the sale" gap for non-strict orgs.

Delete or wire up the dead preflightStrictMode (currently zero callers).

Regression tests (StatutoryRegisterServiceTest): (a) strict mode + inline prescriber context supplied -> records entry, no throw and prescriber fields populated; (b) strict mode + no inline Rx -> throws RX_PRESCRIPTION_REQUIRED (now a reachable path); (c) backfillPrescriber updates a previously-null-prescriber entry for the receipt; plus a PrescriptionServiceTest asserting create() with a receiptId invokes backfillPrescriber.

---

### SEC-15. [LOW] Dunning EMAIL channel permanently claims a level as SENT even when EmailService silently swallowed the send failure — the reminder is never delivered and never retried
`CONFIRMED`
**Fix applied:** Make the email send report success, and have the dunning EMAIL branch honor it (mirroring WHATSAPP). Two edits, no migration.

1) EmailService.java: change `private void send(String to, String subject, String html)` to `private boolean send(...)` — return true after `mailSender.send(message)`, `return false` in the catch. Add a second catch for Spring's runtime mail exception so the contract ('best-effort, logs + swallows') is actually honored: `catch (org.springframework.mail.MailException e) { log.error(...); return false; }` alongside the existing `catch (MessagingException e)`. Change `sendHtml(...)` to `return send(to, subject, html);` (make sendHtml return boolean). The seven templated helpers (sendEmailVerification, sendPasswordReset, sendAccountApproved, sendAccountRejected, sendAccountSuspended, sendAdminPasswordReset, sendNewSignupAlert) call send() as a bare statement and simply ignore the new return value — no change needed and no behavioral change for them except that a previously-propagating MailException is now swallowed (which matches the documented best-effort contract). The workflow-rules EMAIL action calls sendHtml and ignores the result, so it is unaffected.

2) DunningDispatcher.java deliver() EMAIL branch (lines 107-113): replace the `emailService.sendHtml(contact.getEmail(), subject, message); return true;` with `return emailService.sendHtml(contact.getEmail(), subject, message);`. When the send fails, sendHtml now returns false → deliver returns false → dispatch (line 98-100) throws NotDeliveredException → the REQUIRES_NEW tx rolls back the SENT claim → the level is retried on the next sweep, exactly like the WHATSAPP branch.

Regression test — DunningDispatcherTest (add if absent, mirroring the existing dunning test fixtures): (a) EMAIL level where emailService.sendHtml(...) is mocked to return false → assert dispatch(...) throws DunningDispatcher.NotDeliveredException (claim rolled back, no committed SENT); (b) EMAIL level where sendHtml returns true → assert Outcome.SENT and the DunningLog saved with outcome="SENT". Optionally an EmailServiceTest case asserting send returns false when JavaMailSender/MimeMessageHelper throws AddressException (malformed 'to') and when mailSender.send throws a MailException.

---
