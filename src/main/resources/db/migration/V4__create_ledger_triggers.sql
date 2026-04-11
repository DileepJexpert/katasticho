-- ============================================================
-- V4: Ledger immutability triggers
-- These enforce Thought Machine Vault Core principles at DB level.
-- Even if application code has bugs, the database protects integrity.
-- ============================================================

-- 1. Prevent UPDATE on POSTED journal entry
-- Only allowed transitions:
--   DRAFT -> POSTED (one-way)
--   is_reversed: FALSE -> TRUE (when a reversal is posted against it)
CREATE OR REPLACE FUNCTION prevent_journal_entry_update()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        -- Allow DRAFT -> POSTED transition (already handled by status check)
        -- Allow marking as reversed
        IF OLD.is_reversed = FALSE AND NEW.is_reversed = TRUE
           AND NEW.status = OLD.status
           AND NEW.effective_date = OLD.effective_date
           AND NEW.description = OLD.description THEN
            RETURN NEW;
        END IF;

        -- Block all other modifications to POSTED entries
        IF NEW.status != OLD.status
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.effective_date != OLD.effective_date
           OR NEW.source_module != OLD.source_module
           OR NEW.entry_number != OLD.entry_number THEN
            RAISE EXCEPTION 'Cannot modify POSTED journal entry %', OLD.id;
        END IF;
    END IF;

    -- Allow DRAFT -> POSTED transition
    IF OLD.status = 'DRAFT' AND NEW.status = 'POSTED' THEN
        RETURN NEW;
    END IF;

    -- Allow updates to DRAFT entries
    IF OLD.status = 'DRAFT' AND NEW.status = 'DRAFT' THEN
        RETURN NEW;
    END IF;

    -- Block POSTED -> DRAFT (never go backwards)
    IF OLD.status = 'POSTED' AND NEW.status = 'DRAFT' THEN
        RAISE EXCEPTION 'Cannot revert POSTED journal entry % to DRAFT', OLD.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_entry_immutable
BEFORE UPDATE ON journal_entry
FOR EACH ROW EXECUTE FUNCTION prevent_journal_entry_update();


-- 2. Prevent DELETE on POSTED journal entry
CREATE OR REPLACE FUNCTION prevent_journal_entry_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        RAISE EXCEPTION 'Cannot delete POSTED journal entry %', OLD.id;
    END IF;
    RETURN OLD;  -- Allow deleting DRAFT entries
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_entry_no_delete
BEFORE DELETE ON journal_entry
FOR EACH ROW EXECUTE FUNCTION prevent_journal_entry_delete();


-- 3. Enforce double-entry balance when posting (DRAFT -> POSTED)
-- SUM(debit) MUST equal SUM(credit) across all lines
CREATE OR REPLACE FUNCTION check_journal_balance()
RETURNS TRIGGER AS $$
DECLARE
    total_debit DECIMAL(15,2);
    total_credit DECIMAL(15,2);
BEGIN
    IF NEW.status = 'POSTED' AND OLD.status = 'DRAFT' THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO total_debit, total_credit
        FROM journal_line WHERE journal_entry_id = NEW.id;

        IF total_debit != total_credit THEN
            RAISE EXCEPTION 'Journal entry % does not balance. Debit: %, Credit: %',
                NEW.id, total_debit, total_credit;
        END IF;

        IF total_debit = 0 AND total_credit = 0 THEN
            RAISE EXCEPTION 'Journal entry % has no lines or zero amounts', NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_balance_on_post
BEFORE UPDATE OF status ON journal_entry
FOR EACH ROW
WHEN (NEW.status = 'POSTED' AND OLD.status = 'DRAFT')
EXECUTE FUNCTION check_journal_balance();


-- 4. Prevent mutation of journal lines when parent is POSTED
CREATE OR REPLACE FUNCTION prevent_journal_line_mutation()
RETURNS TRIGGER AS $$
DECLARE
    entry_status VARCHAR(10);
BEGIN
    SELECT status INTO entry_status FROM journal_entry
    WHERE id = COALESCE(OLD.journal_entry_id, NEW.journal_entry_id);

    IF entry_status = 'POSTED' THEN
        RAISE EXCEPTION 'Cannot modify lines of POSTED journal entry';
    END IF;

    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_line_immutable
BEFORE UPDATE OR DELETE ON journal_line
FOR EACH ROW EXECUTE FUNCTION prevent_journal_line_mutation();


-- 5. Function to compute account balance (canonical query)
-- Used by account balance endpoint and reporting
CREATE OR REPLACE FUNCTION get_account_balance(
    p_account_id UUID,
    p_org_id UUID,
    p_as_of_date DATE DEFAULT CURRENT_DATE
) RETURNS DECIMAL(15,2) AS $$
DECLARE
    v_balance DECIMAL(15,2);
    v_account_type VARCHAR(20);
BEGIN
    SELECT type INTO v_account_type FROM account WHERE id = p_account_id;

    SELECT COALESCE(SUM(jl.base_debit) - SUM(jl.base_credit), 0)
    INTO v_balance
    FROM journal_line jl
    JOIN journal_entry je ON jl.journal_entry_id = je.id
    WHERE jl.account_id = p_account_id
      AND je.org_id = p_org_id
      AND je.status = 'POSTED'
      AND je.effective_date <= p_as_of_date;

    -- For LIABILITY, EQUITY, REVENUE: natural balance is credit
    -- Return positive for normal balance direction
    IF v_account_type IN ('LIABILITY', 'EQUITY', 'REVENUE') THEN
        v_balance := -v_balance;
    END IF;

    RETURN v_balance;
END;
$$ LANGUAGE plpgsql;
