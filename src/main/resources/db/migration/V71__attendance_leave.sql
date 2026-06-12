-- V71: Attendance + leave for field/office staff (all verticals)
-- GPS-stamped punch in/out, one row per user per day; simple leave
-- request lifecycle. Attendance feeds payroll LOP review later.

CREATE TABLE field_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    user_id UUID NOT NULL,
    work_date DATE NOT NULL,
    punch_in_at TIMESTAMPTZ,
    punch_in_latitude DECIMAL(10,7),
    punch_in_longitude DECIMAL(10,7),
    punch_out_at TIMESTAMPTZ,
    punch_out_latitude DECIMAL(10,7),
    punch_out_longitude DECIMAL(10,7),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_attendance_day ON field_attendance(org_id, user_id, work_date);
CREATE INDEX idx_attendance_org_date ON field_attendance(org_id, work_date);

CREATE TABLE leave_request (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    user_id UUID NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    leave_type VARCHAR(20) NOT NULL DEFAULT 'CASUAL',  -- CASUAL / SICK / EARNED / UNPAID
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',     -- PENDING / APPROVED / REJECTED / CANCELLED
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    rejection_reason VARCHAR(300),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_leave_org_user ON leave_request(org_id, user_id);
CREATE INDEX idx_leave_org_status ON leave_request(org_id, status);
