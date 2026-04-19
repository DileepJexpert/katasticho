-- V28: Add extended item fields — manufacturer, vendor, weight, dimensions, pharmacy

ALTER TABLE items ADD COLUMN IF NOT EXISTS manufacturer    VARCHAR(100);
ALTER TABLE items ADD COLUMN IF NOT EXISTS preferred_vendor_id UUID;
ALTER TABLE items ADD COLUMN IF NOT EXISTS weight          DECIMAL(12,4);
ALTER TABLE items ADD COLUMN IF NOT EXISTS weight_unit     VARCHAR(10);
ALTER TABLE items ADD COLUMN IF NOT EXISTS length          DECIMAL(12,4);
ALTER TABLE items ADD COLUMN IF NOT EXISTS width           DECIMAL(12,4);
ALTER TABLE items ADD COLUMN IF NOT EXISTS height          DECIMAL(12,4);
ALTER TABLE items ADD COLUMN IF NOT EXISTS dimension_unit  VARCHAR(10);

-- Pharmacy-specific fields (visible when organisation.industry = 'PHARMACY')
ALTER TABLE items ADD COLUMN IF NOT EXISTS drug_schedule         VARCHAR(10);
ALTER TABLE items ADD COLUMN IF NOT EXISTS composition           TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS dosage_form           VARCHAR(50);
ALTER TABLE items ADD COLUMN IF NOT EXISTS pack_size             VARCHAR(50);
ALTER TABLE items ADD COLUMN IF NOT EXISTS storage_condition     VARCHAR(100);
ALTER TABLE items ADD COLUMN IF NOT EXISTS prescription_required BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_items_preferred_vendor ON items(preferred_vendor_id) WHERE preferred_vendor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_items_manufacturer    ON items(org_id, manufacturer) WHERE manufacturer IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_items_barcode         ON items(org_id, barcode)      WHERE barcode IS NOT NULL;
