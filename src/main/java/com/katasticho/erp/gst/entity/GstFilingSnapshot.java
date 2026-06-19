package com.katasticho.erp.gst.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Provenance for a period's filing data — when it was last pulled and from
 * which source (real-time GSTR-2A, frozen GSTR-2B, or a manual upload). One row
 * per (org, return period); the ingest upserts it so the ITC-at-risk view can
 * show the owner how fresh the signal is.
 */
@Entity
@Table(name = "gst_filing_snapshot")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GstFilingSnapshot {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    /** Return period as YYYY-MM. */
    @Column(name = "return_period", nullable = false, length = 7)
    private String returnPeriod;

    /** GSTR_2A | GSTR_2B | UPLOAD. */
    @Column(name = "source", nullable = false, length = 20)
    private String source;

    @Column(name = "entry_count", nullable = false)
    @Builder.Default
    private int entryCount = 0;

    @Column(name = "refreshed_at", nullable = false)
    private Instant refreshedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
        if (refreshedAt == null) refreshedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
