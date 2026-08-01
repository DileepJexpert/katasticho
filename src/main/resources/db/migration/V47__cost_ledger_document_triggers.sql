-- Populate the costing explanation ledger from the existing document lifecycle.
-- These triggers are intentionally additive: stock_movement remains the
-- authoritative valuation ledger and this ledger only explains its cost.

CREATE OR REPLACE FUNCTION populate_receipt_cost_event()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    event_id UUID;
    total_charges NUMERIC(15,2);
    basis VARCHAR(30);
    line RECORD;
    addition NUMERIC(15,6);
BEGIN
    IF NEW.status <> 'RECEIVED' OR OLD.status = 'RECEIVED' THEN
        RETURN NEW;
    END IF;

    total_charges := COALESCE(NEW.freight_amount, 0)
        + COALESCE(NEW.duty_amount, 0)
        + COALESCE(NEW.insurance_amount, 0)
        + COALESCE(NEW.other_charges, 0);
    IF total_charges <= 0 THEN
        RETURN NEW;
    END IF;

    basis := CASE WHEN EXISTS (
        SELECT 1 FROM stock_receipt_line
        WHERE receipt_id = NEW.id AND COALESCE(taxable_amount, 0) > 0
    ) THEN 'TAXABLE_VALUE' ELSE 'QUANTITY' END;

    INSERT INTO inventory_cost_event (
        org_id, event_number, event_type, source_type, source_id,
        source_number, warehouse_id, total_amount, allocation_basis,
        status, notes, created_by
    ) VALUES (
        NEW.org_id,
        'IC-GRN-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
        'LANDED_COST', 'STOCK_RECEIPT', NEW.id, NEW.receipt_number,
        NEW.warehouse_id, total_charges, basis, 'POSTED',
        'Inbound landed cost for GRN ' || NEW.receipt_number, NEW.received_by
    ) RETURNING id INTO event_id;

    IF COALESCE(NEW.freight_amount, 0) > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'FREIGHT', 'Inbound freight', NEW.freight_amount,
                'STOCK_RECEIPT', NEW.id);
    END IF;
    IF COALESCE(NEW.duty_amount, 0) > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'DUTY', 'Import/customs duty', NEW.duty_amount,
                'STOCK_RECEIPT', NEW.id);
    END IF;
    IF COALESCE(NEW.insurance_amount, 0) > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'INSURANCE', 'Inbound insurance', NEW.insurance_amount,
                'STOCK_RECEIPT', NEW.id);
    END IF;
    IF COALESCE(NEW.other_charges, 0) > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'OTHER', 'Other inbound charges', NEW.other_charges,
                'STOCK_RECEIPT', NEW.id);
    END IF;

    FOR line IN
        SELECT l.*, m.id AS movement_id, m.batch_id AS movement_batch_id,
               m.item_id AS movement_item_id
        FROM stock_receipt_line l
        JOIN stock_movement m ON m.id = l.stock_movement_id
        WHERE l.receipt_id = NEW.id
    LOOP
        addition := GREATEST(COALESCE(line.landed_unit_cost, line.unit_price)
                             - COALESCE(line.unit_price, 0), 0);
        IF addition > 0 AND line.quantity > 0 THEN
            INSERT INTO inventory_cost_allocation (
                org_id, event_id, stock_movement_id, item_id, batch_id,
                quantity, allocated_amount, unit_cost_addition
            ) VALUES (
                NEW.org_id, event_id, line.movement_id, line.movement_item_id,
                line.movement_batch_id, line.quantity,
                ROUND(addition * line.quantity, 2), addition
            );

            -- The receipt service already applies the landed amount to the
            -- stock movement. Keep the batch master aligned as well.
            IF line.movement_batch_id IS NOT NULL THEN
                UPDATE stock_batch
                SET unit_cost = COALESCE(line.landed_unit_cost, line.unit_price)
                WHERE id = line.movement_batch_id;
            END IF;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_receipt_cost_event ON stock_receipt;
CREATE TRIGGER trg_receipt_cost_event
AFTER UPDATE OF status ON stock_receipt
FOR EACH ROW EXECUTE FUNCTION populate_receipt_cost_event();

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
          AND COALESCE(reversal, false) = false;

        UPDATE job_work_order
        SET total_material_cost = material_total,
            total_cost = material_total + COALESCE(processing_charges, 0)
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_job_work_refresh_cost ON job_work_order;
CREATE TRIGGER trg_job_work_refresh_cost
AFTER UPDATE OF status ON job_work_order
FOR EACH ROW EXECUTE FUNCTION refresh_job_work_material_cost();

CREATE OR REPLACE FUNCTION create_job_work_output_cost_event()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    jwo RECORD;
    event_id UUID;
    raw_share NUMERIC(15,2);
    charge_share NUMERIC(15,2);
