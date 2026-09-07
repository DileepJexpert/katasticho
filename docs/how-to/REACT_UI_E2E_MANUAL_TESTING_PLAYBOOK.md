# Katasticho ERP — React UI End-to-End Manual Testing Playbook

This playbook provides a complete, phase-by-phase testing guide for manually feeding data from scratch into the new React UI (`react_app`) and validating every ERP module.

Follow the phases in exact numerical order: in an accounting and ERP system, subsequent operations strictly depend on entities and balances established in earlier phases.

---

## Quick Navigation & Progress Matrix

| Phase | Module / Area | Primary Route | Prerequisites | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 0** | Environment & Authentication | `/login`, `/` | Backend & Vite running | [ ] |
| **Phase 1** | Foundation & Master Data | `/accounts`, `/warehouses`, `/contacts`, `/items` | Phase 0 | [ ] |
| **Phase 2** | Inbound Procurement (PO → GRN → Bill → Pay) | `/purchase-orders`, `/stock-receipts`, `/bills` | Phase 1 | [ ] |
| **Phase 3** | Inventory Audits & Warehouse Operations | `/inventory/stock-summary`, `/stock-counts` | Phase 2 | [ ] |
| **Phase 4** | Outbound Sales (SO → DC → Invoice → Pay) | `/sales-orders`, `/delivery-challans`, `/invoices`| Phase 2 & 3 | [ ] |
| **Phase 5** | Retail POS Counter & Cash Register | `/pos`, `/pos/cash-registers` | Phase 2 | [ ] |
| **Phase 6** | Financial Accounting, Banking & Tax Hub | `/reports`, `/banking`, `/gst`, `/compliance/tds` | Phase 2, 4 & 5 | [ ] |
| **Phase 7** | HR, Attendance & Payroll | `/employees`, `/payroll/runs` | Phase 1 (CoA) | [ ] |
| **Phase 8** | Enterprise Verticals (Field Sales, Transport, Loyalty) | `/field-sales`, `/transport`, `/loyalty` | Phase 1 & 4 | [ ] |

---

## Phase 0: Environment Launch & Auth Setup

### 0.1 Launch Services
1. **Start Backend (Spring Boot):**
   ```powershell
   ./mvnw spring-boot:run
   ```
   *Verified Port:* `http://localhost:8080` (Postgres on 55432 / Flyway migrations applied).
2. **Start Frontend (React + Vite):**
   ```bash
   cd react_app
   npm run dev
   ```
   *Verified Port:* `http://localhost:5173` (Vite dev server with `/api` proxy).

### 0.2 Sign In
- **URL:** `http://localhost:5173/login`
- **Default Test Credentials:**
  - **Phone / Email:** `9000000001` *(or your registered admin phone)*
  - **Password:** `Test@12345` *(or `Demo@1234`)*
- **Expected Result:**
  - Redirects to Dashboard Overview (`/`).
  - Organization name and user avatar appear in the top navbar.
  - JWT token is stored in memory and sent via `Authorization: Bearer` and `X-Org-Id`.

### 0.3 Navigation Shell Verification
- [ ] Press **`Ctrl + K`** (or `Cmd + K`) to open the Command Palette. Type "Items" and hit Enter — confirms fast navigation.
- [ ] Toggle **Theme Mode** (Dark / Light) in the header — confirms theme tokens persist.
- [ ] Collapse and expand sidebar — verifies navigation responsive state.

---

## Phase 1: Foundation & Master Data Setup

### 1.1 Chart of Accounts Verification
* **Route:** `/accounts`
* **Test Steps:**
  1. Open the Accounts table and verify standard Indian accounts exist:
     - `1001` — Cash on Hand
     - `1002` — Main Bank Account
     - `1200` — Accounts Receivable (Debtors)
     - `1300` — Stock Asset / Inventory
     - `2001` — Accounts Payable (Creditors)
     - `2041` — GST Output Tax
     - `1511` — GST Input Tax Credit
     - `4001` — Sales Revenue
     - `5001` — Cost of Goods Sold (COGS)
  2. Click **"+ New Account"**:
     - **Code:** `6015`
     - **Name:** `Warehouse & Packing Supplies`
     - **Type:** `EXPENSE`
     - Click **Save Account**.
