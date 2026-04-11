package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record InviteAcceptRequest(
        @NotBlank(message = "Invitation token is required")
        String token,

        @NotBlank(message = "Full name is required")
        @Size(min = 2, max = 255)
        String fullName,

        @Size(min = 8, message = "Password must be at least 8 characters")
        String password
) {}
