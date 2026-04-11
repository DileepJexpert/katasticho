package com.katasticho.erp.ai.service;

import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.*;

class SqlValidatorTest {

    private SqlValidator validator;

    @BeforeEach
    void setUp() {
        validator = new SqlValidator();
    }

    // ── Valid Queries ──

    @Test
    @DisplayName("T-AI-01: Accepts valid SELECT with org_id")
    void acceptsValidSelect() {
        String sql = "SELECT SUM(base_debit) FROM journal_line WHERE org_id = '123'";
        assertThatCode(() -> validator.validate(sql)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("T-AI-02: Accepts SELECT with JOIN and org_id")
    void acceptsSelectWithJoin() {
        String sql = """
                SELECT a.name, SUM(jl.base_debit) - SUM(jl.base_credit) AS balance
                FROM journal_line jl
                JOIN account a ON a.id = jl.account_id
                WHERE jl.org_id = '550e8400-e29b-41d4-a716-446655440000'
                GROUP BY a.name
                """;
        assertThatCode(() -> validator.validate(sql)).doesNotThrowAnyException();
    }

    // ── Rejected Mutations ──

    @ParameterizedTest
    @ValueSource(strings = {
            "INSERT INTO account (org_id, name) VALUES ('123', 'Hacked')",
            "UPDATE account SET name = 'Hacked' WHERE org_id = '123'",
            "DELETE FROM journal_line WHERE org_id = '123'",
            "DROP TABLE account",
            "TRUNCATE journal_line",
            "ALTER TABLE account ADD COLUMN hack TEXT",
            "CREATE TABLE hack (id INT)",
            "GRANT ALL ON account TO public",
    })
    @DisplayName("T-AI-03: Rejects DML/DDL statements")
    void rejectsMutations(String sql) {
        // These are rejected either because they don't start with SELECT
        // or because they contain forbidden keywords — both are correct
        assertThatThrownBy(() -> validator.validate(sql))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isIn("ERR_AI_UNSAFE_SQL");
    }

    @Test
    @DisplayName("T-AI-04: Rejects multiple statements (SQL injection)")
    void rejectsMultipleStatements() {
        String sql = "SELECT * FROM account WHERE org_id = '123'; DROP TABLE account";
        assertThatThrownBy(() -> validator.validate(sql))
                .isInstanceOf(BusinessException.class);
    }

    // ── Missing org_id ──

    @Test
    @DisplayName("T-AI-05: Rejects SELECT without org_id filter")
    void rejectsWithoutOrgId() {
        String sql = "SELECT * FROM account WHERE name = 'Cash'";
        assertThatThrownBy(() -> validator.validate(sql))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("ERR_AI_MISSING_TENANT");
    }

    // ── Empty / null ──

    @Test
    @DisplayName("T-AI-06: Rejects empty SQL")
    void rejectsEmptySql() {
        assertThatThrownBy(() -> validator.validate(""))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("ERR_AI_EMPTY_SQL");
    }

    @Test
    @DisplayName("T-AI-07: Rejects null SQL")
    void rejectsNullSql() {
        assertThatThrownBy(() -> validator.validate(null))
                .isInstanceOf(BusinessException.class);
    }

    // ── LIMIT injection ──

    @Test
    @DisplayName("T-AI-08: Injects LIMIT when missing")
    void injectsLimit() {
        String sql = "SELECT * FROM account WHERE org_id = '123'";
        String result = validator.ensureLimit(sql, 100);
        assertThat(result).endsWith("LIMIT 100");
    }

    @Test
    @DisplayName("T-AI-09: Preserves existing LIMIT")
    void preservesExistingLimit() {
        String sql = "SELECT * FROM account WHERE org_id = '123' LIMIT 50";
        String result = validator.ensureLimit(sql, 100);
        assertThat(result).contains("LIMIT 50");
        assertThat(result).doesNotContain("LIMIT 100");
    }

    @Test
    @DisplayName("T-AI-10: Rejects PostgreSQL-specific exploits")
    void rejectsPostgresExploits() {
        String sql = "SELECT pg_sleep(10) WHERE org_id = '123'";
        assertThatThrownBy(() -> validator.validate(sql))
                .isInstanceOf(BusinessException.class);
    }

    // ── Non-SELECT ──

    @Test
    @DisplayName("T-AI-11: Rejects non-SELECT starting keyword")
    void rejectsNonSelect() {
        String sql = "WITH hack AS (DELETE FROM account WHERE org_id = '123' RETURNING *) SELECT * FROM hack";
        // This starts with WITH, not SELECT — but more importantly contains DELETE
        assertThatThrownBy(() -> validator.validate(sql))
                .isInstanceOf(BusinessException.class);
    }
}
