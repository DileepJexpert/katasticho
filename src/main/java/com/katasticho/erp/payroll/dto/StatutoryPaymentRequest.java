package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record StatutoryPaymentRequest(
    @NotBlank String statutoryType,
    String periodLabel,
    LocalDate dueDate,
    @NotNull LocalDate paymentDate,
    @NotNull BigDecimal amount,
    UUID paymentAccountId,
    String referenceNumber
) {}
