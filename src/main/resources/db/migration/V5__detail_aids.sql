-- V5: E-detailing — URL-based detail aids (brochures / visual aids) shown
-- during field visits, with a per-visit log of what was presented.
-- Vertical-neutral: pharma product brochures, FMCG promo decks, catalogs.
-- Media is referenced by URL (org hosts files on Drive/S3/website) since
-- the platform has no file-storage service yet.

CREATE TABLE detail_aid (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(300),
    media_url TEXT NOT NULL,
    media_type VARCHAR(10) NOT NULL DEFAULT 'LINK',   -- PDF / IMAGE / VIDEO / LINK
    product_name VARCHAR(200),                        -- optional product association
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_detail_aid_org ON detail_aid(org_id) WHERE NOT is_deleted;

CREATE TABLE visit_detail_aid_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    field_visit_id UUID NOT NULL,
    detail_aid_id UUID NOT NULL REFERENCES detail_aid(id),
    shown_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_vdal_visit ON visit_detail_aid_log(org_id, field_visit_id);
CREATE INDEX idx_vdal_aid ON visit_detail_aid_log(org_id, detail_aid_id);
