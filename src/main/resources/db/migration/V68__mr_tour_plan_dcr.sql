-- V68: Pharma MR reporting — doctor/chemist classification, tour plans (MTP), DCR
-- Phase 1 of the MR (medical representative) pack on top of the field-sales module.

-- Doctor/chemist/stockist classification on contact (all nullable — non-pharma orgs unaffected)
ALTER TABLE contact ADD COLUMN medical_category VARCHAR(20);   -- DOCTOR / CHEMIST / STOCKIST / HOSPITAL
ALTER TABLE contact ADD COLUMN specialty VARCHAR(100);         -- e.g. Cardiologist, Pediatrician
ALTER TABLE contact ADD COLUMN mr_class VARCHAR(5);            -- A / B / C visit-priority class
ALTER TABLE contact ADD COLUMN visits_per_month INT;           -- required call frequency

-- Monthly tour plan (MTP): MR proposes, manager approves
CREATE TABLE tour_plan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    plan_month DATE NOT NULL,                      -- first day of the month
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',   -- DRAFT / SUBMITTED / APPROVED / REJECTED
    notes TEXT,
    submitted_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    rejection_reason VARCHAR(300),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_tour_plan_month ON tour_plan(org_id, salesperson_id, plan_month)
    WHERE is_deleted = FALSE;

CREATE TABLE tour_plan_entry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    tour_plan_id UUID NOT NULL REFERENCES tour_plan(id),
    plan_date DATE NOT NULL,
    activity_type VARCHAR(20) NOT NULL DEFAULT 'FIELD_WORK',  -- FIELD_WORK / MEETING / OFFICE / CAMP / LEAVE
    beat_id UUID,
    area VARCHAR(150),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_tpe_plan ON tour_plan_entry(org_id, tour_plan_id);

-- Daily Call Report: one per salesperson per day, summarised from field visits
CREATE TABLE dcr_report (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    report_date DATE NOT NULL,
    route_execution_id UUID,
    work_type VARCHAR(20) NOT NULL DEFAULT 'FIELD_WORK',
    doctors_visited INT NOT NULL DEFAULT 0,
    chemists_visited INT NOT NULL DEFAULT 0,
    others_visited INT NOT NULL DEFAULT 0,
    total_visits INT NOT NULL DEFAULT 0,
    total_pob NUMERIC(14,2) NOT NULL DEFAULT 0,
    samples_given INT NOT NULL DEFAULT 0,
    remarks TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',   -- DRAFT / SUBMITTED / APPROVED / REJECTED
    submitted_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    rejection_reason VARCHAR(300),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_dcr_day ON dcr_report(org_id, salesperson_id, report_date)
    WHERE is_deleted = FALSE;
CREATE INDEX idx_dcr_status ON dcr_report(org_id, status);

-- Products detailed / samples / gifts given during a visit (the DCR line detail)
CREATE TABLE visit_product_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    field_visit_id UUID NOT NULL,
    item_id UUID,
    product_name VARCHAR(200) NOT NULL,
    detailed BOOLEAN NOT NULL DEFAULT TRUE,
    sample_qty INT NOT NULL DEFAULT 0,
    gift_name VARCHAR(150),
    gift_qty INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_vpl_visit ON visit_product_log(org_id, field_visit_id);

-- Joint visit (manager working with the MR)
ALTER TABLE field_visit ADD COLUMN joint_visit_user_id UUID;
