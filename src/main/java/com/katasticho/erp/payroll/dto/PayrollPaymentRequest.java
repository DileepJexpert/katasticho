package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record PayrollPaymentRequest(
    @NotNull LocalDate paymentDate,
    @NotNull UUID paymentAccountId,
    @NotNull @Positive BigDecimal amount,
    String paymentMode,
    String referenceNumber
) {}
