package com.katasticho.erp.ai.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.List;
import java.util.UUID;

/**
 * Conversational agent (tool-use) request/response.
 *
 * <p>The user types one natural-language message; the agent picks a single tool
 * (query my data, draft a transaction, list overdue customers), runs it through
 * the existing services, and replies. Write tools only ever produce a DRAFT that
 * a human approves — the agent never posts on its own.
 */
public class AgentChatDtos {

    public record AgentChatRequest(@NotBlank String message) {}

    public record AgentChatResponse(
            String reply,               // natural-language answer to show the user
            String tool,                // tool that ran: query_data / draft_entry / list_overdue / none
            Object data,                // tool payload (query rows, draft result, overdue list) — may be null
            UUID draftSuggestionId,     // set when a draft was created and awaits approval
            boolean actionRequired,     // true when a draft is waiting in the AI Inbox
            List<String> warnings
    ) {}

    private AgentChatDtos() {}
}
