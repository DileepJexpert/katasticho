-- ============================================================================
-- V20: Manufacturing — Maintenance Management.
--
-- Two tables hanging off workstation:
-- (1) maintenance_schedule  preventive schedule per workstation, frequency_days
--     + next_due_date. Rolling forward when each scheduled WO completes.
-- (2) maintenance_work_order  each maintenance event (planned PREVENTIVE /
--     unplanned BREAKDOWN / scheduled INSPECTION). Downtime computed from
--     started_at - completed_at and rolled into the downtime report.
-- ============================================================================

CREATE TABLE public.maintenance_schedule (
    id                    uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                uuid NOT NULL,
    workstation_id        uuid NOT NULL,
    code                  varchar(50)  NOT NULL,
    title                 varchar(200) NOT NULL,
    description           text,
    frequency_days        integer NOT NULL,
    last_completed_date   date,
    next_due_date         date NOT NULL,
    estimated_duration_min integer,
    assigned_to_user_id   uuid,
    is_active             boolean DEFAULT true NOT NULL,
    is_deleted            boolean DEFAULT false NOT NULL,
    created_at            timestamp with time zone DEFAULT now() NOT NULL,
    updated_at            timestamp with time zone DEFAULT now() NOT NULL,
    created_by            uuid,
    CONSTRAINT maintenance_schedule_pkey PRIMARY KEY (id),
    CONSTRAINT maintenance_schedule_freq_check CHECK (frequency_days > 0),
    CONSTRAINT maintenance_schedule_code_uniq UNIQUE (org_id, code)
);
CREATE INDEX idx_maintenance_schedule_ws  ON public.maintenance_schedule (org_id, workstation_id);
CREATE INDEX idx_maintenance_schedule_due ON public.maintenance_schedule (org_id, next_due_date)
    WHERE is_active = true AND is_deleted = false;

CREATE TABLE public.maintenance_work_order (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    mwo_number          varchar(30) NOT NULL,
    workstation_id      uuid NOT NULL,
    schedule_id         uuid,
    maintenance_type    varchar(20) NOT NULL,       -- PREVENTIVE|BREAKDOWN|INSPECTION
    status              varchar(20) DEFAULT 'DRAFT' NOT NULL,  -- DRAFT|IN_PROGRESS|COMPLETED|CANCELLED
    priority            varchar(10) DEFAULT 'NORMAL' NOT NULL, -- URGENT|HIGH|NORMAL|LOW
    title               varchar(200) NOT NULL,
    description         text,
    reported_at         timestamp with time zone DEFAULT now() NOT NULL,
    started_at          timestamp with time zone,
    completed_at        timestamp with time zone,
    downtime_minutes    integer,
    cost                numeric(15,2),
    assigned_to_user_id uuid,
    completed_by        uuid,
    completion_notes    text,
    is_deleted          boolean DEFAULT false NOT NULL,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    updated_at          timestamp with time zone DEFAULT now() NOT NULL,
    created_by          uuid,
    CONSTRAINT maintenance_work_order_pkey PRIMARY KEY (id),
    CONSTRAINT maintenance_work_order_number_uniq UNIQUE (org_id, mwo_number),
    CONSTRAINT maintenance_work_order_type_check
        CHECK (maintenance_type IN ('PREVENTIVE','BREAKDOWN','INSPECTION')),
    CONSTRAINT maintenance_work_order_status_check
        CHECK (status IN ('DRAFT','IN_PROGRESS','COMPLETED','CANCELLED')),
    CONSTRAINT maintenance_work_order_priority_check
        CHECK (priority IN ('URGENT','HIGH','NORMAL','LOW'))
);
CREATE INDEX idx_mwo_ws       ON public.maintenance_work_order (org_id, workstation_id);
CREATE INDEX idx_mwo_status   ON public.maintenance_work_order (org_id, status);
CREATE INDEX idx_mwo_schedule ON public.maintenance_work_order (org_id, schedule_id)
    WHERE schedule_id IS NOT NULL;
CREATE INDEX idx_mwo_reported ON public.maintenance_work_order (org_id, reported_at);
