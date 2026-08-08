# FMCG Business Plan Copy-Paste Test

Use this file to create one complete test organisation for a private-label FMCG business. The business owns the brand, buys raw material or finished goods from different suppliers, uses outside grinders and packers, stores stock, sells through distributors/retailers, and uses field sales staff for visits and collections.

## 1. Organisation Onboarding

Open the ERP onboarding screens and enter:

```text
Organisation name: Sampurna Foods and Distribution
Business type: DISTRIBUTOR
Industry: FMCG Distributor
Industry code: FMCG_DISTRIBUTOR
Sub-category: FOOD_BEV_DIST
Country: IN
State: Maharashtra
State code: 27
City: Pune
PIN: 411001
Address: 12 Market Yard Road
```

Expected modules after onboarding:

```text
ACCOUNTING
AR
AP
GST
INVENTORY
DISTRIBUTION
FIELD_SALES
REPORTS
POS
```

For this business, the Field Sales menu must be available. The approval screen should be named `Field Approvals`, not `MR Approvals`, because this organisation is FMCG and not pharma.

## 2. Login Users

Use password `Demo@1234` for demo users.

| User | Phone | Role | Use |
|---|---|---|---|
| Demo Owner | 9000000001 | OWNER | Setup, accounting, approvals |
| Demo Admin | 9000000002 | ADMIN | Master data, routes, operations |
| Demo Accountant | 9000000003 | ACCOUNTANT | Bills, payments, journals, reports |
| Demo Salesman | 9000000005 | OPERATOR | Field app visits, orders, collections |
| Demo Operator 2 | 9000000008 | OPERATOR | Ownership and route security test |
| Demo Viewer | 9000000007 | VIEWER | Read-only verification |

Field app login:

```text
Phone: 9000000005
Password: Demo@1234
```

## 3. Warehouse

Open `Inventory -> Warehouses -> Add warehouse`.

```text
Code: MAIN
Name: Main Warehouse
Address line 1: 12 Market Yard Road
Address line 2: Near APMC Gate 2
City: Pune
State: Maharashtra
State code: 27
PIN: 411001
Country: IN
Default warehouse: Yes
```

Optional second warehouse:

```text
Code: WEST
Name: West Pune Stock Point
Address line 1: 44 Industrial Estate
City: Pune
State: Maharashtra
State code: 27
PIN: 411026
Country: IN
Default warehouse: No
```

## 4. Capital Setup

Open `Accounting -> Chart of Accounts -> Add Account` and create these equity accounts:

```text
Account type: Equity
Sub-type: Owner Equity
Account code: 3011
Account name: Capital - Partner A

Account type: Equity
Sub-type: Owner Equity
Account code: 3012
Account name: Capital - Partner B

Account type: Equity
Sub-type: Owner Equity
Account code: 3013
Account name: Capital - Partner C
```

Open `Accounting -> Manual Journal` and enter:

```text
Effective date: 01 Aug 2026
Reference: INITIAL-CAPITAL-001
Description: Initial capital contribution by three partners
```

Lines:

```text
Line 1 account: 1020 - Bank Account
Line 1 debit: 300000
Line 1 credit: 0

Line 2 account: 3011 - Capital - Partner A
Line 2 debit: 0
Line 2 credit: 100000

Line 3 account: 3012 - Capital - Partner B
Line 3 debit: 0
Line 3 credit: 100000

Line 4 account: 3013 - Capital - Partner C
Line 4 debit: 0
Line 4 credit: 100000
```

Expected: total debit and credit are both `300000`. Post the journal. Do not edit the posted entry; use a reversal journal if the amount is wrong.

## 5. Supplier Masters

Open `Contacts -> Add Contact` and create these vendors.

```text
Name: Shakti Spice Manufacturer
Type: Vendor
Phone: 9010000001
GSTIN: 27ABCDE1234F1Z5
State: Maharashtra
Payment terms: 30 days

Name: Bharat Grain Supplier
Type: Vendor
Phone: 9010000002
GSTIN: 27BCDEF2345G1Z6
State: Maharashtra
Payment terms: 15 days

Name: Ganesh Grinding Works
Type: Vendor
Phone: 9010000003
GSTIN: 27CDEFG3456H1Z7
State: Maharashtra
Payment terms: 15 days

Name: PackRight Packaging Services
Type: Vendor
Phone: 9010000004
GSTIN: 27DEFGH4567J1Z8
State: Maharashtra
Payment terms: 15 days

Name: FastTrack Transport
Type: Vendor
Phone: 9010000005
GSTIN: 27EFGHI5678K1Z9
State: Maharashtra
Payment terms: Immediate
```

