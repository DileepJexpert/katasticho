package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.dto.AgentChatDtos.AgentChatResponse;
import com.katasticho.erp.ai.dto.AiQueryResponse;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryDraftResult;
import com.katasticho.erp.ar.dto.OverdueCustomerResponse;
import com.katasticho.erp.ar.service.CreditReminderService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Conversational agent with tool-use — the chat front door that can <em>act</em>,
 * not just answer. The user types one message; the agent picks a single tool and
 * runs it through existing services:
 *
 * <ul>
 *   <li><b>query_data</b> (read) → {@link NlpQueryService} natural-language → SQL.</li>
 *   <li><b>draft_entry</b> (write-as-draft) → {@link ConversationalEntryService}
 *       turns "paid 5000 cash for rent" into a DRAFT journal awaiting approval.</li>
 *   <li><b>list_overdue</b> (read) → {@link CreditReminderService} collections list.</li>
 * </ul>
 *
 * <p><b>Planning:</b> the org's configured model ({@link VisionModelRouter}) chooses
 * the tool by returning a small JSON object. If the model is unavailable or returns
 * something unparseable, a deterministic keyword router takes over so the
 * offline-capable intents (record a payment, who owes me) still work — mirroring
 * the rule-based fallback used elsewhere in the AI layer.
 *
 * <p><b>Safety:</b> write tools only ever create DRAFTS. The agent never posts a
 * journal, moves stock, or files anything — a human approves from the AI Inbox.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ConversationalAgentService {

    static final String TOOL_QUERY = "query_data";
    static final String TOOL_DRAFT = "draft_entry";
    static final String TOOL_OVERDUE = "list_overdue";
    static final String TOOL_NONE = "none";

    private static final int MAX_MESSAGE_LEN = 1000;

    private static final String SYSTEM_PROMPT = """
            You are the in-app assistant for an Indian SMB ERP. Decide which ONE tool
            best handles the user's message, and reply with ONLY a single JSON object
            and no other text.

            Tools:
            - query_data: answer a question about the user's own data (revenue, sales,
              purchases, stock on hand, balances, top customers/items). \
            args: {"question": "<the user's question>"}
            - draft_entry: record a cash or bank transaction the user states happened
              (a payment they made or money they received). Creates a DRAFT for the
              user to approve. args: {"text": "<the user's sentence>"}
            - list_overdue: list customers who have overdue payments. args: {}

            If the message is a greeting or too vague to act on, use
            {"tool":"none","reply":"<one short helpful sentence>"}.

            Examples:
            "what was my revenue last month" -> {"tool":"query_data","args":{"question":"what was my revenue last month"}}
            "paid 5000 cash for shop rent" -> {"tool":"draft_entry","args":{"text":"paid 5000 cash for shop rent"}}
            "who owes me money" -> {"tool":"list_overdue","args":{}}
            "hello" -> {"tool":"none","reply":"Hi! Ask me about your sales, record a payment, or check who owes you."}
            """;

    private static final Pattern JSON_OBJECT = Pattern.compile("\\{.*\\}", Pattern.DOTALL);
    private static final Pattern HAS_DIGIT = Pattern.compile("\\d");
    private static final Pattern PAYMENT_WORDS = Pattern.compile(
            "\\b(paid|pay|received|receive|got|collected|spent|bought|purchased|deposited|withdrew)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern OVERDUE_WORDS = Pattern.compile(
            "\\b(overdue|owes?|outstanding|receivables?|collect(?:ions?)?|who owes?)\\b",
            Pattern.CASE_INSENSITIVE);

    private final VisionModelRouter modelRouter;
    private final NlpQueryService nlpQueryService;
    private final ConversationalEntryService conversationalEntryService;
    private final CreditReminderService creditReminderService;
    private final ObjectMapper objectMapper;

    public AgentChatResponse chat(String rawMessage) {
        requireOrgId();
        String message = rawMessage == null ? "" : rawMessage.trim();
        if (message.isEmpty()) {
            return reply(TOOL_NONE, "Type a question, or tell me about a payment to record.");
        }
        if (message.length() > MAX_MESSAGE_LEN) {
            message = message.substring(0, MAX_MESSAGE_LEN);
        }

        Plan plan = plan(message);
        return switch (plan.tool()) {
            case TOOL_QUERY -> runQuery(plan.arg("question", message));
            case TOOL_DRAFT -> runDraft(plan.arg("text", message));
            case TOOL_OVERDUE -> runOverdue();
            default -> reply(TOOL_NONE, plan.reply() != null ? plan.reply()
                    : "I can answer questions about your data, record a payment, or list who owes you.");
        };
    }

    // ── Planning ─────────────────────────────────────────────────────────

    private Plan plan(String message) {
        try {
            String raw = modelRouter.sendMessage(SYSTEM_PROMPT, message);
            Plan parsed = parsePlan(raw);
            if (parsed != null && isKnownTool(parsed.tool())) {
                return parsed;
            }
            log.debug("Agent planner returned no usable tool; using rules. raw={}", raw);
        } catch (Exception e) {
            log.debug("Agent planner unavailable ({}); using keyword rules", e.getMessage());
        }
        return planWithRules(message);
    }

    /** Deterministic fallback so the offline-capable intents work without a model. */
    private Plan planWithRules(String message) {
        if (PAYMENT_WORDS.matcher(message).find() && HAS_DIGIT.matcher(message).find()) {
            return new Plan(TOOL_DRAFT, message, null, message);
        }
        if (OVERDUE_WORDS.matcher(message).find()) {
            return new Plan(TOOL_OVERDUE, null, null, null);
        }
        // Default to the data query — the natural-language answer path.
        return new Plan(TOOL_QUERY, message, null, null);
    }

    private Plan parsePlan(String raw) {
        if (raw == null || raw.isBlank()) return null;
        Matcher m = JSON_OBJECT.matcher(raw);
        if (!m.find()) return null;
        try {
            JsonNode node = objectMapper.readTree(m.group());
            String tool = node.path("tool").asText(null);
            if (tool == null) return null;
            JsonNode args = node.path("args");
            String question = args.path("question").asText(null);
            String text = args.path("text").asText(null);
            String reply = node.path("reply").asText(null);
            // Stash both possible args; arg() picks the right one per tool.
            return new Plan(tool.trim().toLowerCase(Locale.ROOT),
                    question != null ? question : text, reply, text);
        } catch (Exception e) {
            return null;
        }
    }

    private boolean isKnownTool(String tool) {
        return TOOL_QUERY.equals(tool) || TOOL_DRAFT.equals(tool)
                || TOOL_OVERDUE.equals(tool) || TOOL_NONE.equals(tool);
    }

    // ── Tools ────────────────────────────────────────────────────────────

    private AgentChatResponse runQuery(String question) {
        try {
            AiQueryResponse resp = nlpQueryService.processQuery(question);
            return new AgentChatResponse(resp.answer(), TOOL_QUERY, resp, null, false, List.of());
        } catch (BusinessException e) {
            return reply(TOOL_QUERY,
                    "I couldn't answer that from your data. Try rephrasing, or ask about "
                            + "sales, purchases, or stock. (" + e.getMessage() + ")");
        }
    }

    private AgentChatResponse runDraft(String text) {
        EntryDraftResult r = conversationalEntryService.draftFromText(text);
        List<String> warnings = r.warnings() == null ? List.of() : r.warnings();
        if (!r.drafted()) {
            return new AgentChatResponse(r.message(), TOOL_DRAFT, r, null, false, warnings);
        }
        String reply = r.message() + " Review and approve it in your AI Inbox to post.";
        return new AgentChatResponse(reply, TOOL_DRAFT, r, r.suggestionId(), true, warnings);
    }

    private AgentChatResponse runOverdue() {
        List<OverdueCustomerResponse> overdue = creditReminderService.getOverdueCustomers();
        if (overdue.isEmpty()) {
            return new AgentChatResponse(
                    "No customers are overdue right now — your receivables are current.",
                    TOOL_OVERDUE, List.of(), null, false, List.of());
        }
        BigDecimal total = overdue.stream()
                .map(OverdueCustomerResponse::overdueAmount)
                .filter(java.util.Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        List<String> top = new ArrayList<>();
        for (int i = 0; i < Math.min(5, overdue.size()); i++) {
            OverdueCustomerResponse c = overdue.get(i);
            top.add("• " + c.contactName() + " — " + money(c.overdueAmount())
                    + " (" + c.maxDaysOverdue() + " days)");
        }
        String reply = overdue.size() + " customer(s) overdue, " + money(total)
                + " in total:\n" + String.join("\n", top)
                + (overdue.size() > 5 ? "\n…and " + (overdue.size() - 5) + " more." : "");
        return new AgentChatResponse(reply, TOOL_OVERDUE, overdue, null, false, List.of());
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private AgentChatResponse reply(String tool, String text) {
        return new AgentChatResponse(text, tool, null, null, false, List.of());
    }

    private static String money(BigDecimal v) {
        return "₹" + (v == null ? "0" : v.stripTrailingZeros().toPlainString());
    }

    private void requireOrgId() {
        if (TenantContext.getCurrentOrgId() == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
    }

    /** Planner output. {@code primaryArg} is question (query) or text (draft); {@code text} kept for draft. */
    private record Plan(String tool, String primaryArg, String reply, String text) {
        String arg(String which, String fallback) {
            String v = "text".equals(which) && text != null ? text : primaryArg;
            return v == null || v.isBlank() ? fallback : v;
        }
    }
}
