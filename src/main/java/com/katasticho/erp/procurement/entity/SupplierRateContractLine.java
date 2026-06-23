package com.katasticho.erp.procurement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "supplier_rate_contract_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupplierRateContractLine extends BaseEntity {

    @Column(name = "supplier_rate_contract_id", nullable = false)
    private UUID supplierRateContractId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "unit_price", nullable = false, precision = 15, scale = 2)
    private BigDecimal unitPrice;

    @Column(name = "min_order_qty", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal minOrderQty = BigDecimal.ZERO;

    @Column(length = 500)
    private String notes;
}
