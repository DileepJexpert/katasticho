-- ============================================================================
-- V8: Field reporting hierarchy.
--
-- Adds a self-referencing reporting-manager link to app_user so the field force
-- can be organised as a tree (MR -> ABM -> RBM -> ZBM -> ...). Powers
-- manager-based approvals (a submitter's manager can approve their tour plans /
-- DCRs, not just OWNER/ADMIN) and downline-scoped rollup reporting.
--
-- Nullable: top-of-tree users (and non-field staff) simply have no manager.
-- ============================================================================

ALTER TABLE public.app_user ADD COLUMN IF NOT EXISTS reports_to_user_id uuid;

CREATE INDEX IF NOT EXISTS idx_app_user_reports_to
    ON public.app_user (org_id, reports_to_user_id);
