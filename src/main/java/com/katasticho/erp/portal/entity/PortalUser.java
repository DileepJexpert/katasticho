package com.katasticho.erp.portal.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * An external self-service portal login for a {@code Contact} (customer or
 * vendor). Separate from the app's {@code AppUser}; authenticated by a portal
 * JWT signed with a dedicated key.
 */
@Entity
@Table(name = "portal_user")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PortalUser {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    /** CUSTOMER | VENDOR. */
    @Column(nullable = false, length = 20)
    private String kind;

    @Column(nullable = false, length = 255)
    private String email;

    @Column(name = "full_name", length = 255)
    private String fullName;

    @Column(name = "password_hash", length = 255)
    private String passwordHash;

    /** INVITED | ACTIVE | SUSPENDED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "INVITED";

    @Column(name = "invite_token_hash", length = 255)
    private String inviteTokenHash;

    @Column(name = "invite_expires_at")
    private Instant inviteExpiresAt;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    @Column(name = "token_version", nullable = false)
    @Builder.Default
    private int tokenVersion = 0;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
