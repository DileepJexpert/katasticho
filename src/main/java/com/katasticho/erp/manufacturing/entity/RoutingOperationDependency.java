package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * Directed edge in the routing-operation DAG (tracker #16).
 *
 * <p>Each row says "{@link #routingOperationId} cannot start until
 * {@link #predecessorRoutingOperationId} is complete". A routing op
 * can have zero, one, or many predecessors. Cycle prevention lives in
 * {@code RoutingService.addOperationDependency} — the DB has no
 * structural way to enforce acyclicity.
 *
 * <p>When an op has no rows in this table the planner falls back to
 * {@link RoutingOperation#getSequenceNumber()} for ordering, so legacy
 * routings keep working without any data migration.
 */
@Entity
@Table(name = "routing_operation_dependency")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class RoutingOperationDependency extends BaseEntity {

    @Column(name = "routing_operation_id", nullable = false)
    private UUID routingOperationId;

    @Column(name = "predecessor_routing_operation_id", nullable = false)
    private UUID predecessorRoutingOperationId;
}
