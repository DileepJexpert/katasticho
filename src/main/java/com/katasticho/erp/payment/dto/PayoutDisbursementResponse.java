package com.katasticho.erp.payment.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PayoutDisbursementResponse(
    UUID id,
    String provider,
    String providerPayoutId,
    String utr,
    String status,
    UUID contactId,
    String contactName,
    BigDecimal amount,
    String currency,
    String payoutMode,
    String beneficiaryName,
    String accountNumberMasked,
    String ifscCode,
    String vpa,
    UUID vendorPaymentId,
    String failureReason,
    Instant createdAt
) {}
