package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Packaging level barcode definition (e.g. Unit 1x, Pack 10x, Carton 100x, Case 1000x).
 */
@Entity
@Table(name = "item_packaging_barcode")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ItemPackagingBarcode extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "barcode", nullable = false, length = 100)
    private String barcode;

    @Column(name = "packaging_level", nullable = false, length = 30)
    @Builder.Default
    private String packagingLevel = "UNIT"; // UNIT | STRIP | PACK | BOX | CARTON | CASE | PALLET

    @Column(name = "packaging_name", length = 100)
    private String packagingName;

    @Column(name = "conversion_factor", nullable = false, precision = 15, scale = 4)
    @Builder.Default
    private BigDecimal conversionFactor = BigDecimal.ONE;

    @Column(name = "uom_name", length = 50)
    private String uomName;

    @Column(name = "mrp", precision = 15, scale = 4)
    private BigDecimal mrp;

    @Column(name = "sale_price", precision = 15, scale = 4)
    private BigDecimal salePrice;

    @Column(name = "purchase_price", precision = 15, scale = 4)
    private BigDecimal purchasePrice;

    @Column(name = "is_primary", nullable = false)
    @Builder.Default
    private boolean isPrimary = false;

    @Column(name = "notes", length = 255)
    private String notes;
}
