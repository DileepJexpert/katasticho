package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Self-service password change for a logged-in user. The caller proves
 * knowledge of {@code oldPassword}; the session stays valid afterwards.
 */
public record ChangePasswordRequest(
        @NotBlank String oldPassword,
        @NotBlank @Size(min = 8, message = "Password must be at least 8 characters") String newPassword
) {}
