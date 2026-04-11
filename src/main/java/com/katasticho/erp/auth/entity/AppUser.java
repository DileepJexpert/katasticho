package com.katasticho.erp.auth.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "app_user")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AppUser extends BaseEntity {

    @Column
    private String email;

    @Column(length = 20)
    private String phone;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String role = "VIEWER";

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "failed_login_count", nullable = false)
    @Builder.Default
    private int failedLoginCount = 0;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    public boolean isLocked() {
        return lockedUntil != null && Instant.now().isBefore(lockedUntil);
    }

    public void incrementFailedLogins() {
        this.failedLoginCount++;
    }

    public void resetFailedLogins() {
        this.failedLoginCount = 0;
        this.lockedUntil = null;
    }

    public void lock(int lockoutMinutes) {
        this.lockedUntil = Instant.now().plusSeconds(lockoutMinutes * 60L);
    }
}
