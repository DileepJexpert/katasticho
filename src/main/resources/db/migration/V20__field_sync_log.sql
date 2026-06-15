-- ============================================================================
-- V20: Field offline-sync idempotency ledger.
--
-- The Katasticho Field app buffers actions offline and flushes them via
-- POST /api/v1/field/sync/push. Network retries can replay the same batch, so
-- each action carries a client-generated id; this ledger records processed
-- (salesperson, client_id) pairs so a replay returns the prior result instead
-- of double-booking an order or collection.
-- ============================================================================

CREATE TABLE public.field_sync_entry (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id          uuid NOT NULL,
    salesperson_id  uuid NOT NULL,
    client_id       character varying(120) NOT NULL,
    action_type     character varying(40) NOT NULL,
    status          character varying(20) NOT NULL,   -- APPLIED | FAILED
    result_summary  text,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT field_sync_entry_pkey PRIMARY KEY (id)
);

-- Idempotency: one processed action per (org, salesperson, client_id).
CREATE UNIQUE INDEX uq_field_sync_entry
    ON public.field_sync_entry (org_id, salesperson_id, client_id);
