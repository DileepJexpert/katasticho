package com.katasticho.erp.platform.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "platform_admin")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PlatformAdmin {
    @Id @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;
    @Column(name = "full_name", nullable = false) private String fullName;
    @Column(unique = true, nullable = false) private String email;
    @Column(name = "password_hash", nullable = false) private String passwordHash;
    @Column(nullable = false, length = 30) @Builder.Default private String role = "PLATFORM_ADMIN";
    @Column(name = "token_version", nullable = false) @Builder.Default private int tokenVersion = 0;
    @Column(name = "is_active", nullable = false) @Builder.Default private boolean active = true;
    @Column(name = "failed_login_count", nullable = false) @Builder.Default private int failedLoginCount = 0;
    @Column(name = "locked_until") private Instant lockedUntil;
    @Column(name = "last_login_at") private Instant lastLoginAt;
    @Column(name = "created_at", nullable = false, updatable = false) @Builder.Default private Instant createdAt = Instant.now();

    public boolean isLocked() { return lockedUntil != null && Instant.now().isBefore(lockedUntil); }
    public void incrementFailedLogins() { this.failedLoginCount++; }
    public void resetFailedLogins() { this.failedLoginCount = 0; this.lockedUntil = null; }
    public void lock(int lockoutMinutes) { this.lockedUntil = Instant.now().plusSeconds(lockoutMinutes * 60L); }
    public void incrementTokenVersion() { this.tokenVersion++; }
}
