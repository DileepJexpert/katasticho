package com.katasticho.erp.fieldsales.dto;

import java.util.UUID;

/**
 * A planned customer stop on a beat. The sequence controls the default visit
 * order; frequency can be refined later without changing the contact master.
 */
public record BeatCustomerAssignmentRequest(
        UUID contactId,
        Integer visitSequence,
        String visitFrequency
) {
}
