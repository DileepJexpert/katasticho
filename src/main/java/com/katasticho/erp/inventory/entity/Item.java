package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
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

    @Column(length = 50)
    private String barcode;

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

    @Column(name = "default_tax_group_id")
    private UUID defaultTaxGroupId;

    @Column(name = "track_inventory", nullable = false)
    @Builder.Default
    private boolean trackInventory = true;

    /**
     * FEFO / batch tracking opt-in. Default FALSE so every existing item
     * continues to use the v1 aggregate path. Items with this flag ON
     * MUST have an associated {@link StockBatch} for every stock
     * movement — the service layer enforces that invariant via
     * {@code InventoryService.recordMovement()}.
     */
    @Column(name = "track_batches", nullable = false)
    @Builder.Default
    private boolean trackBatches = false;

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

    @Column(length = 100)
    private String manufacturer;

    @Column(name = "preferred_vendor_id")
    private UUID preferredVendorId;

    @Column(precision = 12, scale = 4)
    private BigDecimal weight;

    @Column(name = "weight_unit", length = 10)
    private String weightUnit;

    @Column(name = "length", precision = 12, scale = 4)
    private BigDecimal length;

    @Column(name = "width", precision = 12, scale = 4)
    private BigDecimal width;

    @Column(name = "height", precision = 12, scale = 4)
    private BigDecimal height;

    @Column(name = "dimension_unit", length = 10)
    private String dimensionUnit;

    @Column(name = "drug_schedule", length = 10)
    private String drugSchedule;

    @Column(columnDefinition = "TEXT")
    private String composition;

    @Column(name = "dosage_form", length = 50)
    private String dosageForm;

    @Column(name = "pack_size", length = 50)
    private String packSize;

    @Column(name = "storage_condition", length = 100)
    private String storageCondition;

    @Column(name = "prescription_required", nullable = false)
    @Builder.Default
    private boolean prescriptionRequired = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    /**
     * Optional FK to {@link ItemGroup}. When non-NULL this item is one
     * variant of the group (e.g. "Cotton Tee — Red, M") and
     * {@link #variantAttributes} carries the size/colour/etc. that
     * distinguishes it from siblings.
     *
     * <p>v1 keeps the relation thin — no JPA {@code @ManyToOne} so the
     * existing item DTO stays a flat record and there is no lazy-load
     * surprise inside {@code toResponse}. The service joins to the
     * group via {@code ItemGroupRepository.findById} when it needs
     * defaults at create time.
     */
    @Column(name = "group_id")
    private UUID groupId;

    /**
     * Variant attributes for this item, e.g. {@code {"size":"M","color":"Red"}}.
     * Empty by default. The DB CHECK constraint
     * {@code chk_item_variant_attrs_not_empty} forbids the combination
     * (group_id IS NOT NULL, variant_attributes = '{}'). The service
     * layer additionally validates every key/value against the parent
     * group's {@code attribute_definitions} list.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "variant_attributes", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, String> variantAttributes = new HashMap<>();
}
