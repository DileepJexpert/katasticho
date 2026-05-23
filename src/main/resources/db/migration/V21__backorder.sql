-- Pharmacy / backorder workflow — no new tables, column additions only.

-- 1. Extend the status check constraint to allow BACKORDER.
--    PostgreSQL auto-names inline check constraints; use a DO block so
--    the migration works regardless of the exact auto-generated name.
DO $$
DECLARE v_name text;
BEGIN
    -- Drop any existing status check constraint (auto-named or explicit)
    FOR v_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'public.sales_order'::regclass
          AND contype = 'c'
          AND (conname LIKE '%status%'
               OR pg_get_constraintdef(oid) LIKE '%status%')
    LOOP
        EXECUTE format('ALTER TABLE sales_order DROP CONSTRAINT %I', v_name);
    END LOOP;

    -- Re-add with BACKORDER included
    EXECUTE 'ALTER TABLE sales_order
        ADD CONSTRAINT sales_order_status_check
            CHECK (status IN (
                ''DRAFT'', ''CONFIRMED'', ''BACKORDER'',
                ''PARTIALLY_SHIPPED'', ''SHIPPED'',
                ''PARTIALLY_INVOICED'', ''INVOICED'',
                ''COMPLETED'', ''CANCELLED'', ''VOID''
            ))';
END $$;

-- 2. Flag on the order header — opt-in, default false so existing behaviour
--    is completely unchanged.
ALTER TABLE sales_order
    ADD COLUMN IF NOT EXISTS allow_backorder BOOLEAN NOT NULL DEFAULT FALSE;

-- 3. Per-line backorder quantity — how much of the requested quantity is
--    waiting for a future GRN.  Zero means fully reserved (normal path).
ALTER TABLE sales_order_line
    ADD COLUMN IF NOT EXISTS quantity_backordered NUMERIC(12, 4) NOT NULL DEFAULT 0;

-- 4. Index so the GRN auto-fulfillment query (item × BACKORDER SOs) is fast.
CREATE INDEX IF NOT EXISTS idx_so_line_backorder
    ON sales_order_line (item_id)
    WHERE quantity_backordered > 0;
