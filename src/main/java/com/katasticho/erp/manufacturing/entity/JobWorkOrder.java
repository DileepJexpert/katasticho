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
@Table(name = "job_work_order")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class JobWorkOrder extends BaseEntity {

    @Column(name = "job_work_number", nullable = false, length = 30)
    private String jobWorkNumber;

    @Column(name = "vendor_id", nullable = false)
    private UUID vendorId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "work_order_id")
    private UUID workOrderId;

    @Column(length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "processing_charges", nullable = false)
    @Builder.Default
    private BigDecimal processingCharges = BigDecimal.ZERO;

    @Column(name = "total_material_cost", nullable = false)
    @Builder.Default
    private BigDecimal totalMaterialCost = BigDecimal.ZERO;

    @Column(name = "total_cost", nullable = false)
    @Builder.Default
    private BigDecimal totalCost = BigDecimal.ZERO;

    @Column(name = "challan_number", length = 50)
    private String challanNumber;

    @Column(name = "planned_send_date")
    private LocalDate plannedSendDate;

    @Column(name = "planned_return_date")
    private LocalDate plannedReturnDate;

    @Column(name = "actual_send_date")
    private LocalDate actualSendDate;

    @Column(name = "actual_return_date")
    private LocalDate actualReturnDate;

    @Column(name = "gst_return_deadline")
    private LocalDate gstReturnDeadline;

    private String notes;

    @OneToMany(mappedBy = "jobWorkOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<JobWorkOrderLine> lines = new ArrayList<>();
}
