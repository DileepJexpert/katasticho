package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Item master — both physical goods and services.
 * SERVICE items have {@code trackInventory=false} and never produce
 * stock_movement rows.
 */
@Entity
@Table(name = "item")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Item extends BaseEntity {

    @Column(nullable = false, length = 50)
    private String sku;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "item_type", nullable = false, length = 20)
    @Builder.Default
    private ItemType itemType = ItemType.GOODS;

    @Column(length = 100)
    private String category;

    @Column(length = 100)
    private String brand;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    @Column(name = "unit_of_measure", nullable = false, length = 20)
    @Builder.Default
    private String unitOfMeasure = "PCS";

    /**
     * FK into {@code uom}. Populated by ItemService on create/update by
     * looking up {@link #unitOfMeasure} in the current org's UoM master.
     * Kept nullable at DB level (see V13) for backwards compatibility
     * during the v2 rollout — a follow-up migration will enforce NOT
     * NULL once every code path is verified to set it.
     */
    @Column(name = "base_uom_id")
    private UUID baseUomId;

    @Column(name = "purchase_price", nullable = false)
    @Builder.Default
    private BigDecimal purchasePrice = BigDecimal.ZERO;

    @Column(name = "sale_price", nullable = false)
    @Builder.Default
    private BigDecimal salePrice = BigDecimal.ZERO;

    private BigDecimal mrp;

    @Column(name = "gst_rate", nullable = false)
    @Builder.Default
    private BigDecimal gstRate = BigDecimal.ZERO;

    @Column(name = "track_inventory", nullable = false)
    @Builder.Default
    private boolean trackInventory = true;

    @Column(name = "reorder_level", nullable = false)
    @Builder.Default
    private BigDecimal reorderLevel = BigDecimal.ZERO;

    @Column(name = "reorder_quantity", nullable = false)
    @Builder.Default
    private BigDecimal reorderQuantity = BigDecimal.ZERO;

    @Column(name = "revenue_account_code", length = 20)
    private String revenueAccountCode;

    @Column(name = "cogs_account_code", length = 20)
    private String cogsAccountCode;

    @Column(name = "inventory_account_code", length = 20)
    private String inventoryAccountCode;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
