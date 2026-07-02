-- V29 — Fixed-asset lifecycle completion.
--
-- The fixed_asset + fixed_asset_depreciation tables already exist (V1 baseline)
-- and FixedAssetService already computes SLM/WDV depreciation, posts the
-- monthly journal, and disposes assets. This migration adds the terminal
-- FULLY_DEPRECIATED status (the service now flips an asset there once its book
-- value reaches residual) and constrains the status column, which had no CHECK.
--
-- The "auto monthly journal" scheduler (DepreciationJob) needs no schema — it
-- just calls the existing idempotent runDepreciation on a cron. Auto-run is
-- gated by the org setting assets.auto_depreciation (default off, schema-free).

ALTER TABLE fixed_asset
    ADD CONSTRAINT fixed_asset_status_check
    CHECK (status IN ('ACTIVE', 'FULLY_DEPRECIATED', 'DISPOSED'));
