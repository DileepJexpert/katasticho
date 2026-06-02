ALTER TABLE reminder_log
    ADD COLUMN IF NOT EXISTS followup_status VARCHAR(30),
    ADD COLUMN IF NOT EXISTS promise_to_pay_date DATE,
    ADD COLUMN IF NOT EXISTS note TEXT;

CREATE INDEX IF NOT EXISTS idx_reminder_log_followup
    ON reminder_log(org_id, contact_id, followup_status, sent_at DESC);
