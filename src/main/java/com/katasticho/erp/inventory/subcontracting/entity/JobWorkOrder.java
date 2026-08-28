package com.katasticho.erp.inventory.subcontracting.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "job_work_order")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JobWorkOrder extends BaseEntity {

    @Column(name = "order_number", nullable = false, length = 50)
    private String orderNumber;

    @Column(name = "job_worker_id", nullable = false)
    private UUID jobWorkerId;

    @Column(name = "order_date", nullable = false)
    private LocalDate orderDate;

    @Column(name = "expected_return_date")
    private LocalDate expectedReturnDate;

    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private String status = "DRAFT"; // DRAFT | ISSUED | PARTIALLY_RECEIVED | COMPLETED | CANCELLED

    @Column(name = "process_description", length = 255)
    private String processDescription;

    @Column(name = "total_issued_value", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal totalIssuedValue = BigDecimal.ZERO;

    @Column(name = "total_received_value", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal totalReceivedValue = BigDecimal.ZERO;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;
}
