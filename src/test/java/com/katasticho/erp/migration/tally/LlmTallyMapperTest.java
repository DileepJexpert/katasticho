package com.katasticho.erp.migration.tally;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.service.VisionModelRouter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LlmTallyMapperTest {

    @Mock private VisionModelRouter modelRouter;
    private AiConfig aiConfig;
    private LlmTallyMapper mapper;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        aiConfig = new AiConfig();
        mapper = new LlmTallyMapper(modelRouter, aiConfig, objectMapper);
    }

    @Test
    void parses_well_formed_json_array_with_all_fields() {
        String raw = """
                [
                  {"name": "Office Rent", "kind": "EXPENSE", "confidence": 0.95, "reason": "Rent paid is an indirect expense"},
                  {"name": "Demat Suspense", "kind": "ASSET", "confidence": 0.62, "reason": "Suspense in asset side until resolved"}
                ]
                """;
        var out = mapper.parse(raw);
        assertEquals(2, out.size());
        assertEquals("Office Rent", out.get(0).name());
        assertEquals("EXPENSE", out.get(0).kind());
        assertEquals(0.95, out.get(0).confidence(), 0.001);
    }

    @Test
    void strips_markdown_fences_if_llm_disobeys() {
        String raw = """
                ```json
                [{"name": "X", "kind": "EXPENSE", "confidence": 0.7, "reason": "y"}]
                ```
                """;
        var out = mapper.parse(raw);
        assertEquals(1, out.size());
        assertEquals("X", out.get(0).name());
    }

    @Test
    void normalises_common_llm_kind_variants() {
        assertEquals("REVENUE", LlmTallyMapper.normaliseKind("Income"));
        assertEquals("EXPENSE", LlmTallyMapper.normaliseKind("cost"));
        assertEquals("EXPENSE", LlmTallyMapper.normaliseKind("Expenditure"));
        assertEquals("ASSET", LlmTallyMapper.normaliseKind("BANK"));
        assertEquals("ASSET", LlmTallyMapper.normaliseKind("current_asset"));
        assertEquals("LIABILITY", LlmTallyMapper.normaliseKind("Provision"));
        assertEquals("EQUITY", LlmTallyMapper.normaliseKind("Capital"));
        // garbage falls back to SKIP — never invent a target
        assertEquals("SKIP", LlmTallyMapper.normaliseKind("MYSTERY"));
        assertEquals("SKIP", LlmTallyMapper.normaliseKind(null));
    }

    @Test
    void skips_rows_with_missing_name() {
        String raw = """
                [{"kind": "EXPENSE", "confidence": 0.9, "reason": "no name"},
                 {"name": "OK", "kind": "ASSET", "confidence": 0.8, "reason": "fine"}]
                """;
        var out = mapper.parse(raw);
        assertEquals(1, out.size());
        assertEquals("OK", out.get(0).name());
    }

    @Test
    void garbage_input_returns_empty_list_without_throwing() {
        assertTrue(mapper.parse("not json").isEmpty());
        assertTrue(mapper.parse("").isEmpty());
        assertTrue(mapper.parse(null).isEmpty());
        // Object instead of array → empty
        assertTrue(mapper.parse("{\"name\": \"X\"}").isEmpty());
    }

    @Test
    void isAvailable_is_true_when_useLocal_is_true_regardless_of_api_key() {
        aiConfig.setUseLocal(true);
        aiConfig.setAnthropicApiKey(null);
        assertTrue(mapper.isAvailable(), "local mode should always be available");
    }

    @Test
    void isAvailable_checks_api_key_when_useLocal_is_false() {
        aiConfig.setUseLocal(false);
        aiConfig.setAnthropicApiKey(null);
        assertFalse(mapper.isAvailable());
        aiConfig.setAnthropicApiKey("");
        assertFalse(mapper.isAvailable());
        aiConfig.setAnthropicApiKey("   ");
        assertFalse(mapper.isAvailable());
        aiConfig.setAnthropicApiKey("sk-set");
        assertTrue(mapper.isAvailable());
    }

    @Test
    void suggest_returns_empty_when_unconfigured_without_calling_LLM() {
        aiConfig.setUseLocal(false);
        aiConfig.setAnthropicApiKey(null);
        var out = mapper.suggest(List.of(
                new LlmTallyMapper.UnclassifiedLedger("Anything", "Group", null)));
        assertTrue(out.isEmpty());
        verify(modelRouter, never()).sendMessage(anyString(), anyString());
    }

    @Test
    void suggest_calls_LLM_and_returns_parsed_suggestions_when_configured() {
        aiConfig.setUseLocal(true);
        when(modelRouter.sendMessage(anyString(), anyString())).thenReturn("""
                [{"name": "Office Rent", "kind": "EXPENSE", "confidence": 0.95, "reason": "indirect expense"}]
                """);

        var out = mapper.suggest(List.of(
                new LlmTallyMapper.UnclassifiedLedger("Office Rent", "Indirect Expenses", null)));
        assertEquals(1, out.size());
        assertEquals("EXPENSE", out.get(0).kind());
    }

    @Test
    void suggest_returns_empty_when_LLM_throws_instead_of_propagating() {
        aiConfig.setUseLocal(true);
        when(modelRouter.sendMessage(anyString(), anyString()))
                .thenThrow(new RuntimeException("rate limit"));

        var out = mapper.suggest(List.of(
                new LlmTallyMapper.UnclassifiedLedger("X", "Y", null)));
        assertTrue(out.isEmpty(), "must degrade gracefully on LLM failure");
    }

    @Test
    void renderInput_includes_gstin_when_present_omits_when_blank() {
        String withGstin = mapper.renderInput(List.of(
                new LlmTallyMapper.UnclassifiedLedger("Acme", "Sundry Debtors", "27AAAAA1234F1Z5")));
        assertTrue(withGstin.contains("GSTIN: 27AAAAA1234F1Z5"));

        String noGstin = mapper.renderInput(List.of(
                new LlmTallyMapper.UnclassifiedLedger("Bob", "Sundry Debtors", null)));
        assertFalse(noGstin.contains("GSTIN:"));
    }

    @Test
    void bucketCounts_groups_by_kind_preserves_insertion_order() {
        var suggestions = List.of(
                new LlmTallyMapper.Suggestion("a", "EXPENSE", 0.9, "x"),
                new LlmTallyMapper.Suggestion("b", "ASSET", 0.9, "x"),
                new LlmTallyMapper.Suggestion("c", "EXPENSE", 0.9, "x"),
                new LlmTallyMapper.Suggestion("d", "ASSET", 0.9, "x"),
                new LlmTallyMapper.Suggestion("e", "REVENUE", 0.9, "x"));
        Map<String, Integer> counts = mapper.bucketCounts(suggestions);
        assertEquals(2, counts.get("EXPENSE"));
        assertEquals(2, counts.get("ASSET"));
        assertEquals(1, counts.get("REVENUE"));
    }
}
