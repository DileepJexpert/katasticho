-- ============================================================================
-- V15: HR portal — HR Help Desk. Module 6 of Core HR.
--
-- Employees raise tickets to HR (payslip query, document request, grievance,
-- etc.); HR assigns and resolves them through a status lifecycle, with a
-- comment thread per ticket.
-- ============================================================================

CREATE TABLE public.hr_ticket (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    raised_by_user_id   uuid NOT NULL,
    category            character varying(40) DEFAULT 'GENERAL' NOT NULL,
    subject             character varying(200) NOT NULL,
    description         text,
    priority            character varying(10) DEFAULT 'NORMAL' NOT NULL,   -- LOW|NORMAL|HIGH
    status              character varying(20) DEFAULT 'OPEN' NOT NULL,     -- OPEN|IN_PROGRESS|RESOLVED|CLOSED
    assigned_to_user_id uuid,
    resolution          text,
    is_deleted          boolean DEFAULT false NOT NULL,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    updated_at          timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_ticket_pkey PRIMARY KEY (id),
    CONSTRAINT hr_ticket_priority_check CHECK (priority IN ('LOW', 'NORMAL', 'HIGH')),
    CONSTRAINT hr_ticket_status_check CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'))
);

CREATE INDEX idx_hr_ticket_raised ON public.hr_ticket (org_id, raised_by_user_id, created_at);
CREATE INDEX idx_hr_ticket_assigned ON public.hr_ticket (org_id, assigned_to_user_id, status);
CREATE INDEX idx_hr_ticket_status ON public.hr_ticket (org_id, status);

CREATE TABLE public.hr_ticket_comment (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id          uuid NOT NULL,
    ticket_id       uuid NOT NULL,
    author_user_id  uuid NOT NULL,
    body            text NOT NULL,
    is_deleted      boolean DEFAULT false NOT NULL,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_ticket_comment_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_hr_ticket_comment ON public.hr_ticket_comment (org_id, ticket_id, created_at);
