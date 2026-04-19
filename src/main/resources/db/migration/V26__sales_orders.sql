-- ─────────────────────────────────────────────────────────────
-- Sales Order + Stock Reservation
-- ─────────────────────────────────────────────────────────────

-- Add reserved_qty to stock_balance
ALTER TABLE stock_balance ADD COLUMN reserved_qty NUMERIC(15,4) NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────────────────────
-- SALES ORDER
-- ─────────────────────────────────────────────────────────────
CREATE TABLE sales_order (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organisation(id),
    branch_id               UUID REFERENCES branch(id),
    salesorder_number       VARCHAR(30) NOT NULL,
    reference_number        VARCHAR(50),
    contact_id              UUID NOT NULL REFERENCES contact(id),
    estimate_id             UUID REFERENCES estimate(id),
    order_date              DATE NOT NULL,
    expected_shipment_date  DATE,
    status                  VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN (
            'DRAFT','CONFIRMED',
            'PARTIALLY_SHIPPED','SHIPPED',
            'PARTIALLY_INVOICED','INVOICED',
            'COMPLETED','CANCELLED','VOID'
        )),
    shipped_status          VARCHAR(20) NOT NULL DEFAULT 'NOT_SHIPPED'
        CHECK (shipped_status IN (
            'NOT_SHIPPED','PARTIALLY_SHIPPED','FULLY_SHIPPED'
        )),
    invoiced_status         VARCHAR(20) NOT NULL DEFAULT 'NOT_INVOICED'
        CHECK (invoiced_status IN (
            'NOT_INVOICED','PARTIALLY_INVOICED','FULLY_INVOICED'
        )),
    discount_type           VARCHAR(15) DEFAULT 'ITEM_LEVEL'
        CHECK (discount_type IN ('ITEM_LEVEL','ENTITY_LEVEL')),
    discount_amount         NUMERIC(15,2) DEFAULT 0,
    subtotal                NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount              NUMERIC(15,2) NOT NULL DEFAULT 0,
    shipping_charge         NUMERIC(15,2) DEFAULT 0,
    adjustment              NUMERIC(15,2) DEFAULT 0,
    adjustment_description  VARCHAR(200),
    total                   NUMERIC(15,2) NOT NULL DEFAULT 0,
    billing_address         JSONB,
    shipping_address        JSONB,
    payment_mode            VARCHAR(20),
    delivery_method         VARCHAR(50),
    currency                VARCHAR(3) NOT NULL DEFAULT 'INR',
    place_of_supply         VARCHAR(50),
    notes                   VARCHAR(2000),
    terms                   VARCHAR(2000),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID REFERENCES app_user(id),
    UNIQUE(org_id, salesorder_number)
);

CREATE TABLE sales_order_line (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sales_order_id          UUID NOT NULL REFERENCES sales_order(id) ON DELETE CASCADE,
    line_number             INT NOT NULL,
    item_id                 UUID REFERENCES item(id),
    description             VARCHAR(500),
    quantity                NUMERIC(12,4) NOT NULL,
    quantity_shipped        NUMERIC(12,4) NOT NULL DEFAULT 0,
    quantity_invoiced       NUMERIC(12,4) NOT NULL DEFAULT 0,
    unit                    VARCHAR(20),
    rate                    NUMERIC(15,2) NOT NULL,
    discount_pct            NUMERIC(5,2) DEFAULT 0,
    tax_group_id            UUID REFERENCES tax_group(id),
    tax_rate                NUMERIC(5,2) DEFAULT 0,
    hsn_code                VARCHAR(8),
    amount                  NUMERIC(15,2) NOT NULL,
    UNIQUE(sales_order_id, line_number)
);

-- ─────────────────────────────────────────────────────────────
-- STOCK RESERVATION
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_reservation (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organisation(id),
    item_id                 UUID NOT NULL REFERENCES item(id),
    warehouse_id            UUID NOT NULL REFERENCES warehouse(id),
    source_type             VARCHAR(20) NOT NULL
        CHECK (source_type IN ('SALES_ORDER','TRANSFER_ORDER')),
    source_id               UUID NOT NULL,
    source_line_id          UUID NOT NULL,
    quantity_reserved       NUMERIC(12,4) NOT NULL,
    status                  VARCHAR(15) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE','FULFILLED','CANCELLED')),
    reserved_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fulfilled_at            TIMESTAMPTZ,
    cancelled_at            TIMESTAMPTZ,
    UNIQUE(source_type, source_line_id)
);

-- Link invoice back to sales order (nullable — direct invoices have no SO)
ALTER TABLE invoice ADD COLUMN sales_order_id UUID REFERENCES sales_order(id);
CREATE INDEX idx_invoice_sales_order ON invoice(sales_order_id) WHERE sales_order_id IS NOT NULL;

CREATE INDEX idx_sales_order_org ON sales_order(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_sales_order_contact ON sales_order(org_id, contact_id) WHERE NOT is_deleted;
CREATE INDEX idx_sales_order_status ON sales_order(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_sales_order_branch ON sales_order(org_id, branch_id) WHERE NOT is_deleted;
CREATE INDEX idx_stock_reservation_item ON stock_reservation(org_id, item_id, status);
CREATE INDEX idx_stock_reservation_source ON stock_reservation(source_type, source_id);