* **Expected Result:** Account `6015` appears in the list with zero balance.

---

### 1.2 Warehouses & Racks
* **Route:** `/warehouses` and `/inventory/rack-locations`
* **Test Steps:**
  1. Go to `/warehouses` and click **"+ New Warehouse"**:
     - **Name:** `Central Warehouse - Mumbai`
     - **Code:** `WH-BOM-01`
     - **Address:** `Plot 42, MIDC Andheri East, Mumbai, Maharashtra 400093`
     - **Is Default:** `Yes`
     - Click **Save**.
  2. Go to `/inventory/rack-locations` and click **"+ Add Rack"**:
     - **Warehouse:** `WH-BOM-01`
     - **Rack Code:** `RACK-A1`
     - **Zone:** `Ambient Bulk`
     - **Shelf / Bin:** `S1-B1`
     - Click **Save**.
* **Expected Result:** Warehouse `WH-BOM-01` and rack `RACK-A1` are saved and active.

---

### 1.3 Contacts Master (Vendor & Customer)
* **Route:** `/contacts/new`

#### Contact 1: Supplier / Vendor
- **Business Name:** `Apex Healthcare Distributors Pvt Ltd`
- **Contact Type:** `Vendor`
- **GSTIN:** `27AABCU9603R1ZM` (Maharashtra State 27)
- **PAN:** `AABCU9603R`
- **Phone / Email:** `+91 98200 11223` / `orders@apexdist.com`
- **Address:** `B-12 Commercial Towers, Lower Parel, Mumbai, MH 400013`
- **Payment Terms:** `Net 30 Days`
- **Action:** Click **Save Contact**.

#### Contact 2: Retail Customer
- **Business Name:** `Apollo Care Chemist & Retail`
- **Contact Type:** `Customer`
- **GSTIN:** `27AABCU1234G1Z1` (Intra-state Maharashtra 27)
- **PAN:** `AABCU1234G`
- **Phone / Email:** `+91 98111 22334` / `billing@apollocare.in`
- **Address:** `Shop 4, Linking Road, Bandra West, Mumbai, MH 400050`
- **Credit Limit:** `₹1,00,000` | **Credit Days:** `15`
- **Action:** Click **Save Contact**.

* **Expected Result:** Both contacts appear in `/contacts` with zero outstanding balance.

---

### 1.4 Items / Product Catalog
* **Route:** `/items/new`

#### Item A: Pharma / Batch-Tracked Drug
- **Item Name:** `Dolo 650mg Tablets (Strip of 15)`
- **SKU:** `MED-DOLO-650`
- **Type:** `Inventory Item`
- **HSN Directory Search:** Search `3004` and select `3004 - Medicaments consisting of mixed or unmixed products`.
- **GST Rate:** `12%` (6% CGST + 6% SGST)
- **Unit of Measure:** `STRIP`
- **Purchase Price:** `₹24.00`
- **Selling Price:** `₹33.50` | **MRP:** `₹36.00`
- **Track Batches:** Toggle **ON**
- **Reorder Level:** `50`
- Click **Save Item**.

#### Item B: FMCG / Standard Non-Batch Item
- **Item Name:** `N95 Protective Respirator Mask`
- **SKU:** `GEN-N95-MASK`
- **Type:** `Inventory Item`
- **HSN Directory Search:** Search `6307` and select `6307 - Other made up articles`.
- **GST Rate:** `5%`
- **Unit of Measure:** `PCS`
- **Purchase Price:** `₹15.00`
- **Selling Price:** `₹30.00` | **MRP:** `₹35.00`
- **Track Batches:** Toggle **OFF**
- Click **Save Item**.

* **Expected Result:** Both items appear in `/items`. Stock is currently 0.

---

## Phase 2: Inbound Procurement Flow

