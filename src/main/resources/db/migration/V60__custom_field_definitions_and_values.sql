-- Migration V60: User-Defined Custom Fields (UDF) Framework
-- Enables metadata attributes across master records (CONTACT, ITEM) and vouchers (SALES_ORDER, INVOICE, PURCHASE_BILL, DELIVERY_CHALLAN, PURCHASE_ORDER, GOODS_RECEIPT)

CREATE TABLE IF NOT EXISTS custom_field_definition (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    field_name VARCHAR(100) NOT NULL,
    field_label VARCHAR(100) NOT NULL,
    field_type VARCHAR(30) NOT NULL DEFAULT 'TEXT',
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    default_value VARCHAR(500),
    options_json TEXT,
    validation_regex VARCHAR(255),
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    show_in_grid BOOLEAN NOT NULL DEFAULT FALSE,
    show_in_pdf BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_cfd_org_entity
    ON custom_field_definition (org_id, entity_type)
    WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_cfd_unique_name
    ON custom_field_definition (org_id, entity_type, field_name)
    WHERE is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS custom_field_value (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    field_definition_id UUID NOT NULL REFERENCES custom_field_definition(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    value_text TEXT,
    value_number NUMERIC(19, 4),
    value_date DATE,
    value_boolean BOOLEAN,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_cfv_org_entity_instance
    ON custom_field_value (org_id, entity_type, entity_id)
    WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_cfv_unique_active
    ON custom_field_value (org_id, field_definition_id, entity_id)
    WHERE is_deleted = FALSE;
