-- V56: Biometric Attendance Devices (ZKTeco / eSSL TCP & Cloud ADMS Push)
CREATE TABLE IF NOT EXISTS public.biometric_device (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    device_name VARCHAR(100) NOT NULL,
    device_ip VARCHAR(50),
    port INT DEFAULT 4370,
    serial_number VARCHAR(100),
    protocol VARCHAR(20) NOT NULL DEFAULT 'ZK_TCP',
    location VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'ONLINE',
    last_sync_at TIMESTAMPTZ,
    cloud_webhook_token VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_biometric_device_org ON public.biometric_device(org_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_biometric_device_webhook ON public.biometric_device(cloud_webhook_token);

CREATE TABLE IF NOT EXISTS public.biometric_attendance_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    device_id UUID REFERENCES public.biometric_device(id),
    employee_id UUID REFERENCES public.employee(id),
    biometric_pin VARCHAR(50) NOT NULL,
    punch_time TIMESTAMPTZ NOT NULL,
    punch_type VARCHAR(20) NOT NULL DEFAULT 'CHECK_IN',
    verify_mode VARCHAR(20) DEFAULT 'FINGERPRINT',
    sync_status VARCHAR(20) NOT NULL DEFAULT 'PROCESSED',
    raw_payload TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_biometric_log_org ON public.biometric_attendance_log(org_id, punch_time DESC);
CREATE INDEX IF NOT EXISTS idx_biometric_log_employee ON public.biometric_attendance_log(org_id, employee_id, punch_time);
CREATE INDEX IF NOT EXISTS idx_biometric_log_pin ON public.biometric_attendance_log(org_id, biometric_pin);

-- Add biometric_pin column to employee table
ALTER TABLE public.employee
    ADD COLUMN IF NOT EXISTS biometric_pin VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_employee_biometric_pin ON public.employee(org_id, biometric_pin);
