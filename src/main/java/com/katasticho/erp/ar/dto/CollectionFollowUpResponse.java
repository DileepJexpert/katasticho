package com.katasticho.erp.ar.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record CollectionFollowUpResponse(
        UUID id,
        UUID contactId,
        String status,
        LocalDate promiseToPayDate,
        String note,
        Instant recordedAt,
        UUID recordedBy
) {
}
