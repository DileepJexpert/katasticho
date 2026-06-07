package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "routing_operation")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class RoutingOperation extends BaseEntity {

    @Column(name = "routing_id", nullable = false, insertable = false, updatable = false)
    private UUID routingId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "routing_id", nullable = false)
    @JsonIgnore
    private Routing routing;

    @Column(name = "operation_id", nullable = false)
    private UUID operationId;

    @Column(name = "workstation_id")
    private UUID workstationId;

    @Column(name = "sequence_number", nullable = false)
    private int sequenceNumber;

    @Column(name = "setup_time_override")
    private Integer setupTimeOverride;

    @Column(name = "run_time_override")
    private BigDecimal runTimeOverride;
}
