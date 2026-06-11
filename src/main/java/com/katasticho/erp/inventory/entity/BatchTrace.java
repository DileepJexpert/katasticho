package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "batch_trace")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BatchTrace extends BaseEntity {

    @Column(name = "batch_id", nullable = false)
    private UUID batchId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    /** FORWARD | BACKWARD */
    @Column(name = "trace_type", nullable = false, length = 20)
    private String traceType;

    @Column(name = "source_batch_id")
    private UUID sourceBatchId;

    @Column(name = "source_item_id")
    private UUID sourceItemId;

    @Column(name = "work_order_id")
    private UUID workOrderId;

    @Column(name = "movement_id")
    private UUID movementId;

    @Column
    private BigDecimal quantity;

    @Column(name = "traced_at", nullable = false)
    @Builder.Default
    private Instant tracedAt = Instant.now();
}
