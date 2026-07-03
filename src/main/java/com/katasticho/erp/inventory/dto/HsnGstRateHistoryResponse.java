package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/** One effective-dated GST rate period for an HSN code. */
public record HsnGstRateHistoryResponse(
        String hsnCode,
        BigDecimal gstRate,
        BigDecimal cessRate,
        LocalDate effectiveFrom,
        LocalDate effectiveTo,
        String notificationRef,
        String source,
        String description
) {
}
