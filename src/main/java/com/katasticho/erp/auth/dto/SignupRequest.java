package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public record SignupRequest(
        @NotBlank(message = "Phone number is required")
        @Pattern(regexp = "^\\+?[1-9]\\d{6,14}$", message = "Invalid phone number format")
        String phone,

        @NotBlank(message = "OTP is required")
        @Size(min = 6, max = 6)
        String otp,

        @NotBlank(message = "Full name is required")
        @Size(min = 2, max = 255)
        String fullName,

        @NotBlank(message = "Organisation name is required")
        @Size(min = 2, max = 255)
        String orgName,

        String industry,

        String businessType,

        String industryCode,

        List<String> subCategories
) {}
