-- V63: PDF Visual Template Customizer Settings
CREATE TABLE IF NOT EXISTS pdf_template_setting (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL, -- INVOICE, QUOTATION, BILL, DELIVERY_CHALLAN
    template_theme VARCHAR(50) NOT NULL DEFAULT 'CLASSIC', -- CLASSIC, MODERN, MINIMAL, COMPACT_THERMAL
    primary_color VARCHAR(20) NOT NULL DEFAULT '#0F8576',
    header_layout VARCHAR(30) NOT NULL DEFAULT 'LOGO_LEFT', -- LOGO_LEFT, LOGO_RIGHT, LOGO_CENTER
    show_gst_columns BOOLEAN NOT NULL DEFAULT TRUE,
    show_hsn_column BOOLEAN NOT NULL DEFAULT TRUE,
    show_payment_qr BOOLEAN NOT NULL DEFAULT TRUE,
    show_terms BOOLEAN NOT NULL DEFAULT TRUE,
    terms_and_conditions TEXT,
    show_signature BOOLEAN NOT NULL DEFAULT TRUE,
    signature_label VARCHAR(100) DEFAULT 'Authorized Signatory',
    watermark_text VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_pdf_template_org_doc UNIQUE (org_id, document_type)
);

CREATE INDEX IF NOT EXISTS idx_pdf_template_org_doc ON pdf_template_setting(org_id, document_type) WHERE is_deleted = false;
