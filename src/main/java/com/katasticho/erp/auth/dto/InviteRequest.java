package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record InviteRequest(
        String email,
        String phone,

        @NotBlank(message = "Role is required")
        @Pattern(regexp = "^(ACCOUNTANT|OPERATOR|VIEWER)$", message = "Role must be ACCOUNTANT, OPERATOR, or VIEWER")
        String role
) {}
