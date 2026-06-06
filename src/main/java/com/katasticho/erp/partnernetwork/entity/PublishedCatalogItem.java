package com.katasticho.erp.partnernetwork.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "published_catalog_item")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PublishedCatalogItem extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "drug_master_id")
    private UUID drugMasterId;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    @Column(name = "published_sku")
    private String publishedSku;

    @Column(name = "hsn_code")
    private String hsnCode;

    @Column(name = "manufacturer")
    private String manufacturer;

    @Column(name = "pack_size")
    private String packSize;

    @Column(name = "category")
    private String category;

    @Column(name = "description")
    private String description;

    @Column(name = "published_mrp")
    private BigDecimal publishedMrp;

    @Column(name = "published_ptr")
    private BigDecimal publishedPtr;

    @Column(name = "min_order_qty")
    private BigDecimal minOrderQty;

    @Column(name = "availability_status", nullable = false)
    private String availabilityStatus;

    @Column(name = "is_active", nullable = false)
    private boolean isActive;
}
