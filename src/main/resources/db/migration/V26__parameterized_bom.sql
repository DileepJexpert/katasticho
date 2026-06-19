-- ============================================================================
-- V26: Parameterized BOMs (manufacturing tracker #42).
--
-- A garment "T-Shirt" sold in 5 sizes × 4 colors becomes 20 variant
-- Items today, each carrying its own complete BOM — even though
-- most lines (cotton fabric, thread, label) are identical and only a
-- handful (size-specific pattern card, color-specific dye) actually
-- differ by attribute. Maintaining 20 parallel BOMs and keeping them
-- in sync is the pain.
--
-- bom_component now carries a nullable variant_filter JSONB. When
-- non-null, the line ONLY applies to variants whose variantAttributes
-- satisfy every key=value pair in the filter. NULL = applies to all
-- variants (the legacy/default behaviour — every existing BOM row
-- keeps applying).
--
-- Example (parent = T-Shirt template):
--   line A: Cotton fabric, qty 1.5m,            variant_filter NULL
--   line B: Red dye,       qty 20ml,            variant_filter {"color":"Red"}
--   line C: Size-S pattern,qty 1,               variant_filter {"size":"S"}
--   line D: Size-M pattern,qty 1,               variant_filter {"size":"M"}
--
-- The resolver returns A + B + D for variant {"size":"M","color":"Red"}.
-- ============================================================================

ALTER TABLE public.bom_component
    ADD COLUMN variant_filter jsonb;

-- Partial index — only the rows with a filter at all. Most BOM lines
-- will stay NULL, so the index stays small.
CREATE INDEX idx_bom_component_variant_filter
    ON public.bom_component USING gin (variant_filter)
    WHERE variant_filter IS NOT NULL AND is_deleted = false;
