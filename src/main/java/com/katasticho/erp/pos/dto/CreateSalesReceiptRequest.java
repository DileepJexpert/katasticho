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

        Boolean gstInvoice,

        /** Client temp number (e.g. OFF-0007) when this receipt was rung up
         *  offline — kept on the posted receipt so a paper bill can be traced. */
        String offlineReceiptNumber,

        // ── Inline prescriber capture (Schedule H1 / X / Narcotics) ──
        // Captured at the counter so the statutory register is populated at
        // sale time. Without these, prescriber columns are null until a
        // PrescriptionRecord is later linked to the receipt (and under
        // pharma.h1_strict=true, an H1 sale can't be completed at all).
        String prescriptionNumber,
        String prescriberName,
        String prescriberRegNumber,
        String prescriberAddress,

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
            UUID batchId,
            UUID unitUomId,
            BigDecimal unitConversionFactor,
            Boolean taxInclusive
    ) {}
}
