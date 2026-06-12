package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Secondary output (co-product / by-product) of producing one unit of
 * {@code parentItemId}.
 *
 * <p>When {@code ManufacturingService.receiveFinishedGoods()} receives
 * quantity Q of the main finished good, it also records a
 * PRODUCTION_RECEIVE of {@code Q × quantityPerUnit} for each
 * co-product, costed at {@code total WO cost ×
 * costAllocationPercent/100} spread over the planned co-product
 * quantity. The main FG keeps the remaining percentage. With no
 * co-products defined the receipt path is byte-for-byte unchanged.
 */
@Entity
@Table(name = "bom_co_product")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BomCoProduct extends BaseEntity {

    @Column(name = "parent_item_id", nullable = false)
    private UUID parentItemId;

    @Column(name = "co_product_item_id", nullable = false)
    private UUID coProductItemId;

    @Column(name = "quantity_per_unit", nullable = false)
    private BigDecimal quantityPerUnit;

    @Builder.Default
    @Column(name = "cost_allocation_percent", nullable = false)
    private BigDecimal costAllocationPercent = BigDecimal.ZERO;
}
