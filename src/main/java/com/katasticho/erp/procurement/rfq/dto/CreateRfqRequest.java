package com.katasticho.erp.procurement.rfq.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateRfqRequest(
        @NotBlank String title,
        LocalDate dueDate,
        String notes,
        @NotEmpty @Valid List<LineRequest> lines,
        @NotEmpty List<UUID> supplierContactIds
) {
    public record LineRequest(
            UUID itemId,
            String description,
            @NotNull BigDecimal quantity,
            String hsnCode,
            BigDecimal gstRate
    ) {}
}
