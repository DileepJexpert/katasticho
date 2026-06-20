-- V3: Professional Tax (PT) slab master — state-wise.
--
-- Replaces the flat ₹200/month PT hard-coded in PayrollService with statutory
-- slabs by state. PT is a state-level tax; each state defines its own bracket
-- structure. Most states use monthly slabs by gross salary; Maharashtra has
-- gender-specific brackets and a special February amount; Tamil Nadu / Kerala
-- use half-yearly brackets (we store the monthly equivalent for payroll calc).
--
-- States with NO professional tax (Delhi, Haryana, UP, Rajasthan, Punjab*,
-- Uttarakhand, J&K, HP, Goa, Chhattisgarh, Arunachal, all UTs except Pondy)
-- get NO rows here — the calculator returns nil when no slab matches, so
-- they are correctly nil by default. (*Punjab's PT was struck down and is
-- not currently collected.)
--
-- Rates current as of FY 2025-26 per state PT acts. Update via fresh rows
-- with effective_from when a state revises.
--
-- Platform-level reference data (no org_id) — same pattern as gst_state_code,
-- hsn_gst_master, drug_master.

CREATE TABLE public.pt_slab (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    -- 2-letter state code matching gst_state_code.gst_state_abbreviation
    -- (MH/KA/WB/TN/AP/TS/GJ/MP/OR/KL/BR/JH/AS/TR/MN/MZ/NL/SK/ML/PY).
    state_code          varchar(2)     NOT NULL,
    -- NULL = applies to all genders; 'MALE'/'FEMALE' for states that split
    -- (Maharashtra is the main one).
    gender              varchar(10),
    gross_from          numeric(12, 2) NOT NULL,
    -- NULL = unbounded upper (e.g. ">₹10,000").
    gross_to            numeric(12, 2),
    monthly_amount      numeric(8, 2)  NOT NULL,
    -- A few states (MH, OR, MP) levy an extra amount once in February to
    -- top up the annual cap; NULL means "same as monthly_amount".
    feb_amount          numeric(8, 2),
    effective_from      date           NOT NULL DEFAULT DATE '2024-04-01',
    is_active           boolean        NOT NULL DEFAULT true,
    notes               text,
    created_at          timestamptz    NOT NULL DEFAULT now(),
    CONSTRAINT pt_slab_pkey PRIMARY KEY (id),
    CONSTRAINT pt_slab_gender_check CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE'))
);

CREATE INDEX idx_pt_slab_lookup
    ON public.pt_slab (state_code, gender, gross_from)
    WHERE is_active = true;

-- ── Seed: state slabs current to FY 2025-26 ──────────────────────────

-- Maharashtra (MH): gender-split, Feb has a top-up to hit the ₹2,500 annual cap.
-- Source: Maharashtra State Tax on Professions, Trades, Callings and Employments Act, 1975.
INSERT INTO public.pt_slab (state_code, gender, gross_from, gross_to, monthly_amount, feb_amount, notes) VALUES
    ('MH', 'MALE',   0.00,      7500.00,  0.00,   NULL, 'Nil up to ₹7,500'),
    ('MH', 'MALE',   7500.01,   10000.00, 175.00, NULL, '₹175/month'),
    ('MH', 'MALE',   10000.01,  NULL,     200.00, 300.00, '₹200/month; ₹300 in February (annual cap ₹2,500)'),
    ('MH', 'FEMALE', 0.00,      25000.00, 0.00,   NULL, 'Nil up to ₹25,000 for women'),
    ('MH', 'FEMALE', 25000.01,  NULL,     200.00, 300.00, '₹200/month; ₹300 in February');

-- Karnataka (KA): single threshold (revised FY 2024-25 from ₹15,000 to ₹25,000).
-- Source: Karnataka Tax on Professions, Trades, Callings and Employments Act, 1976.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('KA', 0.00,     25000.00, 0.00,   'Nil up to ₹25,000'),
    ('KA', 25000.01, NULL,     200.00, '₹200/month');

-- West Bengal (WB): graduated slabs.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('WB', 0.00,     10000.00, 0.00,   'Nil up to ₹10,000'),
    ('WB', 10000.01, 15000.00, 110.00, '₹110/month'),
    ('WB', 15000.01, 25000.00, 130.00, '₹130/month'),
    ('WB', 25000.01, 40000.00, 150.00, '₹150/month'),
    ('WB', 40000.01, NULL,     200.00, '₹200/month');

-- Tamil Nadu (TN): half-yearly brackets in statute, stored as monthly equivalent
-- (= half-yearly amount / 6). Used for the monthly payroll deduction.
-- Source: Tamil Nadu Municipal Laws (Profession Tax) Rules.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('TN', 0.00,     21000.00, 0.00,   'Nil up to ₹21,000/month'),
    ('TN', 21000.01, 30000.00, 22.50,  '₹135/half-year = ₹22.50/month'),
    ('TN', 30000.01, 45000.00, 52.50,  '₹315/half-year = ₹52.50/month'),
    ('TN', 45000.01, 60000.00, 115.00, '₹690/half-year = ₹115/month'),
    ('TN', 60000.01, 75000.00, 170.83, '₹1,025/half-year = ₹170.83/month'),
    ('TN', 75000.01, NULL,     208.33, '₹1,250/half-year = ₹208.33/month');

