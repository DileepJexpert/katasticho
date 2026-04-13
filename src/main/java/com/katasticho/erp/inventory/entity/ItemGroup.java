package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * A variant template — e.g. "Cotton Tee" with size and colour
 * attributes. Real stockable items (rows in {@link Item} with
 * {@code group_id} pointing here) are the *variants*; this row carries
 * only the metadata that distinguishes them from each other plus the
 * defaults child items inherit at creation.
 *
 * <p><b>Inheritance is one-shot.</b> When {@code ItemService.createItem}
 * sees a request with {@code groupId}, it copies the missing fields
 * (HSN, GST, UoM, default purchase/sale price) from this group into the
 * new item. Once saved, the item is self-contained — later edits to the
 * group do NOT cascade to historical variants. This matters for
 * invoice and report reproducibility: a tee that sold last year for
 * ₹399 with 5% GST should still show those numbers even after the
 * group's defaults change.
 *
 * <p><b>Attribute definitions are a closed list.</b> Every variant's
 * {@code variant_attributes} JSONB map must use only the keys defined
 * in {@link #attributeDefinitions} and only values from each key's
 * {@code values} list. The service-layer validator rejects anything
 * else with {@code GROUP_INVALID_ATTRIBUTE} or {@code GROUP_INVALID_VALUE}.
 */
@Entity
@Table(name = "item_group")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ItemGroup extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    /**
     * Optional SKU prefix used by the matrix bulk-create endpoint to
     * mint child SKUs as {@code <prefix>-<value1>-<value2>}. When NULL
     * the operator must supply each child SKU manually.
     */
    @Column(name = "sku_prefix", length = 50)
    private String skuPrefix;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    @Column(name = "gst_rate")
    private BigDecimal gstRate;

    @Column(name = "default_uom", length = 20)
    private String defaultUom;

    @Column(name = "default_purchase_price")
    private BigDecimal defaultPurchasePrice;

    @Column(name = "default_sale_price")
    private BigDecimal defaultSalePrice;

    /**
     * Closed list of variant attributes the group permits.
     * Stored as JSONB via Hibernate 6 + Jackson — see
     * {@link AttributeDefinition} for the per-element shape.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "attribute_definitions", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<AttributeDefinition> attributeDefinitions = new ArrayList<>();
}
