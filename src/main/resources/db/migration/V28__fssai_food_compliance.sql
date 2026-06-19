-- ============================================================================
-- V28: FSSAI / Food Safety compliance pack.
--
-- The Food Safety and Standards Authority of India (FSSAI) requires
-- every Food Business Operator (FBO) to declare:
--   - their FBO license number (14-digit, on every label)
--   - veg / non-veg / vegan / egg classification (with the
--     mandatory green/red dot or triangle marking on packaging)
--   - the 8 major allergens called out by Codex / FSSAI labelling
--     regulations 2020 (milk, eggs, fish, crustaceans, tree nuts,
--     peanuts, wheat/gluten, soy, plus mustard / sesame / sulphites
--     added under FSSAI 2.2.2.4)
--   - nutritional information per 100g / 100ml / serving
--   - date marking: BEST_BEFORE vs USE_BY vs EXPIRY (3 different
--     legal meanings under FSSAI 2.4.4)
--   - shelf-life in days, so MFG date + shelf_life = expiry date
--
-- The license + expiry live on Organisation (FBO is at facility
-- level). All the rest live on Item (each SKU has its own
-- allergen profile and nutritional info).
-- ============================================================================

ALTER TABLE public.organisation
    ADD COLUMN fssai_license          varchar(20);

ALTER TABLE public.organisation
    ADD COLUMN fssai_license_expiry   date;

ALTER TABLE public.item
    ADD COLUMN fssai_license          varchar(20);

ALTER TABLE public.item
    ADD COLUMN veg_classification     varchar(20);

ALTER TABLE public.item
    ADD CONSTRAINT item_veg_classification_chk
        CHECK (veg_classification IS NULL
               OR veg_classification IN ('VEGETARIAN', 'NON_VEGETARIAN', 'VEGAN', 'EGG'));

-- Allergens stored as a JSONB array of upper-case codes drawn from
-- the FSSAI / Codex labelling list. Empty array = explicitly NONE,
-- NULL = not yet declared.
ALTER TABLE public.item
    ADD COLUMN allergens              jsonb;

ALTER TABLE public.item
    ADD COLUMN nutritional_info       jsonb;

ALTER TABLE public.item
    ADD COLUMN date_marking_type      varchar(20);

ALTER TABLE public.item
    ADD CONSTRAINT item_date_marking_type_chk
        CHECK (date_marking_type IS NULL
               OR date_marking_type IN ('BEST_BEFORE', 'USE_BY', 'EXPIRY'));

ALTER TABLE public.item
    ADD COLUMN shelf_life_days        integer;

ALTER TABLE public.item
    ADD CONSTRAINT item_shelf_life_days_chk
        CHECK (shelf_life_days IS NULL OR shelf_life_days > 0);

-- GIN index on allergens so the allergen-exposure report ("every
-- item containing peanut") runs in milliseconds even with 100k
-- items.
CREATE INDEX idx_item_allergens
    ON public.item USING gin (allergens)
    WHERE allergens IS NOT NULL AND is_deleted = false;
