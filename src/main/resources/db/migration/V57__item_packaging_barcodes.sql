-- V57: Multi-Barcode Packaging Hierarchy (Unit -> Carton -> Case)
CREATE TABLE IF NOT EXISTS public.item_packaging_barcode (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    item_id UUID NOT NULL REFERENCES public.item(id),
    barcode VARCHAR(100) NOT NULL,
    packaging_level VARCHAR(30) NOT NULL DEFAULT 'UNIT',
    packaging_name VARCHAR(100),
    conversion_factor NUMERIC(15,4) NOT NULL DEFAULT 1.0000,
    uom_name VARCHAR(50),
    mrp NUMERIC(15,4),
    sale_price NUMERIC(15,4),
    purchase_price NUMERIC(15,4),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    notes VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_pkg_barcode_org_code ON public.item_packaging_barcode(org_id, barcode, is_deleted);
CREATE INDEX IF NOT EXISTS idx_pkg_barcode_org_item ON public.item_packaging_barcode(org_id, item_id, is_deleted);
