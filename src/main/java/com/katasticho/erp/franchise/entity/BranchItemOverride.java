package com.katasticho.erp.franchise.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "branch_item_override")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BranchItemOverride extends BaseEntity {

    @Column(name = "branch_id", nullable = false)
    private UUID branchId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "custom_selling_price", precision = 15, scale = 4, nullable = false)
    private BigDecimal customSellingPrice;

    @Column(name = "custom_mrp", precision = 15, scale = 4)
    private BigDecimal customMrp;

    @Column(name = "min_retail_price", precision = 15, scale = 4)
    private BigDecimal minRetailPrice;

    @Column(name = "is_override_active", nullable = false)
    @Builder.Default
    private boolean overrideActive = true;
}