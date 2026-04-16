package com.katasticho.erp.ap.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreatePurchaseBillRequest(
        @NotNull UUID contactId,
        String vendorBillNumber,
        @NotNull LocalDate billDate,
        LocalDate dueDate,
        String placeOfSupply,
        boolean reverseCharge,
        String notes,
        String termsAndConditions,
        UUID branchId,
        @NotEmpty @Valid List<BillLineRequest> lines
) {
    public record BillLineRequest(
            @NotBlank String description,
            String hsnCode,
            UUID itemId,
            @NotNull UUID accountId,
            @NotNull BigDecimal quantity,
            @NotNull BigDecimal unitPrice,
            BigDecimal discountPercent,
            @NotNull BigDecimal gstRate
    ) {
        public BillLineRequest {
            if (discountPercent == null) discountPercent = BigDecimal.ZERO;
        }
    }
}