## 6. Units and Items

Use the item form from `Inventory -> Items -> Add Item`.

### Unit rules

```text
1 BAG = 50 KG
1 KG = 1000 GM
1 CASE = 24 BOTTLE
1 CASE = 12 PACK
1 PACK = 1 selling pack
```

### Raw materials

Create these as inventory goods:

| Name | SKU | Base unit | Purchase unit | Conversion | Purchase price |
|---|---|---|---|---|---:|
| Whole Turmeric | RM-TURMERIC | KG | BAG | 1 BAG = 50 KG | 140 per KG |
| Cumin Seed | RM-CUMIN | KG | BAG | 1 BAG = 50 KG | 220 per KG |
| Gram Flour Base | RM-CHICKPEA | KG | BAG | 1 BAG = 50 KG | 78 per KG |
| Packaging Pouch 100 GM | PK-100GM | PCS | CASE | 1 CASE = 1000 PCS | 1.20 per PCS |
| Printed Masala Label | PK-LABEL | PCS | PACK | 1 PACK = 1000 PCS | 0.35 per PCS |

For raw materials, set `Track inventory = Yes`, `Selling price = 0`, and enter the correct purchase unit and conversion. Use opening stock only for stock already present before the ERP start date.

### Finished goods

| Name | SKU | Base unit | Purchase unit | Selling price | GST |
|---|---|---|---|---:|---:|
| Sampurna Turmeric Powder 100 GM | FG-TURMERIC-100 | PACK | CASE | 45 per PACK | 5 |
| Sampurna Besan 1 KG | FG-BESAN-1KG | PACK | CASE | 120 per PACK | 5 |
| Sampurna Five Dal Family Mix 500 GM | FG-DAL-MIX-500 | PACK | CASE | 85 per PACK | 5 |
| Sampurna Plain Sattu 1 KG | FG-SATTU-1KG | PACK | CASE | 110 per PACK | 5 |
| Sampurna Jamun Vinegar 500 ML | FG-VINEGAR-500 | BOTTLE | CASE | 160 per BOTTLE | 12 |

For loose grocery sales, create a separate loose item when required:

```text
Name: Loose Sugar
SKU: FG-SUGAR-LOOSE
Base selling unit: KG
Purchase unit: BAG
Conversion: 1 BAG = 50 KG
Purchase price per BAG: 2200
Selling price per KG: 50
GST: use the HSN result selected in the form
Track inventory: Yes
```

## 7. Finished-Goods Purchase Test

Use this as the first complete supported distribution flow.

Open `Purchases -> Purchase Orders -> New Purchase Order`.

```text
Supplier: Shakti Spice Manufacturer
Warehouse: Main Warehouse
Supplier reference: SHAKTI-PO-001
Payment terms: 30 days
```

Add:

```text
Item: Sampurna Turmeric Powder 100 GM
Quantity: 1000 PACK
Purchase price: 28 per PACK
Batch: TUR-2608-A
Expiry: 31 Jul 2028

Item: Sampurna Five Dal Family Mix 500 GM
Quantity: 500 PACK
Purchase price: 58 per PACK
Batch: DAL-2608-A
Expiry: 31 Jul 2028
```

Process:

1. Save the purchase order.
2. Create a Goods Receipt from the purchase order.
3. Enter the actual received quantities and costs.
4. Receive stock on the receipt detail page.
5. Create or post the supplier bill if the screen requires a separate bill step.
6. Verify stock, batch, supplier payable, input GST, and purchase journal.

Expected stock after receipt:

```text
Sampurna Turmeric Powder 100 GM: 1000 PACK
Sampurna Five Dal Family Mix 500 GM: 500 PACK
```

## 8. Raw Material, Grinding, and Packaging Cost Test

Use this flow to test your private-label cost model.

### Raw material purchase

Create a purchase order for `Bharat Grain Supplier`:

```text
Item: Whole Turmeric
Quantity: 4 BAG
Conversion: 1 BAG = 50 KG
Received quantity: 200 KG
Purchase price: 140 per KG
Supplier invoice: GRAIN-001
```

Expected raw material value: `28000`.

### Grinding job work

Open `Manufacturing -> Job Work -> New Job Work` if enabled.

```text
Vendor: Ganesh Grinding Works
Input item: Whole Turmeric
Input quantity: 200 KG
Service: Grinding
Rate: 12 per KG
Expected service cost: 2400
Reference: GRIND-TUR-001
```

Record the vendor bill or expense for `2400`. Verify that the amount is posted to the correct expense or conversion-cost account and is included in the cost report as a separate component.

### Packaging

Create a packaging service or expense for `PackRight Packaging Services`:

