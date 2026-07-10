# 12 — Partner Network (B2B Ordering)

Manual UAT for the connected B2B trade network: trading partnerships, published
catalogs, supplier search, and the cross-org network-order lifecycle. Format
matches the rest of the pack — see `README.md` §3.

> **Two organisations required.** This module is genuinely cross-org: a **Seller
> org** publishes a catalog; a **Buyer org** discovers it and places orders.
> Register two orgs (two signups) and keep both logins handy. Screens are under
> **`/partner-network/*`**. Roles: OWNER/ADMIN.

> **Module gate:** `PARTNER_NETWORK` / `canUsePartnerNetwork` (distributor default;
> otherwise enable it on the Modules screen, doc 07, for **both** orgs).

> **Test orgs:**
> | Org | Role in test | Login |
> |---|---|---|
> | **MediSupply Distributors** | Seller (publishes catalog) | seller OWNER |
> | **Sharma Traders** | Buyer (places orders) | buyer OWNER |

---

## A. Trading partnership

### TC-PN-001 — Request a partnership
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | `/partner-network/partners` (`POST /api/v1/partner-network/partners/request`) · **Role:** Buyer OWNER |

**Steps:** As **Buyer (Sharma)**, request a partnership with **Seller
(MediSupply)**.

**Expected result:** A partnership request is created (PENDING) linking
buyer_org ↔ seller_org. It shows under the Seller's **pending** list
(`/partners/pending`).

**Actual / Status / Notes:**

---

### TC-PN-002 — Approve / reject / suspend
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | Seller `/partner-network/partners` (`.../partners/{id}/approve|reject|suspend`) · **Role:** Seller OWNER |

**Expected result:** Seller **Approves** → partnership ACTIVE (now the buyer can
see the seller's catalog). **Reject** blocks it; **Suspend** pauses an active one.
Only the counter-party can decide.

**Actual / Status / Notes:**

---

### TC-PN-003 — Self-partner + self-approve + duplicate prevention
| | |
|---|---|
| **Priority / Type** | P1 / Negative |
| **Route** | API `/partners/request`, `/partners/{id}/approve` |

**Expected result:** An org **cannot** partner with **itself** (rejected). The
**requester cannot approve** their own request (only the other side can).
Requesting a **duplicate** partnership with an existing partner is blocked
(unique constraint). Each is a clean business-error, not a 500.

**Actual / Status / Notes:**

---

## B. Published catalog

### TC-PN-010 — Seller publishes catalog items
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | Seller `/partner-network/catalog` (`POST /api/v1/partner-network/catalog`) · **Role:** Seller OWNER |

**Test data:** Publish **Paracetamol 500mg** with MRP ₹15, **PTR** ₹11,
availability In-stock, pack size 10.

**Expected result:** The item appears in the Seller's published catalog with
MRP/PTR/availability/pack size. Pharma items can link a **drug master** for
cross-org product matching. **Unpublish** (`.../catalog/{id}/unpublish`) removes
it from buyer search.

**Actual / Status / Notes:**

---

## C. Supplier search (buyer side)

### TC-PN-020 — Buyer searches approved suppliers' catalogs
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | Buyer `/partner-network/supplier-search` (`GET .../supplier-search?q=`, `.../by-drug/{id}`) · **Role:** Buyer OWNER |
| **Preconditions** | Partnership ACTIVE (TC-PN-002) + catalog published (TC-PN-010) |

**Expected result:** Searching "Paracetamol" returns the Seller's published item
(MRP/PTR/pack). Search is scoped to **approved** suppliers only — a
non-partner/suspended seller's catalog is not visible. `by-drug` finds the same
product across suppliers via the drug-master link.

**Actual / Status / Notes:**

---

## D. Network order lifecycle

### TC-PN-030 — Buyer places a network order
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | Buyer `/partner-network/outgoing-orders` (`POST /api/v1/partner-network/orders`) · **Role:** Buyer OWNER |

**Test data:** Order 100 × Paracetamol from MediSupply.

**Expected result:** Order created **PLACED**; appears in the Buyer's **outgoing**
list and the Seller's **incoming** list (`/orders/incoming`, `.../incoming/pending`).
An **event** is recorded (actor = buyer).

**Actual / Status / Notes:**

---

### TC-PN-031 — Seller confirms (per-line quantity)
| | |
|---|---|
| **Priority / Type** | P0 / Happy |
| **Route** | Seller `/partner-network/incoming-orders` (`POST .../orders/{id}/confirm`) · **Role:** Seller OWNER |

**Test data:** Confirm 80 of 100 (partial).

**Expected result:** Order → **PARTIALLY_CONFIRMED** (or CONFIRMED when full) with
per-line confirmed qty. A **reject** (`.../reject`) moves it to REJECTED. Event
trail records the seller action.

**Actual / Status / Notes:**

---

### TC-PN-032 — Dispatch → deliver
| | |
|---|---|
| **Priority / Type** | P1 / Happy |
| **Route** | Seller `.../orders/{id}/dispatch`, `.../deliver` · **Role:** Seller OWNER |

**Expected result:** CONFIRMED → **DISPATCHED** → **DELIVERED**, each stamping an
event (`/orders/{id}/events` shows the full timeline with actor + timestamp).

**Actual / Status / Notes:**

---

### TC-PN-033 — Buyer cancels a placed order
| | |
|---|---|
| **Priority / Type** | P1 / Edge |
| **Route** | Buyer `.../orders/{id}/cancel` · **Role:** Buyer OWNER |

**Expected result:** The buyer can **cancel** while the order is still cancellable
(e.g. PLACED). A cancel after dispatch is rejected (business error). The event
trail records the cancel.

**Actual / Status / Notes:**

---

### TC-PN-040 — Link to PO / SO for downstream flow
| | |
|---|---|
| **Priority / Type** | P2 / Edge |
| **Route** | `.../orders/{id}/link-po` (buyer), `.../orders/{id}/link-so` (seller) |

**Expected result:** The buyer can link the network order to their **PurchaseOrder**
and the seller to their **SalesOrder**, so each side drops into its normal
GRN→Bill (buyer) / DC→Invoice (seller) flow. The link is recorded on the order.

**Actual / Status / Notes:**

---

## E. Role / module gate

### TC-PN-050 — Non-admin + non-partner access
| | |
|---|---|
| **Priority / Type** | P2 / Role |
| **Route** | API various · **Role:** OPERATOR / a non-partner org |

**Expected result:** Partnership + catalog + order **writes** require OWNER/ADMIN
(OPERATOR/VIEWER → 403 where gated). A buyer with **no active partnership** cannot
see the seller's catalog or place an order against it. Confirms cross-org access
control.

**Actual / Status / Notes:**

---

### TC-PN-051 — Module gate
| | |
|---|---|
| **Priority / Type** | P2 / Role |
| **Route** | sidebar · **Role:** OWNER of a plain **retailer** org (no override) |

**Expected result:** The **Partner Network** group is **not** in the sidebar for a
retailer by default (see doc 07); a distributor sees it, or enable
`PARTNER_NETWORK` on the Modules screen. Both trading orgs must have it enabled.

**Actual / Status / Notes:**
