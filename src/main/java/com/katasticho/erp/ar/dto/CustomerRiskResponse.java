package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CustomerRiskResponse(
        UUID contactId,
        String customerName,
        String phone,
        BigDecimal creditLimit,
        BigDecimal outstandingAr,
        BigDecimal overdueAmount,
        int invoiceCount,
        int overdueInvoiceCount,
        long maxDaysOverdue,
        BigDecimal creditUtilizationPercent,
        boolean salesHold,
        String salesHoldReason,
        LocalDate salesHoldUntil,
        String riskLevel,
        List<String> reasons,
        CollectionFollowUpResponse latestFollowUp
) {
}
