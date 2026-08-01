package com.katasticho.erp.inventory.cost.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Immutable explanation of how one or more inventory movements were costed. */
@Entity
@Table(name = "inventory_cost_event")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class InventoryCostEvent extends BaseEntity {

    @Column(name = "event_number", nullable = false, length = 30)
    private String eventNumber;

    @Column(name = "event_type", nullable = false, length = 30)
    private String eventType;

    @Column(name = "source_type", nullable = false, length = 40)
    private String sourceType;

    @Column(name = "source_id", nullable = false)
    private UUID sourceId;

    @Column(name = "source_number", length = 60)
    private String sourceNumber;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "total_amount", nullable = false)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "allocation_basis", nullable = false, length = 30)
    private String allocationBasis;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "POSTED";

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<InventoryCostComponent> components = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<InventoryCostAllocation> allocations = new ArrayList<>();

    public void addComponent(InventoryCostComponent component) {
        components.add(component);
        component.setEvent(this);
    }

    public void addAllocation(InventoryCostAllocation allocation) {
        allocations.add(allocation);
        allocation.setEvent(this);
    }
}
