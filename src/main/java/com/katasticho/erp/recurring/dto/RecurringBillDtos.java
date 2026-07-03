package com.katasticho.erp.recurring.dto;

import com.katasticho.erp.recurring.entity.RecurringBill;
import com.katasticho.erp.recurring.entity.RecurringBillGeneration;
import com.katasticho.erp.recurring.entity.RecurringBillLineItem;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Request/response records for recurring bills (grouped to keep the tree tidy). */
public final class RecurringBillDtos {

    private RecurringBillDtos() {}

    public record CreateRecurringBillRequest(
            String profileName,
            UUID contactId,
            String frequency,
            LocalDate startDate,
            LocalDate endDate,
            Integer paymentTermsDays,
            boolean reverseCharge,
            String placeOfSupply,
            boolean autoPost,
            String notes,
            String terms,
            List<RecurringBillLineItem> lineItems) {}

    public record UpdateRecurringBillRequest(
            String profileName,
            String frequency,
            LocalDate endDate,
            Integer paymentTermsDays,
            Boolean reverseCharge,
            String placeOfSupply,
            Boolean autoPost,
            String notes,
            String terms,
            List<RecurringBillLineItem> lineItems) {}

    public record RecurringBillResponse(
            UUID id, String profileName, UUID contactId, String frequency,
            LocalDate startDate, LocalDate endDate, LocalDate nextBillDate,
            int paymentTermsDays, boolean reverseCharge, String placeOfSupply,
            boolean autoPost, String status, int totalGenerated, Instant lastGeneratedAt,
            String notes, String terms, List<RecurringBillLineItem> lineItems) {

        public static RecurringBillResponse of(RecurringBill b) {
            return new RecurringBillResponse(b.getId(), b.getProfileName(), b.getContactId(),
                    b.getFrequency(), b.getStartDate(), b.getEndDate(), b.getNextBillDate(),
                    b.getPaymentTermsDays(), b.isReverseCharge(), b.getPlaceOfSupply(),
                    b.isAutoPost(), b.getStatus(), b.getTotalGenerated(), b.getLastGeneratedAt(),
                    b.getNotes(), b.getTerms(), b.getLineItems());
        }
    }

    public record GeneratedBillResponse(UUID billId, Instant generatedAt, boolean autoPosted) {
        public static GeneratedBillResponse of(RecurringBillGeneration g) {
            return new GeneratedBillResponse(g.getBillId(), g.getGeneratedAt(), g.isAutoPosted());
        }
    }
}
