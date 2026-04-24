package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateAdditionalOrgRequest(
        @NotBlank String name,
        String businessType,
        String industryCode
) {}