### 2.1 Purchase Order (PO)
* **Route:** `/purchase-orders/new`
* **Test Steps:**
  1. **Vendor:** Select `Apex Healthcare Distributors Pvt Ltd`.
  2. **Order Date:** Today | **Expected Date:** +5 days.
  3. **Line Items:**
     - `Dolo 650mg Tablets`: Quantity = `200 STRIP`, Unit Cost = `₹24.00`
     - `N95 Protective Respirator Mask`: Quantity = `100 PCS`, Unit Cost = `₹15.00`
  4. Verify Calculation:
     - Dolo taxable: ₹4,800.00 + GST 12% (₹576.00) = ₹5,376.00
     - Mask taxable: ₹1,500.00 + GST 5% (₹75.00) = ₹1,575.00
     - Grand Total: **₹6,951.00** (Tax split: CGST ₹325.50, SGST ₹325.50).
  5. Click **"Save & Confirm PO"**.
* **Expected Result:** PO status changes to `CONFIRMED`.

---

### 2.2 Goods Receipt Note (GRN / Inwarding)
* **Route:** `/stock-receipts/new`
* **Test Steps:**
  1. Click **"Inward from PO"** and choose the PO created in 2.1.
  2. Warehouse: `Central Warehouse - Mumbai`.
  3. **Batch Capture for Dolo 650:**
     - **Batch Number:** `DOLO-2026-B1`
     - **Mfg Date:** `2026-01-15`
     - **Expiry Date:** `2027-12-31`
     - **Rack:** `RACK-A1`
     - **Received Qty:** `200`
  4. **Quantity for Mask:** `100 PCS`.
  5. Click **"Submit & Inward Stock"**.
* **Expected Result:**
  - Stock is physically received.
  - Check `/inventory/stock-summary`: Dolo = 200 STRIP, N95 Mask = 100 PCS.
  - Opening FIFO cost lot created with unit costs ₹24.00 and ₹15.00.

---

### 2.3 3-Way Matching & Vendor Bill Posting
* **Route:** `/bills/new`
* **Test Steps:**
  1. Select Vendor: `Apex Healthcare Distributors Pvt Ltd`.
  2. Enter Supplier Invoice No: `APEX/26-27/0889`.
  3. Click **"Link Receipts"** and select the GRN from 2.2.
  4. Notice auto-populated lines matching GRN quantities.
  5. Click **"Verify 3-Way Match"** (`/three-way-match`) — confirms 0 variance.
  6. Click **"Approve & Post Bill"**.
* **Expected Result:**
  - Bill moves to `POSTED`.
  - AP ledger journal posts: DR Inventory Asset ₹6,300.00, DR Input GST ₹651.00, CR Accounts Payable ₹6,951.00.
  - Vendor statement shows outstanding balance: **₹6,951.00**.

---

### 2.4 Vendor Payment
* **Route:** `/vendor-payments/new`
* **Test Steps:**
  1. Vendor: `Apex Healthcare Distributors Pvt Ltd`.
  2. Paying Bank Account: `1002 - Main Bank Account`.
  3. Payment Mode: `NEFT / Bank Transfer` | Reference / UTR: `UTR-HDFC-991188`.
  4. Allocation: Allocate `₹6,951.00` to Bill `APEX/26-27/0889`.
  5. Click **"Submit Payment"**.
* **Expected Result:**
  - Bill status updates to `PAID`.
  - Contact outstanding balance for Apex Healthcare resets to **₹0.00**.
  - Journal posts: DR Accounts Payable ₹6,951.00, CR Bank Account ₹6,951.00.

---

## Phase 3: Inventory & Warehouse Operations

### 3.1 Stock Summary & Valuation
* **Route:** `/inventory/stock-summary`
* **Test Steps:**
  - Verify total stock valuation: (200 × ₹24) + (100 × ₹15) = **₹6,300.00**.
  - Verify reorder shortage flags are cleared (stock > reorder level).

### 3.2 Batch Tracing & Expiry Inspection
* **Route:** `/inventory/batches` and `/near-expiry`
* **Test Steps:**
  - Filter by `DOLO-2026-B1`: verify 200 available, expiry `2027-12-31`.
  - Test the Near-Expiry alert table with threshold set to 90 days (should show no urgent alerts for 2027 expiry).

### 3.3 Warehouse Transfer Order
* **Route:** `/transfer-orders/new`
* **Test Steps:**
  1. Transfer `20 PCS` of `N95 Protective Respirator Mask` from `Central Warehouse - Mumbai` to secondary location or bin.
  2. Click **"Dispatch"** → Click **"Receive"**.
