package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.dto.AiQueryResponse;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * NLP-to-SQL query service.
 *
 * Flow:
 * 1. User sends natural language question ("What's my revenue this month?")
 * 2. Claude generates a READ-ONLY SQL query using the schema
 * 3. SqlValidator ensures it's safe (SELECT only, has org_id, no mutations)
 * 4. Execute against PostgreSQL with org_id bound
 * 5. Claude generates a human-readable answer from the results
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NlpQueryService {

    private final ClaudeApiClient claudeApiClient;
    private final SqlValidator sqlValidator;
    private final SchemaProvider schemaProvider;
    private final AiConfig aiConfig;
    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    private static final Pattern SQL_BLOCK_PATTERN =
            Pattern.compile("```sql\\s*\\n?(.*?)\\n?```", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);

    private static final Pattern PLAIN_SELECT_PATTERN =
            Pattern.compile("(SELECT\\s+.+)", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);

    public AiQueryResponse processQuery(String userMessage) {
        UUID orgId = TenantContext.getCurrentOrgId();
        long startTime = System.currentTimeMillis();

        // Step 1: Generate SQL from natural language
        String generatedSql = generateSql(userMessage, orgId);

        // Step 2: Validate SQL safety
        sqlValidator.validate(generatedSql);
        generatedSql = sqlValidator.ensureLimit(generatedSql, aiConfig.getMaxSqlRows());

        // Step 3: Bind org_id and execute
        String boundSql = bindOrgId(generatedSql, orgId);
        List<Map<String, Object>> results;
        try {
            results = jdbcTemplate.queryForList(boundSql);
        } catch (Exception e) {
            log.error("AI-generated SQL execution failed: {}", e.getMessage());
            throw new BusinessException(
                    "Failed to execute the generated query",
                    "ERR_AI_SQL_EXECUTION",
                    HttpStatus.INTERNAL_SERVER_ERROR
            );
        }

        // Step 4: Generate human-readable answer from results
        String answer = generateAnswer(userMessage, generatedSql, results);

        long elapsed = System.currentTimeMillis() - startTime;

        return new AiQueryResponse(
                answer,
                generatedSql,
                results,
                new AiQueryResponse.QueryMetadata(
                        "nlp_query",
                        elapsed,
                        results.size()
                )
        );
    }

    private String generateSql(String userMessage, UUID orgId) {
        String systemPrompt = """
                You are a SQL generator for a multi-tenant ERP system running on PostgreSQL.
                Generate ONLY a single SELECT statement. No explanations, no comments — just the SQL.

                CRITICAL RULES:
                1. ONLY SELECT statements — NEVER INSERT, UPDATE, DELETE, DROP, or any mutation
                2. ALWAYS include "org_id = '%s'" in the WHERE clause for EVERY table
                3. For financial data, use base_debit/base_credit from journal_line (multi-currency safe)
                4. Only query journal_entry with status = 'POSTED' (ignore DRAFT/REVERSED)
                5. Account sign convention: ASSET/EXPENSE are debit-normal, LIABILITY/EQUITY/REVENUE are credit-normal
                6. Use proper date functions: CURRENT_DATE, DATE_TRUNC, INTERVAL, etc.
                7. Format amounts as numeric, not text
                8. Return the SQL inside a ```sql code block

                %s
                """.formatted(orgId, schemaProvider.getSchemaDescription());

        String response = claudeApiClient.sendMessage(systemPrompt, userMessage);
        return extractSql(response);
    }

    private String extractSql(String response) {
        // Try to extract from code block first
        Matcher blockMatcher = SQL_BLOCK_PATTERN.matcher(response);
        if (blockMatcher.find()) {
            return blockMatcher.group(1).strip();
        }

        // Fallback: look for a SELECT statement
        Matcher selectMatcher = PLAIN_SELECT_PATTERN.matcher(response);
        if (selectMatcher.find()) {
            return selectMatcher.group(1).strip();
        }

        log.warn("Could not extract SQL from Claude response: {}", response);
        throw new BusinessException(
                "AI could not generate a valid query for your question",
                "ERR_AI_NO_SQL",
                HttpStatus.BAD_REQUEST
        );
    }

    /**
     * Replace org_id placeholder with actual value.
     * Claude generates org_id = 'UUID', we ensure it's the real tenant's UUID.
     */
    private String bindOrgId(String sql, UUID orgId) {
        // Replace any org_id = 'some-uuid' with the actual orgId
        return sql.replaceAll(
                "org_id\\s*=\\s*'[^']*'",
                "org_id = '" + orgId.toString() + "'"
        );
    }

    private String generateAnswer(String userMessage, String sql,
                                   List<Map<String, Object>> results) {
        String resultsJson;
        try {
            resultsJson = objectMapper.writeValueAsString(results);
        } catch (JsonProcessingException e) {
            resultsJson = results.toString();
        }

        // Truncate large result sets for the answer generation prompt
        if (resultsJson.length() > 5000) {
            resultsJson = resultsJson.substring(0, 5000) + "... (truncated)";
        }

        String systemPrompt = """
                You are a helpful financial assistant for an Indian SME ERP system.
                Given a user's question and the SQL query results, provide a clear, concise answer.

                Rules:
                - Format monetary amounts in Indian notation with ₹ symbol (e.g., ₹12,34,567.89)
                - Use lakhs (L) and crores (Cr) for large amounts
                - Be conversational but precise
                - If results are empty, say so helpfully
                - Don't mention SQL or technical details in your answer
                - Keep answers under 200 words
                """;

        String userPrompt = "Question: %s\n\nQuery results:\n%s".formatted(userMessage, resultsJson);

        return claudeApiClient.sendMessage(systemPrompt, userPrompt);
    }
}
