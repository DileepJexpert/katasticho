package com.katasticho.erp.fieldsales.dto;

import java.util.UUID;

/**
 * A customer stop assigned to a beat, enriched with contact details for
 * operational screens. The contact remains the master record.
 */
public record BeatCustomerResponse(
        UUID id,
        UUID beatId,
        UUID contactId,
        String contactName,
        String companyName,
        String phone,
        Integer visitSequence,
        String visitFrequency,
        boolean active
) {
}
