package com.katasticho.erp.pricing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * One tier of a price list for one item.
 *
 * <p>Multiple rows per (list, item) are allowed — each with a different
 * {@code minQuantity} — so one SKU can have "1+", "10+", "100+" pricing
 * in the same list. The resolver walks tiers in {@code minQuantity DESC}
 * order and returns the first row whose {@code minQuantity} is &le; the
 * requested quantity.
 *
 * <p>Uniqueness is on {@code (priceListId, itemId, minQuantity)} so two
 * tiers can't collide at the same threshold. Soft-deleted rows are
 * ignored by the partial unique index so operator corrections don't
 * block re-creation.
 */
@Entity
@Table(name = "price_list_item")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PriceListItem extends BaseEntity {

    @Column(name = "price_list_id", nullable = false)
    private UUID priceListId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    /**
     * Lowest quantity at which this tier activates. Defaults to 1 (not
     * 0) so every tier row is reachable. The service rejects
     * {@code minQuantity <= 0} with a 400.
     */
    @Column(name = "min_quantity", nullable = false)
    @Builder.Default
    private BigDecimal minQuantity = BigDecimal.ONE;

    @Column(nullable = false)
    private BigDecimal price;
}
