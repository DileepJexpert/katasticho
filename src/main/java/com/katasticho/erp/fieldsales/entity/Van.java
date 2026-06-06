package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "van")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Van extends BaseEntity {

    @Column(nullable = false, length = 30)
    private String code;

    @Column(name = "vehicle_number", nullable = false, length = 30)
    private String vehicleNumber;

    @Column(length = 100)
    private String name;

    @Column(name = "vehicle_type", length = 30)
    @Builder.Default
    private String vehicleType = "VAN";

    @Column(name = "source_warehouse_id")
    private UUID sourceWarehouseId;

    @Column(name = "capacity_weight_kg")
    private BigDecimal capacityWeightKg;

    @Column(name = "capacity_volume_litre")
    private BigDecimal capacityVolumeLitre;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;
}
