package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "work_order")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class WorkOrder extends BaseEntity {

    @Column(name = "work_order_number", nullable = false, length = 30)
    private String workOrderNumber;

    @Column(name = "finished_good_id", nullable = false)
    private UUID finishedGoodId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "quantity_to_produce", nullable = false)
    private BigDecimal quantityToProduce;

    @Column(name = "quantity_produced", nullable = false)
    @Builder.Default
    private BigDecimal quantityProduced = BigDecimal.ZERO;

    @Column(length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "planned_start_date")
    private LocalDate plannedStartDate;

    @Column(name = "planned_end_date")
    private LocalDate plannedEndDate;

    @Column(name = "actual_start_date")
    private LocalDate actualStartDate;

    @Column(name = "actual_end_date")
    private LocalDate actualEndDate;

    @Column(name = "raw_material_cost", nullable = false)
    @Builder.Default
    private BigDecimal rawMaterialCost = BigDecimal.ZERO;

    @Column(name = "direct_labor_cost", nullable = false)
    @Builder.Default
    private BigDecimal directLaborCost = BigDecimal.ZERO;

    @Column(name = "overhead_cost", nullable = false)
    @Builder.Default
    private BigDecimal overheadCost = BigDecimal.ZERO;

    @Column(name = "total_cost", nullable = false)
    @Builder.Default
    private BigDecimal totalCost = BigDecimal.ZERO;

    @Column(name = "unit_cost", nullable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "sales_order_id")
    private UUID salesOrderId;

    @Column(name = "routing_id")
    private UUID routingId;

    @Column(length = 10)
    @Builder.Default
    private String priority = "NORMAL";

    @Column(name = "scrap_qty")
    @Builder.Default
    private BigDecimal scrapQty = BigDecimal.ZERO;

    @Column(name = "scrap_cost")
    @Builder.Default
    private BigDecimal scrapCost = BigDecimal.ZERO;

    private String notes;

    @OneToMany(mappedBy = "workOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<WorkOrderLine> lines = new ArrayList<>();
}
