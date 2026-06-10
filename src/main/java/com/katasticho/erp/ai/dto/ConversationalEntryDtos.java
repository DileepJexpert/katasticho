package com.katasticho.erp.ai.dto;

import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/** Request/response payloads for conversational (sentence → drafted) entry. */
public final class ConversationalEntryDtos {

    private ConversationalEntryDtos() {}

    public record EntryDraftRequest(
            @NotBlank(message = "Type what happened, e.g. \"paid 5000 cash for shop rent\"")
            String text
    ) {}

    public record EntryLine(
            String accountCode,
            String accountName,
            BigDecimal debit,
            BigDecimal credit
    ) {}

    /**
     * The result of drafting an entry. When {@code drafted} is false the text
     * could not be turned into a balanced entry — {@code message} explains how
     * to rephrase and no suggestion/journal is created.
     */
    public record EntryDraftResult(
            boolean drafted,
            UUID suggestionId,
            UUID entryId,
            String voucherType,    // PAYMENT / RECEIPT / JOURNAL
            String narration,
            BigDecimal amount,
            double confidence,
            List<EntryLine> lines,
            List<String> warnings,
            String message
    ) {}

    public record EntryRejectRequest(String reason) {}
}
