package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

public record RegisterRequest(
        @NotBlank String phone,
        @NotBlank @Size(min = 8, message = "Password must be at least 8 characters") String password,
        @NotBlank String fullName,
        @NotBlank String orgName,
        String businessType,
        String industryCode,
        List<String> subCategories
) {}
