-- V6: IMS (Invoice Management System) action loop on gstr2b_entry.
--
-- Under amended Sec 38 of the CGST Act (effective 1 Oct 2025), the recipient
-- must Accept / Reject / keep Pending every inward invoice that lands in
-- IMS. Unactioned rows are "deemed accepted" into GSTR-2B — silent ITC
-- exposure unless the recipient actively reviews each one.
--
-- We extend gstr2b_entry (the row already represents one inward invoice from
-- the supplier's GSTR-1 / IMS) with the IMS lifecycle. No fork — the same
-- row carries both the bookside match status AND the portal-side action.

ALTER TABLE public.gstr2b_entry
    ADD COLUMN ims_action       varchar(20),
    ADD COLUMN ims_action_at    timestamptz,
    ADD COLUMN ims_action_by    uuid,
    ADD COLUMN ims_remarks      text,
    -- AI's suggested action + reason (ACCEPT/REJECT/PENDING + why); the
    -- human still has to apply it via the action loop. Lets us track
    -- recommendation-acceptance rate over time.
    ADD COLUMN ims_ai_recommendation varchar(20),
    ADD COLUMN ims_ai_reason         text;

ALTER TABLE public.gstr2b_entry
    ADD CONSTRAINT gstr2b_entry_ims_action_check
        CHECK (ims_action IS NULL OR ims_action IN ('ACCEPT', 'REJECT', 'PENDING'));

ALTER TABLE public.gstr2b_entry
    ADD CONSTRAINT gstr2b_entry_ims_ai_check
        CHECK (ims_ai_recommendation IS NULL OR ims_ai_recommendation IN ('ACCEPT', 'REJECT', 'PENDING'));

-- Partial index for "no action yet" rows — the deemed-accepted risk surface.
CREATE INDEX idx_gstr2b_no_action
    ON public.gstr2b_entry (org_id, return_period)
    WHERE ims_action IS NULL;
