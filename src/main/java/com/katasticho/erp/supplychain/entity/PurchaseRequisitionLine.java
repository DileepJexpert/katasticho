package com.katasticho.erp.supplychain.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "purchase_requisition_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PurchaseRequisitionLine extends BaseEntity {

    @Column(name = "requisition_id", nullable = false, insertable = false, updatable = false)
    private UUID requisitionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requisition_id", nullable = false)
    @JsonIgnore
    private PurchaseRequisition requisition;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "required_qty", nullable = false)
    private BigDecimal requiredQty;

    @Column(name = "estimated_unit_price", nullable = false)
    @Builder.Default
    private BigDecimal estimatedUnitPrice = BigDecimal.ZERO;

    @Column(name = "estimated_line_total", nullable = false)
    @Builder.Default
    private BigDecimal estimatedLineTotal = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
