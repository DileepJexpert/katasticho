package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "demand_forecast")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DemandForecast extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "forecast_month", nullable = false)
    private LocalDate forecastMonth;

    @Column(name = "forecast_qty", nullable = false)
    @Builder.Default
    private BigDecimal forecastQty = BigDecimal.ZERO;

    @Column(name = "actual_qty")
    private BigDecimal actualQty;

    @Column(length = 30, nullable = false)
    @Builder.Default
    private String method = "MOVING_AVG";

    @Column
    private BigDecimal confidence;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
