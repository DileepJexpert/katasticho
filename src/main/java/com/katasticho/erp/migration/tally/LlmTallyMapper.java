package com.katasticho.erp.migration.tally;

import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.service.VisionModelRouter;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * LLM mapping layer on top of {@link TallyImportService}'s rule-based
 * classifier. When the rule-based classifier returns {@code SKIP} because
 * the parent group isn't a known Tally primary group ("Sundry Debtors",
 * "Bank Accounts", …), this service asks Claude to classify the unmatched
 * rows — turning the ~80% rule-based mapping into ~95%+ per the strategic
 * doc's wedge.
 *
 * <p>Returns a structured suggestion per ledger: kind + confidence + reason.
 * The human still reviews and accepts; nothing is auto-persisted.
 *
 * <p>Routes through {@link VisionModelRouter} — uses local Ollama when
 * {@code app.ai.use-local=true}, remote Claude API otherwise. Inert when
 * remote mode is selected but no API key is configured —
 * {@link #isAvailable()} guards callers.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LlmTallyMapper {

    private static final String SYSTEM_PROMPT = """
            You are an Indian-accounting Tally migration assistant. You map
            unclassified Tally ledger names to one of these target types:

              CUSTOMER  — receivables, parties we sell to
              VENDOR    — payables, parties we buy from
              ASSET     — bank, cash, fixed assets, current assets, advances
              LIABILITY — current liabilities, loans, provisions
              EQUITY    — capital, reserves
              REVENUE   — sales, income, service income
              EXPENSE   — purchases, expenses, direct/indirect costs
              SKIP      — system / duty / tax ledgers that Katasticho manages itself

            For each ledger, return its target type, a confidence (0.0-1.0),
            and a one-line reason. Reply ONLY with a JSON array of objects
            in the exact shape:
            [{"name":"...", "kind":"CUSTOMER|VENDOR|ASSET|LIABILITY|EQUITY|REVENUE|EXPENSE|SKIP",
              "confidence":0.0-1.0, "reason":"..."}]
            No prose, no markdown.
            """;

    private final VisionModelRouter modelRouter;
    private final AiConfig aiConfig;
    private final ObjectMapper objectMapper;

    public boolean isAvailable() {
        if (aiConfig.isUseLocal()) return true;
        String key = aiConfig.getAnthropicApiKey();
        return key != null && !key.isBlank();
    }

    /** One mapping suggestion for one ledger. */
    public record Suggestion(
            String name,
            String kind,         // CUSTOMER / VENDOR / ... / SKIP
            double confidence,
            String reason
    ) {}

    /**
     * Suggest a kind for each unclassified ledger. Returns an empty list when
     * the LLM is unconfigured or the input is empty — never throws.
     */
    public List<Suggestion> suggest(List<UnclassifiedLedger> ledgers) {
        if (ledgers == null || ledgers.isEmpty() || !isAvailable()) {
            return List.of();
        }
        try {
            String userMessage = renderInput(ledgers);
            String raw = modelRouter.sendMessage(SYSTEM_PROMPT, userMessage);
            return parse(raw);
        } catch (Exception e) {
            log.warn("LlmTallyMapper: suggestion call failed — {}", e.toString());
            return List.of();
        }
    }

    /** Input shape — what the rule-based classifier couldn't place. */
    public record UnclassifiedLedger(String name, String parentGroup, String gstin) {}

    String renderInput(List<UnclassifiedLedger> ledgers) {
        StringBuilder sb = new StringBuilder("Map these ledgers:\n");
        for (UnclassifiedLedger l : ledgers) {
            sb.append("- name: ").append(safe(l.name()));
            sb.append("; parent group: ").append(safe(l.parentGroup()));
            if (l.gstin() != null && !l.gstin().isBlank()) {
                sb.append("; GSTIN: ").append(safe(l.gstin()));
            }
            sb.append("\n");
        }
        return sb.toString();
    }

    List<Suggestion> parse(String raw) {
        if (raw == null || raw.isBlank()) return List.of();
        // Defensive: strip code-fence formatting if the model added it despite
        // the instruction.
        String stripped = raw.trim();
        if (stripped.startsWith("```")) {
            int firstNl = stripped.indexOf('\n');
            int lastFence = stripped.lastIndexOf("```");
            if (firstNl > 0 && lastFence > firstNl) {
                stripped = stripped.substring(firstNl + 1, lastFence).trim();
            }
        }

        try {
            JsonNode root = objectMapper.readTree(stripped);
            if (!root.isArray()) return List.of();
            List<Suggestion> out = new ArrayList<>();
            for (JsonNode node : root) {
                String name = txt(node, "name");
                String kind = normaliseKind(txt(node, "kind"));
                double conf = node.path("confidence").asDouble(0.5);
                String reason = txt(node, "reason");
                if (name == null || name.isBlank()) continue;
                out.add(new Suggestion(name, kind, conf, reason));
            }
            return out;
        } catch (Exception e) {
            log.warn("LlmTallyMapper: could not parse LLM response — {}", e.toString());
            return List.of();
        }
    }

    /** Map back to TallyImportService.Kind names; default to SKIP on garbage. */
    static String normaliseKind(String kind) {
        if (kind == null) return "SKIP";
        String k = kind.trim().toUpperCase();
        return switch (k) {
            case "CUSTOMER", "VENDOR", "ASSET", "LIABILITY", "EQUITY",
                 "REVENUE", "EXPENSE", "SKIP" -> k;
            // Common LLM variants
            case "INCOME" -> "REVENUE";
            case "COST", "EXPENDITURE" -> "EXPENSE";
            case "BANK", "CASH", "CURRENT_ASSET" -> "ASSET";
            case "PROVISION", "CURRENT_LIABILITY" -> "LIABILITY";
            case "CAPITAL", "RESERVES" -> "EQUITY";
            default -> "SKIP";
        };
    }

    /** Bucket suggestions by kind for the UI's "893 → CUSTOMER, 121 → ASSET" summary. */
    public Map<String, Integer> bucketCounts(List<Suggestion> suggestions) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (Suggestion s : suggestions) {
            counts.merge(s.kind(), 1, Integer::sum);
        }
        return counts;
    }

    private static String txt(JsonNode node, String field) {
        JsonNode v = node.path(field);
        return v.isMissingNode() || v.isNull() ? null : v.asText();
    }

    private static String safe(String s) {
        return s == null ? "" : s.replace("\n", " ").replace("\r", " ").trim();
    }
}
