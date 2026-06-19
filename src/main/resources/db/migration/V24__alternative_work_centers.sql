-- ============================================================================
-- V24: Alternative work centers (manufacturing tracker #15).
--
-- A routing operation names one primary workstation
-- (routing_operation.workstation_id). When that machine is at capacity
-- or down, production needs a sanctioned fallback. This table records
-- priority-ordered alternate workstations per routing operation so the
-- planner / job-card creation can pick the first one with capacity.
--
-- Additive — a routing op with no alternate rows behaves exactly as
-- before (primary only). The existing workstation_id stays the
-- authoritative primary.
-- ============================================================================

CREATE TABLE public.workstation_alternate (
    id                    uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                uuid NOT NULL,
    routing_operation_id  uuid NOT NULL,
    workstation_id        uuid NOT NULL,
    priority              integer DEFAULT 1 NOT NULL,
    notes                 text,
    created_at            timestamptz DEFAULT now() NOT NULL,
    created_by            uuid,
    updated_at            timestamptz DEFAULT now() NOT NULL,
    updated_by            uuid,
    is_deleted            boolean DEFAULT false NOT NULL
);

ALTER TABLE ONLY public.workstation_alternate
    ADD CONSTRAINT workstation_alternate_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.workstation_alternate
    ADD CONSTRAINT workstation_alternate_op_fkey
        FOREIGN KEY (routing_operation_id) REFERENCES public.routing_operation(id);

ALTER TABLE ONLY public.workstation_alternate
    ADD CONSTRAINT workstation_alternate_ws_fkey
        FOREIGN KEY (workstation_id) REFERENCES public.workstation(id);

-- One alternate row per (op, workstation) — re-registering the same
-- fallback is a no-op at the service layer, but guard here too.
CREATE UNIQUE INDEX idx_workstation_alternate_unique
    ON public.workstation_alternate (org_id, routing_operation_id, workstation_id)
    WHERE is_deleted = false;

CREATE INDEX idx_workstation_alternate_op
    ON public.workstation_alternate (org_id, routing_operation_id)
    WHERE is_deleted = false;