```text
Finished item: Sampurna Turmeric Powder 100 GM
Output quantity: 2000 PACK
Pouch quantity: 2000 PCS
Label quantity: 2000 PCS
Pouch cost: 1.20 per PCS
Label cost: 0.35 per PCS
Packing labour: 2.00 per PACK
Total packaging cost: 7100
Reference: PACK-TUR-001
```

### Other landed costs

Record separate expenses:

```text
Transport cost: 1800
Handling cost: 600
Quality testing cost: 400
```

Expected cost components for this batch:

```text
Raw turmeric: 28000
Grinding: 2400
Packaging: 7100
Transport: 1800
Handling: 600
Quality testing: 400
Total batch cost: 40300
Output quantity: 2000 PACK
Expected cost per PACK: 20.15
```

Verify that costs are traceable to the source purchase, job work, expense, vendor, user, date, and output batch. Do not overwrite a posted cost; use a correction or reversal transaction.

## 9. Customers and Field Sales

Create these customer contacts:

```text
Name: Shree Kirana Store
Type: Customer
Phone: 9020000001
Payment terms: Cash

Name: Maa General Store
Type: Customer
Phone: 9020000002
Payment terms: 15 days

Name: Om Wholesale Mart
Type: Customer
Phone: 9020000003
Payment terms: 30 days

Name: Radha Provision Store
Type: Customer
Phone: 9020000004
Payment terms: 15 days

Name: Unassigned Test Shop
Type: Customer
Phone: 9020000005
Payment terms: Cash
```

In `Field Sales` create:

```text
Beat code: MAIN-MARKET
Beat name: Main Market
Customers: Shree Kirana Store, Maa General Store, Radha Provision Store

Beat code: WHOLESALE-MARKET
Beat name: Wholesale Market
Customers: Om Wholesale Mart

Route code: MONDAY-MARKET
Route name: Monday Main Market
Day: Monday
Beat: MAIN-MARKET

Route code: TUESDAY-WHOLESALE
Route name: Tuesday Wholesale Market
Day: Tuesday
Beat: WHOLESALE-MARKET
```

Assign `Demo Salesman` to `MONDAY-MARKET` and `Demo Operator 2` to `TUESDAY-WHOLESALE`.

## 10. Daily Field App Test

Login to the field app as `9000000005` / `Demo@1234`.

1. Open Today and start the Monday route.
2. Check in at Shree Kirana Store.
3. Record a cash order for 10 Turmeric Powder packs and 5 Dal Mix packs.
4. Record collection of the exact invoice amount.
5. Check out and continue to Maa General Store.
6. Record a credit order for 20 Besan packs.
7. Check out and complete the route.
8. Submit the daily report from the field app.
9. Open ERP as Owner/Admin and open `Field Sales -> Field Approvals`.
10. Approve the submitted daily report.

Expected:

```text
The field app shows generic FMCG wording, not medical-only wording.
The ERP menu says Field Approvals.
The route, salesperson, visit time, GPS ping, order, collection, and report are linked.
The approval page shows Tour Plans and Daily Reports.
```

## 11. Sales, Dispatch, and Collection Test

Open `Sales -> Sales Orders` as Admin.

```text
Customer: Maa General Store
Payment mode: Credit
Credit days: 15
Item: Sampurna Besan 1 KG
Quantity: 20 PACK
Rate: 120
Discount: 0
```

Process:

1. Save and confirm the sales order.
2. Create a delivery challan.
3. Dispatch the challan and verify stock decreases by 20 PACK.
4. Convert the dispatch to a sales invoice.
5. Open `Sales -> Payments/Collections`.
6. Record a partial payment of `1000`.
7. Verify the remaining customer outstanding.
8. Record the balance payment and verify the invoice is paid.

Also test one cash order for `Shree Kirana Store`. Expected: POS or cash sales post to cash/revenue, not Accounts Receivable.

## 12. Accounting Verification

Open these screens after posting transactions:

```text
Accounting -> Journal Register
Accounting -> Day Book
Accounting -> Chart of Accounts
Reports -> Cash Flow
Reports -> GST Summary
Reports -> Stock Summary
Reports -> Customer Statement
Reports -> Vendor Statement
```

Verify:

```text
Bank opening capital: debit 300000
Partner capital accounts: credit 100000 each
Purchase: inventory debit and supplier payable credit
Grinding/packing/transport: expense or cost ledger component is visible
Credit sale: customer receivable debit and sales/GST credit
Customer receipt: bank/cash debit and receivable credit
Supplier payment: payable debit and bank/cash credit
Stock quantity and stock value change together
```

