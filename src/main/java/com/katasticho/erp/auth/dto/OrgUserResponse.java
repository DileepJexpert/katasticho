package com.katasticho.erp.auth.dto;

import com.katasticho.erp.auth.entity.AppUser;

import java.time.Instant;
import java.util.UUID;

public record OrgUserResponse(
        UUID id,
        String fullName,
        String email,
        String phone,
        String role,
        boolean active,
        Instant lastLoginAt,
        boolean hasPassword
) {
    public static OrgUserResponse from(AppUser user) {
        return new OrgUserResponse(
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole(),
                user.isActive(),
                user.getLastLoginAt(),
                user.getPasswordHash() != null
        );
    }
}
