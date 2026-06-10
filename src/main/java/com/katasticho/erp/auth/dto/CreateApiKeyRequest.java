package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request to mint a new API key.
 *
 * @param name          human label, e.g. "Claude Desktop" or "Nightly export"
 * @param expiresInDays optional lifetime in days; null/0 = never expires
 */
public record CreateApiKeyRequest(
        @NotBlank(message = "A name is required")
        String name,
        Integer expiresInDays
) {}
