package com.katasticho.erp.auth.dto;

import com.katasticho.erp.auth.entity.ApiKey;

import java.time.Instant;
import java.util.UUID;

/** API key metadata for listing — never includes the secret. */
public record ApiKeyResponse(
        UUID id,
        String name,
        String keyPrefix,
        boolean active,
        Instant lastUsedAt,
        Instant expiresAt,
        Instant revokedAt,
        Instant createdAt
) {
    public static ApiKeyResponse from(ApiKey k) {
        return new ApiKeyResponse(
                k.getId(), k.getName(), k.getKeyPrefix(), k.isUsable(),
                k.getLastUsedAt(), k.getExpiresAt(), k.getRevokedAt(), k.getCreatedAt());
    }
}
