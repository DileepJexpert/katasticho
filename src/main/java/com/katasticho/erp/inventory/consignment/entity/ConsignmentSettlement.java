package com.katasticho.erp.inventory.consignment.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "consignment_settlement")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConsignmentSettlement extends BaseEntity {

    @Column(name = "consignment_stock_id", nullable = false)
    private UUID consignmentStockId;

    @Column(name = "settlement_number", length = 30)
    private String settlementNumber;

    @Column(name = "quantity_sold", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal quantitySold = BigDecimal.ZERO;

    @Column(name = "unit_cost", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "total_amount", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "settlement_date")
    private LocalDate settlementDate;

    /** DRAFT | SETTLED */
    @Column(length = 20, nullable = false)
    @Builder.Default
    private String status = "DRAFT";

    @Column(columnDefinition = "TEXT")
    private String notes;
}
