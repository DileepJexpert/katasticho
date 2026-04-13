package com.katasticho.erp.pricing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

/**
 * Price list header — one row per named list per org.
 *
 * <p>Part of v2 Feature 3. A price list is a reusable override of
 * {@code item.sale_price} that can be attached to a customer (or flagged
 * as the org default). The resolver at invoice-create time consults the
 * chain {@code customer.defaultPriceListId → org default → item.salePrice}
 * and returns whichever it finds first.
 *
 * <p>Currency lives here, not on {@link PriceListItem}, so a single list
 * can't mix currencies. An INR retail list and a USD export list are
 * two separate rows.
 */
@Entity
@Table(name = "price_list")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PriceList extends BaseEntity {

    @Column(nullable = false, length = 100)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    /**
     * At most one default list per org (enforced by a partial unique
     * index in V15). The service flips the previous default off in the
     * same tx when a new default is set.
     */
    @Column(name = "is_default", nullable = false)
    @Builder.Default
    private boolean isDefault = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
