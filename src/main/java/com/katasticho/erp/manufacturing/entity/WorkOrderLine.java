package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "work_order_line")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class WorkOrderLine extends BaseEntity {

    @Column(name = "work_order_id", nullable = false, insertable = false, updatable = false)
    private UUID workOrderId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "work_order_id", nullable = false)
    @JsonIgnore
    private WorkOrder workOrder;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "required_qty", nullable = false)
    private BigDecimal requiredQty;

    @Column(name = "issued_qty", nullable = false)
    @Builder.Default
    private BigDecimal issuedQty = BigDecimal.ZERO;

    @Column(name = "unit_cost", nullable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "line_cost", nullable = false)
    @Builder.Default
    private BigDecimal lineCost = BigDecimal.ZERO;

    @Column(length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(name = "batch_number", length = 50)
    private String batchNumber;
}
