CREATE TABLE customer_indent (
    id              UUID PRIMARY KEY,
    org_id          UUID NOT NULL,
    contact_id      UUID,
    contact_name    VARCHAR(255),
    contact_phone   VARCHAR(50),
    item_id         UUID NOT NULL,
    item_name       VARCHAR(255) NOT NULL,
    sku             VARCHAR(100),
    requested_qty   NUMERIC(15,4) NOT NULL DEFAULT 1,
    unit            VARCHAR(50),
    notes           TEXT,
    status          VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    purchase_order_id UUID,
    promised_date   DATE,
    fulfilled_receipt_id UUID,
    fulfilled_at    TIMESTAMP,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by      UUID
);

CREATE INDEX idx_indent_org_status ON customer_indent(org_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_indent_org_item ON customer_indent(org_id, item_id) WHERE is_deleted = FALSE;
