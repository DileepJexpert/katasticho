package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "production_scrap")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class ProductionScrap extends BaseEntity {

    @Column(name = "work_order_id", nullable = false)
    private UUID workOrderId;

    @Column(name = "job_card_id")
    private UUID jobCardId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "scrap_qty", nullable = false)
    private BigDecimal scrapQty;

    @Column(name = "unit_cost", nullable = false)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "scrap_cost", nullable = false)
    @Builder.Default
    private BigDecimal scrapCost = BigDecimal.ZERO;

    @Column(name = "reason_code_id")
    private UUID reasonCodeId;

    private String notes;

    @Column(name = "scrapped_at", nullable = false)
    @Builder.Default
    private Instant scrappedAt = Instant.now();
}
