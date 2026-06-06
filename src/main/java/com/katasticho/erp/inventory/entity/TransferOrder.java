package com.katasticho.erp.inventory.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "transfer_order")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransferOrder extends BaseEntity {

    @Column(name = "transfer_number", nullable = false, length = 30)
    private String transferNumber;

    @Column(name = "from_warehouse_id", nullable = false)
    private UUID fromWarehouseId;

    @Column(name = "to_warehouse_id", nullable = false)
    private UUID toWarehouseId;

    @Column(name = "transfer_date", nullable = false)
    private LocalDate transferDate;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "shipped_at")
    private Instant shippedAt;

    @Column(name = "shipped_by")
    private UUID shippedBy;

    @Column(name = "received_at")
    private Instant receivedAt;

    @Column(name = "received_by")
    private UUID receivedBy;

    @OneToMany(mappedBy = "transferOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("createdAt ASC")
    @Builder.Default
    private List<TransferOrderLine> lines = new ArrayList<>();

    public void addLine(TransferOrderLine line) {
        lines.add(line);
        line.setTransferOrder(this);
    }
}
