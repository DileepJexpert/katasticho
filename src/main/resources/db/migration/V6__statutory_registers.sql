-- ─────────────────────────────────────────────────────────────────────────────
-- V6 — Statutory pharma registers (Schedule H1 / Schedule X / Narcotics).
--
-- WHY: Drugs & Cosmetics Rules require Forms 20B/21B/20G holders to maintain
-- SEPARATE statutory registers for these schedules — prescriber + patient +
-- drug + qty per sale — retained 3y (H1) / 2y (Schedule X, Narcotics). The
-- existing PrescriptionRecord captures one-off Rx data for a sale, but the
-- separate inspector-ready register is what Rule 65(11)(h) actually mandates.
-- Without it, a drug-inspector visit fails. Auto-populated on POS sale of any
-- item whose drug_schedule ∈ {H1, SCHEDULE_X, NARCOTICS}.
--
-- Either sale_receipt_id OR invoice_id is required (CHECK). Both can be set
-- if a credit-invoice scenario ever links to a receipt; today only POS receipts
-- write here, so invoice_id will populate later when wholesale flows opt in.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.statutory_register_entry (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                   UUID NOT NULL,
    register_type            VARCHAR(20) NOT NULL
        CHECK (register_type IN ('H1', 'SCHEDULE_X', 'NARCOTICS')),
    sale_receipt_id          UUID,
    invoice_id               UUID,
    item_id                  UUID NOT NULL,
    drug_name                VARCHAR(255) NOT NULL,
    batch_id                 UUID,
    batch_number             VARCHAR(100),
    quantity                 NUMERIC(15, 4) NOT NULL,
    sale_date                DATE NOT NULL,
    retention_until          DATE NOT NULL,
    prescriber_name          VARCHAR(255),
    prescriber_reg_number    VARCHAR(100),
    prescriber_address       TEXT,
    patient_name             VARCHAR(255),
    patient_address          TEXT,
    patient_phone            VARCHAR(20),
    notes                    TEXT,
    is_deleted               BOOLEAN NOT NULL DEFAULT FALSE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by               UUID,
    CONSTRAINT statutory_register_entry_link_required
        CHECK (sale_receipt_id IS NOT NULL OR invoice_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_statutory_reg_org_type_date
    ON public.statutory_register_entry (org_id, register_type, sale_date DESC)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_statutory_reg_retention
    ON public.statutory_register_entry (org_id, retention_until)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_statutory_reg_prescriber
    ON public.statutory_register_entry (org_id, prescriber_reg_number)
    WHERE is_deleted = FALSE AND prescriber_reg_number IS NOT NULL;
