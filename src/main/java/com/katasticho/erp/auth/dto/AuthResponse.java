package com.katasticho.erp.auth.dto;

import java.util.UUID;

public record AuthResponse(
        String accessToken,
        String refreshToken,
        UserInfo user
) {
    public record UserInfo(
            UUID id,
            UUID orgId,
            String fullName,
            String email,
            String phone,
            String role,
            String orgName,
            String industry,
            String industryCode,
            boolean onboardingCompleted,
            String defaultLandingPage
    ) {}
}
