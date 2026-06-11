package com.katasticho.erp.auth.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * An org-scoped API key for programmatic access (MCP server, integrations,
 * scripts). Only the SHA-256 hash is persisted; the plaintext is shown once.
 *
 * <p>A key "acts as" an {@link AppUser} ({@code userId}) so requests carry that
 * user's role for {@code @PreAuthorize}/module gating and audit, exactly like a
 * logged-in session.
 */
@Entity
@Table(name = "api_key")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ApiKey extends BaseEntity {

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "key_hash", nullable = false, length = 64)
    private String keyHash;

    @Column(name = "key_prefix", nullable = false, length = 16)
    private String keyPrefix;

    @Column(name = "last_used_at")
    private Instant lastUsedAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    /** Active, not revoked, not soft-deleted, and not past expiry. */
    public boolean isUsable() {
        return active
                && !isDeleted()
                && revokedAt == null
                && (expiresAt == null || expiresAt.isAfter(Instant.now()));
    }
}
