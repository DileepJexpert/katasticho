package com.katasticho.erp.ai.service;

import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SqlValidatorTest {

    @Mock private JdbcTemplate jdbcTemplate;

    private SqlValidator validator;
    private final UUID orgId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000");

    @BeforeEach
    void setUp() {
        validator = new SqlValidator(jdbcTemplate);
        // Simulated information_schema: org-scoped business tables, the
        // platform organisation table (no org_id), a platform reference
        // table, and a denylisted credential table.
        stubSchema(
                row("journal_line", true), row("account", true), row("invoice", true),
                row("contact", true), row("payment", true),
                row("organisation", false), row("gst_state_code", false),
                row("drug_master", false),           // allowlisted platform reference (no org_id)
                row("refresh_token", false),          // credential table, no org_id, NOT allowlisted
                row("platform_admin", false),         // credential table, no org_id, NOT allowlisted
                row("trading_partner", false),        // cross-org business table, no org_id, NOT allowlisted
                row("app_user", true));
    }

    private Object[] row(String table, boolean scoped) {
        return new Object[]{table, scoped};
    }

    @SuppressWarnings("unchecked")
    private void stubSchema(Object[]... rows) {
        when(jdbcTemplate.query(eq(SqlValidator.TABLE_SCOPE_SQL), any(RowMapper.class)))
                .thenAnswer(invocation -> {
                    RowMapper<Object> mapper = invocation.getArgument(1);
                    java.sql.ResultSet rs = org.mockito.Mockito.mock(ResultSet.class);
                    for (int i = 0; i < rows.length; i++) {
                        lenient().when(rs.getString("table_name")).thenReturn((String) rows[i][0]);
                        lenient().when(rs.getBoolean("scoped")).thenReturn((Boolean) rows[i][1]);
                        mapper.mapRow(rs, i);
                    }
                    return List.of();
                });
    }

    // ── validate(): legacy fast-fail checks ──

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

    @Test
    @DisplayName("T-AI-06/07: Rejects empty and null SQL")
    void rejectsEmptyAndNull() {
        assertThatThrownBy(() -> validator.validate(""))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("ERR_AI_EMPTY_SQL");
        assertThatThrownBy(() -> validator.validate(null))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("T-AI-10: Rejects PostgreSQL-specific exploits")
    void rejectsPostgresExploits() {
        assertThatThrownBy(() -> validator.validate("SELECT pg_sleep(10) WHERE org_id = '123'"))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("T-AI-11: Rejects CTE containing DELETE")
    void rejectsCteWithDelete() {
        String sql = "WITH hack AS (DELETE FROM account WHERE org_id = '123' RETURNING *) SELECT * FROM hack";
        assertThatThrownBy(() -> validator.validate(sql))
                .isInstanceOf(BusinessException.class);
    }

    // ── secure(): tenant predicate injection ──

    @Test
    @DisplayName("T-AI-20: Injects org filter when the model omitted it")
    void injectsOrgFilterWhenMissing() {
        String secured = validator.secure("SELECT * FROM account WHERE name = 'Cash'", orgId);
        assertThat(secured).contains("account.org_id = '" + orgId + "'");
        assertThat(secured).contains("(name = 'Cash') AND");
    }

    @Test
    @DisplayName("T-AI-21: UNION branch without org filter gets one injected")
    void securesUnionExfiltration() {
        String sql = "SELECT total FROM invoice WHERE org_id = '" + orgId + "' "
                + "UNION SELECT total FROM invoice";
        String secured = validator.secure(sql, orgId);
        // Injection is unconditional: the model's predicate (1) + injected in
        // both branches (2) = 3 occurrences. The naked UNION branch is closed.
        assertThat(secured.split("org_id = '" + orgId + "'", -1)).hasSize(4);
    }

    @Test
    @DisplayName("T-AI-22: Subquery in WHERE gets its own org filter")
    void securesWhereSubquery() {
        String sql = "SELECT i.total FROM invoice i WHERE i.org_id = '" + orgId + "' "
                + "AND i.total > (SELECT MAX(total) FROM invoice)";
        String secured = validator.secure(sql, orgId);
        // Model's predicate (1) + injected on outer select (1) + injected
        // inside the previously-unfiltered subquery (1) = 3 occurrences.
        assertThat(secured.split("org_id = '" + orgId + "'", -1)).hasSize(4);
    }

    @Test
    @DisplayName("T-AI-23: Uses the table alias in the injected predicate")
    void injectionUsesAlias() {
        String secured = validator.secure(
                "SELECT jl.debit FROM journal_line jl JOIN account a ON a.id = jl.account_id", orgId);
        assertThat(secured).contains("jl.org_id = '" + orgId + "'");
        assertThat(secured).contains("a.org_id = '" + orgId + "'");
    }

    @Test
    @DisplayName("T-AI-24: OR 1=1 cannot widen results — injected predicate is conjoined outside")
    void orTrickCannotBypass() {
        String secured = validator.secure(
                "SELECT * FROM invoice WHERE org_id = '" + orgId + "' OR 1 = 1", orgId);
        // The original WHERE is parenthesized and our predicate AND-ed after it.
        assertThat(secured).matches("(?s).*\\(.*OR 1 = 1\\) AND invoice\\.org_id = '" + orgId + "'.*");
    }

    @Test
    @DisplayName("T-AI-25: organisation table is pinned to the caller's own row")
    void organisationPinnedToOwnRow() {
        String secured = validator.secure("SELECT name FROM organisation", orgId);
        assertThat(secured).contains("organisation.id = '" + orgId + "'");
    }

    @Test
    @DisplayName("T-AI-26: Platform reference tables stay unfiltered")
    void platformTablesUnfiltered() {
        String secured = validator.secure("SELECT * FROM gst_state_code", orgId);
        assertThat(secured).doesNotContain("org_id");
    }

    @Test
    @DisplayName("T-AI-26b: Allowlisted platform reference table stays unfiltered")
    void allowlistedReferenceTableUnfiltered() {
        String secured = validator.secure("SELECT brand FROM drug_master", orgId);
        assertThat(secured).doesNotContain("org_id");
    }

    @ParameterizedTest
    @DisplayName("T-AI-26c: no-org_id tables NOT on the allowlist are rejected (credential/cross-org)")
    @ValueSource(strings = {
            "SELECT user_id, token_hash FROM refresh_token",
            "SELECT email, password_hash, role FROM platform_admin",
            "SELECT * FROM trading_partner",
    })
    void rejectsNonAllowlistedNoOrgTable(String sql) {
        assertThatThrownBy(() -> validator.secure(sql, orgId))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("may not be queried");
    }

    @Test
    @DisplayName("T-AI-26d: credential table can't be smuggled via UNION with a reference table")
    void rejectsCredentialTableInUnion() {
        assertThatThrownBy(() -> validator.secure(
                "SELECT code FROM gst_state_code UNION SELECT token_hash FROM refresh_token", orgId))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("may not be queried");
    }

    @Test
    @DisplayName("T-AI-27: Unknown tables are rejected")
    void rejectsUnknownTable() {
        assertThatThrownBy(() -> validator.secure("SELECT * FROM pg_shadow", orgId))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Unknown table");
    }

    @Test
    @DisplayName("T-AI-28: Credential tables are denylisted even though org-scoped")
    void rejectsDenylistedTable() {
        assertThatThrownBy(() -> validator.secure("SELECT * FROM app_user", orgId))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("may not be queried");
    }

    @Test
    @DisplayName("T-AI-29: Non-public schemas are rejected")
    void rejectsForeignSchema() {
        assertThatThrownBy(() -> validator.secure(
                "SELECT * FROM information_schema.tables", orgId))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("T-AI-30: CTE body is filtered; CTE reference itself is not re-filtered")
    void securesCteBody() {
        String sql = "WITH rev AS (SELECT total FROM invoice) SELECT * FROM rev";
        String secured = validator.secure(sql, orgId);
        assertThat(secured).contains("invoice.org_id = '" + orgId + "'");
        assertThat(secured).doesNotContain("rev.org_id");
    }

    // ── LIMIT injection ──

    @Test
    @DisplayName("T-AI-08: Injects LIMIT when missing")
    void injectsLimit() {
        String result = validator.ensureLimit("SELECT * FROM account WHERE org_id = '123'", 100);
        assertThat(result).endsWith("LIMIT 100");
    }

    @Test
    @DisplayName("T-AI-09: Preserves existing LIMIT")
    void preservesExistingLimit() {
        String result = validator.ensureLimit(
                "SELECT * FROM account WHERE org_id = '123' LIMIT 50", 100);
        assertThat(result).contains("LIMIT 50").doesNotContain("LIMIT 100");
    }
}
