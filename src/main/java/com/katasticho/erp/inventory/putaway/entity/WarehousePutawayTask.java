package com.katasticho.erp.inventory.putaway.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "warehouse_putaway_task")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WarehousePutawayTask extends BaseEntity {

    @Column(name = "task_number", nullable = false, length = 50)
    private String taskNumber;

    @Column(name = "goods_receipt_id")
    private UUID goodsReceiptId;

    @Column(name = "warehouse_id", nullable = false)
    private UUID warehouseId;

    @Column(name = "source_location", nullable = false, length = 100)
    @Builder.Default
    private String sourceLocation = "RECEIVING_DOCK";

    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private String status = "PENDING"; // PENDING, IN_PROGRESS, COMPLETED, CANCELLED

    @Column(name = "assigned_to")
    private UUID assignedTo;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "task", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<WarehousePutawayLine> lines = new ArrayList<>();
}