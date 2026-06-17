-- ============================================================================
-- V18: HR portal — Module 2 (Employee management), step 1: profile depth.
--
-- Extends the payroll employee master with Zoho People "Core HR" personal +
-- work profile fields. Family/Education/Experience subresources land in V19.
--
-- Existing payroll/attendance/leave behaviour is untouched: every new column
-- is nullable with no statutory side effect.
-- ============================================================================

-- Personal info
ALTER TABLE public.employee ADD COLUMN date_of_birth      date;
ALTER TABLE public.employee ADD COLUMN gender             varchar(15);    -- MALE|FEMALE|OTHER|PREFER_NOT_TO_SAY
ALTER TABLE public.employee ADD COLUMN marital_status     varchar(20);    -- SINGLE|MARRIED|DIVORCED|WIDOWED
ALTER TABLE public.employee ADD COLUMN blood_group        varchar(5);     -- A+, B-, etc.
ALTER TABLE public.employee ADD COLUMN nationality        varchar(50);
ALTER TABLE public.employee ADD COLUMN personal_email     varchar(255);

-- Current address
ALTER TABLE public.employee ADD COLUMN current_address_line1  varchar(255);
ALTER TABLE public.employee ADD COLUMN current_address_line2  varchar(255);
ALTER TABLE public.employee ADD COLUMN current_city           varchar(100);
ALTER TABLE public.employee ADD COLUMN current_state          varchar(100);
ALTER TABLE public.employee ADD COLUMN current_pincode        varchar(10);

-- Permanent address
ALTER TABLE public.employee ADD COLUMN permanent_address_line1 varchar(255);
ALTER TABLE public.employee ADD COLUMN permanent_address_line2 varchar(255);
ALTER TABLE public.employee ADD COLUMN permanent_city          varchar(100);
ALTER TABLE public.employee ADD COLUMN permanent_state         varchar(100);
ALTER TABLE public.employee ADD COLUMN permanent_pincode       varchar(10);

-- Emergency contact
ALTER TABLE public.employee ADD COLUMN emergency_contact_name         varchar(150);
ALTER TABLE public.employee ADD COLUMN emergency_contact_relationship varchar(50);
ALTER TABLE public.employee ADD COLUMN emergency_contact_phone        varchar(30);

-- Work info
ALTER TABLE public.employee ADD COLUMN employment_type    varchar(20);    -- FULL_TIME|PART_TIME|CONTRACT|INTERN|CONSULTANT
ALTER TABLE public.employee ADD COLUMN work_location      varchar(150);
ALTER TABLE public.employee ADD COLUMN probation_end_date date;
ALTER TABLE public.employee ADD COLUMN confirmation_date  date;
ALTER TABLE public.employee ADD COLUMN notice_period_days integer;

-- Profile photo — entity_attachment.id, resolved via AttachmentService
ALTER TABLE public.employee ADD COLUMN photo_attachment_id uuid;

ALTER TABLE public.employee
    ADD CONSTRAINT employee_gender_check
    CHECK (gender IS NULL OR gender IN ('MALE','FEMALE','OTHER','PREFER_NOT_TO_SAY'));

ALTER TABLE public.employee
    ADD CONSTRAINT employee_marital_status_check
    CHECK (marital_status IS NULL OR marital_status IN ('SINGLE','MARRIED','DIVORCED','WIDOWED'));

ALTER TABLE public.employee
    ADD CONSTRAINT employee_employment_type_check
    CHECK (employment_type IS NULL OR employment_type IN ('FULL_TIME','PART_TIME','CONTRACT','INTERN','CONSULTANT'));
