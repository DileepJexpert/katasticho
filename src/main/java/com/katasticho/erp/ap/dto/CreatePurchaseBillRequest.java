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
        UUID purchaseOrderId,
        @NotEmpty @Valid List<BillLineRequest> lines
) {
    public record BillLineRequest(
            String lineType,
            @NotBlank String description,
            String hsnCode,
            UUID itemId,
            UUID accountId,
            String accountCode,
            @NotNull BigDecimal quantity,
            @NotNull BigDecimal unitPrice,
            BigDecimal discountPercent,
            BigDecimal gstRate,
            UUID taxGroupId,
            UUID unitUomId,
            BigDecimal unitConversionFactor,
            UUID purchaseOrderLineId
    ) {
        public BillLineRequest {
            if (lineType == null) lineType = "GOODS";
            if (discountPercent == null) discountPercent = BigDecimal.ZERO;
            if (gstRate == null) gstRate = BigDecimal.ZERO;
        }

        public boolean isGoods() {
            return "GOODS".equalsIgnoreCase(lineType);
        }
    }
}
