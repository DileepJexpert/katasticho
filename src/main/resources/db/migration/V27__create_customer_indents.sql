-- V27: Customer indents / out-of-stock customer requests
CREATE TABLE customer_indent (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    indent_number   VARCHAR(30) NOT NULL,
    contact_id      UUID,
    customer_name   VARCHAR(255) NOT NULL,
    customer_phone  VARCHAR(30),
    item_id         UUID NOT NULL,
    item_name       VARCHAR(255) NOT NULL,
    item_sku        VARCHAR(80),
    quantity        DECIMAL(19,4) NOT NULL DEFAULT 1,
    status          VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',
    source          VARCHAR(20) NOT NULL DEFAULT 'MANUAL',
    needed_by       DATE,
    notes           TEXT,
    notified_at     TIMESTAMPTZ,
    fulfilled_at    TIMESTAMPTZ,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_customer_indent_status
        CHECK (status IN ('REQUESTED','ORDERED','RECEIVED','NOTIFIED','FULFILLED','CANCELLED')),
    CONSTRAINT chk_customer_indent_source
        CHECK (source IN ('POS','MANUAL','PHONE','WHATSAPP')),
    CONSTRAINT chk_customer_indent_qty CHECK (quantity > 0)
);

CREATE SEQUENCE customer_indent_seq START 1001 INCREMENT 1;
CREATE INDEX idx_customer_indent_org_status ON customer_indent(org_id, status, is_deleted);
CREATE INDEX idx_customer_indent_item_status ON customer_indent(org_id, item_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_customer_indent_contact ON customer_indent(org_id, contact_id) WHERE contact_id IS NOT NULL AND is_deleted = FALSE;
