package com.katasticho.erp.platform.dto;

public record PlatformPlanUpdateRequest(
        String planTier,
        String note
) {
}
