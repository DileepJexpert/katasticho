-- ============================================================================
-- V14: HR portal — Timesheets. Module 4 of Core HR.
--
-- Per-day time logs against a project/task with a submit/approve lifecycle and
-- billable flag, so worked hours can be reviewed and (optionally) billed.
-- ============================================================================

CREATE TABLE public.hr_timesheet_entry (
    id               uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id           uuid NOT NULL,
    user_id          uuid NOT NULL,
    work_date        date NOT NULL,
    project          character varying(150),
    task             character varying(200),
    hours            numeric(5,2) DEFAULT 0 NOT NULL,
    billable         boolean DEFAULT false NOT NULL,
    notes            text,
    status           character varying(20) DEFAULT 'DRAFT' NOT NULL,   -- DRAFT|SUBMITTED|APPROVED|REJECTED
    approved_by      uuid,
    decided_at       timestamp with time zone,
    rejection_reason character varying(300),
    is_deleted       boolean DEFAULT false NOT NULL,
    created_at       timestamp with time zone DEFAULT now() NOT NULL,
    updated_at       timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_timesheet_entry_pkey PRIMARY KEY (id),
    CONSTRAINT hr_timesheet_hours_check CHECK (hours >= 0 AND hours <= 24)
);

CREATE INDEX idx_hr_timesheet_user ON public.hr_timesheet_entry (org_id, user_id, work_date);
CREATE INDEX idx_hr_timesheet_status ON public.hr_timesheet_entry (org_id, status);