* **Expected Result:** Transfer completes cleanly; total org valuation remains unchanged.

### 3.4 Physical Stock Count & Adjustment
* **Route:** `/stock-counts/new`
* **Test Steps:**
  1. Choose `Central Warehouse - Mumbai` and item `N95 Protective Respirator Mask`.
  2. System Expected Count: `100 PCS` (or 80 if 20 were transferred).
  3. Input Physical Count: Record `1 unit less` (e.g. `99 PCS`).
  4. Click **"Submit Count"** → Click **"Approve Reconciliation"**.
* **Expected Result:**
  - System logs 1 unit shrinkage variance.
  - Auto-posts shrinkage journal: DR Stock Adjustment / Loss, CR Inventory Asset (₹15.00).

---

## Phase 4: Outbound Sales Flow (Order to Cash)

### 4.1 Sales Order (SO)
* **Route:** `/sales-orders/new`
* **Test Steps:**
  1. Customer: `Apollo Care Chemist & Retail`.
  2. Order Date: Today.
  3. Line Items:
     - `Dolo 650mg Tablets`: Qty = `50 STRIP`, Unit Price = `₹33.50`
     - `N95 Protective Respirator Mask`: Qty = `20 PCS`, Unit Price = `₹30.00`
  4. Verify Calculation:
     - Dolo: ₹1,675.00 + GST 12% (₹201.00) = ₹1,876.00
     - Mask: ₹600.00 + GST 5% (₹30.00) = ₹630.00
     - Grand Total: **₹2,506.00**.
  5. Check Credit Control Banner: confirms ₹2,506.00 is well within customer's ₹1,00,000 credit limit.
  6. Click **"Confirm Sales Order"**.
* **Expected Result:** Sales Order status becomes `CONFIRMED`.

---

### 4.2 Delivery Challan Dispatch (FEFO Batch Pick)
* **Route:** `/delivery-challans/new`
* **Test Steps:**
  1. Create Challan linked to the Sales Order above.
  2. Notice **Auto-Pick (FEFO)**: Batch `DOLO-2026-B1` is automatically selected for Dolo with 50 units allocated.
  3. Click **"Dispatch Goods"**.
* **Expected Result:**
  - Delivery Challan status changes to `DISPATCHED`.
  - **Stock Check:** Open `/inventory/stock-summary`.
    - Dolo stock drops from `200` to `150 STRIP`.
    - Mask stock drops by `20 PCS`.
  - Immutable stock movement records FIFO unit cost for COGS.

---

### 4.3 Sales Tax Invoice
* **Route:** `/invoices/new`
* **Test Steps:**
  1. Click **"Convert from Challan"** and select the dispatched challan.
  2. Verify B2B GSTIN `27AABCU1234G1Z1` and tax breakdown:
     - CGST: `₹115.50`
     - SGST: `₹115.50`
     - Invoice Total: **₹2,506.00**.
  3. Click **"Authorize & Send Invoice"**.
* **Expected Result:**
  - Invoice moves to `SENT` / `POSTED`.
  - Posts Financial Journal:
    - DR Accounts Receivable `₹2,506.00`
    - DR Cost of Goods Sold (prorated FIFO cost)
    - CR Sales Revenue `₹2,275.00`
    - CR GST Output CGST `₹115.50`
    - CR GST Output SGST `₹115.50`
    - CR Inventory Asset (at cost)
  - **Crucial Rule:** NO duplicate stock deduction occurs (already deducted at Challan dispatch).
  - Customer statement shows outstanding AR: **₹2,506.00**.

---

### 4.4 Customer Payment Collection
* **Route:** `/payments/new`
* **Test Steps:**
  1. Customer: `Apollo Care Chemist & Retail`.
  2. Deposit Account: `1002 - Main Bank Account`.
  3. Payment Mode: `UPI / QR Code` | UTR: `UPI-APOLLO-772211`.
  4. Amount: `₹2,506.00` (allocate to Invoice).
  5. Click **"Submit Payment"**.
* **Expected Result:**
  - Invoice status changes to `PAID`.
  - Customer outstanding balance drops back to **₹0.00**.
  - Posts Journal: DR Main Bank Account ₹2,506.00, CR Accounts Receivable ₹2,506.00.

