package com.katasticho.erp.franchise.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "franchise_catalog_policy")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FranchiseCatalogPolicy extends BaseEntity {

    @Column(name = "auto_sync_new_items", nullable = false)
    @Builder.Default
    private boolean autoSyncNewItems = true;

    @Column(name = "allow_branch_price_override", nullable = false)
    @Builder.Default
    private boolean allowBranchPriceOverride = true;

    @Column(name = "max_discount_from_mrp_percent", precision = 5, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal maxDiscountFromMrpPercent = new BigDecimal("15.00");

    @Column(name = "min_margin_percent", precision = 5, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal minMarginPercent = new BigDecimal("8.00");

    @Column(name = "sync_mode", nullable = false, length = 30)
    @Builder.Default
    private String syncMode = "ALL_ITEMS"; // ALL_ITEMS, ACTIVE_ONLY, CATEGORY_FILTERED
}