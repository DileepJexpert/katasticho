-- ============================================================================
-- V24: GSTR-2A/2B filing snapshot metadata.
--
-- The ITC-at-risk monitor and the 2B reconciler both work off gstr2b_entry
-- rows, but the rows themselves don't say WHEN the filing data was last pulled
-- or from WHICH source. This one-row-per-(org, period) table records that
-- provenance so the owner sees "ITC at risk as of <time>, source GSTR-2A" and
-- knows how fresh — and how trustworthy — the signal is.
--
--   source = GSTR_2A  -> real-time feed (pre-cutoff prevention window)
--          = GSTR_2B  -> frozen post-cutoff return (fetched via GSP)
--          = UPLOAD   -> portal JSON uploaded manually
-- ============================================================================

CREATE TABLE public.gst_filing_snapshot (
    id            uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id        uuid NOT NULL,
    return_period character varying(7) NOT NULL,   -- YYYY-MM
    source        character varying(20) NOT NULL,  -- GSTR_2A | GSTR_2B | UPLOAD
    entry_count   integer DEFAULT 0 NOT NULL,
    refreshed_at  timestamp with time zone DEFAULT now() NOT NULL,
    created_at    timestamp with time zone DEFAULT now() NOT NULL,
    updated_at    timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gst_filing_snapshot_pkey PRIMARY KEY (id)
);

-- One snapshot per (org, period); the ingest upserts it.
CREATE UNIQUE INDEX uq_gst_filing_snapshot
    ON public.gst_filing_snapshot (org_id, return_period);
