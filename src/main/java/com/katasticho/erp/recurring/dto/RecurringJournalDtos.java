package com.katasticho.erp.recurring.dto;

import com.katasticho.erp.recurring.entity.RecurringJournal;
import com.katasticho.erp.recurring.entity.RecurringJournalGeneration;
import com.katasticho.erp.recurring.entity.RecurringJournalLine;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Request/response records for recurring journals. */
public final class RecurringJournalDtos {

    private RecurringJournalDtos() {}

    public record CreateRecurringJournalRequest(
            String profileName,
            String frequency,
            LocalDate startDate,
            LocalDate endDate,
            String narration,
            boolean autoPost,
            String notes,
            List<RecurringJournalLine> lines) {}

    public record UpdateRecurringJournalRequest(
            String profileName,
            String frequency,
            LocalDate endDate,
            String narration,
            Boolean autoPost,
            String notes,
            List<RecurringJournalLine> lines) {}

    public record RecurringJournalResponse(
            UUID id, String profileName, String frequency,
            LocalDate startDate, LocalDate endDate, LocalDate nextRunDate,
            String narration, boolean autoPost, String status, int totalGenerated,
            Instant lastGeneratedAt, String notes, List<RecurringJournalLine> lines) {

        public static RecurringJournalResponse of(RecurringJournal j) {
            return new RecurringJournalResponse(j.getId(), j.getProfileName(), j.getFrequency(),
                    j.getStartDate(), j.getEndDate(), j.getNextRunDate(), j.getNarration(),
                    j.isAutoPost(), j.getStatus(), j.getTotalGenerated(), j.getLastGeneratedAt(),
                    j.getNotes(), j.getLines());
        }
    }

    public record GeneratedJournalResponse(UUID journalEntryId, Instant generatedAt, boolean autoPosted) {
        public static GeneratedJournalResponse of(RecurringJournalGeneration g) {
            return new GeneratedJournalResponse(g.getJournalEntryId(), g.getGeneratedAt(), g.isAutoPosted());
        }
    }
}
