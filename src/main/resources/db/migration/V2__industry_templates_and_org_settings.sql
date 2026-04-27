-- Industry Templates: reference data seeded at startup, not per-org
CREATE TABLE industry_template (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_type   VARCHAR(20) NOT NULL,
    industry_code   VARCHAR(30) NOT NULL UNIQUE,
    industry_label  VARCHAR(50) NOT NULL,
    industry_icon   VARCHAR(10),
    sort_order      INT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE industry_sub_category (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    industry_template_id  UUID NOT NULL REFERENCES industry_template(id),
    sub_category_code     VARCHAR(50) NOT NULL,
    sub_category_label    VARCHAR(100) NOT NULL,
    sort_order            INT NOT NULL DEFAULT 0,
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(industry_template_id, sub_category_code)
);

CREATE TABLE industry_feature_config (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    industry_template_id  UUID NOT NULL REFERENCES industry_template(id),
    sub_category_code     VARCHAR(50),
    feature_flags         JSONB NOT NULL DEFAULT '[]'::jsonb,
    uom_list              JSONB NOT NULL DEFAULT '[]'::jsonb,
    coa_template          VARCHAR(30) NOT NULL DEFAULT 'INDIAN_STANDARD',
    tax_template          VARCHAR(30) NOT NULL DEFAULT 'GST_INDIA',
    default_accounts      JSONB NOT NULL DEFAULT '{}'::jsonb,
    item_fields           JSONB NOT NULL DEFAULT '[]'::jsonb,
    sample_items          JSONB NOT NULL DEFAULT '[]'::jsonb,
    additional_accounts   JSONB NOT NULL DEFAULT '[]'::jsonb,
    UNIQUE(industry_template_id, sub_category_code)
);

CREATE INDEX idx_industry_template_type ON industry_template(business_type);
CREATE INDEX idx_industry_sub_cat_template ON industry_sub_category(industry_template_id);
CREATE INDEX idx_industry_feature_template ON industry_feature_config(industry_template_id);

-- Generic org settings: key-value preferences per org
CREATE TABLE org_settings (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id    UUID NOT NULL REFERENCES organisation(id),
    key       VARCHAR(100) NOT NULL,
    value     TEXT NOT NULL,
    UNIQUE(org_id, key)
);

CREATE INDEX idx_org_settings_org ON org_settings(org_id);
