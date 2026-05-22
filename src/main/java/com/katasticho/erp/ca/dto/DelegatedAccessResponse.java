package com.katasticho.erp.ca.dto;

import java.time.Instant;

public record DelegatedAccessResponse(
        String token,
        String redirectUrl,
        Instant expiresAt
) {
}
