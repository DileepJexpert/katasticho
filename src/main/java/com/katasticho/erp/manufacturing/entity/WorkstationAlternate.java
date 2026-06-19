package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * A sanctioned fallback workstation for a routing operation
 * (tracker #15). When the operation's primary workstation
 * ({@link RoutingOperation#getWorkstationId()}) is at capacity or
 * inactive, production can be routed to the highest-priority alternate
 * with capacity.
 *
 * <p>Mirrors {@code BomAlternate} (substitute materials): an ordered,
 * org-scoped, soft-deletable list keyed by the parent entity id.
 * Lower {@link #priority} wins.
 */
@Entity
@Table(name = "workstation_alternate")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class WorkstationAlternate extends BaseEntity {

    @Column(name = "routing_operation_id", nullable = false)
    private UUID routingOperationId;

    @Column(name = "workstation_id", nullable = false)
    private UUID workstationId;

    @Column(nullable = false)
    private int priority;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
