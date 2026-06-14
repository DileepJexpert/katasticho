-- ============================================================================
-- V16: HR portal — Employee Document management. Module 7 of Core HR.
--
-- Employee documents (ID proof, PAN, insurance, contract, ...) with category
-- and expiry. The file itself is stored via the shared AttachmentService
-- (entity_attachment); this table adds the HR metadata + denormalised file
-- info so expiry tracking and per-employee listing are cheap.
-- ============================================================================

CREATE TABLE public.hr_employee_document (
    id               uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id           uuid NOT NULL,
    employee_user_id uuid NOT NULL,
    category         character varying(40) DEFAULT 'OTHER' NOT NULL,
    title            character varying(200) NOT NULL,
    file_name        character varying(255),
    file_url         character varying(1000),
    file_type        character varying(100),
    file_size        bigint,
    expiry_date      date,
    attachment_id    uuid,
    uploaded_by      uuid,
    is_deleted       boolean DEFAULT false NOT NULL,
    created_at       timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_document_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_hr_emp_doc_employee ON public.hr_employee_document (org_id, employee_user_id);
CREATE INDEX idx_hr_emp_doc_expiry ON public.hr_employee_document (org_id, expiry_date);
