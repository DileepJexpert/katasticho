package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record RecentJournalResponse(
        UUID id,
        String entryNumber,
        LocalDate effectiveDate,
        String description,
        String sourceModule,
        String status,
        BigDecimal totalDebit
) {}
