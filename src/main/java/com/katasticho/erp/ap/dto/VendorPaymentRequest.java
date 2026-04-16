package com.katasticho.erp.ap.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record VendorPaymentRequest(
        @NotNull UUID contactId,
        @NotNull @Positive BigDecimal amount,
        @NotBlank String paymentMode,
        @NotNull LocalDate paymentDate,
        @NotNull UUID paidThroughId,
        String referenceNumber,
        BigDecimal tdsAmount,
        String tdsSection,
        String notes,
        UUID branchId,
        @NotEmpty @Valid List<AllocationRequest> allocations
) {
    public record AllocationRequest(
            @NotNull UUID billId,
            @NotNull @Positive BigDecimal amountApplied
    ) {}

    public VendorPaymentRequest {
        if (tdsAmount == null) tdsAmount = BigDecimal.ZERO;
    }
}
