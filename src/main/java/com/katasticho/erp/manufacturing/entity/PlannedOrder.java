package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "planned_order")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlannedOrder extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "mrp_run_id", nullable = false)
    @JsonIgnore
    private MrpRun mrpRun;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    /** PURCHASE | PRODUCTION */
    @Column(name = "order_type", nullable = false, length = 20)
    private String orderType;

    @Column(name = "planned_qty", nullable = false)
    @Builder.Default
    private BigDecimal plannedQty = BigDecimal.ZERO;

    @Column(name = "planned_start_date")
    private LocalDate plannedStartDate;

    @Column(name = "planned_end_date")
    private LocalDate plannedEndDate;

    @Column(name = "lead_time_days", nullable = false)
    @Builder.Default
    private int leadTimeDays = 7;

    @Column(name = "supplier_id")
    private UUID supplierId;

    /** PLANNED | CONVERTED | CANCELLED */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PLANNED";

    @Column(name = "purchase_order_id")
    private UUID purchaseOrderId;

    @Column(name = "work_order_id")
    private UUID workOrderId;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
