-- Migration: V53__multi_tier_trade_schemes.sql
-- Description: Adds half-scheme parameters, company subsidy reimbursement %, special net rates, and free quantity caps for wholesale/pharma distribution.

ALTER TABLE public.schemes
    ADD COLUMN IF NOT EXISTS allow_half_scheme boolean DEFAULT true NOT NULL,
    ADD COLUMN IF NOT EXISTS half_scheme_min_qty numeric(14,4),
    ADD COLUMN IF NOT EXISTS company_subsidy_percent numeric(6,2) DEFAULT 100.00,
    ADD COLUMN IF NOT EXISTS special_net_rate numeric(14,4),
    ADD COLUMN IF NOT EXISTS max_free_quantity_cap numeric(14,4);
