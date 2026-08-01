-- The immutable stock ledger names its reversal flag is_reversal.
CREATE OR REPLACE FUNCTION refresh_job_work_material_cost()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    material_total NUMERIC(15,2);
BEGIN
    IF NEW.status = 'SENT' AND OLD.status <> 'SENT' THEN
        SELECT COALESCE(SUM(ABS(total_cost)), 0)
        INTO material_total
        FROM stock_movement
        WHERE org_id = NEW.org_id
          AND reference_type = 'JOB_WORK_ORDER'
          AND reference_id = NEW.id
          AND movement_type = 'JOB_WORK_OUT'
          AND COALESCE(is_reversal, false) = false;

        UPDATE job_work_order
        SET total_material_cost = material_total,
            total_cost = material_total + COALESCE(processing_charges, 0)
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;
