-- ============================================================================
-- V22: Linked / dependent work orders (manufacturing tracker #60).
--
-- When a finished good's BOM contains another COMPOSITE item (a sub-
-- assembly that we manufacture in-house rather than purchase), the
-- planner used to manually create a separate WO for each sub-assembly.
-- We now record the parent→child relationship explicitly so the
-- system can auto-spawn child WOs and so completion of children can
-- gate the parent.
--
-- parent_work_order_id is nullable — top-level WOs (the ones a
-- planner kicks off directly, or that the SO→WO + reorder-sweep
-- automations create) carry NULL, which is the existing default.
-- ============================================================================

ALTER TABLE public.work_order
    ADD COLUMN parent_work_order_id uuid;

CREATE INDEX idx_work_order_parent_wo
    ON public.work_order (org_id, parent_work_order_id)
    WHERE parent_work_order_id IS NOT NULL AND is_deleted = false;
