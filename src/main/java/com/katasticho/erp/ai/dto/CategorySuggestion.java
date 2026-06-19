package com.katasticho.erp.ai.dto;

import java.util.UUID;

/**
 * A predicted GL account for an un-categorized purchase line, learned from how
 * this vendor's bills were booked in the past.
 *
 * @param accountId   the suggested GL account
 * @param accountCode its code (e.g. "5240")
 * @param accountName its name (e.g. "Travel &amp; Conveyance")
 * @param confidence  0..1 — how consistently history points at this account
 * @param source      EXACT (same vendor + HSN) or VENDOR (same vendor, any HSN)
 * @param observations how many historical lines backed the prediction
 */
public record CategorySuggestion(
        UUID accountId,
        String accountCode,
        String accountName,
        double confidence,
        String source,
        int observations) {
}
