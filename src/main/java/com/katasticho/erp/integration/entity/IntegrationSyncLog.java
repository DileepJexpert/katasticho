package com.katasticho.erp.integration.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "integration_sync_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IntegrationSyncLog extends BaseEntity {

    @Column(name = "integration_id", nullable = false)
    private UUID integrationId;

    /** e.g. CONTACTS, INVOICES, ITEMS, PAYMENTS */
    @Column(name = "sync_type", length = 30)
    private String syncType;

    /** IMPORT | EXPORT */
    @Column(length = 10)
    private String direction;

    /** RUNNING | SUCCESS | PARTIAL | FAILED */
    @Column(length = 20, nullable = false)
    @Builder.Default
    private String status = "RUNNING";

    @Column(name = "records_processed", nullable = false)
    @Builder.Default
    private int recordsProcessed = 0;

    @Column(name = "records_failed", nullable = false)
    @Builder.Default
    private int recordsFailed = 0;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;
}
