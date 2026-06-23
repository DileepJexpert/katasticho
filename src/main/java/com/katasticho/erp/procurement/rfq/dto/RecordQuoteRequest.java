package com.katasticho.erp.procurement.rfq.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record RecordQuoteRequest(
        @NotNull UUID supplierContactId,
        String quoteNumber,
        LocalDate validUntil,
        String notes,
        @NotEmpty @Valid List<QuoteLineRequest> lines
) {
    public record QuoteLineRequest(
            UUID itemId,
            String description,
            @NotNull BigDecimal quantity,
            @NotNull BigDecimal unitPrice,
            Integer leadTimeDays,
            String notes
    ) {}
}
