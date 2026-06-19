package com.katasticho.erp.ai.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record AiModelSettingsRequest(
    @NotBlank @Pattern(regexp = "^(CLAUDE|OLLAMA|OPENAI_COMPAT)$") String provider,
    @NotBlank String modelName,
    String baseUrl  // required for OLLAMA / OPENAI_COMPAT
) {}
