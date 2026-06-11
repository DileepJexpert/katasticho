-- Post-dated vouchers (Tally parity): a journal entered today with a future
-- effective date stays DRAFT and auto-posts on that date (daily job).
ALTER TABLE journal_entry
    ADD COLUMN is_post_dated BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_journal_post_dated
    ON journal_entry(org_id, effective_date)
    WHERE is_post_dated = TRUE AND status = 'DRAFT';
