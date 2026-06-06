# Katasticho ERP — Business Requirements Document

**Version:** 1.0
**Date:** 2026-06-04
**Author:** Katasticho Product Team
**Status:** Draft for Review

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Market Context and Positioning](#2-market-context-and-positioning)
3. [Product Vision](#3-product-vision)
4. [Architecture Principles](#4-architecture-principles)
5. [Capability Model](#5-capability-model)
6. [Module Requirements](#6-module-requirements)
   - 6.1 [Core Platform](#61-core-platform)
   - 6.2 [Sales — Wholesale (B2B)](#62-sales--wholesale-b2b)
   - 6.3 [Sales — Retail / POS](#63-sales--retail--pos)
   - 6.4 [Purchase and Accounts Payable](#64-purchase-and-accounts-payable)
   - 6.5 [Inventory and Warehouse](#65-inventory-and-warehouse)
   - 6.6 [GST Compliance and e-Documents](#66-gst-compliance-and-e-documents)
   - 6.7 [Reports and Dashboards](#67-reports-and-dashboards)
   - 6.8 [Migration Toolkit](#68-migration-toolkit)
   - 6.9 [Pharma Vertical Pack](#69-pharma-vertical-pack)
   - 6.10 [FMCG / Field Sales Pack](#610-fmcg--field-sales-pack)
   - 6.11 [Manufacturing-Lite](#611-manufacturing-lite)
   - 6.12 [Payroll](#612-payroll)
   - 6.13 [Partner Network / B2B Ordering](#613-partner-network--b2b-ordering)
   - 6.14 [AI Foundation](#614-ai-foundation)
7. [UX Requirements](#7-ux-requirements)
8. [Offline and Mobile Strategy](#8-offline-and-mobile-strategy)
9. [Integrations](#9-integrations)
10. [Deployment Model](#10-deployment-model)
11. [Commercial Model](#11-commercial-model)
12. [Support and SLA Model](#12-support-and-sla-model)
13. [Execution Sequence](#13-execution-sequence)
14. [Current Build Status](#14-current-build-status)
15. [Key Architecture Decisions (Non-Negotiable)](#15-key-architecture-decisions-non-negotiable)
16. [Glossary](#16-glossary)

---

## 1. Executive Summary

Katasticho is an **Indian SMB ERP platform** built as a shared core with pluggable vertical packs. It targets the supply chain from manufacturer to distributor to retailer to field salesperson — all as one product where each org enables the capabilities it needs via subscription.

The product is **not** a generic ERP with plugins. It is a **distribution-native operating system** with India-specific operational depth: batch/expiry/FEFO discipline, scheme and pricing complexity, credit control, GST compliance, multi-branch execution, and offline-first mobile. Vertical packs (Pharma, FMCG, Manufacturing) extend the core without forking it.

**Target customers:**
- Pharma distributors (50–500 Cr turnover, 1–10 branches)
- FMCG distributors (same profile)
- Pharma and general retailers / kirana shops (POS-first, small teams)
- Small manufacturers with distribution arm
- Multi-role businesses (e.g., retailer who also distributes)

**Competitive positioning:** Sit between the Indian incumbents (BUSY, Marg, Tally, Horizon) and global cloud platforms (Zoho, Odoo). Beat incumbents on usability, mobile/offline, and migration simplicity. Beat Zoho/Odoo on distributor-local fit, lower implementation drag, and offline-first execution.

**Key differentiators (from market gap analysis):**
1. Workflow speed — single-screen order entry, keyboard-first, no page-flip waste
2. Offline-first execution — orders, collections, van stock work without connectivity
3. Scheme/pricing engine — party-specific rates, slab schemes, free goods, quantity discounts
4. Low-friction migration — Tally/BUSY/Marg/Excel importers with dry-run and validation
5. Batch/expiry/FEFO discipline — operational prevention, not just compliance tracking
6. Modern UX with Indian trade depth — not "accounting expanded into distribution"

---

## 2. Market Context and Positioning

### 2.1 Competitor Landscape

| Cluster | Products | Strength | Weakness |
|---------|----------|----------|----------|
| Accounting-led | BUSY, Tally, Vyapar | GST posture, low entry cost, accounting credibility, offline/desktop | Dated UX, not distribution-native, weak mobile, complex navigation |
| Operations-led | Marg, Horizon, CBO | Deep distribution workflows, batch/expiry, schemes, route/van | Complex for beginners, product sprawl, fragmented UX, support inconsistency |
| Cloud platform | Zoho, Odoo | Breadth, API/customization, cloud ecosystem | Stacked cost model, implementation-heavy, weak offline, not locally native |

### 2.2 Market Gaps (Prioritized by Impact)

| Gap | Impact | Our Approach |
|-----|--------|-------------|
| Offline-first distributor and van-sales execution | Very High | Flutter offline-default app with visible sync, conflict resolution |
| Fast, keyboard-first billing and order entry | Very High | Single-screen order/bill entry, global search, inline warnings |
| Scheme and pricing engine depth | Very High | Party-specific rates, slab schemes, free goods, buy-X-get-Y, date-range pricing |
| Batch/expiry/FEFO discipline with alerts | Very High | FEFO-first batch picker, near-expiry alerts, wrong-batch prevention |
| Low-friction migration cockpit | Very High | Tally/BUSY/Marg/Excel importers, dry-run trial company, validation summary |
| Multi-branch control without enterprise complexity | High | Simple branch/godown setup, role-based visibility, no implementation project |
| Support with clear SLAs and ownership | High | Published P1/P2/P3 response times, WhatsApp support, ticket portal |
| Open integrations (payments, WhatsApp, barcode, GST, banking) | High | Built-in, not "extra" — UPI QR, WhatsApp doc sharing, thermal printing |
| Role-based reporting (trade-reality reports) | High | Outstandings, near-expiry, beat sales, van settlement, branch leakage |
| Retailer ordering / ERP-to-ERP | High | Partner Network module — retailer orders from distributor inside the same product |

### 2.3 Positioning Statement

> Katasticho: India-first, distribution-native ERP. Faster trade execution, fewer errors, easier migration, better mobile and offline control.

This directly attacks the combined weakness of Indian desktop incumbents (dated UX, fragmented mobile) and global cloud platforms (implementation-heavy, offline-weak, not locally native).

---

## 3. Product Vision

### 3.1 One Product, Multiple Roles

A single Katasticho org can operate as any combination of:
- **Retailer** (POS counter sales, walk-in customers)
- **Distributor** (B2B sales with credit, delivery challans, schemes)
- **Manufacturer** (BOM, work orders, finished goods)
- **Purchaser** (PO→GRN→receive stock, vendor management)

The org enables capabilities based on its subscription. The sidebar and available menus adapt dynamically — a retailer who also distributes sees POS, Sales Orders, Delivery Challans, and Purchase Orders all together. Menus group by function, not by "role identity."

### 3.2 Capability-Based Module System

Orgs do NOT declare a single identity ("I am a distributor"). Instead, they enable capabilities:

| Capability | What it unlocks |
|-----------|----------------|
| SELL_RETAIL | POS terminal, sales receipts, end-of-day reconciliation, loyalty |
| SELL_WHOLESALE | Sales orders, delivery challans, sales invoices, credit control, schemes, price lists |
| PURCHASE | Purchase orders, GRN, stock receipts, vendor payments, debit notes |
| INVENTORY | Multi-warehouse, batch tracking, stock transfers, physical count, barcode, FEFO |
| PHARMA | Drug masters, HSN→GST mapping, substitutions, interactions, near-expiry, stockist settlement |
| FMCG_FIELD_SALES | Beat/route planning, van load/unload, day-close, salesman incentives |
| MANUFACTURE | BOM, work orders, WIP tracking, production cost |
| PAYROLL | Employee management, salary structure, payroll runs, statutory compliance |
| PARTNER_NETWORK | B2B ordering, catalog publishing, linked PO↔SO |
| AI | Suggestions, anomaly detection, pattern learning |

Core capabilities (accounting, GST, contacts, items, tax engine, dashboards, settings, workflows, notifications, reports, migration) are always enabled for every org.

### 3.3 SaaS Subscription Model

- Module-based enablement per subscription
- Orgs can add capabilities at any time from Settings
- Billing adjusts based on enabled modules
- No feature flags that require code changes — capability enablement is data-driven via `org_feature_flag` and `vertical_capability` tables (already exist in the codebase)

---

## 4. Architecture Principles

### 4.1 Backend

- **Stack:** Spring Boot 3.3.5, Java 21, JPA/Hibernate, Flyway, PostgreSQL
- **Multi-tenant:** Every org-scoped query filtered by `TenantContext.getCurrentOrgId()`
- **Org-scoped entities:** Extend BaseEntity (`org_id`, `is_deleted`, audit timestamps)
- **Platform-level reference tables:** No `org_id` — `salt_master`, `drug_master`, `manufacturer_master`, `hsn_gst_master`, `generic_substitution`, `drug_interaction`
- **Stock movements:** Append-only ledger. Corrections use REVERSE entries, never UPDATE/DELETE. `stock_balance` is a derived cache, rebuildable from the ledger.
- **Single movement gate:** All stock changes go through `InventoryService.recordMovement()`
- **Controllers:** Return `ApiResponse.ok(...)` wrapper. Guard with `@PreAuthorize("hasAnyRole(...)")`
- **Roles:** OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER
- **Exceptions:** `BusinessException.notFound("Entity", id)` or `new BusinessException(msg, "CODE", HttpStatus.X)`

### 4.2 Frontend

- **Stack:** Flutter (Riverpod + GoRouter + Dio)
- **Offline-first:** Local database (Hive/Isar/Drift), queue outbound mutations, sync on reconnect
- **Capability-aware sidebar:** Menu items show/hide based on org's enabled capabilities
- **Single Android app:** Orders, collections, van stock, approvals, reports — not fragmented companion apps

### 4.3 API Contract

- Base URL: `http://localhost:8080` (no `/api/v1` prefix in Dio config — full path in each call)
- All endpoints under `/api/v1/...`
- RESTful, JSON, paginated where appropriate
- Field Sales (MR) app connects via the same API — no separate backend

---

## 5. Capability Model

### 5.1 Enablement Flow

```
Org Signup → Guided Capability Selection → Enable Selected Modules → Sidebar Adapts
                                                                         ↓
                                              Settings → Add/Remove Capabilities Later
```

### 5.2 Capability Dependencies

| Capability | Requires |
|-----------|----------|
| SELL_RETAIL | Core (always-on) |
| SELL_WHOLESALE | Core |
| PURCHASE | Core |
| INVENTORY | Core |
| PHARMA | INVENTORY |
| FMCG_FIELD_SALES | SELL_WHOLESALE + INVENTORY |
| MANUFACTURE | INVENTORY + PURCHASE |
| PAYROLL | Core |
| PARTNER_NETWORK | SELL_WHOLESALE or PURCHASE |
| AI | Core |

### 5.3 Example Org Configurations

| Business Type | Enabled Capabilities |
|--------------|---------------------|
| Kirana shop | SELL_RETAIL, PURCHASE, INVENTORY |
| Pharma retailer | SELL_RETAIL, PURCHASE, INVENTORY, PHARMA |
| Pharma distributor | SELL_WHOLESALE, PURCHASE, INVENTORY, PHARMA |
| FMCG distributor with field force | SELL_WHOLESALE, PURCHASE, INVENTORY, FMCG_FIELD_SALES |
| Retailer + Distributor (dual role) | SELL_RETAIL, SELL_WHOLESALE, PURCHASE, INVENTORY |
| Small manufacturer with distribution | MANUFACTURE, SELL_WHOLESALE, PURCHASE, INVENTORY |

---

## 6. Module Requirements

### 6.1 Core Platform

**Always enabled for every org. Not a separate subscription.**

#### 6.1.1 Organization and User Management
- Org profile: name, address, GSTIN, state, logo, fiscal year start
- Multi-branch support: each branch has name, address, GSTIN, warehouse(s)
- User management: invite, assign roles, deactivate
- Roles: OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER
- Role-based access control on every endpoint via `@PreAuthorize`
- Branch-level access control: users can be restricted to specific branches
- Persistent last-used context per user: branch, warehouse, printer, voucher series, salesman, route (saved server-side, restored on login)

#### 6.1.2 Contact Master
- Unified contact entity: tagged as CUSTOMER, VENDOR, or BOTH
- Fields: name, trade name, GSTIN, PAN, state, billing/shipping addresses, phone, email, contact person
- Customer-specific: credit limit, payment terms (days), price list assignment, salesman assignment
- Vendor-specific: vendor price tracking, payment terms
- Opening balance (AR/AP) — set during migration or manual entry
- Outstanding = opening balance + invoices - payments (AR) or + bills - payments (AP)
- Contact groups for bulk operations (e.g., assign scheme to group)

#### 6.1.3 Item Master
- Fields: name, SKU, barcode, HSN code, description, type (GOODS/SERVICE), UoM
- Tax: GST rate auto-derived from HSN code via `hsn_gst_master`; manual override allowed
- Pricing: MRP, selling price, purchase cost, margin %
- Inventory flags: batch-tracked (yes/no), expiry-tracked (yes/no), serial-tracked (yes/no)
- Pharma extension (when PHARMA enabled): salt/composition, schedule (H/H1), manufacturer, drug master linkage
- Category/sub-category hierarchy
- Item images
- Active/inactive status
- Item variants (future — Phase 2 Inventory)

#### 6.1.4 Accounting Engine
- Chart of Accounts: standard Indian CoA seeded on org creation, customizable
- Journal posting: all financial events go through `JournalService.postEntry()`
- General Ledger: queryable by account, date range, branch
- Double-entry enforced: every journal entry must balance
- Automatic journal creation for: sales invoices, purchase bills, payments (AR/AP), credit notes, debit notes, POS receipts, stock adjustments, payroll
- Fiscal year management: open/close periods, year-end close
- Multi-currency: India-only for v1 (INR). Data model should support currency field for future international expansion.

#### 6.1.5 Tax Engine
- GST computation: auto-split CGST/SGST (intra-state) or IGST (inter-state) based on org state vs party state
- Tax rates from HSN master: 0%, 5%, 12%, 18%, 28% + cess where applicable
- TDS/TCS: basic support for Section 194Q (TDS on purchase) and Section 206C(1H) (TCS on sale > 50L)
- Tax line items stored per document line for audit trail
- Reverse charge mechanism (RCM) where applicable

#### 6.1.6 Approval Workflows
- Configurable per org: document type + trigger condition → step chain
- Trigger conditions: JSON-based rules (field comparisons, value thresholds)
- Multi-step approval with role-based or user-specific approvers
- Self-approval prevention enforced
- Status: PENDING → APPROVED or REJECTED
- Domain handlers: each document type registers a handler for post-approval/rejection actions
- Active by default = false. Admin activates workflows as needed.
- Currently used for: Sales Order (credit limit breach), Credit Note, Payment (configurable)

#### 6.1.7 Notifications
- In-app notification center
- Push notifications (Firebase Cloud Messaging) for: approval requests, payment reminders, near-expiry alerts, low-stock alerts, order status changes
- WhatsApp notifications (via API integration) for: invoice/receipt sharing, payment reminders, dispatch notifications
- Email notifications for: approval requests, reports, statements

#### 6.1.8 Settings
- Org settings: defaults for tax, payment terms, invoice numbering, voucher series, print formats
- Module toggles: enable/disable capabilities
- Workflow configuration
- User preferences: language (English, Hindi — future regional), date format, number format
- Audit log: who changed what setting and when

#### 6.1.9 Audit Trail
- Every create/update/delete on business entities logged
- Fields: who, when, what changed (before/after), IP
- Queryable by entity type, date range, user
- Non-deletable, append-only

### 6.2 Sales — Wholesale (B2B)

**Capability: SELL_WHOLESALE**

#### 6.2.1 Sales Order (SO)
- **Create:** Select customer, add line items (item, quantity, rate, discount, tax), apply schemes, select price list
- **Price resolution:** Price list → customer-specific rate → item default price (priority order)
- **Scheme application:** Modes — AUTO (auto-apply best scheme), MANUAL (operator selects), DISABLED
- **Credit control on save:**
  - Calculate exposure = existing outstanding + this order value
  - Compare against customer credit limit
  - Policy per org: WARN (show warning, allow save), BLOCK (prevent save), APPROVAL_REQUIRED (route to workflow)
- **Overdue check on save:** If customer has invoices overdue > X days (org setting), apply same WARN/BLOCK/APPROVAL policy
- **Statuses:** DRAFT → CONFIRMED → PARTIALLY_DELIVERED → FULLY_DELIVERED → INVOICED → CLOSED → CANCELLED
- **Backorder:** If partial delivery, remaining quantities stay on SO for future DC creation
- **SO does NOT deduct stock.** Stock deduction happens only at DC dispatch.
- **Conversion:** SO → Delivery Challan (one or many DCs per SO)

#### 6.2.2 Delivery Challan (DC)
- **Create from SO:** Pull confirmed line items, select quantities to dispatch
- **Dispatch action:**
  - FEFO batch allocation: auto-pick nearest-expiry batches first
  - **Stock validation (mandatory):** Before `recordMovement()`, check `stock_balance` for item + warehouse (+ batch if batch-tracked). Throw `DC_INSUFFICIENT_STOCK` if short.
  - Record stock movement (negative quantity) via `InventoryService.recordMovement()`
  - Generate loading sheet / picklist
- **Statuses:** DRAFT → DISPATCHED → DELIVERED → INVOICED → CANCELLED
- **Print:** Delivery challan with batch details, expiry dates, HSN codes
- **DC does NOT post accounting.** Accounting happens at invoice posting.

#### 6.2.3 Sales Invoice
- **Create from DC** (standard path) or **create from SO** (direct invoice without DC)
- **From DC path:** Line items carry batch details from dispatch. **Must NOT deduct stock again** — stock was already deducted at DC dispatch.
- **From SO path (no DC):** Must deduct stock at invoice creation (this path acts as combined DC+Invoice)
- **Invoice posting:**
  - Create journal entry: Debit Accounts Receivable, Credit Revenue + Tax Payable
  - Update customer outstanding
  - Generate e-Invoice (if threshold met)
  - Generate e-Way Bill (if value threshold met and inter-state or distance > 50km)
- **Statuses:** DRAFT → POSTED → PARTIALLY_PAID → PAID → CANCELLED
- **Print:** GST-compliant invoice with all mandatory fields, QR code for e-Invoice

#### 6.2.4 Credit Control
- Per-customer settings: credit limit (amount), payment terms (days), credit policy (WARN/BLOCK/APPROVAL_REQUIRED)
- Org-level defaults: default credit policy, default overdue threshold
- Real-time exposure calculation: outstanding AR + pending SO values + pending approval payments
- Credit limit breach → triggers approval workflow if policy = APPROVAL_REQUIRED
- Overdue warning → shows days overdue, overdue amount, blocks or warns based on policy
- Dashboard widget: top 10 customers by credit exposure

#### 6.2.5 Scheme Engine
- Scheme types:
  - **Percentage discount:** X% off on line total
  - **Flat discount:** Fixed amount off
  - **Buy-X-Get-Y:** Buy X units, get Y units free (same item or different item)
  - **Slab pricing:** Different rate per quantity slab (e.g., 1-100 = Rs 10, 101-500 = Rs 9, 500+ = Rs 8)
  - **Quantity discount:** X% off if quantity >= threshold
- Scheme scope: all customers, customer group, specific customer, specific item, item category
- Scheme validity: date range (start/end date)
- Application mode per org: AUTO, MANUAL, DISABLED
- Stackable vs exclusive: org setting — can multiple schemes apply to same line?
- Scheme audit: which scheme was applied, original vs final amount

#### 6.2.6 Price Lists
- Named price lists with date ranges
- Assignment: customer-specific, customer-group, or default
- Item-level price overrides within a price list
- Rate preservation: when SO converts to DC converts to Invoice, the rate from SO carries through (no re-resolution)
- Multiple price lists per customer (priority-ordered)

#### 6.2.7 Payment Collection (AR)
- Payment methods: cash, cheque, bank transfer, UPI, credit note adjustment
- **Lifecycle:** DRAFT → POSTED (or PENDING_APPROVAL if workflow active) → VOIDED
- Apply payment to specific invoice(s) or as advance receipt
- Partial payments supported
- Balance validation: payment amount must not exceed invoice balance due (accounting for pending-approval payments)
- **Void payment:** Reverses journal entry via `journalService.reverseEntry()`, restores invoice balance, uses pessimistic locking on invoice
- Receipt print with payment details and running balance
- Payment reminders: configurable schedule (e.g., 7 days before due, on due date, 7 days after)

#### 6.2.8 Credit Notes
- Create credit note against invoice (for returns, price adjustment, damage)
- Line items with quantities and rates
- Approval workflow: configurable trigger (e.g., amount > threshold)
- On approval: reverse partial journal, reduce customer outstanding, optionally adjust stock (if goods returned)
- Statuses: DRAFT → PENDING_APPROVAL → APPROVED → POSTED → CANCELLED

#### 6.2.9 Sales Returns
- Return against invoice: specify items, quantities, reason
- Stock adjustment: returned goods go back to inventory (or damaged stock location)
- Creates credit note automatically
- Batch tracking: returned goods tagged with original batch for traceability

### 6.3 Sales — Retail / POS

**Capability: SELL_RETAIL**

#### 6.3.1 POS Terminal
- **Single-screen design:** Item search/scan, cart, payment, receipt — all on one screen, no page flips
- **Item search:** By name, SKU, barcode, salt/composition (if PHARMA enabled), category
- **Barcode scanning:** Camera-based and external scanner support
- **Cart operations:** Add item, change quantity, apply line discount, remove item, clear cart
- **Price display:** MRP, selling price, discount (if any), GST included/excluded toggle
- **Keyboard shortcuts:** Configurable hotkeys for common actions (new bill, search, payment, print)
- **Batch selection:** If item is batch-tracked, show available batches with expiry dates (FEFO-first ordering). Highlight near-expiry batches.
- **Stock visibility:** Show current stock for each item. Show rack/location if pharma.
- **Customer selection:** Optional — walk-in (no customer) or select regular customer for credit/loyalty
- **Compact UI:** Optimized for 10-12" screens (tablet), works on desktop browser too

#### 6.3.2 Sales Receipt
- POS receipt = cash memo. No Accounts Receivable entry.
- Journal: Debit Cash/Bank, Credit Revenue + Tax Payable
- Stock deduction: immediate via `recordMovement()`
- Receipt number: auto-generated, configurable series
- Print: thermal printer format (58mm/80mm), or A4/A5
- Digital receipt: WhatsApp or SMS share option

#### 6.3.3 End-of-Day Reconciliation
- Expected cash = opening cash + cash receipts - cash payouts
- Operator counts physical cash, enters amount
- System shows variance (short/over)
- Day-close report: total sales, payment method breakdown, discount given, returns
- Lock day: prevent further transactions on closed day (optional setting)

#### 6.3.4 Customer Loyalty
- Points accrual: configurable points per Rs spent (e.g., 1 point per Rs 100)
- Points redemption: configurable value per point (e.g., 1 point = Rs 1)
- Minimum redemption threshold
- Points expiry (configurable)
- Loyalty tier: basic structure (Bronze/Silver/Gold based on spend)

#### 6.3.5 POS Hardening Requirements (from QA)
- Correct stock deduction on every sale (no negative stock allowed at POS)
- Correct price resolution (price list → item price, respecting MRP cap)
- Correct GST computation per line item (not averaged across receipt)
- Barcode scanning reliability (handle mis-scans gracefully)
- Print reliability (handle printer offline, paper out)
- Session management (don't lose cart on browser refresh)
- Multi-user POS: different operators, separate cash drawers, shift handover

### 6.4 Purchase and Accounts Payable

**Capability: PURCHASE**

#### 6.4.1 Purchase Order (PO)
- Create PO to vendor: line items with item, quantity, rate, tax
- Vendor price suggestion: show last purchase rate, vendor-specific rate if available
- PO approval workflow: optional, configurable by amount threshold
- Statuses: DRAFT → CONFIRMED → PARTIALLY_RECEIVED → FULLY_RECEIVED → BILLED → CLOSED → CANCELLED
- **PO does NOT post stock.** Stock posting happens only at GRN "Receive Stock."
- Shortage-to-PO: create PO from low-stock alerts or shortage list

#### 6.4.2 Goods Receipt Note (GRN)
- Create from PO: pull PO line items, enter received quantities
- Receive Stock action:
  - Enter batch number, manufacturing date, expiry date, rack/location, cost per unit
  - Record stock movement (positive quantity) via `InventoryService.recordMovement()`
  - Update item cost (weighted average or last purchase cost — org setting)
- Partial receiving: receive some items now, rest later (PO stays PARTIALLY_RECEIVED)
- Quality check: optional pass/fail/hold per line item
- Statuses: DRAFT → RECEIVED → BILLED → CANCELLED

#### 6.4.3 Purchase Invoice (AP Bill)
- Create from GRN or standalone
- Journal: Debit Purchase/Inventory + Tax Input Credit, Credit Accounts Payable
- Vendor outstanding updated
- Due date from vendor payment terms
- Statuses: DRAFT → POSTED → PARTIALLY_PAID → PAID → CANCELLED

#### 6.4.4 Vendor Payment (AP Payment)
- Payment to vendor against specific bill(s) or as advance
- Methods: cash, cheque, bank transfer, NEFT/RTGS
- Journal: Debit Accounts Payable, Credit Bank/Cash
- Statuses: DRAFT → POSTED → VOIDED

#### 6.4.5 Debit Notes
- Create against purchase invoice (for returns to vendor, price adjustment)
- Approval workflow: optional
- Journal reversal on posting
- Stock adjustment if goods returned to vendor

#### 6.4.6 Purchase Returns
- Return to vendor: specify items, quantities, reason
- Stock deduction for returned goods
- Creates debit note automatically
- Batch tracking for returned items

### 6.5 Inventory and Warehouse

**Capability: INVENTORY**

#### 6.5.1 Stock Movement Ledger
- **Append-only:** Every stock change is a new row in `stock_movement`. No UPDATE, no DELETE.
- **Movement types:** PURCHASE_RECEIVE, SALES_DISPATCH, SALES_RETURN, PURCHASE_RETURN, TRANSFER_OUT, TRANSFER_IN, ADJUSTMENT_IN, ADJUSTMENT_OUT, PRODUCTION_ISSUE, PRODUCTION_RECEIVE, REVERSE
- **Corrections:** Always create REVERSE entry + new correct entry. Never modify existing.
- **Single gate:** All movements go through `InventoryService.recordMovement()` — no direct stock writes from any other service.
- **Fields per movement:** item, warehouse, batch (if tracked), quantity (+ or -), cost, reference document type + ID, movement type, timestamp, user

#### 6.5.2 Stock Balance (Derived Cache)
- `stock_balance` table: item + warehouse + batch → current quantity, average cost
- Rebuildable from `stock_movement` ledger at any time
- Used for: availability checks, reports, POS display, reorder alerts
- Updated synchronously after each movement (not async)

#### 6.5.3 Multi-Warehouse
- Each branch can have one or more warehouses/godowns
- Stock tracked per warehouse
- Default warehouse per branch
- Warehouse-level visibility by user role

#### 6.5.4 Batch Tracking
- Batch fields: batch number, manufacturing date, expiry date, cost
- Mandatory for batch-tracked items (enforced on GRN receive)
- Batch selection on dispatch: FEFO-first (nearest expiry picked first)
- Batch traceability: trace from purchase (which vendor, which GRN) to sale (which customer, which invoice)

#### 6.5.5 FEFO (First Expiry, First Out)
- Default consumption strategy for batch-tracked items
- On dispatch/sale: auto-select batch with nearest expiry that has sufficient stock
- Operator can override batch selection with reason
- Near-expiry highlight: batches within X days of expiry shown in warning color (X = org setting, default 90 days)
- Near-expiry alert: daily job identifies items with batches expiring within threshold, creates notification

#### 6.5.6 Stock Transfer Between Warehouses
- Transfer order: from-warehouse → to-warehouse, line items with quantities + batches
- Two-step: Transfer Out (deducts from source) → Transfer In (adds to destination)
- Single-step option for same-branch transfers
- Statuses: DRAFT → IN_TRANSIT → RECEIVED → CANCELLED
- Stock in transit visible in reports

#### 6.5.7 Physical Stock Count / Adjustment
- Create stock count sheet: list of items in warehouse, show system quantity
- Operator enters physical count per item per batch
- System computes variance
- On commit: create ADJUSTMENT_IN or ADJUSTMENT_OUT movements for each variance
- Journal posting for cost adjustment (Debit/Credit Stock Adjustment account)
- Approval workflow for adjustments above threshold (optional)
- Bulk count form for warehouse-wide counts

#### 6.5.8 Low Stock Alerts and Reorder
- Reorder point per item per warehouse (configurable)
- Reorder quantity (configurable)
- Alert when stock falls below reorder point
- Quick action: generate PO from low-stock alert
- Dashboard widget: items below reorder point

#### 6.5.9 Barcode / SKU
- System-generated SKU if not provided
- Barcode generation: EAN-13, Code-128
- Barcode print: label format for Zebra/thermal printers
- Barcode scan: camera-based (Flutter) + external USB/Bluetooth scanner

#### 6.5.10 Rack / Location Management
- Rack/location master per warehouse (already implemented in backend)
- Assign rack location on GRN receive
- Show rack location on POS search results (pharma use case: "where is this medicine?")
- Rack-wise stock report

#### 6.5.11 UoM (Unit of Measure) with Conversion
- Base UoM per item (e.g., tablet, piece, kg)
- Conversion units: strip = 10 tablets, box = 10 strips = 100 tablets
- Purchase in one UoM, sell in another — system auto-converts
- Stock always stored in base UoM

#### 6.5.12 Opening Stock
- During migration or initial setup: enter opening stock per item per warehouse per batch
- Creates ADJUSTMENT_IN movement
- Opening stock with cost for valuation

### 6.6 GST Compliance and e-Documents

**Always enabled. Not a separate module — compliance is table stakes.**

#### 6.6.1 GST Computation
- Auto CGST/SGST split (intra-state) or IGST (inter-state) based on org state vs party state
- HSN-to-rate mapping: `hsn_gst_master` table (3004=12%, 2106=18%, 3002=5%, etc.)
- Cess computation where applicable
- Reverse Charge Mechanism (RCM) support
- Composition scheme support (flat rate, no input credit)
- Tax exemptions by item or party type

#### 6.6.2 e-Invoice
- Auto-generate e-Invoice for B2B invoices above threshold (currently Rs 5 Cr, decreasing over time)
- Integration with NIC (National Informatics Centre) e-Invoice portal via API
- IRN (Invoice Reference Number) generation
- QR code on printed invoice
- e-Invoice cancellation within 24 hours
- Bulk e-Invoice generation for batch processing

#### 6.6.3 e-Way Bill
- Auto-generate for consignments above Rs 50,000 (or as per state rules)
- Integration with NIC e-Way Bill portal via API
- Vehicle number, transporter details capture at DC dispatch
- e-Way Bill extension/cancellation
- Multi-vehicle support for part loads

#### 6.6.4 GST Returns Assistance
- **GSTR-1:** Auto-populate outward supply data from sales invoices. Export in GSTR-1 format (JSON/Excel).
- **GSTR-3B:** Summary computation of output tax, input tax credit, tax payable. Export format.
- **GSTR-2A/2B reconciliation:** Import vendor-filed data, match against purchase bills, highlight mismatches.
- Note: v1 = export-ready data + reconciliation. Actual filing via GST portal (not direct API filing in v1).

#### 6.6.5 TDS / TCS
- TDS on purchase (Section 194Q): auto-compute when applicable, generate TDS entries
- TCS on sale (Section 206C(1H)): auto-compute on sales above Rs 50L threshold
- TDS/TCS return data export (Form 26Q, 27EQ format)

### 6.7 Reports and Dashboards

**Always enabled. Reports are role-based, mirroring trade reality.**

#### 6.7.1 Role-Based Dashboards
Each role sees a different default dashboard:

| Role | Dashboard Focus |
|------|---------------|
| OWNER | Revenue, outstanding AR/AP, cash position, near-expiry, top customers, P&L snapshot |
| ADMIN | User activity, pending approvals, branch comparison, system health |
| ACCOUNTANT | Day book, bank reconciliation, GST summary, journal activity |
| OPERATOR | Pending dispatch, low stock, today's orders, today's receipts |
| WAREHOUSE | Stock by warehouse, pending GRN, near-expiry, rack occupancy |
| SALESMAN | My customers, my collections, my targets vs actual, pending orders |

#### 6.7.2 Core Accounting Reports
1. **Day Book** — Chronological transaction log (all vouchers for a day/period)
2. **Journal Register** — All journal entries with filters
3. **General Ledger** — Account-wise transaction history
4. **Trial Balance** — All accounts with debit/credit balances
5. **Profit and Loss** — Revenue - Expenses for period
6. **Balance Sheet** — Assets, Liabilities, Equity at a point in time
7. **Cash Flow Statement** — Cash inflows and outflows by category

#### 6.7.3 Trade Reports
8. **Sales Register** — All sales invoices with line-level detail, tax breakup, scheme applied
9. **Purchase Register** — All purchase bills with line-level detail
10. **Customer Statement** — Account-wise: invoices, payments, credit notes, running balance
11. **Vendor Statement** — Same for AP side
12. **Outstanding AR** — All customers with outstanding amounts, aging buckets (0-30, 31-60, 61-90, 90+)
13. **Outstanding AP** — Same for vendors
14. **AR Aging** — Aging analysis with invoice-level drill-down
15. **AP Aging** — Same for vendors
16. **Collection Summary** — Payment collection by salesman, date, method

#### 6.7.4 Inventory Reports
17. **Stock Summary** — Current stock by item, warehouse, batch
18. **Stock Movement Report** — All movements for an item/warehouse/period
19. **Low Stock Alert** — Items below reorder point
20. **Near-Expiry Report** — Batches expiring within threshold
21. **Batch Traceability** — Full chain: purchase → stock → sale for a batch
22. **Stock Valuation** — Stock value by warehouse (at cost)
23. **Rack-wise Stock** — Stock by rack/location (pharma)

#### 6.7.5 Distributor-Specific Reports
24. **Pending Dispatch** — Confirmed SOs not yet dispatched (or partially dispatched)
25. **Challan Not Invoiced** — Dispatched DCs not yet invoiced
26. **Route-wise Sales** — Sales by route/beat/area (when FMCG enabled)
27. **Van Settlement** — Van load vs sold vs returned vs cash collected (when FMCG enabled)
28. **Salesman Performance** — Sales, collections, new customers by salesman
29. **Branch Comparison** — Revenue, outstanding, stock value across branches
30. **Scheme Utilization** — Which schemes were applied, discount given, impact on margin

#### 6.7.6 Report Features (Common)
- Date range filter on all reports
- Branch filter (multi-branch orgs)
- Export: CSV, Excel, PDF
- Print: A4, custom formats
- Drill-down: click a total to see underlying transactions
- Scheduled reports: email daily/weekly/monthly to specified users
- Saved filters: save frequently used filter combinations

### 6.8 Migration Toolkit

**Always available. Migration is a first-class feature, not an afterthought.**

Migration is one of the top 5 purchase blockers in this market. Buyers fear data loss, incorrect opening balances, and being stuck between two systems. The migration toolkit must make this process visible, validated, and reversible.

#### 6.8.1 Supported Source Systems
- **Tally (TallyPrime / Tally.ERP 9):** XML export import
- **BUSY:** Data export import
- **Marg:** Data export import
- **Excel / CSV:** Template-based import with column mapping
- **Manual entry:** Guided wizard for opening balances

#### 6.8.2 Migration Flow
```
1. Source Selection → 2. File Upload/Connection → 3. Data Mapping
→ 4. Validation (dry-run) → 5. Trial Company → 6. User Acceptance
→ 7. Cutover → 8. Hypercare
```

#### 6.8.3 Data to Migrate
| Data | Priority | Notes |
|------|----------|-------|
| Chart of Accounts | P0 | Map source accounts to Katasticho CoA |
| Customer master + opening balances | P0 | Name, GSTIN, credit limit, outstanding |
| Vendor master + opening balances | P0 | Name, GSTIN, outstanding |
| Item master | P0 | Name, HSN, rate, tax rate, UoM, batch config |
| Opening stock (with batches) | P0 | Item, warehouse, batch, quantity, cost, expiry |
| Opening AR invoices (unpaid/partial) | P0 | For outstanding tracking |
| Opening AP bills (unpaid/partial) | P0 | For outstanding tracking |
| Bank/cash opening balances | P0 | For reconciliation starting point |
| Historical transactions | P1 | Optional — for trend analysis, not for accounting |
| Price lists | P1 | Customer-specific rates |
| Schemes | P2 | Usually re-created in new system |

#### 6.8.4 Validation and Dry-Run
- **Validation checks:**
  - GSTIN format validation
  - Duplicate detection (by name, GSTIN, phone)
  - HSN code validity
  - Opening balance reconciliation (sum of customer balances = total AR, etc.)
  - Required field completeness
  - Tax rate consistency (HSN code matches expected rate)
- **Dry-run mode:** Import into a trial company (separate org). User can explore, verify, delete and re-import.
- **Validation report:** Exportable summary of errors, warnings, and import statistics
- **Error handling:** Row-level errors (skip row, show error) — don't fail the entire import

#### 6.8.5 Cutover Process
1. Freeze transactions in source system (agreed cutover date)
2. Final export from source
3. Import into production org
4. Verify opening balances match source system totals
5. User acceptance sign-off
6. Begin live operations
7. Hypercare period (1 week) — dedicated support for migration issues

### 6.9 Pharma Vertical Pack

**Capability: PHARMA. Requires: INVENTORY.**

#### 6.9.1 Drug Master Integration
- Platform-level `drug_master` table: drug name, composition, manufacturer, schedule, category
- Platform-level `salt_master` table: active pharmaceutical ingredients
- Search drugs by name, composition, salt, manufacturer
- Link item master to drug master for pharma items
- Auto-fill HSN code (3004 for most medicines) on drug linkage

#### 6.9.2 HSN → GST Auto-Mapping
- `hsn_gst_master` table with standard mappings:
  - 3004 (standard medicines) → 12% GST
  - 2106 (supplements/nutraceuticals) → 18% GST
  - 3002 (vaccines/sera) → 5% GST
  - 3006 (surgical/dental) → 12% GST
- Auto-fill GST rate when HSN selected in item creation
- Override allowed with audit trail

#### 6.9.3 Manufacturer Master
- Platform-level `manufacturer_master` table
- Autocomplete in item creation
- Filter items/stock by manufacturer

#### 6.9.4 Generic Substitution Suggestions
- `generic_substitution` table: salt → alternative drugs with same composition
- At POS checkout: if selected drug is out of stock, suggest generics with same salt
- Show: substitute name, manufacturer, price comparison, stock availability
- Operator can accept suggestion (swap item in cart) or dismiss

#### 6.9.5 Drug Interaction Warnings
- `drug_interaction` table: salt A + salt B → interaction severity + description
- At POS/prescription: when adding multiple drugs, check for interactions between salts
- Severity levels: MILD (info), MODERATE (warning), SEVERE (block or require override)
- Override with pharmacist approval for SEVERE interactions

#### 6.9.6 Near-Expiry Management
- Daily batch job: identify batches expiring within threshold (default 90 days, configurable)
- Near-expiry alert on dashboard
- Near-expiry report: sortable by days remaining, value at risk
- Expiry settlement workflow:
  1. Identify near-expiry/expired stock
  2. Create return claim to manufacturer/distributor
  3. Track claim status (SUBMITTED → ACCEPTED → CREDIT_RECEIVED → REJECTED)
  4. Adjust stock on claim acceptance
  5. Create credit note/debit note as needed

#### 6.9.7 Batch Recall
- Recall alert: manufacturer issues recall for specific batch(es)
- System identifies: which stock is affected (by batch), which customers received the batch
- Generate customer notifications
- Track recall response: returned quantity, replacement, credit issued

#### 6.9.8 Schedule H / H1 Drug Controls (Future)
- Flag items as Schedule H or H1
- Require prescription reference for Schedule H1 sales
- Maintain prescription register
- Regulatory compliance reporting

### 6.10 FMCG / Field Sales Pack

**Capability: FMCG_FIELD_SALES. Requires: SELL_WHOLESALE + INVENTORY.**

This is a **separate mobile app** that connects to Katasticho backend via the same API. Field sales staff (MR/Salesman) use this app; back-office staff use the main web/tablet app.

#### 6.10.1 Beat / Route Planning
- Define beats: named route with list of assigned customers (retailers)
- Assign beats to salesmen
- Weekly/monthly beat schedule: which salesman visits which beat on which day
- Beat adherence tracking: planned vs actual visits

#### 6.10.2 Daily Call Plan
- Auto-generated from beat schedule
- Shows: customers to visit today, last order date, outstanding amount, pending collections
- Salesman can reorder visit sequence
- Mark visit: VISITED, SKIPPED (with reason), ORDER_PLACED, COLLECTION_DONE

#### 6.10.3 Order Booking from Field
- Salesman creates SO on mobile (offline-capable)
- Shows: customer-specific price list, applicable schemes, credit status, last order items
- Quick reorder: repeat last order with quantity adjustment
- Order syncs to backend when online → creates SO in main system
- Back-office can review/modify before confirmation

#### 6.10.4 Van Sales (Cash Van)
- **Van loading:** Transfer stock from warehouse to van (creates transfer order)
- **Van stock:** Real-time van inventory (works offline)
- **Direct sale from van:** Create invoice + collect payment in field
- **Van unloading:** Return unsold stock to warehouse at day end
- **Van statement:** Load - Sold - Returned - Damaged = must match physical count + cash

#### 6.10.5 Route Collection
- Collect payments from customers on route
- Payment methods: cash, cheque, UPI
- Issue receipt on mobile (print via Bluetooth thermal printer or share via WhatsApp)
- Collection syncs to backend → creates payment entry
- Cash collection statement: salesman-wise daily collection summary

#### 6.10.6 Day-Close Wizard
- Guided end-of-day process:
  1. Review all visits (completed, skipped)
  2. Review all orders placed
  3. Review all collections made
  4. Cash reconciliation: expected vs physical
  5. Van stock reconciliation: expected vs physical
  6. Submit day report
- Day report sent to manager for review

#### 6.10.7 Salesman Incentive / Target Tracking
- Define targets: monthly revenue target per salesman, per beat, per product category
- Track actual vs target
- Incentive slabs: e.g., 80-100% = Rs X, 100-120% = Rs Y, >120% = Rs Z
- Dashboard: salesman-wise target achievement

#### 6.10.8 GPS and Visit Tracking
- Capture GPS coordinates on customer visit
- Distance calculation for route optimization
- Visit duration tracking
- Geo-fencing: verify salesman is at customer location

#### 6.10.9 Secondary Sales Data
- Retailers report their sales to end consumers (secondary sales)
- Distributor can see: primary sales (distributor→retailer) vs secondary sales (retailer→consumer)
- Secondary sales dashboard for brand-level analysis

### 6.11 Manufacturing-Lite

**Capability: MANUFACTURE. Requires: INVENTORY + PURCHASE.**

Note: This is NOT full MRP. It covers simple finished-goods production, BOM explosion, and work order tracking. Advanced production planning (MPS, capacity planning, shop floor scheduling) is out of scope.

#### 6.11.1 Bill of Materials (BOM)
- Define BOM per finished good: list of raw materials + quantities
- Multi-level BOM: finished good can contain sub-assemblies that have their own BOMs
- By-products: define expected by-products with quantities
- BOM cost: sum of component costs (auto-calculated)
- BOM versioning: track changes to BOM over time
- Composite items: virtual items whose stock = min buildable count across components (never gets own stock movement)

#### 6.11.2 Work Orders
- Create work order for a finished good: select BOM, enter production quantity
- **Issue to production:** Deduct raw materials from inventory via `recordMovement()` (PRODUCTION_ISSUE)
- **Receive finished goods:** Add finished goods to inventory via `recordMovement()` (PRODUCTION_RECEIVE)
- **Receive by-products:** Add by-products to inventory
- Statuses: DRAFT → IN_PROGRESS → COMPLETED → CANCELLED
- Partial completion: receive partial quantity, remaining stays in progress
- Work order linked to production batch (for traceability)

#### 6.11.3 WIP (Work-In-Progress) Tracking
- Raw materials issued but finished goods not yet received = WIP
- WIP value = sum of issued raw material costs
- WIP report: work orders in progress, value tied up

#### 6.11.4 Production Costing
- Finished good cost = sum of (raw material cost * quantity used) + direct labor (manual entry) + overhead (manual entry)
- Auto-update finished good cost in item master on work order completion
- Cost variance report: standard BOM cost vs actual production cost

#### 6.11.5 Production Reports
- Production Summary: work orders by period, finished goods produced, cost
- Raw Material Consumption: materials consumed by period, work order
- BOM Cost vs Actual: variance analysis
- WIP Report: outstanding work orders, tied-up value

### 6.12 Payroll

**Capability: PAYROLL.**

Full specification in `docs/PAYROLL_IMPLEMENTATION_SPEC.md`. Key requirements summarized here.

#### 6.12.1 Employee Management
- Employee master: name, designation, department, date of joining, salary mode
- Salary handling modes: NONE, SIMPLE_EXPENSE (record salary as expense without payslip), FORMAL_PAYROLL (full payslip with deductions)
- Employee documents: PAN, Aadhaar, bank details (for salary transfer)

#### 6.12.2 Salary Structure
- Salary components: Basic, HRA, DA, Conveyance, Special Allowance, etc.
- Component types: EARNING, DEDUCTION, EMPLOYER_CONTRIBUTION
- Salary template: reusable structure assignable to employees
- CTC breakdown per employee

#### 6.12.3 Payroll Run
- Monthly payroll processing: select period, generate payslips for all active employees
- Auto-compute: PF (12% employee + 12% employer), ESI (0.75% employee + 3.25% employer if gross < Rs 21,000), Professional Tax (state-wise slabs), TDS (based on declared investments and regime)
- Payslip review and approval
- Bulk salary disbursement (bank file generation)
- Journal posting via `JournalService.postEntry()`: Debit Salary Expense, Credit Salary Payable + Statutory Payable

#### 6.12.4 Statutory Compliance
- PF return data export (ECR format)
- ESI return data export
- Professional Tax challan
- TDS computation (old regime / new regime), Form 16 data

### 6.13 Partner Network / B2B Ordering

**Capability: PARTNER_NETWORK.**

Full specification in `docs/PARTNER_NETWORK_MODULE_PLAN.md`. Key requirements summarized here.

#### 6.13.1 Trading Partner Management
- Send/receive partnership requests between Katasticho orgs
- Approval workflow for new partnerships
- Relationship types: BUYER, SELLER, BOTH

#### 6.13.2 Published Catalog
- Seller publishes item catalog to trading partners
- Buyer sees seller's catalog with prices, stock availability, schemes
- Real-time or periodic sync

#### 6.13.3 B2B Order Flow
```
Buyer creates PO → Seller receives as incoming B2B order
→ Seller confirms → Creates SO → Dispatch via DC → Invoice
→ Buyer's PO status updated automatically
```
- Linked documents: buyer's PO ↔ seller's SO (cross-org reference)
- Must call existing services (`PurchaseOrderService`, `SalesOrderService`, etc.) — no direct stock/accounting writes

#### 6.13.4 Retailer Self-Service
- Retailer logs into their Katasticho org
- Browses distributor's published catalog
- Places order (creates PO in retailer's org, incoming order in distributor's org)
- Tracks order status, views invoices, statements
- This replaces the need for Marg-style "eRetail" as a separate app

### 6.14 AI Foundation

**Capability: AI.**

Full specification in `docs/AI_APPROACH_AND_ROADMAP.md`. Key requirements summarized here.

#### 6.14.1 Core Principle
AI must NEVER directly post journals, change stock, or file GST. All actions go through existing services with human approval.

#### 6.14.2 Observe → Suggest → Review → Learn
1. **Domain events** captured for every business action
2. **Rule-based agents** analyze events for anomalies, compliance gaps, optimization opportunities
3. **Suggestions** presented in AI Inbox (Flutter)
4. **User reviews** (accept/reject/modify) each suggestion
5. **Pattern learning** from reviewed suggestions improves future recommendations

#### 6.14.3 Initial Agents (Rule-Based, No External AI)
- Anomaly detection: unusual transactions, credit limit breaches, stock discrepancies
- GST compliance: mismatched HSN codes, missing e-invoices, GSTR reconciliation gaps
- Inventory intelligence: slow-moving stock, dead stock, reorder optimization, demand forecasting

#### 6.14.4 Future: External AI / MCP Integration
- Natural language assistant endpoint: `POST /api/v1/ai/assistant`
- AI summary fields on business tables (opt-in)
- MCP (Model Context Protocol) integrations

---

## 7. UX Requirements

### 7.1 Design Philosophy

The market research is clear: **"the unmet need is not more modules; it is less operational friction in the modules that matter most."** Every UX decision must be evaluated against this principle.

Katasticho must feel like a **distribution-native operating system**, not accounting software expanded into distribution (BUSY pattern) and not a broad platform that needs implementation work to feel local (Zoho/Odoo pattern).

### 7.2 P0 UX Priorities (Must-Have for Launch)

| Priority | Requirement | Rationale |
|----------|------------|-----------|
| P0 | Single-screen order and bill entry | Removes page-switching and "screen flip" waste. Users complain about this across every incumbent. |
| P0 | Global search for party, item, batch, invoice, and barcode | Directly addresses "difficult to locate things" (BUSY user complaint). Must be accessible via keyboard shortcut (Ctrl+K or /). |
| P0 | Inline scheme/credit/stock warnings instead of modal interruptions | Keeps operator in flow. Show warnings as inline banners on the order form, not as blocking dialogs. |
| P0 | FEFO-first batch picker with near-expiry highlight | Reduces wrong-batch dispatch and expiry mistakes. Batch picker sorted by expiry date, near-expiry batches in warning color. |
| P0 | Persistent last-used context by role | Branch, warehouse, printer, voucher series, salesman, and route should not be reselected repeatedly. Save per user, restore on login. |
| P0 | Keyboard-first navigation | All high-frequency operations (new order, search, save, print) accessible via keyboard shortcuts. Configurable hotkeys. |

### 7.3 P1 UX Priorities (Required Within 30 Days of Launch)

| Priority | Requirement | Rationale |
|----------|------------|-----------|
| P1 | Migration wizard with dry-run and error export | Turns migration from a sales promise into a visible process. |
| P1 | Offline sync dashboard | Makes mobile confidence measurable and supportable. Shows sync status, pending items, last sync time, conflicts. |
| P1 | Van-load and day-close wizard | Converts route/van complexity into guided step-by-step execution. |
| P1 | Role-based dashboards | Owners, accountants, warehouse teams, and salesmen need different defaults. |
| P1 | Responsive layout | Same app works on 10" tablet (POS), 14" laptop (back office), and mobile (field). Not three separate UIs — responsive breakpoints. |

### 7.4 Sidebar / Menu Structure

Menu adapts based on enabled capabilities. Example for a pharma distributor + retailer (SELL_RETAIL + SELL_WHOLESALE + PURCHASE + INVENTORY + PHARMA):

```
Dashboard
---
POS                          [SELL_RETAIL]
  New Sale
  Sales Receipts
  End of Day
---
Sales                        [SELL_WHOLESALE]
  Sales Orders
  Delivery Challans
  Sales Invoices
  Credit Notes
  Schemes
  Price Lists
---
Purchase                     [PURCHASE]
  Purchase Orders
  Goods Receipt
  Purchase Bills
  Debit Notes
---
Payments
  Receivables (AR)           [SELL_WHOLESALE or SELL_RETAIL]
  Payables (AP)              [PURCHASE]
---
Inventory                    [INVENTORY]
  Items
  Stock Summary
  Stock Transfers
  Stock Count
  Batches & Expiry
  Low Stock Alerts
---
Pharma                       [PHARMA]
  Drug Search
  Near-Expiry
  Substitutions
  Interactions
  Expiry Claims
---
Contacts
  Customers
  Vendors
---
Accounting
  Journal Entries
  Chart of Accounts
  Bank Reconciliation
---
Reports
  [context-aware list based on enabled modules]
---
Settings
  Org Profile
  Users & Roles
  Branches & Warehouses
  Workflows
  Module Management
  Migration
```

---

## 8. Offline and Mobile Strategy

### 8.1 Why Offline-First is Non-Negotiable

From the market research: Zoho Books explicitly has no offline mode. Odoo has limited PWA offline with capped data. Indian distributors, van-sales teams, and retail counters in low-connectivity areas need software that works without internet. Owner trust rises sharply when orders, collections, and van stock work offline.

### 8.2 Offline Architecture

```
[Flutter App]
    ├── Local Database (Drift/Isar)
    │   ├── Master data cache (items, customers, price lists, schemes)
    │   ├── Pending mutations queue (orders, payments, stock movements)
    │   └── Offline transaction log
    ├── Sync Engine
    │   ├── Background sync when online
    │   ├── Conflict detection (server wins for master data, merge for transactions)
    │   ├── Retry with exponential backoff
    │   └── Sync status visible to user
    └── Offline Indicator
        ├── Banner when offline
        ├── Last sync timestamp
        └── Pending items count
```

### 8.3 What Works Offline

| Feature | Offline Support | Notes |
|---------|----------------|-------|
| POS sales | Full | Cart, pricing, receipt (queued for sync) |
| Order booking (field) | Full | SO created locally, syncs later |
| Payment collection (field) | Full | Receipt generated locally |
| Van stock check | Full | Van inventory cached locally |
| Item/customer search | Full | Master data cached |
| Stock check | Read-only | Shows last-synced stock |
| Reports | Limited | Only locally cached data |
| Approval actions | Online only | Requires server state |
| Migration import | Online only | Server-side processing |

### 8.4 One App, Not Many

Buyers are tired of fragmented companion apps (Marg has 5+ apps, BUSY's app is a desktop extension). Katasticho will have:

1. **Web app** (Flutter web) — primary for back-office, desktop/tablet
2. **Android app** (Flutter) — same codebase, optimized for mobile + offline
3. **iOS app** (Flutter) — same codebase (lower priority, Android-first for Indian market)

All three share the same codebase. Role-based UI adaptation (not separate apps per role).

---

## 9. Integrations

### 9.1 Integration Philosophy

Compliance and communication integrations must be **invisible and reliable** — not presented as "extra features." They should feel built-in.

### 9.2 Required Integrations

| Integration | Purpose | Priority |
|-------------|---------|----------|
| **NIC e-Invoice API** | e-Invoice generation (IRN, QR code) | P0 |
| **NIC e-Way Bill API** | e-Way Bill generation | P0 |
| **GST Portal** | GSTR-1/3B data export, GSTR-2A/2B import for reconciliation | P0 |
| **WhatsApp Business API** | Share invoices, receipts, dispatch docs, payment reminders | P0 |
| **Thermal printer** | POS receipts (58mm/80mm), barcode labels | P0 |
| **Barcode scanner** | Camera + USB/Bluetooth external scanners | P0 |
| **UPI QR generation** | Generate QR code for payment collection at POS/field | P1 |
| **Bank statement import** | CSV/OFX import for bank reconciliation | P1 |
| **SMS gateway** | OTP, payment reminders, dispatch notifications | P1 |
| **Email (SMTP)** | Statements, reports, approval notifications | P1 |
| **Firebase Cloud Messaging** | Push notifications for mobile app | P1 |
| **Payment gateway (Razorpay/PhonePe)** | Online payment collection links | P2 |
| **Tally XML import** | Migration from Tally | P0 |
| **Excel/CSV import/export** | Universal data exchange | P0 |
| **API / Webhooks** | Third-party integrations, custom workflows | P2 |

---

## 10. Deployment Model

### 10.1 Deployment Options

The market research recommends offering multiple deployment modes to neutralize the anti-cloud objection without giving up SaaS convenience:

| Mode | Description | Target Customer |
|------|-------------|----------------|
| **Managed Cloud (SaaS)** | Hosted by Katasticho. Monthly/annual subscription. Auto-updates, managed backups, zero infra management. | Default for most customers. Low-touch onboarding. |
| **Private Cloud / On-Prem** | Customer hosts on their own infra (or dedicated cloud VM). Same product, same data model. Customer manages updates. | Larger distributors with data sovereignty requirements or very poor connectivity. |

Same product, same codebase, different hosting. No feature differences between deployment modes.

### 10.2 Infrastructure (Managed Cloud)

- Cloud: GCP/AWS (see `docs/GOOGLE_CLOUD_VM_DEPLOYMENT_RUNBOOK.md` for current setup)
- Database: PostgreSQL (managed)
- File storage: Cloud storage (invoices, reports, backups)
- CDN: For Flutter web app
- Monitoring: Application metrics, error tracking, uptime monitoring
- Backup: Daily automated backups with point-in-time recovery
- Multi-region: India-first (Mumbai/Chennai), international later

---

## 11. Commercial Model

### 11.1 Pricing Strategy

Sit between Tally/Vyapar on entry cost and Zoho/Odoo on cloud sophistication. Do not force customers to choose between affordability and operational fit.

### 11.2 Two-Lane Pricing

| Lane | Model | Target |
|------|-------|--------|
| **Cloud** | Monthly subscription per org. Tiered by modules + users. | SMBs who want zero infra, quick start |
| **Annual** | Annual subscription (discounted vs monthly). | Cost-conscious buyers, desktop-first preference |

### 11.3 Suggested Tier Structure

| Tier | Included Modules | Target Business |
|------|-----------------|----------------|
| **Starter** | Core + SELL_RETAIL or SELL_WHOLESALE + INVENTORY | Single-location retailer or small distributor |
| **Growth** | Core + SELL_RETAIL + SELL_WHOLESALE + PURCHASE + INVENTORY + 1 vertical pack | Multi-location distributor, pharma retailer |
| **Enterprise** | All modules, unlimited branches, priority support | Large distributor, manufacturer-distributor |

### 11.4 Bundled Services

- Migration assistance included in all paid plans (self-service tools + 1 support session)
- First-week hypercare included in Growth and Enterprise
- Onboarding wizard (self-service) in all plans
- Training materials (video + docs) in all plans

---

## 12. Support and SLA Model

### 12.1 Why Support is a Differentiator

From market research: "Many products advertise support, but few present the support experience as a strategic differentiator." Users complain about support across BUSY, Marg, CBO, Tally, and Odoo. Clear SLAs build trust.

### 12.2 SLA Tiers

| Severity | Definition | Response Time | Resolution Target |
|----------|-----------|--------------|-------------------|
| **P1 — Critical** | System down, data loss risk, cannot transact | 1 hour | 4 hours |
| **P2 — High** | Major feature broken, workaround exists | 4 hours | 24 hours |
| **P3 — Medium** | Non-critical bug, minor feature issue | 24 hours | 72 hours |
| **P4 — Low** | Enhancement request, cosmetic issue | 48 hours | Best effort |

### 12.3 Support Channels

| Channel | Availability | Tier |
|---------|-------------|------|
| WhatsApp support | Business hours (9am-7pm IST) | All plans |
| Ticket portal | 24/7 | All plans |
| Phone support | Business hours | Growth + Enterprise |
| Remote assist (screen share) | By appointment | Growth + Enterprise |
| Named account success manager | Dedicated | Enterprise |
| Partner escalation | Via certified partner | All plans |

### 12.4 Partner Program

- Certify partners by **domain**, not just by region: Distributor Core, Pharma, FMCG
- Provide: migration kits, demo data, UAT checklists, implementation playbooks
- Partner quality tracking and ratings

---

## 13. Execution Sequence

### 13.1 Phase Overview

Execution follows stabilize-existing-first, add-new-after principle. Distributor flows are stabilized first because they touch the most core systems and represent the strongest market wedge.

| Phase | Focus | Timeline | Depends On |
|-------|-------|----------|-----------|
| **Phase 0** | QA and Bug Fixes | Current | — |
| **Phase 1** | Distributor Core Hardening | Month 1-2 | Phase 0 |
| **Phase 2** | Retail / POS Hardening | Month 2-3 | Phase 1 |
| **Phase 3** | Inventory Feature Parity | Month 3-4 | Phase 1 |
| **Phase 4** | GST Compliance (e-Invoice, e-Way Bill, GSTR) | Month 3-4 | Phase 1 |
| **Phase 5** | Reports Completion + Migration Toolkit | Month 4-5 | Phase 1-3 |
| **Phase 6** | Pharma Vertical Pack | Month 5-6 | Phase 3 |
| **Phase 7** | FMCG / Field Sales Pack | Month 6-8 | Phase 1, 3 |
| **Phase 8** | Manufacturing-Lite | Month 7-9 | Phase 3 |
| **Phase 9** | Payroll | Month 8-10 | Phase 1 |
| **Phase 10** | Partner Network / B2B Ordering | Month 9-11 | Phase 1, 3 |
| **Phase 11** | AI Foundation | Month 10-12 | Phase 1-5 |
| **Phase 12** | Offline / Mobile Hardening | Continuous | All phases |

### 13.2 Phase Details

#### Phase 0: QA and Bug Fixes (Current)
- Fix BUG-1: Sales Register tax JOIN inflates amounts
- Fix BUG-4: Empty drug-interaction seeds
- Fix BUG-5: Empty generic-substitution seeds
- Fix BUG-6: Delivery challan dispatch — no stock validation
- Fix BUG-7: POS receipt tax split approximation
- Manual QA per 16-section checklist (see `docs/how-to/DISTRIBUTOR_MANUAL_QA_CHECKLIST.md`)
- Verify contact `outstandingAr` restored on payment void

#### Phase 1: Distributor Core Hardening
- SO → DC → Invoice chain: end-to-end QA, edge cases, concurrency
- Credit control: WARN/BLOCK/APPROVAL_REQUIRED per policy (backend done, Flutter E2E)
- Scheme engine: AUTO/MANUAL/DISABLED modes (backend done, Flutter E2E)
- Price list resolution on SO and Invoice, rate preservation on SO→Invoice conversion
- Payment approval workflow E2E
- Credit note approval E2E
- Distributor dashboard v2
- Distributor operational reports: Pending Dispatch, Challan Not Invoiced

#### Phase 2: Retail / POS Hardening
- Single-screen POS redesign (no page flips)
- Keyboard shortcuts
- Barcode scanning reliability
- Stock/price correctness on every sale
- Compact UI for tablet
- End-of-day reconciliation
- Print reliability
- Session management
- Multi-user POS with shift handover

#### Phase 3: Inventory Feature Parity
- Stock transfer between warehouses
- Physical stock count + adjustment (bulk form + commit)
- Barcode generation and scanning
- Serial number tracking (optional)
- Item variants/groups
- UoM conversion hardening
- Reorder point alerts

#### Phase 4: GST Compliance
- e-Invoice integration (NIC API)
- e-Way Bill integration (NIC API)
- GSTR-1 data export
- GSTR-3B summary computation
- GSTR-2A/2B reconciliation
- TDS/TCS basic support

#### Phase 5: Reports + Migration
- Complete remaining reports (Day Book, Vendor Statement + 16 more)
- CSV/Excel/PDF export for all reports
- Migration toolkit: Tally importer, BUSY importer, Excel/CSV importer
- Migration dry-run, validation, trial company
- Database performance indexes

#### Phase 6: Pharma Vertical Pack
- Flutter UI: HSN→GST auto-fill, manufacturer autocomplete, rack location management
- Flutter UI: generic substitution suggestions at POS
- Flutter UI: drug interaction warnings
- Fix BUG-4/BUG-5: seed real drug interaction and substitution data
- Near-expiry alert dashboard widget
- Expiry settlement / return-to-manufacturer workflow

#### Phase 7: FMCG / Field Sales Pack
- Beat/route planning
- Daily call plan
- Order booking from field (mobile, offline)
- Van sales: loading, selling, unloading, settlement
- Route collection
- Day-close wizard
- Salesman incentive/target tracking
- GPS/visit tracking
- Secondary sales capture

#### Phase 8: Manufacturing-Lite
- Work order creation from BOM
- Issue to production (raw material deduction)
- Receive finished goods
- WIP tracking
- Production cost rollup
- Production reports

#### Phase 9: Payroll
- Per specification in `docs/PAYROLL_IMPLEMENTATION_SPEC.md`
- 12 new tables
- PF/ESI/PT/TDS computation
- Payslip generation, journal posting
- Flutter: 11 screens

#### Phase 10: Partner Network
- Per specification in `docs/PARTNER_NETWORK_MODULE_PLAN.md`
- Trading partner management
- Published catalog
- B2B order flow (linked buyer PO ↔ seller SO)
- Retailer self-service ordering

#### Phase 11: AI Foundation
- Per specification in `docs/AI_APPROACH_AND_ROADMAP.md`
- Domain events, suggestions, AI inbox
- Rule-based agents (no external AI initially)
- Pattern learning

#### Phase 12: Offline / Mobile Hardening (Continuous)
- Not a single phase — offline capability is built incrementally with each phase
- Phase 1-2: Basic offline for POS (cart, pricing cached)
- Phase 5: Offline sync dashboard
- Phase 7: Full offline for field sales (orders, collections, van stock)
- Ongoing: Conflict resolution, sync reliability, offline data limits

---

## 14. Current Build Status

Honest assessment of what exists vs what needs building, based on codebase review.

| Module | Backend | Flutter UI | Overall | Notes |
|--------|---------|-----------|---------|-------|
| Core (auth, roles, org) | 90% | 80% | 85% | Needs branch-level access control |
| Accounting (journals, GL, CoA) | 90% | 70% | 80% | Needs year-end close |
| Contacts | 90% | 80% | 85% | Needs contact groups |
| Item Master | 85% | 75% | 80% | Needs variants, barcode generation |
| Tax Engine (GST) | 85% | 80% | 82% | Needs RCM, composition scheme |
| Workflows | 90% | 70% | 80% | BUG-3 fixed. Needs context hints UI. |
| Sales — Wholesale (SO→DC→Invoice) | 80% | 70% | 75% | BUG-6 open. Needs edge-case QA. |
| Sales — Retail / POS | 60% | 50% | 55% | Needs major hardening (see Phase 2) |
| Purchase (PO→GRN→receive) | 75% | 65% | 70% | Needs vendor price tracking |
| AP (bills, vendor payments) | 70% | 60% | 65% | Functional but needs QA |
| AR (payments, credit notes) | 85% | 70% | 78% | BUG-2 fixed. Solid foundation. |
| Inventory (movements, batches, FEFO) | 65% | 55% | 60% | Needs transfers, physical count, barcode |
| Pharma (masters, search) | 45% | 10% | 30% | Backend exists, Flutter UI missing, seeds broken |
| GST Compliance (e-Invoice, e-Way) | 10% | 0% | 5% | Computation exists, integrations not built |
| Reports | 45% | 20% | 35% | 10/14 P0 backend done, Flutter UI missing |
| Migration | 0% | 0% | 0% | Not started |
| Dashboards | 40% | 30% | 35% | Basic widgets exist, need role-based |
| FMCG / Field Sales | 0% | 0% | 0% | Not started |
| Manufacturing | 15% | 5% | 10% | BOM service exists, work orders don't |
| Payroll | 0% | 0% | 0% | Fully spec'd in docs |
| Partner Network | 0% | 0% | 0% | Spec'd in docs |
| AI Foundation | 0% | 0% | 0% | Spec'd in docs |
| Offline / Sync | 5% | 5% | 5% | Architecture decided, not implemented |

---

## 15. Key Architecture Decisions (Non-Negotiable)

These decisions are baked into the codebase and must not be violated by any future development.

1. **PO does NOT post stock.** PO → draft GRN → GRN "Receive Stock" is the only stock posting step.
2. **SO does NOT deduct stock.** SO → draft DC → DC "Dispatch" is the only stock deduction step.
3. **DC does NOT post accounting.** DC → Invoice → Invoice posting is the accounting step.
4. **Invoice posting from SO path must NOT deduct stock again** (already deducted at DC dispatch).
5. **Stock movements are append-only.** Corrections use REVERSE entries, never UPDATE/DELETE.
6. **`stock_balance` is a derived cache**, rebuildable from the stock movement ledger.
7. **Single movement gate:** All stock changes go through `InventoryService.recordMovement()`.
8. **Composite item stock = derived** from min buildable count across components. Composite never gets its own stock movement.
9. **AI must never directly post journals, change stock, or file GST.** All through existing services.
10. **Do NOT build a generic rule engine.** Use `org_settings` for the first policy layer.
11. **Distributor capability extends existing flows — never fork them.**
12. **Workflow must be org-configurable, no customer-specific code branches.**
13. **POS receipts go to Cash/Revenue journal, NOT Accounts Receivable.**
14. **Multi-tenant:** Every org-scoped query filtered by `TenantContext.getCurrentOrgId()`.
15. **Partner Network must call existing services** (PurchaseOrderService, SalesOrderService, etc.) — no direct stock/accounting writes.

---

## 16. Glossary

| Term | Definition |
|------|-----------|
| **Org** | A registered business entity in Katasticho. The top-level tenant. |
| **Branch** | A physical location of an org (office, godown, shop). Each branch can have its own GSTIN. |
| **Capability** | A module that can be enabled/disabled per org subscription (e.g., SELL_RETAIL, PHARMA). |
| **Vertical Pack** | A capability that adds industry-specific features (Pharma, FMCG, Manufacturing). |
| **SO** | Sales Order — B2B order from customer with credit terms. |
| **DC** | Delivery Challan — dispatch document that triggers stock deduction. |
| **GRN** | Goods Receipt Note — receiving document for purchased goods. |
| **FEFO** | First Expiry, First Out — batch consumption strategy. |
| **BOM** | Bill of Materials — recipe for manufacturing a finished good. |
| **WIP** | Work in Progress — raw materials issued but finished goods not yet received. |
| **AR** | Accounts Receivable — money owed to the org by customers. |
| **AP** | Accounts Payable — money owed by the org to vendors. |
| **IRN** | Invoice Reference Number — unique identifier for e-Invoice. |
| **HSN** | Harmonized System of Nomenclature — product classification code for GST. |
| **GSTIN** | GST Identification Number — 15-digit tax ID for registered businesses. |
| **Beat** | A defined route/area assigned to a salesman for regular customer visits. |
| **Van Sales** | Direct selling from a loaded vehicle at customer locations. |
| **Loading Sheet** | Document listing items loaded into a van for route delivery. |
| **MR** | Medical Representative — field salesperson in pharma industry. |
| **Secondary Sales** | Sales from retailer to end consumer (as opposed to primary: distributor to retailer). |
| **Stockist** | Another term for distributor in pharma trade. |

---

## Appendix A: Document References

| Document | Location | Relevance |
|----------|----------|-----------|
| Market Gap Analysis | `docs/Indian Distributor, Pharma, and FMCG ERP Market Gaps.pdf` | Competitive landscape, market gaps, positioning |
| Product Development Roadmap | `docs/PRODUCT_DEVELOPMENT_ROADMAP.md` | Detailed phase roadmap, resume checkpoints |
| Distributor Direction Assessment | `docs/DISTRIBUTOR_FIRST_DIRECTION_ASSESSMENT.md` | Strategic rationale for distributor-first |
| QA Checklist | `docs/how-to/DISTRIBUTOR_MANUAL_QA_CHECKLIST.md` | 16-section manual QA checklist |
| Inventory Feature Gap | `docs/architecture/inventory-feature-gap.md` | Zoho parity analysis, sprint plan |
| Reports Status | `docs/REPORTS_IMPLEMENTATION_STATUS.md` | Which reports exist, what's missing |
| Reports Specification | `docs/REPORTS_P0_SPECIFICATION.md` | SQL/DTO specs for all 14 P0 reports |
| Payroll Specification | `docs/PAYROLL_IMPLEMENTATION_SPEC.md` | Full payroll module spec |
| AI Roadmap | `docs/AI_APPROACH_AND_ROADMAP.md` | AI architecture, agents, safety rules |
| Partner Network Plan | `docs/PARTNER_NETWORK_MODULE_PLAN.md` | B2B ordering module plan |
| Workflow Context Hints | `docs/WORKFLOW_CONTEXT_HINTS_PLAN.md` | Approval workflow UX improvements |
| Project Reference | `CLAUDE.md` | Build commands, bug list, architecture decisions |

---

## Appendix B: Open Questions for Review

1. **Multi-currency timeline:** v1 is INR-only. When do we need multi-currency? Is there an export market in the target customer base?
2. **ONDC integration:** Should we plan for ONDC (Open Network for Digital Commerce) connector? Some FMCG distributors may want this.
3. **Offline data limits:** How much master data to cache offline? Full catalog or filtered by route/beat?
4. **Schedule H/H1 enforcement:** How strict should pharma drug scheduling be in v1? Advisory only, or hard block without prescription reference?
5. **Tally import fidelity:** Which Tally data fields are must-have for migration? Need to survey target customers.
6. **iOS priority:** Is iOS needed for v1, or can it wait until Android is stable?
7. **Regional language support:** Hindi is listed as future. Is it needed before go-live? Which other languages?
8. **Audit trail retention:** How long to retain audit logs? Legal requirement vs storage cost.

---

*This document is the single source of truth for Katasticho ERP product requirements. All development should reference this BRD. Updates to this document require product team review.*
