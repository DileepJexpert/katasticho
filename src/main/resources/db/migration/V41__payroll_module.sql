-- Payroll module: 12 tables, organisation column addition, and indexes.

-- 1. Add salary_handling_mode to organisation
ALTER TABLE organisation
    ADD COLUMN IF NOT EXISTS salary_handling_mode VARCHAR(20) DEFAULT 'NONE';

-- 2. payroll_settings (one per org, NOT org-scoped BaseEntity)
CREATE TABLE payroll_settings (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                            UUID NOT NULL UNIQUE,
    payroll_start_month               DATE,
    pay_frequency                     VARCHAR(20) DEFAULT 'MONTHLY',
    default_salary_expense_account_id UUID,
    default_salary_payable_account_id UUID,
    default_pf_payable_account_id     UUID,
    default_esi_payable_account_id    UUID,
    default_pt_payable_account_id     UUID,
    default_lwf_payable_account_id    UUID,
    default_tds_payable_account_id    UUID,
    pf_enabled                        BOOLEAN NOT NULL DEFAULT false,
    esi_enabled                       BOOLEAN NOT NULL DEFAULT false,
    pt_enabled                        BOOLEAN NOT NULL DEFAULT false,
    lwf_enabled                       BOOLEAN NOT NULL DEFAULT false,
    tds_enabled                       BOOLEAN NOT NULL DEFAULT false,
    created_at                        TIMESTAMPTZ DEFAULT NOW(),
    updated_at                        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payroll_settings_org FOREIGN KEY (org_id) REFERENCES organisation(id)
);

-- 3. employee (org-scoped with is_deleted)
CREATE TABLE employee (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID NOT NULL,
    employee_code     VARCHAR(50),
    full_name         VARCHAR(255) NOT NULL,
    phone             VARCHAR(30),
    email             VARCHAR(255),
    designation       VARCHAR(100),
    department        VARCHAR(100),
    date_of_joining   DATE,
    date_of_exit      DATE,
    employment_status VARCHAR(20) DEFAULT 'ACTIVE',
    payment_mode      VARCHAR(20),
    bank_account_name VARCHAR(255),
    bank_account_number VARCHAR(50),
    bank_ifsc         VARCHAR(20),
    pan               VARCHAR(20),
    aadhaar_last4     VARCHAR(4),
    uan               VARCHAR(50),
    esi_number        VARCHAR(50),
    is_pf_applicable  BOOLEAN NOT NULL DEFAULT false,
    is_esi_applicable BOOLEAN NOT NULL DEFAULT false,
    is_pt_applicable  BOOLEAN NOT NULL DEFAULT false,
    is_lwf_applicable BOOLEAN NOT NULL DEFAULT false,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    is_deleted        BOOLEAN DEFAULT false,
    CONSTRAINT fk_employee_org FOREIGN KEY (org_id) REFERENCES organisation(id)
);

CREATE INDEX idx_employee_org ON employee(org_id);
CREATE INDEX idx_employee_org_status ON employee(org_id, employment_status) WHERE is_deleted = false;

-- 4. salary_component (org-scoped)
CREATE TABLE salary_component (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID NOT NULL,
    code           VARCHAR(50) NOT NULL,
    name           VARCHAR(100) NOT NULL,
    component_type VARCHAR(20) NOT NULL CHECK (component_type IN ('EARNING', 'DEDUCTION', 'EMPLOYER_CONTRIBUTION')),
    taxability     VARCHAR(30),
    is_statutory   BOOLEAN DEFAULT false,
    is_active      BOOLEAN DEFAULT true,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_salary_component_org FOREIGN KEY (org_id) REFERENCES organisation(id)
);

CREATE INDEX idx_salary_component_org ON salary_component(org_id);
CREATE UNIQUE INDEX idx_salary_component_org_code ON salary_component(org_id, code);

-- 5. employee_salary_structure (org-scoped)
CREATE TABLE employee_salary_structure (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID NOT NULL,
    employee_id    UUID NOT NULL,
    effective_from DATE NOT NULL,
    effective_to   DATE,
    ctc_monthly    NUMERIC(14,2),
    gross_monthly  NUMERIC(14,2),
    status         VARCHAR(20) DEFAULT 'ACTIVE',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_ess_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_ess_employee FOREIGN KEY (employee_id) REFERENCES employee(id)
);

CREATE INDEX idx_ess_org ON employee_salary_structure(org_id);
CREATE INDEX idx_ess_employee ON employee_salary_structure(employee_id);

-- 6. employee_salary_component (org-scoped)
CREATE TABLE employee_salary_component (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL,
    salary_structure_id UUID NOT NULL,
    salary_component_id UUID NOT NULL,
    calculation_type    VARCHAR(20) NOT NULL CHECK (calculation_type IN ('FIXED', 'PERCENTAGE', 'FORMULA')),
    amount              NUMERIC(14,2),
    percentage          NUMERIC(7,4),
    base_component_code VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_esc_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_esc_structure FOREIGN KEY (salary_structure_id) REFERENCES employee_salary_structure(id),
    CONSTRAINT fk_esc_component FOREIGN KEY (salary_component_id) REFERENCES salary_component(id)
);

CREATE INDEX idx_esc_structure ON employee_salary_component(salary_structure_id);

