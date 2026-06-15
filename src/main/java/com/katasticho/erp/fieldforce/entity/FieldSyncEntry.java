package com.katasticho.erp.fieldforce.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** Idempotency record for one offline-synced field action. */
@Entity
@Table(name = "field_sync_entry")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldSyncEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "client_id", nullable = false, length = 120)
    private String clientId;

    @Column(name = "action_type", nullable = false, length = 40)
    private String actionType;

    /** APPLIED | FAILED. */
    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "result_summary", columnDefinition = "text")
    private String resultSummary;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
