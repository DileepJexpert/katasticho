-- V58: Subcontracting & Job Work Statutory Register (Challan 45 / GST ITC-04)

CREATE TABLE IF NOT EXISTS public.job_work_order (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    job_worker_id UUID NOT NULL REFERENCES public.contact(id),
    order_date DATE NOT NULL,
    expected_return_date DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', -- DRAFT | ISSUED | PARTIALLY_RECEIVED | COMPLETED | CANCELLED
    process_description VARCHAR(255),
    total_issued_value NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    total_received_value NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_jwo_org_status ON public.job_work_order(org_id, status, is_deleted);
CREATE INDEX IF NOT EXISTS idx_jwo_org_worker ON public.job_work_order(org_id, job_worker_id, is_deleted);

CREATE TABLE IF NOT EXISTS public.job_work_issue_line (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    job_work_order_id UUID NOT NULL REFERENCES public.job_work_order(id),
    challan_number VARCHAR(50) NOT NULL,
    challan_date DATE NOT NULL,
    item_id UUID NOT NULL REFERENCES public.item(id),
    hsn_code VARCHAR(20),
    uom VARCHAR(20) NOT NULL DEFAULT 'PCS',
    issued_quantity NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    returned_quantity NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    unit_rate NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    taxable_value NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    nature_of_processing VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_jwi_org_order ON public.job_work_issue_line(org_id, job_work_order_id, is_deleted);

CREATE TABLE IF NOT EXISTS public.job_work_receipt_line (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    job_work_order_id UUID NOT NULL REFERENCES public.job_work_order(id),
    inward_challan_number VARCHAR(50) NOT NULL,
    receipt_date DATE NOT NULL,
    finished_item_id UUID NOT NULL REFERENCES public.item(id),
    uom VARCHAR(20) NOT NULL DEFAULT 'PCS',
    received_quantity NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    consumed_raw_item_id UUID REFERENCES public.item(id),
    consumed_quantity NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    scrap_quantity NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    job_work_charges NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    notes VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_jwr_org_order ON public.job_work_receipt_line(org_id, job_work_order_id, is_deleted);
