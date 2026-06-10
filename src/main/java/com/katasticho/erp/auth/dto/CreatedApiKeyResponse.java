package com.katasticho.erp.auth.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Returned ONCE when a key is created — the only time the plaintext {@code key}
 * is ever exposed. Store it securely; it cannot be retrieved again.
 */
public record CreatedApiKeyResponse(
        UUID id,
        String name,
        String keyPrefix,
        String key,
        Instant expiresAt,
        Instant createdAt
) {}
