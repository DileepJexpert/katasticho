package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record PayrollPaymentRequest(
    @NotNull LocalDate paymentDate,
    @NotNull UUID paymentAccountId,
    @NotNull BigDecimal amount,
    String paymentMode,
    String referenceNumber
) {}
