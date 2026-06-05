package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "van_stock_transfer")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VanStockTransfer extends BaseEntity {

    @Column(name = "van_id", nullable = false)
    private UUID vanId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "transfer_type", nullable = false, length = 20)
    private String transferType;

    @Column(name = "transfer_date", nullable = false)
    private LocalDate transferDate;

    @Column(name = "route_execution_id")
    private UUID routeExecutionId;

    @Column(length = 20)
    @Builder.Default
    private String status = "DRAFT";

    private String notes;

    @Column(name = "confirmed_by")
    private UUID confirmedBy;

    @Column(name = "confirmed_at")
    private Instant confirmedAt;
}
