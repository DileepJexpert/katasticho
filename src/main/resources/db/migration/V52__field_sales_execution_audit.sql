-- V52: Structured immutable audit table for field-sales admin execution overrides.
-- Rows are written once (INSERT only) by FieldSalesService when an OWNER/ADMIN
-- bypasses normal assignment or van validation.  Application code never UPDATEs
-- or DELETEs these rows.

CREATE TABLE field_sales_execution_audit (
    id               UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id           UUID        NOT NULL,
    execution_id     UUID        NOT NULL,
    actor_id         UUID        NOT NULL,
    salesperson_id   UUID        NOT NULL,
    route_id         UUID        NOT NULL,
    van_id           UUID,
    execution_date   DATE        NOT NULL,
    override_type    VARCHAR(30) NOT NULL,   -- ROUTE_UNASSIGNED | VAN_MISMATCH | BOTH
    override_reason  VARCHAR(1000) NOT NULL,
    audited_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast lookups by execution and by salesperson
CREATE INDEX idx_fs_exec_audit_execution ON field_sales_execution_audit (org_id, execution_id);
CREATE INDEX idx_fs_exec_audit_salesperson ON field_sales_execution_audit (org_id, salesperson_id);
