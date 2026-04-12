package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Conversion factor between two {@link Uom}s.
 *
 * <p>Two flavours are supported:
 * <ul>
 *   <li><b>Org-wide</b> — {@code itemId == null}. The conversion applies
 *       to any item using this (from, to) pair. Used for universal
 *       relations like 1 KG = 1000 GM.</li>
 *   <li><b>Per-item</b> — {@code itemId != null}. Overrides the org-wide
 *       rule for one specific item. Used for pack sizes that differ by
 *       product, e.g. 1 BOX of Paracetamol = 10 STRIP but 1 BOX of
 *       Syringes = 100 PCS.</li>
 * </ul>
 *
 * <p>Resolution rule (see {@code UomService.convert}): per-item override
 * wins over org-wide; identity (same UoM) is always factor = 1;
 * otherwise the conversion fails and the caller must fix their data.
 */
@Entity
@Table(name = "uom_conversion")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UomConversion extends BaseEntity {

    /** Nullable — null = org-wide conversion. */
    @Column(name = "item_id")
    private UUID itemId;

    @Column(name = "from_uom_id", nullable = false)
    private UUID fromUomId;

    @Column(name = "to_uom_id", nullable = false)
    private UUID toUomId;

    @Column(nullable = false, precision = 18, scale = 6)
    private BigDecimal factor;
}
