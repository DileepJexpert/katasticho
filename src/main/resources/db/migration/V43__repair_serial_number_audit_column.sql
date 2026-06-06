-- Repair V38 serial_number schema for databases where V38 already ran before
-- SerialNumber extends BaseEntity, so Hibernate validation requires created_by.
ALTER TABLE serial_number
    ADD COLUMN IF NOT EXISTS created_by UUID;
