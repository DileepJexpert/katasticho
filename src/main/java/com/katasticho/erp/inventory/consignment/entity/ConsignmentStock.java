package com.katasticho.erp.inventory.consignment.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "consignment_stock")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConsignmentStock extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "supplier_id", nullable = false)
    private UUID supplierId;

    @Column(nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ZERO;

    @Column(name = "unit_cost", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal unitCost = BigDecimal.ZERO;

    @Column(name = "consignment_date")
    private LocalDate consignmentDate;

    @Column(name = "agreement_ref", length = 50)
    private String agreementRef;

    /** ACTIVE | CLOSED */
    @Column(length = 20, nullable = false)
    @Builder.Default
    private String status = "ACTIVE";

    /** ON_SALE | PERIODIC */
    @Column(name = "settlement_method", length = 20, nullable = false)
    @Builder.Default
    private String settlementMethod = "ON_SALE";

    @Column(columnDefinition = "TEXT")
    private String notes;
}