BEGIN
    IF NEW.movement_type <> 'JOB_WORK_IN'
       OR NEW.reference_type <> 'JOB_WORK_ORDER'
       OR NEW.quantity <= 0
       OR COALESCE(NEW.total_cost, 0) <= 0 THEN
        RETURN NEW;
    END IF;

    SELECT j.* INTO jwo
    FROM job_work_order j
    WHERE j.id = NEW.reference_id
      AND EXISTS (
          SELECT 1 FROM job_work_order_line l
          WHERE l.job_work_order_id = j.id
            AND l.line_type = 'OUTPUT'
            AND l.item_id = NEW.item_id
      );
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    INSERT INTO inventory_cost_event (
        org_id, event_number, event_type, source_type, source_id,
        source_number, warehouse_id, total_amount, allocation_basis,
        status, notes, created_by
    ) VALUES (
        NEW.org_id,
        'IC-JW-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
        'CONVERSION', 'JOB_WORK_RECEIPT', NEW.reference_id,
        NEW.reference_number, NEW.warehouse_id, NEW.total_cost,
        'OUTPUT_QUANTITY', 'POSTED', 'Job-work output cost', NEW.created_by
    ) RETURNING id INTO event_id;

    raw_share := CASE WHEN COALESCE(jwo.total_cost, 0) > 0
        THEN ROUND(NEW.total_cost * jwo.total_material_cost / jwo.total_cost, 2)
        ELSE NEW.total_cost END;
    charge_share := NEW.total_cost - raw_share;

    IF raw_share > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'RAW_MATERIAL', 'Material consumed by job work',
                raw_share, 'JOB_WORK_ORDER', NEW.reference_id);
    END IF;
    IF charge_share > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'JOB_WORK', 'External grinding/processing charge',
                charge_share, 'JOB_WORK_ORDER', NEW.reference_id);
    END IF;

    INSERT INTO inventory_cost_allocation (
        org_id, event_id, stock_movement_id, item_id, batch_id,
        quantity, allocated_amount, unit_cost_addition
    ) VALUES (
        NEW.org_id, event_id, NEW.id, NEW.item_id, NEW.batch_id,
        NEW.quantity, NEW.total_cost / NEW.quantity, 0
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_job_work_output_cost_event ON stock_movement;
CREATE TRIGGER trg_job_work_output_cost_event
AFTER INSERT ON stock_movement
FOR EACH ROW EXECUTE FUNCTION create_job_work_output_cost_event();

CREATE OR REPLACE FUNCTION create_production_cost_event()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    wo RECORD;
    event_id UUID;
    factor NUMERIC(15,8);
BEGIN
    IF NEW.movement_type <> 'PRODUCTION_RECEIVE'
       OR NEW.reference_type <> 'WORK_ORDER'
       OR NEW.quantity <= 0
       OR COALESCE(NEW.total_cost, 0) <= 0 THEN
        RETURN NEW;
    END IF;

    SELECT w.* INTO wo FROM work_order w WHERE w.id = NEW.reference_id;
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    factor := CASE WHEN COALESCE(wo.total_cost, 0) > 0
        THEN NEW.total_cost / wo.total_cost ELSE 1 END;

    INSERT INTO inventory_cost_event (
        org_id, event_number, event_type, source_type, source_id,
        source_number, warehouse_id, total_amount, allocation_basis,
        status, notes, created_by
    ) VALUES (
        NEW.org_id,
        'IC-WO-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
        'CONVERSION', 'WORK_ORDER_RECEIPT', NEW.reference_id,
        NEW.reference_number, NEW.warehouse_id, NEW.total_cost,
        'OUTPUT_QUANTITY', 'POSTED', 'Manufacturing output cost', NEW.created_by
    ) RETURNING id INTO event_id;

    IF COALESCE(wo.raw_material_cost, 0) * factor > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'RAW_MATERIAL', 'Material consumed in production',
                ROUND(wo.raw_material_cost * factor, 2), 'WORK_ORDER', NEW.reference_id);
    END IF;
    IF COALESCE(wo.direct_labor_cost, 0) * factor > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'PACKAGING_LABOR', 'Direct production/packing labour',
                ROUND(wo.direct_labor_cost * factor, 2), 'WORK_ORDER', NEW.reference_id);
    END IF;
    IF COALESCE(wo.overhead_cost, 0) * factor > 0 THEN
        INSERT INTO inventory_cost_component
            (org_id, event_id, component_type, description, amount, source_type, source_id)
        VALUES (NEW.org_id, event_id, 'OVERHEAD', 'Manufacturing overhead',
                ROUND(wo.overhead_cost * factor, 2), 'WORK_ORDER', NEW.reference_id);
    END IF;

    INSERT INTO inventory_cost_allocation (
        org_id, event_id, stock_movement_id, item_id, batch_id,
        quantity, allocated_amount, unit_cost_addition
    ) VALUES (
        NEW.org_id, event_id, NEW.id, NEW.item_id, NEW.batch_id,
        NEW.quantity, NEW.total_cost / NEW.quantity, 0
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_production_cost_event ON stock_movement;
CREATE TRIGGER trg_production_cost_event
AFTER INSERT ON stock_movement
FOR EACH ROW EXECUTE FUNCTION create_production_cost_event();
