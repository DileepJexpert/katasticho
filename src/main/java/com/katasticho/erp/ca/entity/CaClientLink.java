package com.katasticho.erp.ca.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "ca_client_link")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CaClientLink {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "ca_firm_id", nullable = false)
    private UUID caFirmId;

    @Column(name = "client_org_id", nullable = false)
    private UUID clientOrgId;

    @Column(name = "assigned_user_id")
    private UUID assignedUserId;

    @Column(name = "backup_user_id")
    private UUID backupUserId;

    @Column(name = "engagement_type", nullable = false, length = 50)
    @Builder.Default
    private String engagementType = "FULL_SERVICE";

    @Column(name = "engagement_start", nullable = false)
    @Builder.Default
    private LocalDate engagementStart = LocalDate.now();

    @Column(name = "engagement_end")
    private LocalDate engagementEnd;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
