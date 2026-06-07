-- V46: Manufacturing Tier 1 — Routing/Operations, Job Work, Quality Control, Scrap
-- Adds 15 tables + work_order enhancements for Tier 1 manufacturing features

-- ===== 1. WORKSTATIONS =====
CREATE TABLE IF NOT EXISTS workstation (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    code          VARCHAR(30)  NOT NULL,
    name          VARCHAR(100) NOT NULL,
    description   TEXT,
    hourly_rate   NUMERIC(15,2) DEFAULT 0,
    capacity_hours_per_day NUMERIC(5,2) DEFAULT 8,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_workstation_org ON workstation(org_id) WHERE NOT is_deleted;

-- ===== 2. OPERATIONS =====
CREATE TABLE IF NOT EXISTS operation (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    code          VARCHAR(30)  NOT NULL,
    name          VARCHAR(100) NOT NULL,
    description   TEXT,
    default_workstation_id UUID REFERENCES workstation(id),
    setup_time_minutes     INT DEFAULT 0,
    run_time_minutes_per_unit NUMERIC(10,2) DEFAULT 0,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_operation_org ON operation(org_id) WHERE NOT is_deleted;

-- ===== 3. ROUTING =====
CREATE TABLE IF NOT EXISTS routing (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    name          VARCHAR(100) NOT NULL,
    item_id       UUID,
    is_default    BOOLEAN DEFAULT FALSE,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_routing_org_item ON routing(org_id, item_id) WHERE NOT is_deleted;

CREATE TABLE IF NOT EXISTS routing_operation (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    routing_id    UUID NOT NULL REFERENCES routing(id),
    operation_id  UUID NOT NULL REFERENCES operation(id),
    workstation_id UUID REFERENCES workstation(id),
    sequence_number INT NOT NULL,
    setup_time_override INT,
    run_time_override   NUMERIC(10,2),
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_routing_op_routing ON routing_operation(routing_id) WHERE NOT is_deleted;

-- ===== 4. JOB CARDS =====
CREATE TABLE IF NOT EXISTS job_card (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    work_order_id UUID NOT NULL REFERENCES work_order(id),
    operation_id  UUID NOT NULL REFERENCES operation(id),
    workstation_id UUID REFERENCES workstation(id),
    sequence_number INT NOT NULL,
    assigned_to   UUID,
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    planned_start TIMESTAMPTZ,
    planned_end   TIMESTAMPTZ,
    actual_start  TIMESTAMPTZ,
    actual_end    TIMESTAMPTZ,
    planned_qty   NUMERIC(15,4) DEFAULT 0,
    completed_qty NUMERIC(15,4) DEFAULT 0,
    scrap_qty     NUMERIC(15,4) DEFAULT 0,
    time_logged_minutes INT DEFAULT 0,
    notes         TEXT,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_job_card_wo ON job_card(work_order_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_job_card_assigned ON job_card(org_id, assigned_to) WHERE NOT is_deleted;

-- ===== 5. JOB WORK / SUBCONTRACTING =====
CREATE TABLE IF NOT EXISTS job_work_order (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    job_work_number VARCHAR(20) NOT NULL,
    vendor_id     UUID NOT NULL,
    warehouse_id  UUID NOT NULL,
    work_order_id UUID REFERENCES work_order(id),
    status        VARCHAR(30)  NOT NULL DEFAULT 'DRAFT',
    processing_charges   NUMERIC(15,2) DEFAULT 0,
    total_material_cost  NUMERIC(15,2) DEFAULT 0,
    total_cost           NUMERIC(15,2) DEFAULT 0,
    challan_number       VARCHAR(30),
    planned_send_date    DATE,
    planned_return_date  DATE,
    actual_send_date     DATE,
    actual_return_date   DATE,
    gst_return_deadline  DATE,
    notes         TEXT,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_jwo_org_status ON job_work_order(org_id, status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_jwo_org_vendor ON job_work_order(org_id, vendor_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_jwo_gst_deadline ON job_work_order(org_id, gst_return_deadline) WHERE NOT is_deleted AND gst_return_deadline IS NOT NULL;

CREATE TABLE IF NOT EXISTS job_work_order_line (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    job_work_order_id UUID NOT NULL REFERENCES job_work_order(id),
    item_id       UUID NOT NULL,
    line_type     VARCHAR(10)  NOT NULL DEFAULT 'MATERIAL',
    sent_qty      NUMERIC(15,4) DEFAULT 0,
    received_qty  NUMERIC(15,4) DEFAULT 0,
    wastage_qty   NUMERIC(15,4) DEFAULT 0,
    unit_cost     NUMERIC(15,4) DEFAULT 0,
    line_cost     NUMERIC(15,2) DEFAULT 0,
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_jwol_order ON job_work_order_line(job_work_order_id) WHERE NOT is_deleted;

-- ===== 6. QUALITY CONTROL =====
CREATE TABLE IF NOT EXISTS qc_template (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    name          VARCHAR(100) NOT NULL,
    item_id       UUID,
    inspection_type VARCHAR(20) NOT NULL DEFAULT 'INCOMING',
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_qc_template_org ON qc_template(org_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_qc_template_item ON qc_template(org_id, item_id) WHERE NOT is_deleted AND item_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS qc_parameter (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    template_id   UUID NOT NULL REFERENCES qc_template(id),
    name          VARCHAR(100) NOT NULL,
    description   TEXT,
    parameter_type VARCHAR(20) NOT NULL DEFAULT 'NUMERIC',
    unit          VARCHAR(20),
    min_value     NUMERIC(15,4),
    max_value     NUMERIC(15,4),
    acceptable_values TEXT,
    is_mandatory  BOOLEAN NOT NULL DEFAULT TRUE,
    sequence_number INT NOT NULL DEFAULT 1,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_qc_param_template ON qc_parameter(template_id) WHERE NOT is_deleted;

CREATE TABLE IF NOT EXISTS qc_inspection (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    inspection_number VARCHAR(20) NOT NULL,
    template_id   UUID REFERENCES qc_template(id),
    inspection_type VARCHAR(20) NOT NULL,
    reference_type  VARCHAR(30),
    reference_id    UUID,
    item_id       UUID NOT NULL,
    batch_id      UUID,
    inspected_qty NUMERIC(15,4),
    accepted_qty  NUMERIC(15,4),
    rejected_qty  NUMERIC(15,4),
    status        VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    inspector_id  UUID,
    inspected_at  TIMESTAMPTZ,
    notes         TEXT,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_qc_insp_org ON qc_inspection(org_id, status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_qc_insp_ref ON qc_inspection(reference_type, reference_id) WHERE NOT is_deleted;

CREATE TABLE IF NOT EXISTS qc_inspection_result (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    inspection_id UUID NOT NULL REFERENCES qc_inspection(id),
    parameter_id  UUID NOT NULL REFERENCES qc_parameter(id),
    measured_value VARCHAR(100),
    numeric_value  NUMERIC(15,4),
    is_passed     BOOLEAN,
    notes         TEXT,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_qc_result_insp ON qc_inspection_result(inspection_id) WHERE NOT is_deleted;

-- ===== 7. SCRAP =====
CREATE TABLE IF NOT EXISTS scrap_reason_code (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    code          VARCHAR(30)  NOT NULL,
    description   VARCHAR(200) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_scrap_reason_org ON scrap_reason_code(org_id) WHERE NOT is_deleted;

CREATE TABLE IF NOT EXISTS production_scrap (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    work_order_id UUID NOT NULL REFERENCES work_order(id),
    job_card_id   UUID REFERENCES job_card(id),
    item_id       UUID NOT NULL,
    scrap_qty     NUMERIC(15,4) NOT NULL,
    unit_cost     NUMERIC(15,4) DEFAULT 0,
    scrap_cost    NUMERIC(15,2) DEFAULT 0,
    reason_code_id UUID REFERENCES scrap_reason_code(id),
    notes         TEXT,
    scrapped_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_prod_scrap_wo ON production_scrap(work_order_id) WHERE NOT is_deleted;

-- ===== 8. WORK ORDER ENHANCEMENTS =====
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS sales_order_id UUID;
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS routing_id UUID;
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS priority VARCHAR(10) DEFAULT 'NORMAL';
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS scrap_qty NUMERIC(15,4) DEFAULT 0;
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS scrap_cost NUMERIC(15,2) DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_wo_sales_order ON work_order(sales_order_id) WHERE NOT is_deleted AND sales_order_id IS NOT NULL;
