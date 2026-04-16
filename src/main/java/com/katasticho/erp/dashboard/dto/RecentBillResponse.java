package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record RecentBillResponse(
        java.util.UUID id,
        String billNumber,
        String vendorName,
        String status,
        BigDecimal totalAmount,
        LocalDate billDate
) {}
