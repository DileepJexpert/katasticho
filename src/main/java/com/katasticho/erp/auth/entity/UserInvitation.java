package com.katasticho.erp.auth.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_invitation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserInvitation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column
    private String email;

    @Column(length = 20)
    private String phone;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String role = "VIEWER";

    @Column(nullable = false, unique = true)
    private String token;

    @Column(name = "invited_by", nullable = false)
    private UUID invitedBy;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "accepted_at")
    private Instant acceptedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }

    public boolean isExpired() {
        return Instant.now().isAfter(expiresAt);
    }

    public boolean isAccepted() {
        return acceptedAt != null;
    }

    public boolean isValid() {
        return !isExpired() && !isAccepted();
    }
}
