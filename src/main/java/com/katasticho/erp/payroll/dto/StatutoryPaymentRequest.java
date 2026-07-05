package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record StatutoryPaymentRequest(
    @NotBlank String statutoryType,
    String periodLabel,
    LocalDate dueDate,
    @NotNull LocalDate paymentDate,
    @NotNull @Positive BigDecimal amount,
    UUID paymentAccountId,
    String referenceNumber
) {}
