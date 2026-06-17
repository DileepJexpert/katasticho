-- ============================================================================
-- V19: HR portal — Module 2 step 2: employee subresources.
--
-- Family/dependents, education history, prior work experience. Each row
-- belongs to one employee (payroll.employee.id). Soft-delete + audit columns
-- match the rest of the HR schema.
-- ============================================================================

CREATE TABLE public.hr_employee_family (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id          uuid NOT NULL,
    employee_id     uuid NOT NULL,
    name            varchar(150) NOT NULL,
    relationship    varchar(30)  NOT NULL,        -- SPOUSE|CHILD|FATHER|MOTHER|SIBLING|OTHER
    date_of_birth   date,
    is_dependent    boolean DEFAULT false NOT NULL,
    phone           varchar(30),
    notes           text,
    is_deleted      boolean DEFAULT false NOT NULL,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    updated_at      timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_family_pkey PRIMARY KEY (id),
    CONSTRAINT hr_employee_family_rel_check
        CHECK (relationship IN ('SPOUSE','CHILD','FATHER','MOTHER','SIBLING','OTHER'))
);
CREATE INDEX idx_hr_employee_family_emp ON public.hr_employee_family (org_id, employee_id);

CREATE TABLE public.hr_employee_education (
    id                uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id            uuid NOT NULL,
    employee_id       uuid NOT NULL,
    degree            varchar(100) NOT NULL,
    field_of_study    varchar(150),
    institution       varchar(255),
    start_year        integer,
    end_year          integer,
    grade             varchar(50),                -- "First class" / "8.5 CGPA" / "75%"
    notes             text,
    is_deleted        boolean DEFAULT false NOT NULL,
    created_at        timestamp with time zone DEFAULT now() NOT NULL,
    updated_at        timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_education_pkey PRIMARY KEY (id)
);
CREATE INDEX idx_hr_employee_education_emp ON public.hr_employee_education (org_id, employee_id);

CREATE TABLE public.hr_employee_experience (
    id                uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id            uuid NOT NULL,
    employee_id       uuid NOT NULL,
    company_name      varchar(255) NOT NULL,
    designation       varchar(150),
    from_date         date,
    to_date           date,                       -- NULL = current (only valid for prior jobs if employee re-joined)
    location          varchar(150),
    responsibilities  text,
    is_deleted        boolean DEFAULT false NOT NULL,
    created_at        timestamp with time zone DEFAULT now() NOT NULL,
    updated_at        timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_experience_pkey PRIMARY KEY (id),
    CONSTRAINT hr_employee_experience_date_check
        CHECK (to_date IS NULL OR from_date IS NULL OR to_date >= from_date)
);
CREATE INDEX idx_hr_employee_experience_emp ON public.hr_employee_experience (org_id, employee_id);
