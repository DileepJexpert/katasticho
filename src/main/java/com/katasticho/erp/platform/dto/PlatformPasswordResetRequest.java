package com.katasticho.erp.platform.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PlatformPasswordResetRequest(
        @NotBlank @Size(min = 8, message = "Password must be at least 8 characters") String newPassword,
        String reason
) {}
