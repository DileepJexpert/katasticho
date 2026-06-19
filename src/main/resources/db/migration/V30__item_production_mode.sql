-- Tracker #34: Make-to-Order vs Make-to-Stock production modes.
--
-- Item-level setting that drives WHICH automation creates a work
-- order for a composite item:
--
--   MTO  — only build when there's a sale order  → SO→WO fires;
--          reorder sweep (autoCreateWorkOrdersFromReorder) skips.
--   MTS  — build to stock for forecast/reorder  → reorder sweep fires;
--          SO→WO skips (stock should already be there).
--   NULL — legacy behaviour preserved: both automations fire (every
--          existing composite item keeps doing what it did before).
--
-- The CHECK constraint keeps the enum surface closed. Default NULL
-- so existing rows are untouched.

ALTER TABLE item
    ADD COLUMN production_mode VARCHAR(10);

ALTER TABLE item
    ADD CONSTRAINT item_production_mode_check
    CHECK (production_mode IS NULL
           OR production_mode IN ('MTO', 'MTS'));
