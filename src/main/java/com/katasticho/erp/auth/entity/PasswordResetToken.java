package com.katasticho.erp.auth.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "password_reset_token")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PasswordResetToken {
    @Id @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;
    @Column(name = "user_id", nullable = false) private UUID userId;
    @Column(name = "token_hash", nullable = false, length = 128) private String tokenHash;
    @Column(name = "delivery_method", nullable = false, length = 10) @Builder.Default private String deliveryMethod = "EMAIL";
    @Column(name = "delivered_to", nullable = false) private String deliveredTo;
    @Column(name = "expires_at", nullable = false) private Instant expiresAt;
    @Column(nullable = false) @Builder.Default private boolean used = false;
    @Column(name = "used_at") private Instant usedAt;
    @Column(name = "ip_address", length = 45) private String ipAddress;
    @Column(name = "created_at", nullable = false, updatable = false) @Builder.Default private Instant createdAt = Instant.now();

    public boolean isExpired() { return Instant.now().isAfter(expiresAt); }
    public void markUsed() { this.used = true; this.usedAt = Instant.now(); }
}
