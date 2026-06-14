-- ============================================================================
-- V13: HR portal — Shift management. Module 3 of Core HR.
--
-- Shift definitions (timings + weekly offs) and per-employee shift assignments
-- over date ranges, so attendance can be evaluated against the right shift.
-- ============================================================================

CREATE TABLE public.hr_shift (
    id          uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id      uuid NOT NULL,
    code        character varying(20) NOT NULL,
    name        character varying(100) NOT NULL,
    start_time  time NOT NULL,
    end_time    time NOT NULL,
    weekly_offs character varying(40) DEFAULT 'SAT,SUN',   -- comma list of day codes
    is_active   boolean DEFAULT true NOT NULL,
    is_deleted  boolean DEFAULT false NOT NULL,
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at  timestamp with time zone DEFAULT now() NOT NULL,
    created_by  uuid,
    CONSTRAINT hr_shift_pkey PRIMARY KEY (id)
);
CREATE UNIQUE INDEX uq_hr_shift_code ON public.hr_shift (org_id, code) WHERE is_deleted = false;

CREATE TABLE public.hr_shift_assignment (
    id             uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id         uuid NOT NULL,
    user_id        uuid NOT NULL,
    shift_id       uuid NOT NULL,
    effective_from date NOT NULL,
    effective_to   date,                                   -- null = open-ended (current)
    is_deleted     boolean DEFAULT false NOT NULL,
    created_at     timestamp with time zone DEFAULT now() NOT NULL,
    updated_at     timestamp with time zone DEFAULT now() NOT NULL,
    created_by     uuid,
    CONSTRAINT hr_shift_assignment_pkey PRIMARY KEY (id)
);
CREATE INDEX idx_hr_shift_assign_user ON public.hr_shift_assignment (org_id, user_id, effective_from);
