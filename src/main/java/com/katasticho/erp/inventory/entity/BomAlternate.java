package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.util.UUID;

/**
 * One registered substitute material for a {@link BomComponent} line.
 *
 * <p>An alternate does NOT change the BOM itself — it whitelists an
 * item that may replace the component's primary child on a specific
 * work order via {@code POST
 * /api/v1/manufacturing/work-orders/{id}/lines/{lineId}/substitute}
 * (only while the WO is still DRAFT, i.e. before any stock moved).
 *
 * <p>{@code priority} orders alternates when more than one exists
 * (1 = first choice).
 */
@Entity
@Table(name = "bom_alternate")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BomAlternate extends BaseEntity {

    @Column(name = "bom_component_id", nullable = false)
    private UUID bomComponentId;

    @Column(name = "alternate_item_id", nullable = false)
    private UUID alternateItemId;

    @Builder.Default
    @Column(nullable = false)
    private Integer priority = 1;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
