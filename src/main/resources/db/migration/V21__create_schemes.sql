CREATE TABLE schemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    scheme_type VARCHAR(30) NOT NULL, -- BUY_X_GET_Y, PERCENT_DISCOUNT
    item_id UUID REFERENCES items(id),
    buy_quantity NUMERIC(14,4),
    free_quantity NUMERIC(14,4),
    discount_percent NUMERIC(6,2),
    min_order_quantity NUMERIC(14,4) DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    supplier_id UUID REFERENCES suppliers(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_schemes_org ON schemes(org_id, is_deleted, is_active);
CREATE INDEX idx_schemes_item ON schemes(item_id) WHERE item_id IS NOT NULL;
