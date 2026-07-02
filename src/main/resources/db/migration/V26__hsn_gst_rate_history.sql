-- V26 — HSN → GST rate history with effective dates.
--
-- hsn_gst_master holds ONE current rate per HSN code — when GST 2.0 changed
-- rates on 2025-09-22 the seed rows were simply overwritten, so the system
-- can't answer "what rate applied on a given bill/invoice date". This adds an
-- effective-dated history layer as a REFERENCE + REPORT capability. It does
-- NOT touch document rate resolution: every invoice/bill/receipt already
-- SNAPSHOTS gstRate + taxGroupId + taxAmount onto the line at creation, so
-- posted history is immutable regardless. The effective-date need is correct
-- DEFAULTS on back-dated entry + audit/reporting, which this layer covers with
-- zero posting-behaviour change.
--
-- Platform table (no org_id, no BaseEntity) — HSN codes + statutory GST rates
-- are shared across all tenants, same as hsn_gst_master.

CREATE TABLE hsn_gst_rate_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hsn_code VARCHAR(10) NOT NULL,
    gst_rate NUMERIC(5, 2) NOT NULL,
    cess_rate NUMERIC(5, 2),                 -- nullable; net-new compensation-cess capability
    effective_from DATE NOT NULL,
    effective_to DATE,                       -- nullable = still current
    notification_ref VARCHAR(120),           -- e.g. 'Notification 9/2025-CT(Rate)'
    source VARCHAR(40),                      -- 'BASELINE','GST_2_0','MANUAL', ...
    description VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_hsn_rate_history_lookup
    ON hsn_gst_rate_history (hsn_code, effective_from DESC);

-- One period start per code — stops duplicate effective_from rows.
CREATE UNIQUE INDEX uq_hsn_rate_history_period
    ON hsn_gst_rate_history (hsn_code, effective_from);

-- Baseline: one open-ended period per existing HSN code carrying the current
-- rate. effective_from = GST rollout (2017-07-01) with no fabricated pre-2.0
-- transition — codes that never changed read correctly, and when a real rate
-- change is known the API adds the newer period and auto-closes this baseline.
INSERT INTO hsn_gst_rate_history (hsn_code, gst_rate, effective_from, effective_to, source, description)
SELECT hsn_code, gst_rate, DATE '2017-07-01', NULL, 'BASELINE', description
FROM hsn_gst_master
WHERE is_active = true;
