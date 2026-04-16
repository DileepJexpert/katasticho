package com.katasticho.erp.pos.dto;

import com.katasticho.erp.pos.entity.PaymentMode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateSalesReceiptRequest(

        UUID branchId,

        UUID contactId,

        @NotNull(message = "Receipt date is required")
        LocalDate receiptDate,

        @NotNull(message = "Payment mode is required")
        PaymentMode paymentMode,

        UUID paidThroughId,

        @NotNull(message = "Amount received is required")
        @DecimalMin(value = "0.00", message = "Amount received must be >= 0")
        BigDecimal amountReceived,

        String upiReference,

        String notes,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<LineRequest> lines
) {
    public record LineRequest(
            UUID itemId,
            String description,

            @NotNull(message = "Quantity is required")
            @DecimalMin(value = "0.001", message = "Quantity must be > 0")
            BigDecimal quantity,

            String unit,

            @NotNull(message = "Rate is required")
            @DecimalMin(value = "0.00", message = "Rate must be >= 0")
            BigDecimal rate,

            UUID taxGroupId,
            String hsnCode,
            UUID batchId
    ) {}
}
