-- ============================================================================
-- V13: Unit of Measure (UoM) foundation — Sprint 26 (v2 Feature 1)
--
-- Why first in the v2 expansion:
--   Every downstream v2 feature (BOM, variants, price lists, stock counts,
--   batch tracking) records quantities. If UoM lands later, we retrofit a
--   uom_id column onto every one of those tables. By introducing the UoM
--   data model BEFORE those features ship, every new table can reference
--   uom_id from day one and we never do a bulk backfill.
--
-- What this migration does:
--   1. Creates the `uom` master (org-scoped) with a UoM category
--      (WEIGHT / VOLUME / COUNT / LENGTH / PACKAGING).
--   2. Seeds a common set of default UoMs for every existing organisation
--      (PCS, BOX, STRIP, PACK, BOTTLE, BAG, KG, GM, LTR, ML).
--   3. Creates `uom_conversion` for multi-UoM support:
--        - Org-wide conversions (item_id NULL) e.g. 1 KG = 1000 GM
--        - Per-item conversions (item_id set) e.g. 1 BOX of Paracetamol = 10 STRIP
--      Seeds the org-wide WEIGHT/VOLUME conversions.
--   4. Adds `item.base_uom_id` FK (nullable for now) and backfills it from
--      the existing `unit_of_measure` string column for every existing item.
--      The string column is retained for backwards compatibility — nothing
--      in the service layer needs to change immediately.
--
-- What this migration does NOT do:
--   - It does NOT make `base_uom_id` NOT NULL. Existing code still writes
--     items via the string column; service layer will populate the FK on
--     create/update going forward. A follow-up migration can enforce NOT
--     NULL once every orchestration path is verified.
--   - It does NOT rewrite any stock_movement, invoice_line, or
--     stock_receipt_line quantities. Those remain in the item's base UoM
--     as they always have.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. UoM master
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE uom (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL REFERENCES organisation(id),
    name          VARCHAR(50)  NOT NULL,            -- "Kilogram"
    abbreviation  VARCHAR(20)  NOT NULL,            -- "KG"
    category      VARCHAR(20)  NOT NULL             -- WEIGHT / VOLUME / COUNT / LENGTH / PACKAGING
                  CHECK (category IN ('WEIGHT','VOLUME','COUNT','LENGTH','PACKAGING')),
    is_base       BOOLEAN      NOT NULL DEFAULT FALSE,  -- the canonical UoM of its category (e.g. KG for WEIGHT)
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    UUID
);

CREATE UNIQUE INDEX idx_uom_org_abbr ON uom(org_id, abbreviation) WHERE NOT is_deleted;
CREATE INDEX idx_uom_org_category   ON uom(org_id, category)    WHERE NOT is_deleted;
CREATE INDEX idx_uom_org_active     ON uom(org_id, is_active)   WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. UoM conversion
--
-- Two kinds of rows are allowed:
--   a. Org-wide conversion: item_id IS NULL. Applies to every item that
--      uses the (from_uom_id, to_uom_id) pair. Example: 1 KG = 1000 GM.
--   b. Per-item conversion: item_id IS NOT NULL. Overrides the org-wide
--      rule for one specific item. Example: 1 BOX of "Paracetamol 500mg"
--      = 10 STRIP. Different items can have different pack sizes.
--
-- Resolution rule (UomService.convert): per-item override wins over org-wide;
-- identity (same UoM) is always factor = 1; otherwise throw.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE uom_conversion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    item_id         UUID REFERENCES item(id),      -- NULL = org-wide
    from_uom_id     UUID NOT NULL REFERENCES uom(id),
    to_uom_id       UUID NOT NULL REFERENCES uom(id),
    factor          NUMERIC(18,6) NOT NULL
                    CHECK (factor > 0),
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID,
    CONSTRAINT uom_conversion_not_self CHECK (from_uom_id <> to_uom_id)
);

-- Org-wide uniqueness: only one row per (org, from, to, NULL item)
CREATE UNIQUE INDEX idx_uom_conv_org_wide
    ON uom_conversion(org_id, from_uom_id, to_uom_id)
    WHERE item_id IS NULL AND NOT is_deleted;

-- Per-item uniqueness: only one row per (org, item, from, to)
CREATE UNIQUE INDEX idx_uom_conv_per_item
    ON uom_conversion(org_id, item_id, from_uom_id, to_uom_id)
    WHERE item_id IS NOT NULL AND NOT is_deleted;

