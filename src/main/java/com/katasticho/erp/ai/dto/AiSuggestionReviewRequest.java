package com.katasticho.erp.ai.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.Map;

public record AiSuggestionReviewRequest(
        @NotBlank String action,
        Map<String, Object> reviewedValue,
        String correctionReason
) {}
