package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ResetPasswordRequest(
        @NotBlank String phone,
        @NotBlank String otp,
        @NotBlank @Size(min = 8, message = "Password must be at least 8 characters") String newPassword
) {}
