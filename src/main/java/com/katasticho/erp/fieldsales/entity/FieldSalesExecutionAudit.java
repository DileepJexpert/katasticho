package com.katasticho.erp.fieldsales.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Immutable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Immutable, structured audit record for every admin override that bypasses
 * normal field-sales assignment enforcement. Written once on execution start;
 * never updated or deleted by application code.
 */
@Entity
@Table(name = "field_sales_execution_audit")
@Immutable
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
public class FieldSalesExecutionAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** The org this audit record belongs to. */
    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    /** The RouteExecution that was created under override. */
    @Column(name = "execution_id", nullable = false, updatable = false)
    private UUID executionId;

    /** The admin user who performed the override. */
    @Column(name = "actor_id", nullable = false, updatable = false)
    private UUID actorId;

    /** The salesperson for whom the execution was created. */
    @Column(name = "salesperson_id", nullable = false, updatable = false)
    private UUID salespersonId;

    /** Route for which the override was granted. */
    @Column(name = "route_id", nullable = false, updatable = false)
    private UUID routeId;

    /** Van used in the execution (may be null when no van). */
    @Column(name = "van_id", updatable = false)
    private UUID vanId;

    /** Date of the route execution. */
    @Column(name = "execution_date", nullable = false, updatable = false)
    private LocalDate executionDate;

    /**
     * Type of override: ROUTE_UNASSIGNED | VAN_MISMATCH | BOTH.
     */
    @Column(name = "override_type", length = 30, nullable = false, updatable = false)
    private String overrideType;

    /** The reason supplied by the admin. Never null or blank. */
    @Column(name = "override_reason", nullable = false, updatable = false, length = 1000)
    private String overrideReason;

    /** UTC instant at which the override was recorded. */
    @Column(name = "audited_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant auditedAt = Instant.now();
}