## 13. Audit and Immutability Test

1. Post a transport expense of `1000` as Accountant.
2. Login as another user and try to change it to `1500`.
3. Expected: the posted transaction cannot be edited in place.
4. If the amount is wrong, create a reversal/correction with reference `CORRECTION-TRANSPORT-001`.
5. Open the audit log and verify who created, posted, reversed, or approved each transaction.
6. Verify self-approval is rejected when the submitter tries to approve their own report.

## 14. Viewer and Ownership Security

As `Demo Viewer`:

```text
Open reports: allowed
Open item and customer details: allowed
Create item: blocked
Post purchase: blocked
Dispatch stock: blocked
Record collection: blocked
Approve field report: blocked
Change route assignment: blocked
```

As `Demo Operator 2`, try opening or acting on the Monday route and its visits. Expected: only the assigned salesperson can perform visit actions, while Admin/Owner can supervise.

## 15. Final Pass Checklist

Mark each item only after checking the screen and the accounting/report result:

```text
[ ] FMCG onboarding saved businessType and industryCode
[ ] Field Sales module enabled for distributor
[ ] ERP menu says Field Approvals for FMCG
[ ] Pharma wording is not shown in FMCG screens
[ ] Partners capital journal is balanced and posted
[ ] Warehouse and supplier masters created
[ ] Raw material purchase received
[ ] Finished goods purchase received
[ ] Grinding cost recorded separately
[ ] Packaging cost recorded separately
[ ] Transport and handling costs recorded separately
[ ] Cost per output unit is traceable
[ ] Batch/expiry and stock quantities are correct
[ ] Field route and salesperson assignment are correct
[ ] Visit GPS and route execution are recorded
[ ] Field order and collection reach ERP
[ ] Daily report is submitted and approved
[ ] Sales order to dispatch to invoice works
[ ] Customer outstanding is correct
[ ] Vendor outstanding is correct
[ ] Journals and reports reconcile
[ ] Posted entries are immutable and reversals are auditable
[ ] Viewer and salesperson permissions are enforced

## 16. Verified SO-DC-Invoice Run (2026-08-08)

This is the first end-to-end distributor transaction verified manually. Keep it as the reference flow for regression testing after future changes.

### Sales Order

```text
Customer: Shree Ganesh Kirana Store
Item: Turmeric Masala 100g
Quantity: 10 PCS
Rate: 45 per PCS
GST: 18%
Fulfilment warehouse: Main FMCG Warehouse
Subtotal: 450
GST amount: 81
Total: 531
Expected initial status: DRAFT
```

Process:

1. Create the Sales Order and verify the total is `531`.
2. Confirm the Sales Order.
3. Verify stock is reserved from `Main FMCG Warehouse` and the order becomes `CONFIRMED`.

### Delivery Challan

```text
Sales Order: SO-2026-000001
Vehicle Number: dl3ccp5617
Tracking Number: 35342k
Delivery Method: hand by bike
Quantity to dispatch: 10 PCS
```

Process:

1. Create the Delivery Challan from the confirmed Sales Order.
2. Open the challan detail page and verify its status is `DRAFT`.
3. Dispatch the challan.
4. Verify the status becomes `DISPATCHED` and stock decreases by `10 PCS`.
5. Verify the linked Sales Order shows `10` shipped.

### Sales Invoice

1. Select `Create Sales Invoice` from the dispatched challan.
2. Verify the invoice contains the dispatched quantity only.
3. Verify the invoice totals:

```text
Subtotal: 450
Tax: 81
Total: 531
Amount paid: 0
Balance due: 531
Invoice status: SENT
Sales Order invoiced status: FULLY_INVOICED
```

4. Verify the Sales Order status becomes `INVOICED`.
5. Verify the Delivery Challan remains `DISPATCHED`; this is correct because dispatch status and billing status are separate.
6. Verify the Delivery Challan no longer offers `Create Sales Invoice` after the Sales Order is fully invoiced.
7. A second invoice attempt must be rejected and must not create another invoice.

### Payment Test - Next Step

Open the invoice and click `Record Payment`.

```text
Payment amount: 531
Payment mode: CASH
Payment date: 08 Aug 2026
Reference: CASH-SHREE-001
Notes: Full payment for INV-2026-000001
```

Expected result:

```text
Invoice status: PAID
Amount paid: 531
Balance due: 0
Customer outstanding: reduced by 531
Journal: Debit Cash / Bank, Credit Accounts Receivable
```

After any backend or Flutter code change, restart the backend and restart Flutter before repeating this flow. Refresh the existing document before creating a new one; do not create duplicate challans or invoices for the same shipped quantity.
```
