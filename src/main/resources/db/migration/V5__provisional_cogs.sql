-- ─────────────────────────────────────────────────────────────────────────────
-- V5 — Provisional COGS at sale + true-up at GRN ("bill-freely" hole fix).
--
-- THE HOLE: when bill-freely is on, the POS counter can sell an item before
-- its purchase price is known. Pre-fix:
--   AccountingPostingEngine.postPosReceipt skipped the COGS journal line
--   entirely when item.purchasePrice was 0/null. Net effect: revenue booked
--   at full ₹X, COGS booked at ₹0, inventory asset did NOT decrement. When
--   the GRN finally arrived it booked DR Inventory / CR AP — but the missing
--   COGS was never retroactively booked. Profit overstated forever.
--
-- THE FIX (Option B):
--   1. At sale time, resolve a PROVISIONAL unit cost from MRP × (1 − margin)
--      or salePrice × (1 − margin), book DR COGS / CR Stock-Out Suspense
--      (a liability placeholder, code 2042). Mark each such stock_movement
--      with cost_provisional=true so the reconciler can find it later.
--   2. At GRN time (PURCHASE movement), the reconciler walks unsettled
--      provisional SALE movements for that item, posts a correction journal:
--        DR Stock-Out Suspense  (close the placeholder)
--        CR Inventory           (real consumption at the now-known cost)
--        DR/CR COGS             (the variance — actual vs provisional)
--      and stamps each settled movement with cost_settled_at = now.
--
-- The append-only stock_movement contract is preserved:
--   - cost_provisional is set at INSERT and never mutates (updatable=false)
--   - cost_settled_at IS the one mutation allowed (and only NULL → timestamp)
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Stock-movement metadata for the provisional / settled lifecycle.
ALTER TABLE public.stock_movement
    ADD COLUMN IF NOT EXISTS cost_provisional BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.stock_movement
    ADD COLUMN IF NOT EXISTS cost_settled_at TIMESTAMPTZ NULL;

-- 2. Hot path: the reconciler hits this exact predicate on every GRN per item.
CREATE INDEX IF NOT EXISTS idx_stock_movement_unsettled_provisional
    ON public.stock_movement (org_id, item_id)
    WHERE cost_provisional = TRUE
      AND cost_settled_at IS NULL;

-- 3. Seed code 2042 'Stock-Out Suspense' (LIABILITY) into the coa_template for
--    every (country, industry) combination that already has a 2031 row (the
--    canonical "every full-statutory CoA" tag). This catches India's RETAIL /
--    TRADING / SERVICES / F_AND_B at country 'IN' and any future country that
--    seeds a 2031 row. Gulf 'AE' templates don't have 2031 (no TCS in UAE) so
--    we add Suspense to them separately by code+country pair below.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT
    country,
    industry,
    '2042',
    'Stock-Out Suspense',
    'LIABILITY',
    'CURRENT_LIABILITY',
    '2000',
    2,
    TRUE
FROM public.coa_template
WHERE code = '2031'
ON CONFLICT (country, industry, code) DO NOTHING;

-- 4. Gulf 'AE' TRADING template has no 2031 (no TCS in UAE) — add Suspense
--    there too so AE orgs can run bill-freely without missing the GL.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
VALUES ('AE', 'TRADING', '2042', 'Stock-Out Suspense', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, TRUE)
ON CONFLICT (country, industry, code) DO NOTHING;
