package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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

    @Column(name = "track_serial_numbers", nullable = false)
    @Builder.Default
    private boolean trackSerialNumbers = false;

    @Column(name = "reorder_level", nullable = false)
    @Builder.Default
    private BigDecimal reorderLevel = BigDecimal.ZERO;

    @Column(name = "reorder_quantity", nullable = false)
    @Builder.Default
    private BigDecimal reorderQuantity = BigDecimal.ZERO;

    /**
     * Tracker #34: how this composite item gets replenished.
     * <ul>
     *   <li>{@code MTO} — build on sale order only (SO→WO fires;
     *       reorder sweep skips).</li>
     *   <li>{@code MTS} — build to stock from reorder level
     *       (reorder sweep fires; SO→WO skips).</li>
     *   <li>{@code null} — legacy: both automations run.</li>
     * </ul>
     */
    @Column(name = "production_mode", length = 10)
    private String productionMode;

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

    @Column(name = "rack_location_id")
    private UUID rackLocationId;

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

    @Column(name = "weight_based_billing", nullable = false)
    @Builder.Default
    private boolean weightBasedBilling = false;

    @Column(name = "purchase_uom_id")
    private UUID purchaseUomId;

    @Column(name = "purchase_uom_conversion", precision = 15, scale = 4)
    private BigDecimal purchaseUomConversion;

    @Column(name = "purchase_price_per_uom", precision = 15, scale = 2)
    private BigDecimal purchasePricePerUom;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    /**
     * Phantom BOM flag — only meaningful for {@code itemType =
     * COMPOSITE}. A phantom sub-assembly is never stocked or produced
     * on its own: BOM explosion ({@code BomService.explode} and the MRP
     * engine) flattens through it, pulling in the phantom's own
     * components (scaled by the phantom line quantity) instead of
     * listing the phantom itself. Default FALSE keeps every existing
     * composite on the v1 single-level path.
     */
    @Column(name = "is_phantom", nullable = false)
    @Builder.Default
    private boolean phantom = false;

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

    // ── FSSAI / food compliance (V28) ────────────────────────────────

    /** 14-digit FSSAI license printed on the item's retail pack. */
    @Column(name = "fssai_license", length = 20)
    private String fssaiLicense;

    /** {@code VEGETARIAN | NON_VEGETARIAN | VEGAN | EGG} — drives the mandatory dot/triangle on the label. */
    @Column(name = "veg_classification", length = 20)
    private String vegClassification;

    /**
     * FSSAI / Codex major-allergen codes declared on the label, e.g.
     * {@code ["MILK","WHEAT_GLUTEN","SOY"]}. Empty = explicitly
     * "none of the major allergens"; NULL = not yet declared.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "allergens", columnDefinition = "jsonb")
    private List<String> allergens;

    /**
     * Per-serving / per-100g nutritional facts, e.g.
     * {@code {"calories_kcal":250, "protein_g":8, "fat_g":12,
     *         "carbs_g":30, "sugars_g":5, "sodium_mg":120}}.
     * FSSAI 2.2.2.1 spec — units are part of the key so callers
     * can render them directly.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "nutritional_info", columnDefinition = "jsonb")
    private Map<String, Object> nutritionalInfo;

    /** {@code BEST_BEFORE | USE_BY | EXPIRY}. */
    @Column(name = "date_marking_type", length = 20)
    private String dateMarkingType;

    /** Shelf life in days from manufacture — drives auto-expiry on a new batch. */
    @Column(name = "shelf_life_days")
    private Integer shelfLifeDays;
}
