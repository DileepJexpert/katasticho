package com.katasticho.erp.ca.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ca_alert_dismissal")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CaAlertDismissal {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "ca_firm_id", nullable = false)
    private UUID caFirmId;

    @Column(name = "suggestion_id", nullable = false)
    private UUID suggestionId;

    @Column(name = "dismissed_by", nullable = false)
    private UUID dismissedBy;

    @Column(name = "assigned_user_id")
    private UUID assignedUserId;

    @Column(name = "dismissed_at")
    private Instant dismissedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }
}
