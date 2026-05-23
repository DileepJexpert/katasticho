package com.katasticho.erp.platform.dto;

import com.katasticho.erp.auth.entity.AppUser;

import java.time.Instant;
import java.util.UUID;

public record PlatformUserResponse(
        UUID id,
        UUID orgId,
        String fullName,
        String email,
        String phone,
        String role,
        boolean active,
        Instant lastLoginAt
) {
    public static PlatformUserResponse from(AppUser user) {
        return new PlatformUserResponse(
                user.getId(),
                user.getOrgId(),
                user.getFullName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole(),
                user.isActive(),
                user.getLastLoginAt()
        );
    }
}
