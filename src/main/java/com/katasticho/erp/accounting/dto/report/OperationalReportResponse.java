package com.katasticho.erp.accounting.dto.report;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record OperationalReportResponse(
        String reportKey,
        String title,
        String description,
        LocalDate startDate,
        LocalDate endDate,
        String currency,
        List<SummaryMetric> metrics,
        List<ColumnDef> columns,
        List<Map<String, Object>> rows
) {
    public record SummaryMetric(
            String key,
            String label,
            BigDecimal value,
            String format
    ) {}

    public record ColumnDef(
            String key,
            String label,
            String type
    ) {}
}