CREATE INDEX idx_uom_conv_org ON uom_conversion(org_id) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Seed default UoMs for every existing organisation
--
-- Runs as a PL/pgSQL block so we can loop over organisations without
-- requiring application-level seeding. New organisations created AFTER
-- this migration get their defaults from OrganisationService (follow-up).
-- ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    org RECORD;
    v_pcs    UUID;
    v_box    UUID;
    v_strip  UUID;
    v_pack   UUID;
    v_bottle UUID;
    v_bag    UUID;
    v_kg     UUID;
    v_gm     UUID;
    v_ltr    UUID;
    v_ml     UUID;
BEGIN
    FOR org IN SELECT id FROM organisation LOOP

        -- COUNT / PACKAGING category
        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Pieces',  'PCS',    'COUNT',     TRUE)  RETURNING id INTO v_pcs;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Box',     'BOX',    'PACKAGING', FALSE) RETURNING id INTO v_box;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Strip',   'STRIP',  'PACKAGING', FALSE) RETURNING id INTO v_strip;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Pack',    'PACK',   'PACKAGING', FALSE) RETURNING id INTO v_pack;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Bottle',  'BOTTLE', 'PACKAGING', FALSE) RETURNING id INTO v_bottle;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Bag',     'BAG',    'PACKAGING', FALSE) RETURNING id INTO v_bag;

        -- WEIGHT
        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Kilogram', 'KG',    'WEIGHT', TRUE)  RETURNING id INTO v_kg;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Gram',     'GM',    'WEIGHT', FALSE) RETURNING id INTO v_gm;

        -- VOLUME
        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Litre',      'LTR', 'VOLUME', TRUE)  RETURNING id INTO v_ltr;

        INSERT INTO uom (org_id, name, abbreviation, category, is_base)
        VALUES (org.id, 'Millilitre', 'ML',  'VOLUME', FALSE) RETURNING id INTO v_ml;

        -- Seed org-wide conversions (both directions so lookups are symmetric)
        -- WEIGHT: 1 KG = 1000 GM
        INSERT INTO uom_conversion (org_id, from_uom_id, to_uom_id, factor)
            VALUES (org.id, v_kg, v_gm, 1000);
        INSERT INTO uom_conversion (org_id, from_uom_id, to_uom_id, factor)
            VALUES (org.id, v_gm, v_kg, 0.001);

        -- VOLUME: 1 LTR = 1000 ML
        INSERT INTO uom_conversion (org_id, from_uom_id, to_uom_id, factor)
            VALUES (org.id, v_ltr, v_ml, 1000);
        INSERT INTO uom_conversion (org_id, from_uom_id, to_uom_id, factor)
            VALUES (org.id, v_ml, v_ltr, 0.001);

    END LOOP;
END $$;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Link item to its base UoM
--
-- We add the column as NULLABLE and backfill from unit_of_measure. The
-- service layer populates it going forward. A follow-up migration can
-- enforce NOT NULL once we are certain every create path sets it.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE item
    ADD COLUMN base_uom_id UUID REFERENCES uom(id);

CREATE INDEX idx_item_base_uom ON item(base_uom_id) WHERE base_uom_id IS NOT NULL;

-- Backfill: match item.unit_of_measure (case-insensitive, trimmed) to the
-- newly seeded uom.abbreviation for the item's own org.
UPDATE item i
SET    base_uom_id = u.id
FROM   uom u
WHERE  u.org_id       = i.org_id
  AND  UPPER(TRIM(u.abbreviation)) = UPPER(TRIM(i.unit_of_measure))
  AND  NOT u.is_deleted
  AND  i.base_uom_id IS NULL;

-- Any item whose unit_of_measure string doesn't match a seeded UoM keeps
-- base_uom_id = NULL. The service layer will fall back to PCS for these
-- on next update. We log them here so operators can investigate.
DO $$
DECLARE
    unmatched INT;
BEGIN
    SELECT COUNT(*) INTO unmatched
      FROM item
     WHERE base_uom_id IS NULL
       AND NOT is_deleted;
    IF unmatched > 0 THEN
        RAISE NOTICE 'V13: % item row(s) have unit_of_measure strings that did not match any seeded UoM abbreviation. They will be assigned PCS on next item update.', unmatched;
    END IF;
END $$;
