-- ============================================================================
-- V27: Pharma Batch Manufacturing Record (BMR).
--
-- Schedule M / CDSCO / WHO-GMP compliance requires a per-batch BMR
-- document capturing every step of manufacture, in-process check
-- records, operator + supervisor sign-offs, deviations from the
-- master formula, and yield reconciliation.
--
-- We sit BMR on top of the existing WorkOrder + JobCard machinery:
--   - work_order  = one batch
--   - job_card    = one operation step inside the batch
--   - This migration adds three companion tables:
--       bmr_step_record  — per-step parameter readings (temp, pH, etc.)
--       bmr_signoff      — operator/supervisor/QA signatures
--       bmr_deviation    — exception log against the master formula
--
-- yield reconciliation is computed read-only from
-- WorkOrder.quantityToProduce vs quantityProduced — no separate table.
-- ============================================================================

CREATE TABLE public.bmr_step_record (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    work_order_id       uuid NOT NULL,
    job_card_id         uuid,         -- nullable: WO-level parameter, not tied to a step
    parameter_key       varchar(100) NOT NULL,
    parameter_value     varchar(200) NOT NULL,
    unit                varchar(20),
    observed_at         timestamptz DEFAULT now() NOT NULL,
    observed_by         uuid,
    notes               text,
    created_at          timestamptz DEFAULT now() NOT NULL,
    created_by          uuid,
    updated_at          timestamptz DEFAULT now() NOT NULL,
    updated_by          uuid,
    is_deleted          boolean DEFAULT false NOT NULL
);

ALTER TABLE ONLY public.bmr_step_record
    ADD CONSTRAINT bmr_step_record_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.bmr_step_record
    ADD CONSTRAINT bmr_step_record_wo_fkey
        FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);

CREATE INDEX idx_bmr_step_record_wo
    ON public.bmr_step_record (org_id, work_order_id)
    WHERE is_deleted = false;

CREATE INDEX idx_bmr_step_record_jc
    ON public.bmr_step_record (org_id, job_card_id)
    WHERE is_deleted = false AND job_card_id IS NOT NULL;

CREATE TABLE public.bmr_signoff (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    work_order_id       uuid NOT NULL,
    job_card_id         uuid,         -- nullable: WO-level signoff (e.g., QA release)
    role                varchar(20) NOT NULL,
    signed_by           uuid NOT NULL,
    signed_at           timestamptz DEFAULT now() NOT NULL,
    notes               text,
    created_at          timestamptz DEFAULT now() NOT NULL,
    created_by          uuid,
    updated_at          timestamptz DEFAULT now() NOT NULL,
    updated_by          uuid,
    is_deleted          boolean DEFAULT false NOT NULL,
    CONSTRAINT bmr_signoff_role_chk
        CHECK (role IN ('OPERATOR', 'SUPERVISOR', 'QA', 'QC'))
);

ALTER TABLE ONLY public.bmr_signoff
    ADD CONSTRAINT bmr_signoff_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.bmr_signoff
    ADD CONSTRAINT bmr_signoff_wo_fkey
        FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);

CREATE INDEX idx_bmr_signoff_wo
    ON public.bmr_signoff (org_id, work_order_id)
    WHERE is_deleted = false;

-- One signoff per (wo, jc or NULL-wo-level, role, user). A
-- supervisor can sign a JC once per role; re-signoff is the
-- service-layer's job.
CREATE UNIQUE INDEX idx_bmr_signoff_unique
    ON public.bmr_signoff (org_id, work_order_id,
                           COALESCE(job_card_id, '00000000-0000-0000-0000-000000000000'),
                           role, signed_by)
    WHERE is_deleted = false;

CREATE TABLE public.bmr_deviation (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    work_order_id       uuid NOT NULL,
    job_card_id         uuid,
    severity            varchar(20) NOT NULL,
    title               varchar(200) NOT NULL,
    description         text,
    reported_by         uuid,
    reported_at         timestamptz DEFAULT now() NOT NULL,
    status              varchar(20) DEFAULT 'OPEN' NOT NULL,
    resolution          text,
    resolved_by         uuid,
    resolved_at         timestamptz,
    created_at          timestamptz DEFAULT now() NOT NULL,
    created_by          uuid,
    updated_at          timestamptz DEFAULT now() NOT NULL,
    updated_by          uuid,
    is_deleted          boolean DEFAULT false NOT NULL,
    CONSTRAINT bmr_deviation_severity_chk
        CHECK (severity IN ('MINOR', 'MAJOR', 'CRITICAL')),
    CONSTRAINT bmr_deviation_status_chk
        CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'ACCEPTED'))
);

ALTER TABLE ONLY public.bmr_deviation
    ADD CONSTRAINT bmr_deviation_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.bmr_deviation
    ADD CONSTRAINT bmr_deviation_wo_fkey
        FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);

CREATE INDEX idx_bmr_deviation_wo
    ON public.bmr_deviation (org_id, work_order_id)
    WHERE is_deleted = false;

CREATE INDEX idx_bmr_deviation_open
    ON public.bmr_deviation (org_id, status)
    WHERE is_deleted = false AND status IN ('OPEN', 'INVESTIGATING');