-- Andhra Pradesh (AP) & Telangana (TS): same slab structure (Telangana inherited from AP).
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('AP', 0.00,     15000.00, 0.00,   'Nil up to ₹15,000'),
    ('AP', 15000.01, 20000.00, 150.00, '₹150/month'),
    ('AP', 20000.01, NULL,     200.00, '₹200/month'),
    ('TS', 0.00,     15000.00, 0.00,   'Nil up to ₹15,000'),
    ('TS', 15000.01, 20000.00, 150.00, '₹150/month'),
    ('TS', 20000.01, NULL,     200.00, '₹200/month');

-- Gujarat (GJ): single threshold.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('GJ', 0.00,     12000.00, 0.00,   'Nil up to ₹12,000'),
    ('GJ', 12000.01, NULL,     200.00, '₹200/month');

-- Madhya Pradesh (MP): graduated; Feb has a small top-up.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, feb_amount, notes) VALUES
    ('MP', 0.00,     18750.00, 0.00,   NULL,   'Nil up to ₹18,750'),
    ('MP', 18750.01, 25000.00, 125.00, NULL,   '₹125/month'),
    ('MP', 25000.01, 33333.00, 167.00, NULL,   '₹167/month'),
    ('MP', 33333.01, NULL,     208.00, 212.00, '₹208/month; ₹212 in February (annual cap ₹2,500)');

-- Odisha (OR): graduated; Feb top-up.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, feb_amount, notes) VALUES
    ('OR', 0.00,     13304.00, 0.00,   NULL,   'Nil up to ₹13,304'),
    ('OR', 13304.01, 25000.00, 125.00, NULL,   '₹125/month'),
    ('OR', 25000.01, NULL,     200.00, 300.00, '₹200/month; ₹300 in February (annual cap ₹2,500)');

-- Kerala (KL): half-yearly brackets stored as monthly equivalent (/ 6).
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('KL', 0.00,     11999.00, 0.00,   'Nil up to ₹11,999/month'),
    ('KL', 12000.00, 17999.00, 20.00,  '₹120/half-year = ₹20/month'),
    ('KL', 18000.00, 29999.00, 30.00,  '₹180/half-year = ₹30/month'),
    ('KL', 30000.00, 44999.00, 50.00,  '₹300/half-year = ₹50/month'),
    ('KL', 45000.00, 59999.00, 75.00,  '₹450/half-year = ₹75/month'),
    ('KL', 60000.00, 74999.00, 100.00, '₹600/half-year = ₹100/month'),
    ('KL', 75000.00, 99999.00, 125.00, '₹750/half-year = ₹125/month'),
    ('KL', 100000.00, 124999.00, 166.67, '₹1,000/half-year = ₹166.67/month'),
    ('KL', 125000.00, NULL,    208.33, '₹1,250/half-year = ₹208.33/month');

-- Bihar (BR): annual slabs in statute; we store the monthly equivalent (annual / 12).
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('BR', 0.00,      25000.00, 0.00,   'Nil up to ₹3 lakh annual (~₹25,000/month)'),
    ('BR', 25000.01,  41666.66, 83.33,  '₹1,000/year = ₹83.33/month'),
    ('BR', 41666.67,  50000.00, 125.00, '₹1,500/year = ₹125/month'),
    ('BR', 50000.01,  NULL,     208.33, '₹2,500/year = ₹208.33/month');

-- Jharkhand (JH): same as Bihar (annual slabs).
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('JH', 0.00,      25000.00, 0.00,   'Nil up to ₹3 lakh annual'),
    ('JH', 25000.01,  41666.66, 83.33,  '₹1,000/year = ₹83.33/month'),
    ('JH', 41666.67,  50000.00, 125.00, '₹1,500/year = ₹125/month'),
    ('JH', 50000.01,  NULL,     208.33, '₹2,500/year = ₹208.33/month');

-- Assam (AS): graduated monthly slabs.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('AS', 0.00,     10000.00, 0.00,   'Nil up to ₹10,000'),
    ('AS', 10000.01, 15000.00, 150.00, '₹150/month'),
    ('AS', 15000.01, 25000.00, 180.00, '₹180/month'),
    ('AS', 25000.01, NULL,     208.00, '₹208/month');

-- Puducherry (PY): graduated half-yearly slabs stored as monthly equivalent.
INSERT INTO public.pt_slab (state_code, gross_from, gross_to, monthly_amount, notes) VALUES
    ('PY', 0.00,     16666.00, 0.00,  'Nil up to ₹1 lakh half-yearly'),
    ('PY', 16666.01, 33333.00, 41.66, '₹250/half-year = ₹41.66/month'),
    ('PY', 33333.01, 50000.00, 83.33, '₹500/half-year = ₹83.33/month'),
    ('PY', 50000.01, 66666.00, 125.00, '₹750/half-year = ₹125/month'),
    ('PY', 66666.01, 83333.00, 166.66, '₹1,000/half-year = ₹166.66/month'),
    ('PY', 83333.01, NULL,    208.33, '₹1,250/half-year = ₹208.33/month');
