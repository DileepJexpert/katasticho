-- V11: Supplier rate contracts.
--
-- Pricing has selling-side PriceListService for the customer-facing price.
-- Procurement had no symmetric supplier-negotiated rate table; PO unit prices
-- were either copied from PO history, dictated by the planner, or pulled from
-- the supplier quote when an RFQ ran. This migration owns the third path:
-- a negotiated (supplier × item) rate that auto-fills the PO line when the
-- planner doesn't enter one explicitly.
--
-- One ACTIVE contract per (org, supplier, item) — enforced by a partial
-- unique index. Daily sweep moves ACTIVE→EXPIRED when valid_until elapses.

-- ── supplier_rate_contract (header) ────────────────────────────────────────
CREATE TABLE supplier_rate_contract (
    id                       UUID PRIMARY KEY,
    org_id                   UUID NOT NULL,
    contract_number          VARCHAR(30) NOT NULL,
    supplier_contact_id      UUID NOT NULL,
    status                   VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    valid_from               DATE NOT NULL,
    valid_until              DATE,
    currency                 VARCHAR(3) NOT NULL DEFAULT 'INR',
    notes                    TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by               UUID,
    is_deleted               BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_supplier_rate_contract_status
        CHECK (status IN ('DRAFT', 'ACTIVE', 'EXPIRED', 'CANCELLED'))
);

CREATE UNIQUE INDEX uq_supplier_rate_contract_number_per_org
    ON supplier_rate_contract (org_id, contract_number) WHERE is_deleted = FALSE;

CREATE INDEX idx_supplier_rate_contract_expiry
    ON supplier_rate_contract (org_id, status, valid_until)
    WHERE is_deleted = FALSE AND status = 'ACTIVE';

CREATE INDEX idx_supplier_rate_contract_supplier
    ON supplier_rate_contract (org_id, supplier_contact_id) WHERE is_deleted = FALSE;

-- ── supplier_rate_contract_line ────────────────────────────────────────────
CREATE TABLE supplier_rate_contract_line (
    id                              UUID PRIMARY KEY,
    org_id                          UUID NOT NULL,
    supplier_rate_contract_id       UUID NOT NULL REFERENCES supplier_rate_contract(id),
    item_id                         UUID NOT NULL,
    unit_price                      NUMERIC(15, 2) NOT NULL,
    min_order_qty                   NUMERIC(15, 4) NOT NULL DEFAULT 0,
    notes                           VARCHAR(500),
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by                      UUID,
    is_deleted                      BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_supplier_rate_contract_line_parent
    ON supplier_rate_contract_line (supplier_rate_contract_id) WHERE is_deleted = FALSE;

CREATE INDEX idx_supplier_rate_contract_line_item
    ON supplier_rate_contract_line (org_id, item_id) WHERE is_deleted = FALSE;

-- One ACTIVE contract line per (org, supplier, item): the lookup result must
-- be unambiguous when the PO drafter asks "what's our negotiated rate for X
-- from supplier Y today?". Achieved with a partial unique index gated on the
-- parent contract being ACTIVE — enforced application-side at activate().
-- A separate concurrent ACTIVE contract referencing the same (supplier, item)
-- would be caught by the application's SRC_OVERLAPPING_ACTIVE guard.
