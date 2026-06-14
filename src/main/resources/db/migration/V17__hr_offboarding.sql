-- ============================================================================
-- V17: HR portal — Offboarding. Module 9 of Core HR (final module).
--
-- Exit/resignation flow: initiate -> work a clearance checklist (IT/Finance/
-- HR/Admin) -> settle full-and-final -> complete (marks the employee EXITED).
-- ============================================================================

CREATE TABLE public.hr_offboarding (
    id                uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id            uuid NOT NULL,
    employee_user_id  uuid NOT NULL,
    initiated_by      uuid,
    resignation_date  date,
    last_working_day  date,
    reason            text,
    status            character varying(20) DEFAULT 'INITIATED' NOT NULL,  -- INITIATED|COMPLETED|CANCELLED
    fnf_amount        numeric(15,2),
    fnf_settled       boolean DEFAULT false NOT NULL,
    notes             text,
    is_deleted        boolean DEFAULT false NOT NULL,
    created_at        timestamp with time zone DEFAULT now() NOT NULL,
    updated_at        timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_offboarding_pkey PRIMARY KEY (id),
    CONSTRAINT hr_offboarding_status_check CHECK (status IN ('INITIATED', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX idx_hr_offboarding_emp ON public.hr_offboarding (org_id, employee_user_id);
CREATE INDEX idx_hr_offboarding_status ON public.hr_offboarding (org_id, status);

CREATE TABLE public.hr_offboarding_task (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id          uuid NOT NULL,
    offboarding_id  uuid NOT NULL,
    label           character varying(200) NOT NULL,
    category        character varying(20) DEFAULT 'OTHER' NOT NULL,        -- IT|FINANCE|HR|ADMIN|OTHER
    completed       boolean DEFAULT false NOT NULL,
    completed_by    uuid,
    completed_at    timestamp with time zone,
    is_deleted      boolean DEFAULT false NOT NULL,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_offboarding_task_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_hr_offb_task ON public.hr_offboarding_task (org_id, offboarding_id);
