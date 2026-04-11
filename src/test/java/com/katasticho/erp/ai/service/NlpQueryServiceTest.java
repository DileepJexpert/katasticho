package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.dto.AiQueryResponse;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NlpQueryServiceTest {

    @Mock private ClaudeApiClient claudeApiClient;
    @Mock private JdbcTemplate jdbcTemplate;

    private NlpQueryService nlpQueryService;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);

        AiConfig config = new AiConfig();
        config.setMaxSqlRows(100);
        config.setModel("claude-sonnet-4-20250514");

        SqlValidator validator = new SqlValidator();
        SchemaProvider schemaProvider = new SchemaProvider();
        ObjectMapper objectMapper = new ObjectMapper();

        nlpQueryService = new NlpQueryService(
                claudeApiClient, validator, schemaProvider,
                config, jdbcTemplate, objectMapper);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    @DisplayName("T-AI-12: Processes NLP query end-to-end")
    void processesQuery() {
        // Claude generates SQL
        String sqlResponse = "```sql\nSELECT SUM(base_total) as revenue FROM invoice WHERE org_id = '"
                + orgId + "' AND status != 'CANCELLED'\n```";
        when(claudeApiClient.sendMessage(anyString(), eq("What is my revenue?")))
                .thenReturn(sqlResponse);

        // SQL execution returns data
        when(jdbcTemplate.queryForList(anyString()))
                .thenReturn(List.of(Map.of("revenue", 150000.0)));

        // Claude generates answer
        when(claudeApiClient.sendMessage(anyString(), contains("Query results")))
                .thenReturn("Your total revenue is ₹1,50,000.");

        AiQueryResponse result = nlpQueryService.processQuery("What is my revenue?");

        assertThat(result.answer()).contains("1,50,000");
        assertThat(result.generatedSql()).contains("SELECT");
        assertThat(result.results()).hasSize(1);
        assertThat(result.metadata().intent()).isEqualTo("nlp_query");
        assertThat(result.metadata().rowCount()).isEqualTo(1);

        // Verify Claude was called twice: once for SQL gen, once for answer gen
        verify(claudeApiClient, times(2)).sendMessage(anyString(), anyString());
    }

    @Test
    @DisplayName("T-AI-13: Rejects when Claude generates unsafe SQL")
    void rejectsUnsafeSql() {
        // Claude generates dangerous SQL
        String unsafeResponse = "```sql\nDELETE FROM invoice WHERE org_id = '" + orgId + "'\n```";
        when(claudeApiClient.sendMessage(anyString(), anyString()))
                .thenReturn(unsafeResponse);

        assertThatThrownBy(() -> nlpQueryService.processQuery("Delete all invoices"))
                .isInstanceOf(BusinessException.class);

        // SQL should never be executed
        verify(jdbcTemplate, never()).queryForList(anyString());
    }

    @Test
    @DisplayName("T-AI-14: Replaces org_id with actual tenant UUID")
    void bindsCorrectOrgId() {
        String sqlResponse = "```sql\nSELECT COUNT(*) FROM invoice WHERE org_id = 'fake-uuid' AND status = 'PAID'\n```";
        when(claudeApiClient.sendMessage(anyString(), anyString()))
                .thenReturn(sqlResponse);

        when(jdbcTemplate.queryForList(contains(orgId.toString())))
                .thenReturn(List.of(Map.of("count", 5)));

        when(claudeApiClient.sendMessage(anyString(), contains("Query results")))
                .thenReturn("You have 5 paid invoices.");

        AiQueryResponse result = nlpQueryService.processQuery("How many paid invoices?");

        // Verify the actual org_id was bound, not the fake one
        verify(jdbcTemplate).queryForList(contains(orgId.toString()));
        assertThat(result.results()).hasSize(1);
    }

    @Test
    @DisplayName("T-AI-15: Handles SQL execution failure gracefully")
    void handlesSqlExecutionFailure() {
        String sqlResponse = "```sql\nSELECT invalid_column FROM account WHERE org_id = '" + orgId + "'\n```";
        when(claudeApiClient.sendMessage(anyString(), anyString()))
                .thenReturn(sqlResponse);
        when(jdbcTemplate.queryForList(anyString()))
                .thenThrow(new RuntimeException("column does not exist"));

        assertThatThrownBy(() -> nlpQueryService.processQuery("Show me invalid data"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Failed to execute");
    }

    @Test
    @DisplayName("T-AI-16: Handles when Claude can't generate SQL")
    void handlesMissingSql() {
        when(claudeApiClient.sendMessage(anyString(), anyString()))
                .thenReturn("I'm sorry, I cannot help with that question.");

        assertThatThrownBy(() -> nlpQueryService.processQuery("Tell me a joke"))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("ERR_AI_NO_SQL");
    }
}
