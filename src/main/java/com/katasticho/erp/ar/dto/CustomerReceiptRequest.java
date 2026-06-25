package com.katasticho.erp.ar.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Record a lump-sum customer receipt allocated across zero or more invoices.
 * The unallocated remainder ({@code amount} − Σ allocations) is parked as a
 * Customer Advance. {@code allocations} may be empty for a pure advance
 * collection.
 */
public record CustomerReceiptRequest(
        @NotNull UUID contactId,
        @NotNull @Positive BigDecimal amount,
        @NotBlank String paymentMethod,
        @NotNull LocalDate receiptDate,
        String referenceNumber,
        String notes,
        UUID branchId,
        @Valid List<AllocationRequest> allocations
) {
    public record AllocationRequest(
            @NotNull UUID invoiceId,
            @NotNull @Positive BigDecimal amountApplied
    ) {}

    public CustomerReceiptRequest {
        if (allocations == null) allocations = List.of();
    }
}
