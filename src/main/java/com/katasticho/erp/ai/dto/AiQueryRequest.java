package com.katasticho.erp.ai.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AiQueryRequest(
        @NotBlank(message = "Message is required")
        @Size(max = 1000, message = "Message must be under 1000 characters")
        String message
) {}
