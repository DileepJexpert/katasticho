package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record OutstandingReceivableResponse(
        BigDecimal totalOutstanding,
        int overdueCount,
        BigDecimal overdueAmount,
        String currency,
        List<TopCustomer> topCustomers
) {
    public record TopCustomer(
            UUID contactId,
            String name,
            BigDecimal outstanding,
            int invoiceCount
    ) {}
}
