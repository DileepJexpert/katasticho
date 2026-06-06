package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "picklist")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Picklist extends BaseEntity {

    @Column(name = "picklist_number", nullable = false, length = 30)
    private String picklistNumber;

    @Column(name = "sales_order_id", nullable = false)
    private UUID salesOrderId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "assigned_to")
    private UUID assignedTo;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @OneToMany(mappedBy = "picklist", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("createdAt ASC")
    @Builder.Default
    private List<PicklistLine> lines = new ArrayList<>();

    public void addLine(PicklistLine line) {
        lines.add(line);
        line.setPicklist(this);
    }
}
