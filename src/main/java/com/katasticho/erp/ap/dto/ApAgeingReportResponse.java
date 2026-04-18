package com.katasticho.erp.ap.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record ApAgeingReportResponse(
        BigDecimal totalOutstanding,
        BigDecimal current,
        BigDecimal days1to30,
        BigDecimal days31to60,
        BigDecimal days61to90,
        BigDecimal days90plus,
        List<VendorAgeing> vendors
) {
    public record VendorAgeing(
            UUID contactId,
            String vendorName,
            BigDecimal totalOutstanding,
            BigDecimal current,
            BigDecimal days1to30,
            BigDecimal days31to60,
            BigDecimal days61to90,
            BigDecimal days90plus,
            List<BillAgeing> bills
    ) {}

    public record BillAgeing(
            UUID billId,
            String billNumber,
            BigDecimal balanceDue,
            long daysOverdue,
            String bucket
    ) {}
}
