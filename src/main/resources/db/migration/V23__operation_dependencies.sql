-- ============================================================================
-- V23: Operation dependencies (manufacturing tracker #16).
--
-- Adds an explicit predecessor / successor graph between routing
-- operations so production scheduling (Gantt) can compute the
-- critical path and so the shop floor can see which operations
-- must finish before a given one can start.
--
-- The existing sequence_number on routing_operation still works for
-- the simple serial case; this table is additive. When no
-- dependencies exist for an operation, sequence_number remains the
-- ordering source of truth (one-line backwards compatibility).
-- ============================================================================

CREATE TABLE public.routing_operation_dependency (
    id                                uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                            uuid NOT NULL,
    routing_operation_id              uuid NOT NULL,
    predecessor_routing_operation_id  uuid NOT NULL,
    created_at                        timestamptz DEFAULT now() NOT NULL,
    created_by                        uuid,
    updated_at                        timestamptz DEFAULT now() NOT NULL,
    updated_by                        uuid,
    is_deleted                        boolean DEFAULT false NOT NULL
);

ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_op_fkey
        FOREIGN KEY (routing_operation_id) REFERENCES public.routing_operation(id);

ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_pred_fkey
        FOREIGN KEY (predecessor_routing_operation_id) REFERENCES public.routing_operation(id);

-- Self-edges are caught in service code but guard at the DB too for
-- safety — a UUID can never equal itself in this column pair.
ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_no_self
        CHECK (routing_operation_id <> predecessor_routing_operation_id);

CREATE UNIQUE INDEX idx_routing_op_dep_unique
    ON public.routing_operation_dependency
       (org_id, routing_operation_id, predecessor_routing_operation_id)
    WHERE is_deleted = false;

CREATE INDEX idx_routing_op_dep_succ
    ON public.routing_operation_dependency (org_id, routing_operation_id)
    WHERE is_deleted = false;

CREATE INDEX idx_routing_op_dep_pred
    ON public.routing_operation_dependency (org_id, predecessor_routing_operation_id)
    WHERE is_deleted = false;
