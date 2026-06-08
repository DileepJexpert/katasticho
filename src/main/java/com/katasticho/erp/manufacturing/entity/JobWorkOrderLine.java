package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "job_work_order_line")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class JobWorkOrderLine extends BaseEntity {

    @Column(name = "job_work_order_id", nullable = false, insertable = false, updatable = false)
    private UUID jobWorkOrderId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "job_work_order_id", nullable = false)
    @JsonIgnore
    private JobWorkOrder jobWorkOrder;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "line_type", nullable = false, length = 20)
    @Builder.Default
    private String lineType = "MATERIAL";

    @Column(name = "sent_qty", nullable = false)
    @Builder.Default
    private BigDecimal sentQty = BigDecimal.ZERO;

    @Column(name = "received_qty", nullable = false)
    @Builder.Default
    private BigDecimal receivedQty = BigDecimal.ZERO;

    @Column(name = "wastage_qty", nullable = false)
    @Builder.Default
    private BigDecimal wastageQty = BigDecimal.ZERO;

    @Column(name = "unit_cost", nullable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "line_cost", nullable = false)
    @Builder.Default
    private BigDecimal lineCost = BigDecimal.ZERO;

    @Column(length = 20)
    @Builder.Default
    private String status = "PENDING";
}
