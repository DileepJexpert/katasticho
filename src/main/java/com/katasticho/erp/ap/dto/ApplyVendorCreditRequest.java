package com.katasticho.erp.ap.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.util.UUID;

public record ApplyVendorCreditRequest(
        @NotNull UUID billId,
        @NotNull @Positive BigDecimal amount
) {}
