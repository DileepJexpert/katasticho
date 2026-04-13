-- ============================================================================
-- V17: Item groups / variants — Sprint 28 (v2 Feature 5)
--
-- Why this migration:
--   v1 stores every SKU as an isolated row. A garment retailer selling
--   a "Cotton Tee" in S/M/L × Red/Blue/Black ends up with nine totally
--   unrelated items — same HSN, same GST, same UoM, no link between
--   them, and the picker is impossible to scan.
--
--   This migration adds an item_group abstraction that sits *above* the
--   item table as a presentation/organisation layer. Variants are still
--   real Item rows (so stock, BOM, batches, FEFO, invoicing, GRN, credit
--   notes, and price lists keep working unchanged), but they carry a
--   FK back to their group plus the JSONB attribute map that
--   distinguishes them within it.
--
-- Design principles encoded here:
--   1. Group is NOT a new ItemType. There is no "parent SKU" row in the
--      item table for the group. The group only exists as metadata —
--      sale_price / hsn_code / gst_rate are *defaults* copied into new
--      child items at create time (one-shot inheritance, not a runtime
--      resolver). Historical items stay frozen even if the group later
--      changes — critical for invoice and report reproducibility.
--   2. attribute_definitions enumerates which attribute keys + allowed
--      values the group permits. The service layer rejects any variant
--      whose key/value falls outside this list. Without it the JSONB
--      bag turns into a garbage dump of "color/colour/Color" typos.
--   3. A CHECK constraint forbids a non-NULL group_id paired with an
--      empty {} attribute map — an item in a group with zero
--      attributes is a variant of nothing and would break the unique
--      index for a second variant.
--
-- What this migration does NOT do:
--   - Does NOT back-fill or auto-group existing items. Pre-V17 rows
--     keep group_id = NULL and behave exactly as before.
--   - Does NOT cascade on group delete. The service refuses to delete
--     a group that still has live children (GROUP_HAS_CHILDREN).
--   - Does NOT support nested groups. attribute_definitions is a flat
--     list; one level of variation is enough for v1.
--   - Does NOT enforce "child must be GOODS or SERVICE" in SQL.
--     Composite items in groups are blocked at service-layer save time
--     so the error message is clearer and the rule is easier to relax
--     in v2 without a migration.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. item_group — the variant template
--
-- attribute_definitions is a JSONB array of {key, values}. Example:
--   [
--     {"key": "size",  "values": ["S","M","L","XL"]},
--     {"key": "color", "values": ["Red","Blue","Black"]}
--   ]
-- The service validates every variant_attributes against this list
-- before persisting an item, so by the time a row hits stock it's
-- guaranteed to be a real combination from this template.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE item_group (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                   UUID NOT NULL REFERENCES organisation(id),
    name                     VARCHAR(255) NOT NULL,
    description              TEXT,

    -- Optional SKU prefix the matrix bulk-create uses to mint child
    -- SKUs as "<prefix>-<size>-<color>". When NULL the operator must
    -- type each child SKU manually.
    sku_prefix               VARCHAR(50),

    -- Defaults copied (one-shot) into every child item created in this
    -- group. NULL on the group means "no default — child must supply".
    hsn_code                 VARCHAR(10),
    gst_rate                 NUMERIC(5,2),
    default_uom              VARCHAR(20),
    default_purchase_price   NUMERIC(15,4),
    default_sale_price       NUMERIC(15,4),

    attribute_definitions    JSONB NOT NULL DEFAULT '[]'::jsonb,

    is_deleted               BOOLEAN NOT NULL DEFAULT FALSE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by               UUID,

    -- attribute_definitions must be a JSON array — guards against the
    -- service accidentally writing an object or scalar through Jackson.
    CONSTRAINT chk_item_group_attr_defs_array
        CHECK (jsonb_typeof(attribute_definitions) = 'array')
);

-- Two groups in the same org cannot share a name — the picker uses
-- name as the user-facing identifier, so a duplicate would be
-- ambiguous. Partial index ignores soft-deleted rows so a removed
-- group's name can be reused.
CREATE UNIQUE INDEX idx_item_group_org_name
    ON item_group(org_id, lower(name))
    WHERE NOT is_deleted;

CREATE INDEX idx_item_group_org
    ON item_group(org_id) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Extend item with the variant link
--
-- Both columns are nullable and default to NULL/{} so every existing
-- item stays as it was. No back-fill.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE item
    ADD COLUMN group_id           UUID REFERENCES item_group(id),
    ADD COLUMN variant_attributes JSONB NOT NULL DEFAULT '{}'::jsonb;

-- The hard rule from the F5 design: an item linked to a group MUST
-- carry a non-empty attribute map. Without this constraint a UI bug
-- could create "ghost" variants that share no distinguishing data,
-- and the unique index below would let a second one slip through if
-- both had {}.
ALTER TABLE item
    ADD CONSTRAINT chk_item_variant_attrs_not_empty
    CHECK (
        group_id IS NULL
        OR (variant_attributes IS NOT NULL
            AND jsonb_typeof(variant_attributes) = 'object'
            AND variant_attributes <> '{}'::jsonb)
    );

-- Within one group, every (key,value...) combination is unique.
-- Postgres compares jsonb structurally, so {"size":"M","color":"Red"}
-- and {"color":"Red","size":"M"} are equal — exactly what we want.
-- Partial index ignores soft-deleted variants so a removed combo can
-- be re-added.
CREATE UNIQUE INDEX idx_item_group_variant_unique
    ON item(group_id, variant_attributes)
    WHERE group_id IS NOT NULL AND NOT is_deleted;

-- Group detail screens list variants by group; this is the hot path.
CREATE INDEX idx_item_group_id
    ON item(group_id) WHERE group_id IS NOT NULL AND NOT is_deleted;
