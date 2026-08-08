-- Supplier is a procurement role projection of one unified Contact.
-- A contact may be a customer, vendor, or both, but it must have at most one
-- active supplier projection so concurrent enable requests cannot duplicate it.
CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_org_contact_active
    ON public.supplier (org_id, contact_id)
    WHERE contact_id IS NOT NULL AND is_deleted = FALSE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'supplier_contact_id_fkey'
          AND conrelid = 'public.supplier'::regclass
    ) THEN
        ALTER TABLE public.supplier
            ADD CONSTRAINT supplier_contact_id_fkey
            FOREIGN KEY (contact_id) REFERENCES public.contact(id);
    END IF;
END $$;