---

## Phase 5: Retail POS Counter (Front-of-House)

### 5.1 Open Register / Shift
* **Route:** `/pos`
* **Test Steps:**
  1. On loading POS, opening register prompt appears.
  2. Opening Drawer Cash: Enter `₹1,000.00`.
  3. Click **"Open Register"**.
* **Expected Result:** Active register session begins; POS terminal UI renders.

---

### 5.2 Counter Billing & Cart
* **Test Steps:**
  1. Search `MED-DOLO-650` in the barcode/item search box. Click to add `2 Strips`.
  2. Search `GEN-N95-MASK`. Add `3 Masks`.
  3. Cart calculates line totals, taxes, and grand total in real-time.
  4. Pharma Safety Check: Verify interaction banner behaves correctly if conflicting salts are configured.

---

### 5.3 Checkout Tender
* **Test Steps:**
  1. Click **"Pay"**.
  2. Choose **Cash**: Tendered `₹200.00` → system displays exact Change Due.
  3. Click **"Complete Sale & Print Receipt"**.
* **Expected Result:**
  - Thermal receipt modal previews receipt with HSN breakdown and tax summary.
  - Posts POS Cash Journal directly: DR Cash on Hand, CR Sales Revenue, CR GST Output (bypasses AR).

---

### 5.4 Shift Close & Cash Drawer Reconciliation
* **Route:** `/pos/cash-registers`
* **Test Steps:**
  1. Click **"Close Current Shift"**.
  2. System shows Expected Cash: `₹1,000.00 (Float) + Cash Sales`.
  3. Input Counted Cash matching expected.
  4. Submit shift close.
* **Expected Result:** Register session closes cleanly with 0 variance.

---

## Phase 6: Financial Accounting, Banking & Tax Hub

### 6.1 Accounting Reports Verification
* **Route:** `/reports`
* **Test Steps:**
  - **Day Book (`/reports/day-book`):** Select today's date — confirm all transactions (GRN, Bill, Bill Payment, Challan COGS, Sales Invoice, Customer Receipt, POS Receipt) are logged in chronological order.
  - **Trial Balance (`/reports/trial-balance`):** Confirm Total Debits equal Total Credits.
  - **Profit & Loss (`/reports/profit-and-loss`):**
    - Revenue = Sales Invoice Revenue + POS Counter Revenue.
    - COGS = Blended FIFO cost lot consumption.
    - Gross Profit is accurate and positive.
  - **Balance Sheet (`/reports/balance-sheet`):** Assets = Liabilities + Capital.

---

### 6.2 Manual Journal Entry
* **Route:** `/journals/new`
* **Test Steps:**
  1. Date: Today | Reference: `MJE-ADJUST-01`.
  2. Line 1: DR `6015 - Warehouse & Packing Supplies` = `₹500.00`.
  3. Line 2: CR `1001 - Cash on Hand` = `₹500.00`.
  4. Narration: `Purchased packing tape and bubble wrap`.
  5. Click **"Post Journal Entry"**.
* **Expected Result:** Journal appears in General Ledger; Cash account decreases by ₹500.00.

---

### 6.3 Statutory GST Center
* **Route:** `/gst`
* **Test Steps:**
  - **GSTR-1:**
    - **Table 4A (B2B):** Displays the Sales Invoice for `Apollo Care Chemist` with GSTIN `27AABCU1234G1Z1`.
    - **Table 7/9 (B2C):** Displays the retail POS counter sale.
    - **HSN Summary:** Displays entries for `3004` and `6307`.
    - Click **"Export GSTR-1 CSV"** / **"Export JSON"** to test compliance download.
  - **GSTR-3B:**
    - Table 3.1: Displays Outward Taxable Supplies.
    - Table 4.A.5: Displays Input Tax Credit (ITC) from the Apex Healthcare vendor bill.

---

### 6.4 TDS & TCS Compliance
* **Route:** `/compliance/tds` and `/compliance/tcs`
* **Test Steps:**
  - Verify Section 194C / 194J / 194Q thresholds.
  - Check TDS summary table and CSV export button.

---

## Phase 7: HR, Attendance & Payroll

