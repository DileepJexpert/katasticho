package com.katasticho.erp.auth.dto;

import com.katasticho.erp.auth.entity.UserInvitation;

import java.time.Instant;
import java.util.UUID;

public record PendingInviteResponse(
        UUID id,
        String email,
        String phone,
        String role,
        Instant expiresAt,
        Instant createdAt,
        boolean expired
) {
    public static PendingInviteResponse from(UserInvitation invite) {
        return new PendingInviteResponse(
                invite.getId(),
                invite.getEmail(),
                invite.getPhone(),
                invite.getRole(),
                invite.getExpiresAt(),
                invite.getCreatedAt(),
                invite.isExpired()
        );
    }
}
