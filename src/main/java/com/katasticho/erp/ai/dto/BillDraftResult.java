package com.katasticho.erp.ai.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Outcome of drafting (or approving) an AI-drafted purchase bill.
 *
 * <p>{@code suggestionId} is the AI Inbox entry; {@code billId} is the DRAFT
 * (or, after approval, POSTED) purchase bill. {@code warnings} surfaces things
 * the human should glance at before approving — e.g. a newly created vendor or
 * lines that couldn't be matched to an inventory item and were booked as
 * expense instead.
 */
public record BillDraftResult(
        UUID suggestionId,
        UUID billId,
        String billNumber,
        String status,
        UUID contactId,
        String vendorName,
        boolean vendorCreated,
        BigDecimal totalAmount,
        int lineCount,
        int unmatchedItemCount,
        double confidence,
        List<String> warnings
) {}
