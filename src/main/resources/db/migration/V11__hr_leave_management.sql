-- ============================================================================
-- V11: HR portal — Leave Management (Time off). Module 1 of Core HR.
--
-- Production leave: configurable leave types (paid/unpaid, quota, accrual,
-- carry-forward), an org holiday calendar, per-employee yearly balances, and
-- balance-aware apply/approve. The existing leave_request row is reused (so the
-- payroll LOP path keeps working) and gains a typed link + working-day count.
-- ============================================================================

CREATE TABLE public.hr_leave_type (
    id                uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id            uuid NOT NULL,
    code              character varying(20) NOT NULL,
    name              character varying(100) NOT NULL,
    is_paid           boolean DEFAULT true NOT NULL,
    annual_quota      numeric(6,1) DEFAULT 0 NOT NULL,
    accrual_method    character varying(10) DEFAULT 'ANNUAL' NOT NULL,   -- ANNUAL | MONTHLY | NONE
    carry_forward_max numeric(6,1) DEFAULT 0 NOT NULL,
    requires_approval boolean DEFAULT true NOT NULL,
    is_active         boolean DEFAULT true NOT NULL,
    is_deleted        boolean DEFAULT false NOT NULL,
    created_at        timestamp with time zone DEFAULT now() NOT NULL,
    updated_at        timestamp with time zone DEFAULT now() NOT NULL,
    created_by        uuid,
    CONSTRAINT hr_leave_type_pkey PRIMARY KEY (id),
    CONSTRAINT hr_leave_type_accrual_check CHECK (accrual_method IN ('ANNUAL', 'MONTHLY', 'NONE'))
);
CREATE UNIQUE INDEX uq_hr_leave_type_code ON public.hr_leave_type (org_id, code) WHERE is_deleted = false;

CREATE TABLE public.hr_holiday (
    id           uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id       uuid NOT NULL,
    holiday_date date NOT NULL,
    name         character varying(120) NOT NULL,
    is_optional  boolean DEFAULT false NOT NULL,
    is_deleted   boolean DEFAULT false NOT NULL,
    created_at   timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_holiday_pkey PRIMARY KEY (id)
);
CREATE UNIQUE INDEX uq_hr_holiday_date ON public.hr_holiday (org_id, holiday_date) WHERE is_deleted = false;

CREATE TABLE public.hr_leave_balance (
    id               uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id           uuid NOT NULL,
    user_id          uuid NOT NULL,
    leave_type_id    uuid NOT NULL,
    year             integer NOT NULL,
    entitled         numeric(6,1) DEFAULT 0 NOT NULL,
    carried_forward  numeric(6,1) DEFAULT 0 NOT NULL,
    used             numeric(6,1) DEFAULT 0 NOT NULL,
    is_deleted       boolean DEFAULT false NOT NULL,
    created_at       timestamp with time zone DEFAULT now() NOT NULL,
    updated_at       timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_leave_balance_pkey PRIMARY KEY (id)
);
CREATE UNIQUE INDEX uq_hr_leave_balance ON public.hr_leave_balance (org_id, user_id, leave_type_id, year) WHERE is_deleted = false;

-- Typed link + working-day count on the existing request row.
ALTER TABLE public.leave_request ADD COLUMN IF NOT EXISTS leave_type_id uuid;
ALTER TABLE public.leave_request ADD COLUMN IF NOT EXISTS working_days numeric(6,1);
