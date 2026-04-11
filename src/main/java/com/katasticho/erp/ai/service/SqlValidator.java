package com.katasticho.erp.ai.service;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.regex.Pattern;

/**
 * Validates AI-generated SQL to ensure READ-ONLY safety.
 *
 * Rules:
 * 1. ONLY SELECT statements allowed
 * 2. No DDL (CREATE, DROP, ALTER, TRUNCATE)
 * 3. No DML (INSERT, UPDATE, DELETE, MERGE)
 * 4. No GRANT/REVOKE/EXECUTE
 * 5. No subquery-based mutations
 * 6. Must contain org_id filter (multi-tenancy enforcement)
 * 7. LIMIT clause required (max rows cap)
 */
@Component
@Slf4j
public class SqlValidator {

    private static final List<Pattern> FORBIDDEN_PATTERNS = List.of(
            Pattern.compile("\\b(INSERT|UPDATE|DELETE|MERGE|UPSERT)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(CREATE|DROP|ALTER|TRUNCATE|RENAME)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(GRANT|REVOKE|EXECUTE|EXEC|CALL)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(INTO\\s+OUTFILE|LOAD\\s+DATA)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(pg_sleep|dblink|lo_import|lo_export)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(COPY|\\\\copy)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile(";\\s*\\w", Pattern.CASE_INSENSITIVE) // Multiple statements
    );

    private static final Pattern SELECT_PATTERN =
            Pattern.compile("^\\s*SELECT\\b", Pattern.CASE_INSENSITIVE);

    private static final Pattern ORG_ID_PATTERN =
            Pattern.compile("org_id\\s*=\\s*", Pattern.CASE_INSENSITIVE);

    /**
     * Validate that the SQL is a safe, read-only SELECT with org_id filtering.
     *
     * @throws BusinessException if validation fails
     */
    public void validate(String sql) {
        if (sql == null || sql.isBlank()) {
            throw new BusinessException(
                    "AI generated empty SQL",
                    "ERR_AI_EMPTY_SQL",
                    HttpStatus.BAD_REQUEST
            );
        }

        String trimmed = sql.strip();

        // Must start with SELECT
        if (!SELECT_PATTERN.matcher(trimmed).find()) {
            log.warn("AI generated non-SELECT SQL: {}", truncateForLog(trimmed));
            throw new BusinessException(
                    "Only SELECT queries are allowed",
                    "ERR_AI_UNSAFE_SQL",
                    HttpStatus.FORBIDDEN
            );
        }

        // Check for forbidden patterns
        for (Pattern forbidden : FORBIDDEN_PATTERNS) {
            if (forbidden.matcher(trimmed).find()) {
                log.warn("AI generated SQL with forbidden pattern: {}", truncateForLog(trimmed));
                throw new BusinessException(
                        "Query contains forbidden SQL operations",
                        "ERR_AI_UNSAFE_SQL",
                        HttpStatus.FORBIDDEN
                );
            }
        }

        // Must contain org_id filter for multi-tenancy
        if (!ORG_ID_PATTERN.matcher(trimmed).find()) {
            log.warn("AI generated SQL without org_id filter: {}", truncateForLog(trimmed));
            throw new BusinessException(
                    "Query must include org_id filter",
                    "ERR_AI_MISSING_TENANT",
                    HttpStatus.FORBIDDEN
            );
        }
    }

    /**
     * Ensure SQL has a LIMIT clause, inject one if missing.
     */
    public String ensureLimit(String sql, int maxRows) {
        if (Pattern.compile("\\bLIMIT\\s+\\d+", Pattern.CASE_INSENSITIVE).matcher(sql).find()) {
            return sql;
        }
        // Remove trailing semicolon if present
        String clean = sql.stripTrailing();
        if (clean.endsWith(";")) {
            clean = clean.substring(0, clean.length() - 1);
        }
        return clean + " LIMIT " + maxRows;
    }

    private String truncateForLog(String sql) {
        return sql.length() > 200 ? sql.substring(0, 200) + "..." : sql;
    }
}
