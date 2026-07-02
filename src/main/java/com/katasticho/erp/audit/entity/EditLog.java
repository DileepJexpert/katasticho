package com.katasticho.erp.audit.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

/**
 * Read-side mapping of the append-only {@code edit_log} audit trail.
 *
 * <p>Rows are NEVER written through JPA — {@code EditLogHibernateListener}
 * inserts them over raw JDBC on the business transaction's own connection.
 * This entity exists only so the query API can page/filter the trail.
 * Deliberately no {@code BaseEntity}: no org-stamping hooks, no soft delete,
 * no updated_at — the trail is immutable by construction.
 */
@Entity
@Table(name = "edit_log")
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EditLog {

    @Id
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "entity_type", nullable = false, length = 40)
    private String entityType;

    @Column(name = "entity_id", nullable = false)
    private UUID entityId;

    @Column(nullable = false, length = 10)
    private String action;

    @Column(name = "entity_label")
    private String entityLabel;

    /** JSON object {field: {"from": ..., "to": ...}} — null for CREATE / hard DELETE. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "field_changes", columnDefinition = "jsonb")
    private String fieldChanges;

    @Column(name = "changed_by")
    private UUID changedBy;

    @Column(name = "changed_at", nullable = false)
    private Instant changedAt;
}
