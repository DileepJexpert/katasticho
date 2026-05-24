package com.katasticho.erp.pharma.dto;

import jakarta.validation.constraints.NotBlank;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PrescriptionRequest(
        UUID contactId,
        UUID receiptId,
        String doctorName,
        String doctorRegNumber,
        @NotBlank String prescriptionNumber,
        LocalDate prescribedDate,
        LocalDate validUntil,
        String notes,
        List<PrescriptionItemDto> items
) {}
