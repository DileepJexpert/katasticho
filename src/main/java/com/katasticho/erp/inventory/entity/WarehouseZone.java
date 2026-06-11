package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "warehouse_zone")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WarehouseZone extends BaseEntity {

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(nullable = false, length = 20)
    private String code;

    @Column(nullable = false)
    private String name;

    /** STORAGE | QUARANTINE | STAGING | CROSS_DOCK | RETURNS */
    @Column(name = "zone_type", nullable = false, length = 20)
    @Builder.Default
    private String zoneType = "STORAGE";

    @Column
    private BigDecimal capacity;

    @Column(name = "current_utilization", nullable = false)
    @Builder.Default
    private BigDecimal currentUtilization = BigDecimal.ZERO;

    @Column(name = "temperature_controlled", nullable = false)
    @Builder.Default
    private boolean temperatureControlled = false;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
