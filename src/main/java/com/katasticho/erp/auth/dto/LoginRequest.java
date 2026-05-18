package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank(message = "Phone or email is required")
        String identifier,

        @NotBlank(message = "Password is required")
        String password
) {}
