package com.katasticho.erp.ai.dto;

import java.util.List;
import java.util.Map;

public record AiQueryResponse(
        String answer,
        String generatedSql,
        List<Map<String, Object>> results,
        QueryMetadata metadata
) {
    public record QueryMetadata(
            String intent,
            long executionTimeMs,
            int rowCount
    ) {}
}
