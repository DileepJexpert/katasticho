-- V5: Employee tax declaration (Form 12BB + regime choice).
--
-- Per-employee, per-FY record of the tax-regime election (OLD or NEW) and
-- investment declarations (HRA, 80C, 80D, home loan interest, LTA, …).
-- Without this, salary TDS withholding is a guess; with it, the monthly TDS
-- (and the year-end Form 16) reflect what the employee actually claims.
--
-- Lifecycle: DRAFT (employee editing) → SUBMITTED (employee finalised at
-- FY start) → VERIFIED (payroll team approved after IT-proof submission
-- in Jan/Feb). Status drives whether payroll can rely on the declaration
-- for monthly TDS.
--
-- NEW regime applies the simplified slabs with limited deductions (only
-- standard deduction + 80CCD(2)); OLD regime allows HRA exemption + Section
-- 80 deductions + home-loan interest + LTA — the calculator in A6 picks
-- the right path from this row.

CREATE TABLE public.employee_tax_declaration (
    id                       uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                   uuid           NOT NULL,
    employee_id              uuid           NOT NULL,
    -- "2026-27" — financial year (Apr 1 to Mar 31).
    fiscal_year              varchar(9)     NOT NULL,
    -- OLD: traditional regime (default for legacy employees)
    -- NEW: simplified regime (default for new joiners FY 2023-24 onwards)
    tax_regime               varchar(10)    NOT NULL,

    -- HRA exemption (Section 10(13A)) — OLD regime only.
    hra_rent_paid            numeric(12, 2),
    hra_metro_city           boolean        NOT NULL DEFAULT false,
    landlord_pan             varchar(20),   -- statutorily required when rent > ₹1L/year

    -- Section 80 deductions — OLD regime only.
    -- Caps shown for reference; service applies them in
    -- effectiveSection80Deduction.
    deduction_80c            numeric(12, 2), -- ₹1.5L cap (LIC/PPF/ELSS/EPF/...)
    deduction_80ccd_1b       numeric(12, 2), -- ₹50k cap (NPS extra, over and above 80C)
    deduction_80d_self       numeric(12, 2), -- ₹25k/₹50k senior — mediclaim self+family
    deduction_80d_parents    numeric(12, 2), -- ₹25k/₹50k senior — mediclaim parents
    deduction_80e            numeric(12, 2), -- no cap — education loan interest
    deduction_80g            numeric(12, 2), -- donations (cap depends on cause)
    deduction_80tta          numeric(12, 2), -- ₹10k cap — savings account interest
    deduction_80ttb          numeric(12, 2), -- ₹50k cap — senior citizen interest (replaces 80TTA)

    -- Section 24(b) — home loan interest (self-occupied).
    home_loan_interest       numeric(12, 2), -- ₹2L cap

    -- LTA exemption (Section 10(5)) — OLD regime only.
    lta_claim                numeric(12, 2),

    -- Other income reported by the employee so monthly TDS isn't short.
    other_income             numeric(12, 2),

    -- Lifecycle
    status                   varchar(20)    NOT NULL DEFAULT 'DRAFT',
    submitted_at             timestamptz,
    verified_at              timestamptz,
    verified_by              uuid,
    notes                    text,

    -- Audit
    created_at               timestamptz    NOT NULL DEFAULT now(),
    updated_at               timestamptz    NOT NULL DEFAULT now(),
    created_by               uuid,
    updated_by               uuid,
    is_deleted               boolean        NOT NULL DEFAULT false,

    CONSTRAINT employee_tax_declaration_pkey PRIMARY KEY (id),
    CONSTRAINT etd_regime_check CHECK (tax_regime IN ('OLD', 'NEW')),
    CONSTRAINT etd_status_check CHECK (status IN ('DRAFT', 'SUBMITTED', 'VERIFIED'))
);

-- One declaration per employee per FY (soft-deleted rows excluded).
CREATE UNIQUE INDEX idx_etd_unique
    ON public.employee_tax_declaration (org_id, employee_id, fiscal_year)
    WHERE is_deleted = false;

CREATE INDEX idx_etd_by_employee
    ON public.employee_tax_declaration (org_id, employee_id)
    WHERE is_deleted = false;
