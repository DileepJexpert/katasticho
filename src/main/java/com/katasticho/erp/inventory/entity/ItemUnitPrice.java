package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "item_unit_price")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ItemUnitPrice extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "uom_id", nullable = false)
    private UUID uomId;

    @Column(name = "conversion_factor", nullable = false, precision = 15, scale = 4)
    private BigDecimal conversionFactor;

    @Column(name = "custom_price", precision = 15, scale = 2)
    private BigDecimal customPrice;
}
