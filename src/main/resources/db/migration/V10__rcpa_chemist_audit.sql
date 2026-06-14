-- ============================================================================
-- V10: RCPA — Retail Chemist Prescription Audit.
--
-- A pharma MR audits a chemist's actual sales of each product over a period —
-- both the company's own brands and competitor brands. This yields brand/
-- prescription share and competitor-volume intelligence that primary sales
-- alone can't show.
--
-- Org-scoped. An audit is recorded by the salesperson for a chemist contact,
-- optionally tied to the field visit during which it was taken.
-- ============================================================================

CREATE TABLE public.rcpa_audit (
    id                 uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id             uuid NOT NULL,
    salesperson_id     uuid NOT NULL,
    chemist_contact_id uuid NOT NULL,
    audit_date         date NOT NULL,
    field_visit_id     uuid,
    remarks            text,
    is_deleted         boolean DEFAULT false NOT NULL,
    created_at         timestamp with time zone DEFAULT now() NOT NULL,
    updated_at         timestamp with time zone DEFAULT now() NOT NULL,
    created_by         uuid,
    CONSTRAINT rcpa_audit_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_rcpa_audit_chemist ON public.rcpa_audit (org_id, chemist_contact_id, audit_date);
CREATE INDEX idx_rcpa_audit_salesperson ON public.rcpa_audit (org_id, salesperson_id, audit_date);

CREATE TABLE public.rcpa_line (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id          uuid NOT NULL,
    audit_id        uuid NOT NULL,
    product_name    character varying(255) NOT NULL,
    brand_type      character varying(12) DEFAULT 'OWN' NOT NULL,   -- OWN | COMPETITOR
    competitor_name character varying(255),
    our_item_id     uuid,
    quantity        numeric(18,3) DEFAULT 0 NOT NULL,
    value           numeric(18,2) DEFAULT 0 NOT NULL,
    is_deleted      boolean DEFAULT false NOT NULL,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rcpa_line_pkey PRIMARY KEY (id),
    CONSTRAINT rcpa_line_brand_type_check CHECK (brand_type IN ('OWN', 'COMPETITOR'))
);

CREATE INDEX idx_rcpa_line_audit ON public.rcpa_line (org_id, audit_id);
