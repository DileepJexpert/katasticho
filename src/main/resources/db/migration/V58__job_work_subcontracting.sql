-- V58: retired duplicate subcontracting aggregate.
--
-- V1 already owns the job_work_order / job_work_order_line aggregate through
-- the manufacturing module. The original version of this migration attempted
-- to create a second incompatible aggregate over the same parent table. That
-- made a fresh database fail at migration time and allowed two stock workflows
-- to post movements for one business document. Job work has one canonical
-- lifecycle: manufacturing JobWorkOrder -> send -> receive/cancel.
DO $$ BEGIN NULL; END $$;
