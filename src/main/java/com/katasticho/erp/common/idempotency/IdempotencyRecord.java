package com.katasticho.erp.common.idempotency;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * One processed (or in-flight) command request from an external caller that
 * supplied an {@code Idempotency-Key} header. Deliberately NOT a BaseEntity:
 * the row is infrastructure, written by the filter outside any tenant-scoped
 * business transaction, and must never be soft-deleted.
 */
@Entity
@Table(name = "idempotency_record")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IdempotencyRecord {

    public static final String STATUS_IN_PROGRESS = "IN_PROGRESS";
    public static final String STATUS_COMPLETED = "COMPLETED";

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "idempotency_key", nullable = false, updatable = false, length = 200)
    private String idempotencyKey;

    @Column(name = "request_method", nullable = false, updatable = false, length = 10)
    private String requestMethod;

    @Column(name = "request_path", nullable = false, updatable = false, length = 300)
    private String requestPath;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "response_status")
    private Integer responseStatus;

    @Column(name = "response_body", columnDefinition = "TEXT")
    private String responseBody;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    public boolean isExpired() {
        return expiresAt != null && expiresAt.isBefore(Instant.now());
    }
}
