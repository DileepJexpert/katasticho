package com.katasticho.erp.ai.dto;

import com.katasticho.erp.ai.entity.OrgAiSettings;

public record AiModelSettingsResponse(
    String provider,
    String modelName,
    String baseUrl
) {
    public static AiModelSettingsResponse from(OrgAiSettings s) {
        return new AiModelSettingsResponse(s.getProvider(), s.getModelName(), s.getBaseUrl());
    }
    public static AiModelSettingsResponse defaults() {
        return new AiModelSettingsResponse("CLAUDE", "claude-sonnet-4-20250514", null);
    }
}
