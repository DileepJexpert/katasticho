package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "operation")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Operation extends BaseEntity {

    @Column(nullable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 100)
    private String name;

    private String description;

    @Column(name = "default_workstation_id")
    private UUID defaultWorkstationId;

    @Column(name = "setup_time_minutes", nullable = false)
    @Builder.Default
    private int setupTimeMinutes = 0;

    @Column(name = "run_time_minutes_per_unit", nullable = false)
    @Builder.Default
    private BigDecimal runTimeMinutesPerUnit = BigDecimal.ZERO;
}
