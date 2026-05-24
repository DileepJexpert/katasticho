package com.katasticho.erp.pharma.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PrescriptionResponse(
        UUID id,
        UUID contactId,
        UUID receiptId,
        String doctorName,
        String doctorRegNumber,
        String prescriptionNumber,
        LocalDate prescribedDate,
        LocalDate validUntil,
        String notes,
        List<PrescriptionItemDto> items,
        Instant createdAt
) {}