-- 7. payroll_run (org-scoped)
CREATE TABLE payroll_run (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                      UUID NOT NULL,
    period_start                DATE NOT NULL,
    period_end                  DATE NOT NULL,
    status                      VARCHAR(20) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'CALCULATED', 'APPROVED', 'POSTED', 'CANCELLED')),
    employee_count              INT DEFAULT 0,
    gross_total                 NUMERIC(14,2) DEFAULT 0,
    deduction_total             NUMERIC(14,2) DEFAULT 0,
    employer_contribution_total NUMERIC(14,2) DEFAULT 0,
    net_pay_total               NUMERIC(14,2) DEFAULT 0,
    journal_entry_id            UUID,
    created_by                  UUID,
    approved_by                 UUID,
    approved_at                 TIMESTAMPTZ,
    posted_at                   TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payroll_run_org FOREIGN KEY (org_id) REFERENCES organisation(id)
);

CREATE INDEX idx_payroll_run_org ON payroll_run(org_id);
CREATE INDEX idx_payroll_run_org_period ON payroll_run(org_id, period_start, period_end);

-- 8. payslip (org-scoped)
CREATE TABLE payslip (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                 UUID NOT NULL,
    payroll_run_id         UUID NOT NULL,
    employee_id            UUID NOT NULL,
    gross_pay              NUMERIC(14,2) DEFAULT 0,
    total_deductions       NUMERIC(14,2) DEFAULT 0,
    employer_contributions NUMERIC(14,2) DEFAULT 0,
    net_pay                NUMERIC(14,2) DEFAULT 0,
    status                 VARCHAR(20) DEFAULT 'DRAFT',
    pdf_url                TEXT,
    created_at             TIMESTAMPTZ DEFAULT NOW(),
    updated_at             TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payslip_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_payslip_run FOREIGN KEY (payroll_run_id) REFERENCES payroll_run(id),
    CONSTRAINT fk_payslip_employee FOREIGN KEY (employee_id) REFERENCES employee(id)
);

CREATE INDEX idx_payslip_run ON payslip(payroll_run_id);
CREATE INDEX idx_payslip_employee ON payslip(employee_id);

-- 9. payslip_line (org-scoped)
CREATE TABLE payslip_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL,
    payslip_id          UUID NOT NULL,
    salary_component_id UUID NOT NULL,
    component_type      VARCHAR(20) NOT NULL,
    amount              NUMERIC(14,2) NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payslip_line_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_payslip_line_payslip FOREIGN KEY (payslip_id) REFERENCES payslip(id),
    CONSTRAINT fk_payslip_line_component FOREIGN KEY (salary_component_id) REFERENCES salary_component(id)
);

CREATE INDEX idx_payslip_line_payslip ON payslip_line(payslip_id);

-- 10. payroll_payment (org-scoped)
CREATE TABLE payroll_payment (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id             UUID NOT NULL,
    payroll_run_id     UUID NOT NULL,
    payment_date       DATE NOT NULL,
    payment_account_id UUID NOT NULL,
    amount             NUMERIC(14,2) NOT NULL,
    payment_mode       VARCHAR(30),
    reference_number   VARCHAR(100),
    journal_entry_id   UUID,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payroll_payment_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_payroll_payment_run FOREIGN KEY (payroll_run_id) REFERENCES payroll_run(id)
);

CREATE INDEX idx_payroll_payment_run ON payroll_payment(payroll_run_id);

-- 11. statutory_payment (org-scoped)
CREATE TABLE statutory_payment (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id             UUID NOT NULL,
    statutory_type     VARCHAR(20) NOT NULL,
    period_label       VARCHAR(20),
    due_date           DATE,
    payment_date       DATE,
    amount             NUMERIC(14,2) NOT NULL,
    payment_account_id UUID,
    reference_number   VARCHAR(100),
    status             VARCHAR(20) DEFAULT 'PENDING',
    journal_entry_id   UUID,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_statutory_payment_org FOREIGN KEY (org_id) REFERENCES organisation(id)
);

CREATE INDEX idx_statutory_payment_org ON statutory_payment(org_id);
CREATE INDEX idx_statutory_payment_org_type ON statutory_payment(org_id, statutory_type);

-- 12. payroll_audit_log (org-scoped)
CREATE TABLE payroll_audit_log (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID NOT NULL,
    entity_type  VARCHAR(50) NOT NULL,
    entity_id    UUID NOT NULL,
    action       VARCHAR(50) NOT NULL,
    old_value    JSONB,
    new_value    JSONB,
    performed_by UUID,
    performed_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payroll_audit_org FOREIGN KEY (org_id) REFERENCES organisation(id)
);

CREATE INDEX idx_payroll_audit_org ON payroll_audit_log(org_id);
CREATE INDEX idx_payroll_audit_entity ON payroll_audit_log(entity_type, entity_id);

-- 13. payroll_document_snapshot (org-scoped)
CREATE TABLE payroll_document_snapshot (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID NOT NULL,
    payroll_run_id UUID NOT NULL,
    snapshot_json  JSONB NOT NULL,
    snapshot_hash  VARCHAR(128),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_payroll_snapshot_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_payroll_snapshot_run FOREIGN KEY (payroll_run_id) REFERENCES payroll_run(id)
);

CREATE INDEX idx_payroll_snapshot_run ON payroll_document_snapshot(payroll_run_id);
