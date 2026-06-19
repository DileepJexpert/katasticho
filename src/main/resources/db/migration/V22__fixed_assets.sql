-- ============================================================================
-- V22: Fixed Assets + Depreciation (India dual schedule).
--
-- Asset register with two parallel depreciation views:
--   * BOOK (Companies Act) — SLM or WDV, per-asset useful life / rate, residual
--     value; posted to the GL (DR Depreciation Expense / CR Accumulated Dep).
--   * INCOME-TAX (block of assets, WDV, prescribed rate) — computed for the
--     return only, never posted to the books.
-- ============================================================================

CREATE TABLE public.fixed_asset (
    id                          uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                      uuid NOT NULL,
    asset_code                  character varying(40) NOT NULL,
    name                        character varying(200) NOT NULL,
    category                    character varying(60),                 -- e.g. Computer, Furniture, Plant
    acquisition_date            date NOT NULL,
    cost                        numeric(18,2) NOT NULL,
    residual_value              numeric(18,2) DEFAULT 0 NOT NULL,

    -- Book (Companies Act) depreciation
    book_method                 character varying(10) NOT NULL,        -- SLM | WDV
    book_useful_life_months     integer,                               -- for SLM
    book_rate_pct               numeric(7,3),                          -- annual %, for WDV
    accumulated_depreciation    numeric(18,2) DEFAULT 0 NOT NULL,      -- book, running

    -- Income-tax (block of assets) depreciation
    it_block                    character varying(40),                 -- e.g. COMPUTER_40, PLANT_15
    it_rate_pct                 numeric(7,3),                          -- annual WDV %

    -- GL account codes (default to the standard CoA: 1600 / 1690 / 5270)
    asset_account_code          character varying(20),
    accumulated_dep_account_code character varying(20),
    dep_expense_account_code    character varying(20),

    status                      character varying(20) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE | DISPOSED
    disposal_date               date,
    disposal_proceeds           numeric(18,2),
    source_bill_id              uuid,
    notes                       text,
    is_deleted                  boolean DEFAULT false NOT NULL,
    created_at                  timestamp with time zone DEFAULT now() NOT NULL,
    updated_at                  timestamp with time zone DEFAULT now() NOT NULL,
    created_by                  uuid,
    CONSTRAINT fixed_asset_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_fixed_asset_code
    ON public.fixed_asset (org_id, asset_code) WHERE is_deleted = false;
CREATE INDEX idx_fixed_asset_org ON public.fixed_asset (org_id) WHERE is_deleted = false;

-- One book-depreciation charge per asset per period (idempotent runs).
CREATE TABLE public.fixed_asset_depreciation (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    fixed_asset_id      uuid NOT NULL,
    period_year         integer NOT NULL,
    period_month        integer NOT NULL,
    opening_wdv         numeric(18,2) NOT NULL,
    depreciation_amount numeric(18,2) NOT NULL,
    closing_wdv         numeric(18,2) NOT NULL,
    journal_entry_id    uuid,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT fixed_asset_depreciation_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_fixed_asset_dep_period
    ON public.fixed_asset_depreciation (org_id, fixed_asset_id, period_year, period_month);
CREATE INDEX idx_fixed_asset_dep_asset
    ON public.fixed_asset_depreciation (org_id, fixed_asset_id);
