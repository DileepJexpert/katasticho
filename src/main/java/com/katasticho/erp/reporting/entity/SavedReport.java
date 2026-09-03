package com.katasticho.erp.reporting.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "saved_report")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavedReport {

    @Id
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description")
    private String description;

    @Column(name = "base_report_key", nullable = false)
    private String baseReportKey;

    /** JSON array of column key strings */
    @Column(name = "column_keys", nullable = false, columnDefinition = "TEXT")
    private String columnKeys;

    /** JSON object of filter criteria */
    @Column(name = "filters", columnDefinition = "TEXT")
    private String filters;

    /** Comma-separated or JSON array of tags */
    @Column(name = "tags")
    private String tags;

    @Column(name = "is_public")
    private boolean isPublic;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @Column(name = "is_deleted")
    private boolean deleted;

    @PrePersist
    void prePersist() {
        if (id == null) id = UUID.randomUUID();
    }
}
