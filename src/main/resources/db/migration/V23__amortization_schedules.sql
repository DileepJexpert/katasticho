-- ============================================================================
-- V23: Recurring amortization schedules (prepaids / deferred income / accruals).
--
-- A fixed amount spread over N periods, posting one journal per period
-- (DR debit_account / CR credit_account for the period amount). Covers:
--   * PREPAID         — prepaid expense drawn down to expense
--   * DEFERRED_INCOME — unearned revenue recognised to income
--   * ACCRUAL         — expense accrued over time to a liability
-- The accounts carry the meaning; the engine just posts the per-period amount.
-- ============================================================================

CREATE TABLE public.amortization_schedule (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    schedule_type       character varying(20) NOT NULL,    -- PREPAID | DEFERRED_INCOME | ACCRUAL
    description         character varying(200) NOT NULL,
    reference           character varying(60),
    total_amount        numeric(18,2) NOT NULL,
    start_year          integer NOT NULL,
    start_month         integer NOT NULL,
    number_of_periods   integer NOT NULL,
    debit_account_code  character varying(20) NOT NULL,
    credit_account_code character varying(20) NOT NULL,
    recognized_amount   numeric(18,2) DEFAULT 0 NOT NULL,
    status              character varying(20) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE | COMPLETED | CANCELLED
    source_module       character varying(40),
    source_id           uuid,
    notes               text,
    is_deleted          boolean DEFAULT false NOT NULL,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    updated_at          timestamp with time zone DEFAULT now() NOT NULL,
    created_by          uuid,
    CONSTRAINT amortization_schedule_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_amort_schedule_org ON public.amortization_schedule (org_id) WHERE is_deleted = false;

-- One posting per schedule per period (idempotent runs).
CREATE TABLE public.amortization_entry (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    schedule_id         uuid NOT NULL,
    period_year         integer NOT NULL,
    period_month        integer NOT NULL,
    amount              numeric(18,2) NOT NULL,
    journal_entry_id    uuid,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT amortization_entry_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_amort_entry_period
    ON public.amortization_entry (org_id, schedule_id, period_year, period_month);
CREATE INDEX idx_amort_entry_schedule ON public.amortization_entry (org_id, schedule_id);
