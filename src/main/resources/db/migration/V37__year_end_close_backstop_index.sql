-- V37 — Concurrency backstop for year-end close.
--
-- YearEndCloseService.closeYear is check-then-act: it queries for an existing
-- non-reversed close entry, then posts the closing journal. Two concurrent
-- closeYear requests for the same (org, fiscalYear) can both pass the
-- alreadyClosed check and each post a full closing journal — driving every P&L
-- account to its inverse balance and doubling Retained Earnings.
--
-- The primary fix is a pessimistic org-row lock in the service (serialises the
-- two calls). This partial unique index is the DB-level backstop: the closing
-- journal carries a deterministic sourceId = UUIDv3("YEC:<org>:<fy>"), so a
-- second active (non-reversal, non-reversed) YEAR_END_CLOSE entry for the same
-- (org, sourceId) now fails at INSERT with a unique violation instead of
-- silently double-posting. A legitimately-reversed year (is_reversed=true) is
-- excluded from the predicate, so re-closing after a reversal still works.

CREATE UNIQUE INDEX uq_je_year_end_close
    ON journal_entry (org_id, source_module, source_id)
    WHERE source_module = 'YEAR_END_CLOSE'
      AND is_reversal = FALSE
      AND is_reversed = FALSE
      AND source_id IS NOT NULL;
