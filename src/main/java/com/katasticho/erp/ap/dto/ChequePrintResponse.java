package com.katasticho.erp.ap.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record ChequePrintResponse(
        UUID paymentId,
        String paymentNumber,
        String payeeName,
        BigDecimal amount,
        String amountFormatted,
        String amountInWords,
        LocalDate paymentDate,
        String dateFormatted,
        String dateSpaced,
        String chequeNumber,
        boolean accountPayeeOnly,
        String bankName,
        String bankAccountNo,
        String ifscCode,
        String organisationName
) {}
