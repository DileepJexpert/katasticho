package com.katasticho.erp.dunning.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** DTOs for dunning levels, the sweep result, and the send log. */
public final class DunningDtos {

    private DunningDtos() {}

    public record LevelRequest(
            Integer seq,
            String name,
            Integer daysOverdue,
            String channel,        // EMAIL | WHATSAPP | AI_INBOX | NONE
            String subject,
            String messageTemplate,
            Boolean active) {}

    public record LevelResponse(
            UUID id, int seq, String name, int daysOverdue, String channel,
            String subject, String messageTemplate, boolean active) {}

    public record DunningRunResult(int candidates, int sent, int skipped, int failed) {}

    /** What the sweep WOULD fire right now (read-only, never sends). */
    public record DunningPreviewRow(
            UUID invoiceId, String invoiceNumber, UUID contactId, int daysOverdue,
            BigDecimal amount, UUID levelId, String levelName, String channel, boolean alreadySent) {}

    public record DunningLogResponse(
            UUID id, UUID invoiceId, UUID contactId, UUID dunningLevelId,
            int daysOverdue, BigDecimal amount, String channel, String outcome,
            String detail, Instant sentAt) {}
}
