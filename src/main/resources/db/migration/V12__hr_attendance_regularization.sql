-- ============================================================================
-- V12: HR portal — Attendance management. Module 2 of Core HR.
--
-- Adds attendance regularization: an employee requests a punch correction for a
-- date (forgot to punch, wrong time); a manager approves, which writes the
-- corrected punch onto the day's field_attendance row. The monthly attendance
-- summary (present/leave/holiday/absent/hours) is computed in the service from
-- field_attendance + leave + the holiday calendar.
-- ============================================================================

CREATE TABLE public.attendance_regularization (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    user_id             uuid NOT NULL,
    work_date           date NOT NULL,
    requested_punch_in  timestamp with time zone,
    requested_punch_out timestamp with time zone,
    reason              text,
    status              character varying(20) DEFAULT 'PENDING' NOT NULL,
    approved_by         uuid,
    decided_at          timestamp with time zone,
    rejection_reason    character varying(300),
    is_deleted          boolean DEFAULT false NOT NULL,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    updated_at          timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT attendance_regularization_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_att_reg_user ON public.attendance_regularization (org_id, user_id, work_date);
CREATE INDEX idx_att_reg_status ON public.attendance_regularization (org_id, status);
