package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * One child line of a composite item's bill of materials.
 *
 * <p>The parent is always an {@link Item} with {@code itemType =
 * COMPOSITE}. The child must be a simple {@code GOODS} (or {@code
 * SERVICE}) item — v1 rejects nested BOMs at service-layer save time to
 * keep the invoice-send explosion trivially non-recursive.
 *
 * <p>Quantity is how many units of the child make up ONE unit of the
 * parent. When an invoice line sells 3 parents, {@code
 * InventoryService.deductStockForInvoice()} posts {@code 3 ×
 * child.quantity} for every row returned by {@link
 * com.katasticho.erp.inventory.repository.BomComponentRepository#findByOrgIdAndParentItemIdAndIsDeletedFalse}.
 *
 * <p>A DB check constraint enforces {@code quantity > 0} and
 * {@code parent_item_id <> child_item_id}; the service layer surfaces
 * clearer error messages before the DB rejects.
 */
@Entity
@Table(name = "bom_component")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BomComponent extends BaseEntity {

    @Column(name = "parent_item_id", nullable = false)
    private UUID parentItemId;

    @Column(name = "child_item_id", nullable = false)
    private UUID childItemId;

    @Column(nullable = false)
    private BigDecimal quantity;

    /**
     * Expected process loss for this component, as a percentage of the
     * nominal quantity. {@code ManufacturingService.issueToProduction()}
     * issues {@code requiredQty × (1 + scrapPercent/100)} so the shop
     * floor receives enough material to cover the loss. Default 0 keeps
     * every existing BOM byte-for-byte unchanged.
     */
    @Builder.Default
    @Column(name = "scrap_percent")
    private BigDecimal scrapPercent = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "version")
    private Integer version = 1;

    @Column(name = "effective_from")
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(name = "change_notes")
    private String changeNotes;
}
