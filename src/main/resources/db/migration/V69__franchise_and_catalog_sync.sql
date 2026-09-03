-- V69: Multi-Branch Franchising, Central Master Catalog Sync & Royalty Settlement
CREATE TABLE IF NOT EXISTS franchise_node (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    node_code VARCHAR(50) NOT NULL,
    node_name VARCHAR(150) NOT NULL,
    node_type VARCHAR(30) NOT NULL DEFAULT 'FOFO', -- COCO, FOFO, FICO
    branch_id UUID REFERENCES branch(id) ON DELETE SET NULL,
    contact_email VARCHAR(100),
    phone VARCHAR(30),
    city VARCHAR(100),
    state_code VARCHAR(5),
    royalty_rate_percent NUMERIC(5, 2) NOT NULL DEFAULT 5.00,
    fixed_monthly_fee NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_franchise_node_code UNIQUE (org_id, node_code)
);

CREATE TABLE IF NOT EXISTS franchise_catalog_policy (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    auto_sync_new_items BOOLEAN NOT NULL DEFAULT TRUE,
    allow_branch_price_override BOOLEAN NOT NULL DEFAULT TRUE,
    max_discount_from_mrp_percent NUMERIC(5, 2) NOT NULL DEFAULT 15.00,
    min_margin_percent NUMERIC(5, 2) NOT NULL DEFAULT 8.00,
    sync_mode VARCHAR(30) NOT NULL DEFAULT 'ALL_ITEMS', -- ALL_ITEMS, ACTIVE_ONLY, CATEGORY_FILTERED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_franchise_policy_org UNIQUE (org_id)
);

CREATE TABLE IF NOT EXISTS branch_item_override (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branch(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES item(id) ON DELETE CASCADE,
    custom_selling_price NUMERIC(15, 4) NOT NULL,
    custom_mrp NUMERIC(15, 4),
    min_retail_price NUMERIC(15, 4),
    is_override_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_branch_item_override UNIQUE (org_id, branch_id, item_id)
);

CREATE TABLE IF NOT EXISTS franchise_royalty_settlement (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    franchise_node_id UUID NOT NULL REFERENCES franchise_node(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    gross_sales_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    royalty_percent NUMERIC(5, 2) NOT NULL DEFAULT 5.00,
    royalty_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    fixed_fee_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    total_settlement_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(30) NOT NULL DEFAULT 'CALCULATED', -- DRAFT, CALCULATED, INVOICED, SETTLED
    generated_invoice_id UUID REFERENCES invoice(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_franchise_node_org ON franchise_node(org_id, is_active) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_branch_override_lookup ON branch_item_override(org_id, branch_id, item_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_royalty_settlement_node ON franchise_royalty_settlement(org_id, franchise_node_id, status) WHERE is_deleted = false;
