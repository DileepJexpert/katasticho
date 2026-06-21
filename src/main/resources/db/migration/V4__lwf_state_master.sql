-- V4: Labour Welfare Fund (LWF) — state-wise rules.
--
-- Replaces the flat ₹25 employee + ₹75 employer LWF hard-coded in PayrollService
-- with statutory state rules. LWF is a state-level levy that varies in three
-- dimensions:
--
--   1. Amount (employee + employer) — different per state.
--   2. Frequency — MONTHLY / HALF_YEARLY / ANNUAL.
--   3. Collection months — most states deduct in June + December (half-yearly);
--      some collect annually in December; a few are monthly; CG is on the
--      Sept + March cycle.
--
-- States with no LWF (most NE states, J&K, UP, Bihar, Jharkhand, Rajasthan, HP,
-- Sikkim, Uttarakhand) get no rows — calculator returns ₹0 when no rule matches,
-- which is statutorily correct.
--
-- Rates current to FY 2025-26 per each state's Labour Welfare Fund Act.
-- Platform-level reference data (no org_id) — same pattern as pt_slab.

CREATE TABLE public.lwf_rule (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    -- 2-letter state code (alphaCode in gst_state_code).
    state_code          varchar(2)     NOT NULL,
    -- MONTHLY: deducted every month
    -- HALF_YEARLY: deducted in two specific months (typically Jun + Dec)
    -- ANNUAL: deducted once a year (typically Dec)
    frequency           varchar(20)    NOT NULL,
    -- Comma-separated 1-12 month numbers when LWF is collected. Calculator
    -- checks if the payslip's period_end month is in this set; if not, it
    -- emits ₹0 for that month (don't repeat-charge a half-yearly amount).
    -- Example: '6,12' for June+December; '1,2,3,4,5,6,7,8,9,10,11,12' for monthly.
    collection_months   varchar(50)    NOT NULL,
    -- Optional gross-salary brackets — most states are flat; the gross
    -- range below covers ALL employees (use this for states with NO gross
    -- threshold). Set a real bound only for states like Goa that bracket
    -- LWF by gross.
    gross_from          numeric(12, 2) NOT NULL DEFAULT 0,
    gross_to            numeric(12, 2),
    -- Per-collection amounts (NOT monthly amounts unless frequency = MONTHLY).
    -- E.g. Maharashtra half-yearly = ₹25 employee per collection (so ₹50/year).
    employee_amount     numeric(8, 2)  NOT NULL,
    employer_amount     numeric(8, 2)  NOT NULL,
    effective_from      date           NOT NULL DEFAULT DATE '2024-04-01',
    is_active           boolean        NOT NULL DEFAULT true,
    notes               text,
    created_at          timestamptz    NOT NULL DEFAULT now(),
    CONSTRAINT lwf_rule_pkey PRIMARY KEY (id),
    CONSTRAINT lwf_rule_frequency_check CHECK (
        frequency IN ('MONTHLY', 'HALF_YEARLY', 'ANNUAL'))
);

CREATE INDEX idx_lwf_rule_lookup
    ON public.lwf_rule (state_code, gross_from)
    WHERE is_active = true;

-- ── Seed ───────────────────────────────────────────────────────────

-- Maharashtra (MH): ₹25 employee + ₹75 employer, half-yearly (Jun + Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('MH', 'HALF_YEARLY', '6,12', 25.00, 75.00,
     '₹25 EE + ₹75 ER per half — collected in June and December salaries (₹50/year EE)');

-- Karnataka (KA): ₹20 employee + ₹40 employer, annual (December).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('KA', 'ANNUAL', '12', 20.00, 40.00,
     '₹20 EE + ₹40 ER annual — December salary');

-- Gujarat (GJ): ₹6 employee + ₹12 employer, half-yearly (Jun + Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('GJ', 'HALF_YEARLY', '6,12', 6.00, 12.00,
     '₹6 EE + ₹12 ER per half');

-- Tamil Nadu (TN): ₹20 employee + ₹40 employer, annual (December).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('TN', 'ANNUAL', '12', 20.00, 40.00,
     '₹20 EE + ₹40 ER annual');

-- Andhra Pradesh (AP) & Telangana (TS): ₹30 employee + ₹70 employer, annual (Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('AP', 'ANNUAL', '12', 30.00, 70.00, '₹30 EE + ₹70 ER annual'),
    ('TS', 'ANNUAL', '12', 30.00, 70.00, '₹30 EE + ₹70 ER annual');

-- West Bengal (WB): ₹3 employee + ₹15 employer, half-yearly (Jun + Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('WB', 'HALF_YEARLY', '6,12', 3.00, 15.00, '₹3 EE + ₹15 ER per half');

-- Madhya Pradesh (MP): ₹10 employee + ₹30 employer, half-yearly (Jun + Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('MP', 'HALF_YEARLY', '6,12', 10.00, 30.00, '₹10 EE + ₹30 ER per half');

-- Chhattisgarh (CG): ₹15 employee + ₹45 employer, half-yearly — collected
-- in MARCH and SEPTEMBER (different from the Jun/Dec norm).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('CG', 'HALF_YEARLY', '3,9', 15.00, 45.00,
     '₹15 EE + ₹45 ER per half — March and September');

-- Kerala (KL): ₹45 employee + ₹45 employer, monthly.
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('KL', 'MONTHLY', '1,2,3,4,5,6,7,8,9,10,11,12', 45.00, 45.00,
     '₹45 EE + ₹45 ER monthly');

-- Punjab (PB): ₹5 employee + ₹20 employer, monthly.
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('PB', 'MONTHLY', '1,2,3,4,5,6,7,8,9,10,11,12', 5.00, 20.00,
     '₹5 EE + ₹20 ER monthly');

-- Haryana (HR): ₹31 employee + ₹62 employer, monthly (revised FY 2024-25).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('HR', 'MONTHLY', '1,2,3,4,5,6,7,8,9,10,11,12', 31.00, 62.00,
     '₹31 EE + ₹62 ER monthly (revised FY 2024-25)');

-- Delhi (DL): ₹0.75 employee + ₹2.25 employer, half-yearly (Jun + Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('DL', 'HALF_YEARLY', '6,12', 0.75, 2.25,
     '₹0.75 EE + ₹2.25 ER per half — Delhi-specific tiny amounts');

-- Odisha (OR): ₹20 employee + ₹40 employer, half-yearly (Jun + Dec).
INSERT INTO public.lwf_rule (state_code, frequency, collection_months, employee_amount, employer_amount, notes) VALUES
    ('OR', 'HALF_YEARLY', '6,12', 20.00, 40.00,
     '₹20 EE + ₹40 ER per half');
