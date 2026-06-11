package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "mrp_demand")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MrpDemand extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "mrp_run_id", nullable = false)
    @JsonIgnore
    private MrpRun mrpRun;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    /** SALES_ORDER | FORECAST | MRP_EXPLOSION */
    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType;

    @Column(name = "source_id")
    private UUID sourceId;

    @Column(name = "required_date", nullable = false)
    private LocalDate requiredDate;

    @Column(name = "required_qty", nullable = false)
    @Builder.Default
    private BigDecimal requiredQty = BigDecimal.ZERO;
}
