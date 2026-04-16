package com.katasticho.erp.ap.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateVendorCreditRequest(
        @NotNull UUID contactId,
        @NotNull LocalDate creditDate,
        UUID purchaseBillId,
        @NotBlank String reason,
        String placeOfSupply,
        UUID branchId,
        @NotEmpty @Valid List<CreditLineRequest> lines
) {
    public record CreditLineRequest(
            @NotBlank String description,
            String hsnCode,
            UUID itemId,
            @NotNull UUID accountId,
            @NotNull BigDecimal quantity,
            @NotNull BigDecimal unitPrice,
            @NotNull BigDecimal gstRate,
            UUID taxGroupId
    ) {}
}
