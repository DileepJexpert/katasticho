package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateUserRoleRequest(
        @NotBlank
        @Pattern(regexp = "^(ADMIN|ACCOUNTANT|OPERATOR|VIEWER)$",
                 message = "Role must be ADMIN, ACCOUNTANT, OPERATOR, or VIEWER")
        String role
) {}
