package com.katasticho.erp.ai.dto;

public record AiInboxSummaryResponse(
        long pending,
        long highPriorityPending
) {}
