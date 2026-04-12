package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * Unit of Measure master. Org-scoped. An organisation typically has a
 * small set of UoMs seeded at creation (PCS, BOX, STRIP, KG, GM, LTR,
 * ML, ...). Every {@link Item} points at a base UoM via
 * {@code item.base_uom_id}; all stock_movement quantities for that item
 * are recorded in its base UoM. Purchase and sale UoMs (future work)
 * use {@link UomConversion} to translate at I/O boundaries.
 */
@Entity
@Table(name = "uom")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Uom extends BaseEntity {

    @Column(nullable = false, length = 50)
    private String name;

    @Column(nullable = false, length = 20)
    private String abbreviation;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UomCategory category;

    /**
     * True for the canonical UoM of its category (e.g. KG for WEIGHT,
     * LTR for VOLUME). Used to resolve a sensible default when an item
     * is imported without an explicit UoM.
     */
    @Column(name = "is_base", nullable = false)
    @Builder.Default
    private boolean base = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