### 7.1 Employee Master Setup
* **Route:** `/employees`
* **Test Steps:**
  1. Click **"+ Add Employee"**:
     - **Name:** `Suresh Patil`
     - **Email:** `suresh.patil@company.com` | **Mobile:** `+91 98765 43210`
     - **Department:** `Operations` | **Designation:** `Warehouse Executive`
     - **PAN:** `ABCPS1234D` | **UAN:** `100987654321`
     - Click **Save Employee**.
* **Expected Result:** Employee appears active in employee list.

---

### 7.2 Salary Structure Setup
* **Route:** `/payroll/settings`
* **Test Steps:**
  1. Assign salary structure for Suresh Patil:
     - **Basic Salary:** `₹20,000.00`
     - **HRA:** `₹8,000.00`
     - **Special Allowance:** `₹4,000.00`
     - **Gross Salary:** `₹32,000.00`
  2. Verify Statutory Calculations:
     - Employee PF (12% of Basic): `₹2,400.00`
     - Professional Tax (Maharashtra PT Slab): `₹200.00`
     - Net Pay: `₹29,400.00`.
  3. Click **Save Structure**.

---

### 7.3 Execute Monthly Payroll Run
* **Route:** `/payroll/runs`
* **Test Steps:**
  1. Click **"+ New Payroll Run"**.
  2. Month: Current Month (e.g. September 2026).
  3. Click **"Compute Payroll"**: System generates payslip for Suresh Patil.
  4. Click **"Approve & Post Journal"**.
* **Expected Result:**
  - Payroll run moves to `POSTED`.
  - Salary Journal posts:
    - DR Salary Expense `₹32,000.00`
    - CR Salary Payable `₹29,400.00`
    - CR PF Payable `₹2,400.00`
    - CR PT Payable `₹200.00`.

---

## Phase 8: Enterprise Verticals & Extensions

### 8.1 Field Sales & Route Planning
* **Route:** `/field-sales/beats` and `/field-sales/vans`
* **Test Steps:**
  1. In `/field-sales/beats`, create Beat: `Bandra Retail Chemist Route`. Assign `Apollo Care Chemist`.
  2. In `/field-sales/vans`, create Van: `Van 01 - Western Suburbs`.
  3. Allocate van stock from `Central Warehouse - Mumbai`.
  4. Open `/field-sales/dashboard` to verify route planning view.

---

### 8.2 Logistics & Lorry Receipts
* **Route:** `/transport/lorry-receipts`
* **Test Steps:**
  1. Click **"+ New Lorry Receipt"**.
  2. Consignor: `Our Organisation` | Consignee: `Apollo Care Chemist & Retail`.
  3. Transporter: `Mahalaxmi Roadlines` | Vehicle No: `MH-04-AB-1234`.
  4. Packages: `5 Cartons` | Freight: `₹1,200.00`.
  5. Click **Save LR**.
* **Expected Result:** Lorry receipt is generated and tracked.

---

### 8.3 Customer Loyalty Wallet
* **Route:** `/loyalty`
* **Test Steps:**
  - Inspect loyalty points ledger for `Apollo Care Chemist & Retail`.
  - Confirm loyalty points accumulated from their posted sales invoice.

---

### 8.4 AI Command Center
* **Route:** `/ai`
* **Test Steps:**
  - Type query: `"What was our highest selling item today?"` or `"Show near-expiry stock"`.
  - Observe AI assistant contextual answer based on ERP database.

---

## Final Verification Checklist & Sign-off

- [ ] **Phase 0:** Environment & Login verified
- [ ] **Phase 1:** CoA, Warehouse, Contacts, Items created
- [ ] **Phase 2:** PO → GRN → Bill → Vendor Payment verified
- [ ] **Phase 3:** Stock Summary, Batch Trace, Transfer & Count verified
- [ ] **Phase 4:** SO → Challan (FEFO) → Invoice → Customer Payment verified
- [ ] **Phase 5:** POS Open Float → Counter Sale → Shift Close verified
- [ ] **Phase 6:** Day Book, P&L, Balance Sheet, GSTR-1, GSTR-3B verified
- [ ] **Phase 7:** Employee, Salary Structure, Payroll Run posted
- [ ] **Phase 8:** Field Sales, Transport LR, Loyalty verified
