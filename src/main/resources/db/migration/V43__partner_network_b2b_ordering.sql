-- V43: Partner Network — B2B ordering between organisations
-- Enables manufacturers, distributors, and retailers to trade within the same platform.

-- Trading partner: approved buyer↔seller relationship
CREATE TABLE trading_partner (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_org_id UUID NOT NULL,
    buyer_org_id UUID NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    requested_by_org_id UUID NOT NULL,
    price_list_id UUID,
    credit_limit NUMERIC(15,2),
    payment_terms VARCHAR(100),
    delivery_terms VARCHAR(200),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_at TIMESTAMPTZ,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_trading_partner UNIQUE (seller_org_id, buyer_org_id),
    CONSTRAINT chk_trading_partner_status CHECK (status IN ('PENDING','APPROVED','REJECTED','SUSPENDED','REVOKED')),
    CONSTRAINT chk_trading_partner_diff_orgs CHECK (seller_org_id <> buyer_org_id)
);

-- Published catalog: items a seller makes visible to approved buyers
CREATE TABLE published_catalog_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    item_id UUID NOT NULL,
    drug_master_id UUID,
    display_name VARCHAR(200) NOT NULL,
    published_sku VARCHAR(60),
    hsn_code VARCHAR(20),
    manufacturer VARCHAR(200),
    pack_size VARCHAR(60),
    category VARCHAR(100),
    description TEXT,
    published_mrp NUMERIC(15,2),
    published_ptr NUMERIC(15,2),
    min_order_qty NUMERIC(10,2) DEFAULT 1,
    availability_status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_catalog_availability CHECK (availability_status IN ('AVAILABLE','LOW_STOCK','OUT_OF_STOCK','DISCONTINUED'))
);

-- Network order: cross-org order linking buyer PO ↔ seller SO
CREATE TABLE network_order (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(30) NOT NULL,
    buyer_org_id UUID NOT NULL,
    seller_org_id UUID NOT NULL,
    trading_partner_id UUID NOT NULL REFERENCES trading_partner(id),
    buyer_po_id UUID,
    seller_so_id UUID,
    status VARCHAR(30) NOT NULL DEFAULT 'PLACED',
    total_amount NUMERIC(15,2),
    total_qty NUMERIC(10,2),
    requested_delivery_date DATE,
    buyer_notes TEXT,
    seller_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_at TIMESTAMPTZ,
    dispatched_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_network_order_status CHECK (status IN (
        'PLACED','CONFIRMED','PARTIALLY_CONFIRMED','REJECTED',
        'PROCESSING','DISPATCHED','PARTIALLY_DISPATCHED',
        'DELIVERED','PARTIALLY_DELIVERED','CANCELLED','CLOSED'))
);

-- Network order lines
CREATE TABLE network_order_line (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    network_order_id UUID NOT NULL REFERENCES network_order(id),
    catalog_item_id UUID REFERENCES published_catalog_item(id),
    buyer_item_id UUID,
    seller_item_id UUID,
    drug_master_id UUID,
    display_name VARCHAR(200),
    hsn_code VARCHAR(20),
    ordered_qty NUMERIC(10,2) NOT NULL,
    confirmed_qty NUMERIC(10,2),
    dispatched_qty NUMERIC(10,2) DEFAULT 0,
    unit_price NUMERIC(15,2) NOT NULL,
    line_total NUMERIC(15,2),
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    seller_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_nol_status CHECK (status IN ('PENDING','CONFIRMED','REJECTED','DISPATCHED','DELIVERED','CANCELLED'))
);

-- Network order events: audit trail
CREATE TABLE network_order_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    network_order_id UUID NOT NULL REFERENCES network_order(id),
    event_type VARCHAR(50) NOT NULL,
    actor_org_id UUID NOT NULL,
    actor_user_id UUID,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_trading_partner_seller ON trading_partner(seller_org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_trading_partner_buyer ON trading_partner(buyer_org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_catalog_org ON published_catalog_item(org_id, is_active) WHERE NOT is_deleted;
CREATE INDEX idx_catalog_drug_master ON published_catalog_item(drug_master_id) WHERE drug_master_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX idx_catalog_hsn ON published_catalog_item(hsn_code) WHERE hsn_code IS NOT NULL AND NOT is_deleted;
CREATE INDEX idx_network_order_buyer ON network_order(buyer_org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_network_order_seller ON network_order(seller_org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_network_order_partner ON network_order(trading_partner_id) WHERE NOT is_deleted;
CREATE INDEX idx_network_order_line_order ON network_order_line(network_order_id);
CREATE INDEX idx_network_order_event_order ON network_order_event(network_order_id);
