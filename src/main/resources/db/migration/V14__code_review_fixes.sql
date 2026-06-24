-- ─────────────────────────────────────────────────────────────────────────────
-- V14 — Code review fixes (2026-06-23).
--
-- Schema support for the backend code-review pass:
--   (a) Supplier ↔ Contact FK so PO/bill/rate-contract pricing no longer
--       relies on display-name string matching.
--   (b) Supplier rate contract line: denormalised supplier_contact_id +
--       is_active_line flag so the DB can enforce "one active rate per
--       (org, supplier, item)" via a partial unique index instead of an
--       application-side guard with a race window.
--   (c) stock_movement.cost_settled_by_grn_id back-pointer so a GRN cancel
--       can find the SALE movements its reconciliation settled, reverse the
--       correction journal, and clear the stamps so the next GRN reconciles
--       again. The append-only trigger
--       (prevent_stock_movement_mutation) only guards
--       quantity/unit_cost/total_cost/movement_type/movement_date/item_id/
--       warehouse_id/org_id, so this new nullable column is mutable just like
--       cost_settled_at.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── (a) Supplier ↔ Contact bridge ───────────────────────────────────────────
ALTER TABLE public.supplier
    ADD COLUMN IF NOT EXISTS contact_id UUID;

-- Best-effort backfill: per-org case-insensitive name match.
UPDATE public.supplier s
SET contact_id = sub.contact_id
FROM (
    SELECT DISTINCT ON (c.org_id, LOWER(c.display_name)) c.org_id, LOWER(c.display_name) AS dn, c.id AS contact_id
    FROM public.contact c
    WHERE c.is_deleted = FALSE
    ORDER BY c.org_id, LOWER(c.display_name), c.created_at ASC
) sub
WHERE s.contact_id IS NULL
  AND s.org_id = sub.org_id
  AND LOWER(s.name) = sub.dn;

CREATE INDEX IF NOT EXISTS idx_supplier_contact
    ON public.supplier (org_id, contact_id) WHERE is_deleted = FALSE;

-- ── (b) Rate contract line: denormalise supplier_contact_id + active flag ──
ALTER TABLE public.supplier_rate_contract_line
    ADD COLUMN IF NOT EXISTS supplier_contact_id UUID;

ALTER TABLE public.supplier_rate_contract_line
    ADD COLUMN IF NOT EXISTS is_active_line BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: copy supplier_contact_id from parent header; flip is_active_line
-- true for lines whose parent contract is currently ACTIVE.
UPDATE public.supplier_rate_contract_line l
SET supplier_contact_id = c.supplier_contact_id,
    is_active_line      = (c.status = 'ACTIVE')
FROM public.supplier_rate_contract c
WHERE c.id = l.supplier_rate_contract_id
  AND l.supplier_contact_id IS NULL;

-- DB-enforced "one active rate per (org, supplier, item)" — closes the race
-- window between two concurrent activate() calls.
CREATE UNIQUE INDEX IF NOT EXISTS uq_src_active_line
    ON public.supplier_rate_contract_line (org_id, supplier_contact_id, item_id)
    WHERE is_active_line = TRUE AND is_deleted = FALSE;

-- ── (c) Reconciliation back-pointer on stock_movement ───────────────────────
ALTER TABLE public.stock_movement
    ADD COLUMN IF NOT EXISTS cost_settled_by_grn_id UUID;

-- Indexed only for the (rare) GRN-cancel sweep — keep the index partial so
-- the hot insert path on stock_movement stays cheap.
CREATE INDEX IF NOT EXISTS idx_stock_movement_settled_by_grn
    ON public.stock_movement (cost_settled_by_grn_id)
    WHERE cost_settled_by_grn_id IS NOT NULL;
