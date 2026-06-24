package com.katasticho.erp.procurement.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateSupplierRateContractRequest(
        @NotNull UUID supplierContactId,
        LocalDate validFrom,
        LocalDate validUntil,
        String notes,
        @NotEmpty @Valid List<LineRequest> lines
) {
    public record LineRequest(
            @NotNull UUID itemId,
            @NotNull BigDecimal unitPrice,
            BigDecimal minOrderQty,
            String notes
    ) {}
}
