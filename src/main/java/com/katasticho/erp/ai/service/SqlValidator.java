package com.katasticho.erp.ai.service;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.sf.jsqlparser.expression.Expression;
import net.sf.jsqlparser.expression.Parenthesis;
import net.sf.jsqlparser.expression.StringValue;
import net.sf.jsqlparser.expression.operators.conditional.AndExpression;
import net.sf.jsqlparser.expression.operators.relational.EqualsTo;
import net.sf.jsqlparser.parser.CCJSqlParserUtil;
import net.sf.jsqlparser.schema.Column;
import net.sf.jsqlparser.schema.Table;
import net.sf.jsqlparser.statement.Statement;
import net.sf.jsqlparser.statement.select.FromItem;
import net.sf.jsqlparser.statement.select.Join;
import net.sf.jsqlparser.statement.select.LateralSubSelect;
import net.sf.jsqlparser.statement.select.ParenthesedSelect;
import net.sf.jsqlparser.statement.select.PlainSelect;
import net.sf.jsqlparser.statement.select.Select;
import net.sf.jsqlparser.statement.select.SelectItem;
import net.sf.jsqlparser.statement.select.SetOperationList;
import net.sf.jsqlparser.statement.select.WithItem;
import net.sf.jsqlparser.util.deparser.ExpressionDeParser;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Validates AND rewrites AI-generated SQL so it can never read another
 * tenant's data.
 *
 * The old implementation only checked that the substring "org_id =" appeared
 * somewhere, which a UNION / subquery / OR-clause trivially bypassed. This
 * version parses the statement with JSqlParser and ENFORCES tenancy by
 * construction:
 *
 * 1. ONLY a single SELECT statement is accepted (parse-level, plus the legacy
 *    regex fast-fails for DML/DDL/multi-statement/pg exploits).
 * 2. Every table referenced anywhere in the statement must exist in the
 *    public schema; unknown tables (pg_catalog, information_schema, typos)
 *    are rejected, and credential-bearing tables are denylisted outright.
 * 3. For every SELECT — including CTE bodies, UNION branches, derived tables
 *    and WHERE/HAVING/select-item subqueries — a predicate binding each
 *    org-scoped table to the caller's org is AND-ed onto that SELECT's WHERE.
 *    The model's own predicates are irrelevant to safety: ours are conjoined
 *    outside them, so no OR/UNION trick can widen the result set.
 *    The platform-level `organisation` table is pinned to `id = :org`.
 *
 * Callers must execute the SQL returned by {@link #secure}, not the input.
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class SqlValidator {

    private final JdbcTemplate jdbcTemplate;

    static final String TABLE_SCOPE_SQL =
            "SELECT table_name, BOOL_OR(column_name = 'org_id') AS scoped "
                    + "FROM information_schema.columns WHERE table_schema = 'public' "
                    + "GROUP BY table_name";

    /** Credential/infra tables the AI may never touch, org-filtered or not. */
    private static final Set<String> DENYLISTED_TABLES = Set.of(
            "app_user", "api_key", "push_token", "flyway_schema_history", "shedlock");

    /**
     * The ONLY no-{@code org_id} public tables the AI may read unfiltered — genuine
     * shared platform reference data. Everything else lacking an org_id column is
     * rejected by {@link #appendPredicateFor} (fail-closed). This is an ALLOWLIST,
     * not a denylist, precisely because the no-org bucket also contains credential/
     * token tables ({@code refresh_token}, {@code password_reset_token},
     * {@code email_verification_token}, {@code delegated_access_token},
     * {@code platform_admin}) and cross-org business tables ({@code trading_partner},
     * {@code network_order}, {@code ca_client_link}, ...) that a denylist would keep
     * missing. Restores the pre-rewrite validator's fail-closed posture (which required
     * an {@code org_id} filter on every query).
     */
    private static final Set<String> PLATFORM_REFERENCE_TABLES = Set.of(
            "salt_master", "drug_master", "manufacturer_master", "hsn_gst_master",
            "generic_substitution", "drug_interaction", "gst_state_code", "currency",
            "coa_template", "pt_slab", "lwf_rule", "ai_model_registry");

    private static final List<Pattern> FORBIDDEN_PATTERNS = List.of(
            Pattern.compile("\\b(INSERT|UPDATE|DELETE|MERGE|UPSERT)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(CREATE|DROP|ALTER|TRUNCATE|RENAME)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(GRANT|REVOKE|EXECUTE|EXEC|CALL)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(INTO\\s+OUTFILE|LOAD\\s+DATA)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(pg_sleep|dblink|lo_import|lo_export)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(COPY|\\\\copy)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile(";\\s*\\w", Pattern.CASE_INSENSITIVE) // Multiple statements
    );

    private static final Pattern SELECT_OR_WITH_PATTERN =
            Pattern.compile("^\\s*(SELECT|WITH)\\b", Pattern.CASE_INSENSITIVE);

    /** lower(table_name) -> has org_id column. Lazily loaded, immutable after. */
    private volatile Map<String, Boolean> tableScopes;

    /**
     * Legacy fast-fail checks (read-only shape, forbidden keywords). Kept for
     * defense in depth; {@link #secure} is the actual tenancy enforcement.
     */
    public void validate(String sql) {
        if (sql == null || sql.isBlank()) {
            throw new BusinessException("AI generated empty SQL",
                    "ERR_AI_EMPTY_SQL", HttpStatus.BAD_REQUEST);
        }
        String trimmed = sql.strip();
        if (!SELECT_OR_WITH_PATTERN.matcher(trimmed).find()) {
            log.warn("AI generated non-SELECT SQL: {}", truncateForLog(trimmed));
            throw unsafe("Only SELECT queries are allowed");
        }
        for (Pattern forbidden : FORBIDDEN_PATTERNS) {
            if (forbidden.matcher(trimmed).find()) {
                log.warn("AI generated SQL with forbidden pattern: {}", truncateForLog(trimmed));
                throw unsafe("Query contains forbidden SQL operations");
            }
        }
    }

    /**
     * Validate the statement and return a rewritten copy with the caller's
     * org predicate injected into every SELECT. Execute the RETURNED string.
     */
    public String secure(String sql, UUID orgId) {
        validate(sql);
        Statement statement;
        try {
            statement = CCJSqlParserUtil.parse(sql.strip());
        } catch (Exception e) {
            log.warn("AI SQL failed to parse: {} ({})", truncateForLog(sql), e.getMessage());
            throw unsafe("Query could not be parsed as a single SELECT statement");
        }
        if (!(statement instanceof Select select)) {
            throw unsafe("Only SELECT queries are allowed");
        }

        Set<String> cteNames = new HashSet<>();
        List<PlainSelect> plainSelects = new ArrayList<>();
        collectSelect(select, plainSelects, cteNames);

        for (PlainSelect ps : plainSelects) {
            injectOrgFilter(ps, cteNames, orgId);
        }
        return statement.toString();
    }

    /**
     * Ensure SQL has a LIMIT clause, inject one if missing.
     */
    public String ensureLimit(String sql, int maxRows) {
        if (Pattern.compile("\\bLIMIT\\s+\\d+", Pattern.CASE_INSENSITIVE).matcher(sql).find()) {
            return sql;
        }
        String clean = sql.stripTrailing();
        if (clean.endsWith(";")) {
            clean = clean.substring(0, clean.length() - 1);
        }
        return clean + " LIMIT " + maxRows;
    }

    // ── AST walk ─────────────────────────────────────────────────────────

    private void collectSelect(Select select, List<PlainSelect> out, Set<String> cteNames) {
        if (select == null) {
            return;
        }
        if (select.getWithItemsList() != null) {
            for (WithItem with : select.getWithItemsList()) {
                if (with.getAlias() != null) {
                    cteNames.add(normalize(with.getAlias().getName()));
                }
                collectSelect(with.getSelect(), out, cteNames);
            }
        }
        if (select instanceof PlainSelect ps) {
            out.add(ps);
            collectFromItem(ps.getFromItem(), out, cteNames);
            if (ps.getJoins() != null) {
                for (Join join : ps.getJoins()) {
                    collectFromItem(join.getRightItem(), out, cteNames);
                    for (Expression on : join.getOnExpressions()) {
                        collectExpression(on, out, cteNames);
                    }
                }
            }
            collectExpression(ps.getWhere(), out, cteNames);
            collectExpression(ps.getHaving(), out, cteNames);
            if (ps.getSelectItems() != null) {
                for (SelectItem<?> item : ps.getSelectItems()) {
                    collectExpression(item.getExpression(), out, cteNames);
                }
            }
        } else if (select instanceof SetOperationList sol) {
            for (Select side : sol.getSelects()) {
                collectSelect(side, out, cteNames);
            }
        } else if (select instanceof ParenthesedSelect paren) {
            collectSelect(paren.getSelect(), out, cteNames);
        }
    }

    private void collectFromItem(FromItem item, List<PlainSelect> out, Set<String> cteNames) {
        if (item instanceof LateralSubSelect lateral) {
            collectSelect(lateral.getSelect(), out, cteNames);
        } else if (item instanceof ParenthesedSelect paren) {
            collectSelect(paren.getSelect(), out, cteNames);
        } else if (item instanceof Select sub) {
            collectSelect(sub, out, cteNames);
        }
        // Plain Table refs are handled at injection time.
    }

    /**
     * Find subqueries embedded in expressions (WHERE x IN (SELECT..), EXISTS,
     * scalar subselects in the SELECT list, ...). A deparse walk visits every
     * node of the expression tree, so no subquery shape is missed.
     */
    private void collectExpression(Expression expression, List<PlainSelect> out, Set<String> cteNames) {
        if (expression == null) {
            return;
        }
        ExpressionDeParser walker = new ExpressionDeParser() {
            @Override
            public <S> StringBuilder visit(Select subSelect, S context) {
                collectSelect(subSelect, out, cteNames);
                return this.getBuffer();
            }
        };
        walker.setBuffer(new StringBuilder());
        expression.accept(walker);
    }

    // ── Injection ────────────────────────────────────────────────────────

    private void injectOrgFilter(PlainSelect ps, Set<String> cteNames, UUID orgId) {
        List<Expression> predicates = new ArrayList<>();
        appendPredicateFor(ps.getFromItem(), cteNames, orgId, predicates);
        if (ps.getJoins() != null) {
            for (Join join : ps.getJoins()) {
                appendPredicateFor(join.getRightItem(), cteNames, orgId, predicates);
            }
        }
        if (predicates.isEmpty()) {
            return;
        }
        Expression combined = predicates.get(0);
        for (int i = 1; i < predicates.size(); i++) {
            combined = new AndExpression(combined, predicates.get(i));
        }
        if (ps.getWhere() == null) {
            ps.setWhere(combined);
        } else {
            // Parenthesize the model's WHERE so an OR inside it can never
            // escape the AND-ed tenant predicate (5.x Parenthesis is a
            // single-element expression list).
            Parenthesis existing = new Parenthesis();
            existing.add(ps.getWhere());
            ps.setWhere(new AndExpression(existing, combined));
        }
    }

    private void appendPredicateFor(FromItem item, Set<String> cteNames, UUID orgId,
                                    List<Expression> predicates) {
        if (!(item instanceof Table table)) {
            return;
        }
        String name = normalize(table.getName());
        if (cteNames.contains(name)) {
            return;
        }
        if (table.getSchemaName() != null
                && !"public".equalsIgnoreCase(normalize(table.getSchemaName()))) {
            throw unsafe("Only public-schema tables may be queried");
        }
        if (DENYLISTED_TABLES.contains(name)) {
            throw unsafe("Table '" + name + "' may not be queried");
        }
        Boolean orgScoped = tableScopes().get(name);
        if (orgScoped == null) {
            throw unsafe("Unknown table: " + name);
        }
        String reference = table.getAlias() != null ? table.getAlias().getName() : table.getName();
        if ("organisation".equals(name)) {
            predicates.add(equalsPredicate(reference, "id", orgId));
        } else if (orgScoped) {
            predicates.add(equalsPredicate(reference, "org_id", orgId));
        } else if (!PLATFORM_REFERENCE_TABLES.contains(name)) {
            // Deny-by-default: a public table with NO org_id column is NOT automatically
            // "shared reference data" — that bucket also holds credential/token tables
            // (refresh_token, password_reset_token, delegated_access_token, platform_admin)
            // and cross-org business tables (trading_partner, network_order, ...). Only the
            // explicit PLATFORM_REFERENCE_TABLES allowlist may run unfiltered; anything else
            // is rejected so it can never leak cross-tenant through the AI query feature.
            throw unsafe("Non-tenant table '" + name + "' may not be queried");
        }
        // else: allowlisted platform reference table — shared by design, no predicate.
    }

    private Expression equalsPredicate(String tableReference, String column, UUID orgId) {
        return new EqualsTo(
                new Column(new Table(tableReference), column),
                new StringValue(orgId.toString()));
    }

    // ── Schema metadata ──────────────────────────────────────────────────

    private Map<String, Boolean> tableScopes() {
        Map<String, Boolean> cached = tableScopes;
        if (cached == null) {
            synchronized (this) {
                if (tableScopes == null) {
                    Map<String, Boolean> loaded = new HashMap<>();
                    jdbcTemplate.query(TABLE_SCOPE_SQL, (rs, rowNum) -> loaded.put(
                            rs.getString("table_name").toLowerCase(Locale.ROOT),
                            rs.getBoolean("scoped")));
                    tableScopes = Map.copyOf(loaded);
                }
                cached = tableScopes;
            }
        }
        return cached;
    }

    private String normalize(String identifier) {
        return identifier == null ? null
                : identifier.replace("\"", "").trim().toLowerCase(Locale.ROOT);
    }

    private BusinessException unsafe(String message) {
        return new BusinessException(message, "ERR_AI_UNSAFE_SQL", HttpStatus.FORBIDDEN);
    }

    private String truncateForLog(String sql) {
        return sql.length() > 200 ? sql.substring(0, 200) + "..." : sql;
    }
}
