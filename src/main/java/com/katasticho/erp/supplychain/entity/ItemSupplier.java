package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "item_supplier")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ItemSupplier extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "supplier_id", nullable = false)
    private UUID supplierId;

    @Column(name = "lead_time_days", nullable = false)
    @Builder.Default
    private Integer leadTimeDays = 7;

    @Column(name = "min_order_qty", nullable = false)
    @Builder.Default
    private BigDecimal minOrderQty = BigDecimal.ONE;

    @Column(name = "unit_price", nullable = false)
    @Builder.Default
    private BigDecimal unitPrice = BigDecimal.ZERO;

    @Column(name = "is_preferred", nullable = false)
    @Builder.Default
    private boolean preferred = false;

    @Column(name = "supplier_sku", length = 50)
    private String supplierSku;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
