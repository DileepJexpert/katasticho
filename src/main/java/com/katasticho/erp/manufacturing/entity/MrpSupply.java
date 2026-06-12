package com.katasticho.erp.manufacturing.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "mrp_supply")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MrpSupply extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "mrp_run_id", nullable = false)
    @JsonIgnore
    private MrpRun mrpRun;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    /** ON_HAND | PURCHASE_ORDER | WORK_ORDER */
    @Column(name = "supply_type", nullable = false, length = 30)
    private String supplyType;

    @Column(name = "supply_id")
    private UUID supplyId;

    @Column(name = "available_date", nullable = false)
    private LocalDate availableDate;

    @Column(name = "available_qty", nullable = false)
    @Builder.Default
    private BigDecimal availableQty = BigDecimal.ZERO;
}
